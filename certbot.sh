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
# domain-a.com.certbot.nginx.ssl-sidecar=true
# domain-b.com.certbot.nginx.ssl-sidecar=false
#
# $1 - Profile name (optional)
#
# @private
function certify() {
  local email
  local domain
  local sidecar
  local conf_file

  email="$(get_conf "certbot.email" "$1")"
  IFS=',' read -ra domains <<<"$(get_conf "certbot.domains" "$1")"

  for domain in "${domains[@]}"; do
    conf_file="/etc/nginx/conf.d/$domain.conf"
    sidecar="$(get_conf "$domain.certbot.nginx.ssl-sidecar" "$1")"

    sed "s/\$domain/$domain/g" "$CSHD_TEMPLATES/certbot/challenge.txt" | sudo tee "$conf_file" >/dev/null
    sudo certbot --nginx --agree-tos --no-redirect -n -m "$email" -d "$domain"

    if [[ -z "$sidecar" ]] || [[ "$sidecar" == "false" ]]; then
      sed "s/\$domain/$domain/g" "$CSHD_TEMPLATES/certbot/ssl.txt" | sudo tee "$conf_file" >/dev/null
    fi

    sudo nginx -s reload
  done
}

run
