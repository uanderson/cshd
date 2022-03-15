#!/bin/bash

set -e
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
  local local_revision
  local origin_revision

  profile_dir="$CSHD_HOME/profiles/$1"
  profile_branch="$(get_conf "repository.branch" "$1")"

  cd "$profile_dir" || fatal "Profile directory not found"

  local_revision="$(git rev-parse "$profile_branch")"
  origin_revision="$(git rev-parse origin)"

  # Fetches any new updates to the stack
  git fetch origin "$profile_branch"

  # If the origin revision is different from what
  # we have, pull the changes and update the stack
  if [[ "$local_revision" != "$origin_revision" ]]; then
    git reset --hard
    git clean --force -d -x
    git pull

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
