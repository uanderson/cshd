#!/bin/bash

set -e
source "${0%/*}/common.sh"

# Entry point to run this script.
#
# @private
function run() {
  local profile

  IFS=',' read -ra profiles <<<"$(get_conf 'profiles')"

  if [[ -z "$profiles" ]]; then
    certify "default"
  else
    for profile in "${profiles[@]}"; do
      certify "$profile"
    done
  fi
}

# Certifies domains provided.
#
# Example:
#
# certbot.email=x@usoar.es
# certbot.domains=domain-a.com,domain-b.com
#
# domain-a.com.certbot.redirect=true
# domain-b.com.certbot.redirect=false
#
# $1 - Profile name (optional)
#
# @private
function certify() {
  local email
  local domain
  local redirect
  local command

  email="$(get_conf "certbot.email" "$1")"
  IFS=',' read -ra domains <<<"$(get_conf "certbot.domains" "$1")"

  for domain in "${domains[@]}"; do
    redirect="$(get_conf "$domain.certbot.redirect" "$1")"
    write_conf "$domain" "$redirect"

    command="sudo certbot -m $email -d $domain --nginx --agree-tos -n"
    if [[ "$redirect" == "true" ]]; then command+=" --redirect"; else command+=" --no-redirect"; fi

    eval "$command"
  done
}

# Writes configuration file for each domain.
#
# $1 - Domain
# $2 - Redirect
#
# @private
function write_conf() {
  local template_name

  if [[ "$2" == "true" ]]; then template_name="redirect"; else template_name="no-redirect"; fi
  sed "s/\$domain/$1/g" "$CSHD_TEMPLATES/certbot/$template_name.txt" | sudo tee "/etc/nginx/conf.d/$1.conf" >/dev/null

  sudo nginx -s reload
}

run
