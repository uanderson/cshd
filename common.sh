#!/bin/bash

# CSHD's defaults
: "${CSHD_HOME:="$HOME"/cshd}"
: "${CSHD_CONF_FILE:=/etc/cshd/cshd.conf}"
: "${CSHD_TEMPLATES:="$(
  cd "${0%/*}"
  pwd
)"/.templates}"

# Where are we?
: "${BLACKBOX_HOME:="$(
  cd "${0%/*}"
  pwd
)"/.blackbox}"

# Gets the configuration value for the environment.
# When a profile is provided, it delegates the search
# of the configuration to `get_profile_conf`.
#
# $1 - Property name
# $2 - Profile name (optional)
#
# Returns the property value
#
# @public
function get_conf() {
  local profile_conf_file
  local profile_conf_value
  local local_conf_value
  local system_conf_value

  if [[ ! -f "$CSHD_CONF_FILE" ]]; then
    fatal "Configuration file $CSHD_CONF_FILE not found"
  fi

  profile_conf_file="$CSHD_HOME/profiles/$2/cshd.conf"

  if [[ -z $2 ]]; then
    grep_conf "$CSHD_CONF_FILE" "$1"
  else
    profile_conf_value="$(grep_conf "$profile_conf_file" "$1")"
    local_conf_value="$(grep_conf "$CSHD_CONF_FILE" "$2.$1")"
    system_conf_value="$(grep_conf "$CSHD_CONF_FILE" "$1")"

    if [[ -n "$profile_conf_value" ]]; then
      echo "$profile_conf_value"
    elif [[ -n "$local_conf_value" ]]; then
      echo "$local_conf_value"
    else
      echo "$system_conf_value"
    fi
  fi
}

# Gets the configuration from the file.
#
# $1 - Property name
# $2 - File name
#
# Returns the property value.
#
# @private
function grep_conf() {
  grep -s "${2}" "$1" | cut -d'=' -f2 | tr -d '\r' | xargs
}

# @public
function fatal() {
  printf "ERROR: %s\\n" "$*" >&2
  exit 1
}

# @public
function log() {
  printf "LOG: %s\\n" "$*" >&2
}
