#!/bin/bash

source "${0%/*}/common.sh"

# Where we start.
#
# @private
function run() {
  local profile

  IFS=',' read -ra profiles <<<"$(get_conf 'profiles')"

  if [[ -z "$profiles" ]]; then
    compose "default"
  else
    for profile in "${profiles[@]}"; do
      compose "$profile"
    done
  fi
}

# Composes the stack for the profile.
#
# $1 - Profile name (optional)
#
# @private
function compose() {
  local profile_dir
  local profile_branch

  profile_dir="$CSHD_HOME/profiles/$1"
  profile_branch="$(get_conf "repository.branch" "$1")"

  cd "$profile_dir" || fatal "Profile directory not found"

  local remote_branch
  local local_branch

  local_branch=$(git rev-parse --abbrev-ref --symbolic-full-name @)
  remote_branch=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})

  if [[ "$local_branch" = "$remote_branch" ]]; then
    echo "No remote changes found"
  elif [[ "$(git rev-list --left-right $local_branch...$remote_branch)" ]]; then
    git reset --hard origin/"$profile_branch"

    git pull --force

    "$BLACKBOX_HOME"/blackbox_decrypt_all_files

    # The `docker.env`'s existence means that the environment
    # was able to decrypt the secrets and we can proceed
    # with the composition of the stack
    if [[ -f "$profile_dir/docker.env" ]]; then
      # Exports the current profile directory being
      # activated in order to docker compose to know
      # where to find its environment file
      export CSHD_PROFILE_DIR="$profile_dir"

      docker compose --env-file "$profile_dir/docker.env" up --detach
    fi
  fi
}

run
