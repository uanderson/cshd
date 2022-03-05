#!/bin/bash

set -e
source "${0%/*}/common.sh"

CSHD_HOME="$(pwd)"
BLACKBOX_BIN="$CSHD_HOME/.blackbox"

# Activates all the profiles specified by the
# 'activation' property in the 'cshd.conf' file.
function activate() {
  local profile_dir
  local profile_uri
  local profile_branch
  local is_freshly_cloned

  profile_dir="$CSHD_HOME/profiles/$1"
  profile_uri="$(get_conf $1.'repository.uri')"
  profile_branch="$(get_conf $1.'repository.branch')"
  is_freshly_cloned=false

  if [[ ! -d "$profile_dir" ]]; then
    git clone --quiet --single-branch --branch "$profile_branch" "$profile_uri" "$profile_dir"

    is_freshly_cloned=true
  fi

  cd "$profile_dir" || fatal "Profile directory is missing"

  local head_revision
  local remote_revision
  head_revision="$(git rev-parse HEAD)"
  remote_revision="$(git rev-parse "$profile_branch")"

  if [[ "$is_freshly_cloned" == true ]] || [[ "$head_revision" != "$remote_revision" ]]; then
    git -C "$profile_dir" clean --force --quiet -d -x
    git -C "$profile_dir" reset --hard --quiet HEAD
    git -C "$profile_dir" pull --quiet

    "$BLACKBOX_BIN"/blackbox_decrypt_all_files

    if [[ ! -f "$profile_dir/docker.env" ]]; then
      fatal "Docker environment file is missing"
    fi

    export CSHD_PROFILE_DIR="$profile_dir"

    docker compose --env-file "$profile_dir/docker.env" up --detach
  fi
}

IFS=',' read -ra profiles <<<"$(get_conf 'activation')"
for profile in "${profiles[@]}"; do
  activate "$profile"
done
