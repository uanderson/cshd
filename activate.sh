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
    activate "default"
  else
    for profile in "${profiles[@]}"; do
      activate "$profile"
    done
  fi
}

# Clones the remote profile repository.
#
# $1 - Profile name
#
# @public
function activate() {
  local profile_dir
  profile_dir="$CSHD_HOME/profiles/$1"

  if [[ -d "$profile_dir" ]]; then
    rm -rf "$profile_dir"
  fi

  git clone --single-branch \
    --branch "$(get_conf "repository.branch" "$1")" \
    "$(get_conf "repository.uri" "$1")" \
    "$profile_dir"

  "$profile_dir"/.hooks/preactivate.sh >/dev/null 2>&1
  cd "$profile_dir" || fatal "Profile directory $profile_dir not found"

  if [[ "$(get_conf "gpg.generate" "$1")" != "false" ]]; then
    generate_gpg "$1"
  fi

  "$profile_dir"/.hooks/postactivate.sh >/dev/null 2>&1
}

# Generates a GPG key for the name and e-mail
# configuration within the repository.
#
# By default, the key is of type RSA and has
# no protection.
#
# $1 - Profile name
#
# @private
function generate_gpg() {
  local name
  local email
  local template

  name="$(get_conf "gpg.name" "$1")"
  email="$(get_conf "gpg.email" "$1")"
  template="$(mktemp)"

  if [[ ! "$(gpg --list-secret-key)" == *"$email"* ]]; then
    sed "s/\$name/$name/g; s/\$email/$email/g" "$CSHD_TEMPLATES/gpg/default.txt" | tee "$template" >/dev/null
    gpg --batch --generate-key "$template"

    if [[ "$(get_conf "gpg.commit" "$1")" != "false" ]]; then
      commit_gpg "$email" "$1"
    fi
  fi

  rm -f "$template"
}

# Generates a new branch and add the GPG key
# to the blackbox ring, committing and pushing
# it afterwards.
#
# $1 - GPG e-mail
# $2 - Profile name
#
# @private
function commit_gpg() {
  local branch_name
  branch_name="blackbox/$(date +"%Y-%M-%d%T" | md5sum | head -c 7)"

  git config user.name "$(get_conf "git.name" "$2")"
  git config user.email "$(get_conf "git.email" "$2")"
  git checkout -b "$branch_name"

  "$BLACKBOX_HOME"/blackbox_addadmin "$1"

  git add .
  git commit \
    -m "chore: add admin" \
    -m "Administrator '$1' added"

  git push -u origin "$branch_name"
  git checkout "$(get_conf "repository.branch" "$2")"
}

run
