#!/bin/bash

if [[ -z "$CSHD_CONF_FILE" ]]; then
  CSHD_CONF_FILE="/etc/cshd/cshd.conf"
fi

function get_conf() {
  if [[ ! -f "$CSHD_CONF_FILE" ]]; then
    fatal "Configuration file is missing"
  fi

  local value
  value="$(grep "${1}" "$CSHD_CONF_FILE" | cut -d'=' -f2 | tr -d '\r')"

  if [[ -z "$value" ]]; then
    fatal "Property '$1' is missing"
  fi

  echo "$value"
}

fatal() {
  printf "ERROR: %s\\n" "$*" >&2
  exit 1
}
