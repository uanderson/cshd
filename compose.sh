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
  local profile_behind
  local profile_behind_count

  profile_dir="$CSHD_HOME/profiles/$1"
  profile_branch="$(get_conf "repository.branch" "$1")"

  cd "$profile_dir" || fatal "Profile directory not found"

  profile_behind_count="$(git rev-list --left-right "${profile_branch}"...origin/"${profile_branch}" 2> /dev/null | grep -c '^>')"

  if [[ "$profile_behind_count" = 0 ]]; then
    profile_behind_count=''
  else
    profile_behind=true
  fi

  # Execute if there are changes
  if [[ -n "$profile_behind" ]]; then
    git fetch origin "$profile_branch"
    git reset --hard
    git clean --force -d -x
    git pull

    while IFS="" read -r encrypted_file || [ -n "$encrypted_file" ]; do
      "$BLACKBOX_HOME"/blackbox_decrypt_file "$encrypted_file"
    done <.blackbox/blackbox-files.txt

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
