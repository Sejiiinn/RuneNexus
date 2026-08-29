#!/bin/sh

set -u

readonly DEFAULT_TOKEN_FILE='/run/secrets/duckdns_token'
readonly DEFAULT_STATUS_FILE='/tmp/rune-nexus-duckdns-last-success'
readonly DEFAULT_UPDATE_INTERVAL_SECONDS='300'
readonly DEFAULT_RETRY_INTERVAL_SECONDS='30'

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >&2
}

is_positive_integer() {
  case "$1" in
    '' | *[!0-9]*) return 1 ;;
    *) [ "$1" -gt 0 ] ;;
  esac
}

validate_interval() {
  interval_name="$1"
  interval_value="$2"
  minimum_value="$3"

  if ! is_positive_integer "$interval_value" ||
    [ "$interval_value" -lt "$minimum_value" ]; then
    log "$interval_name must be an integer greater than or equal to $minimum_value"
    return 1
  fi
}

healthcheck() {
  status_file="${DUCKDNS_STATUS_FILE:-$DEFAULT_STATUS_FILE}"
  update_interval="${DUCKDNS_UPDATE_INTERVAL_SECONDS:-$DEFAULT_UPDATE_INTERVAL_SECONDS}"

  validate_interval 'DUCKDNS_UPDATE_INTERVAL_SECONDS' "$update_interval" 60 || return 1
  [ -r "$status_file" ] || return 1

  last_success="$(tr -d '\r\n' < "$status_file")"
  is_positive_integer "$last_success" || return 1

  now="$(date +%s)"
  max_age="$((update_interval * 3))"
  age="$((now - last_success))"
  [ "$age" -ge 0 ] && [ "$age" -le "$max_age" ]
}

read_token() {
  token_file="${DUCKDNS_TOKEN_FILE:-$DEFAULT_TOKEN_FILE}"
  if [ ! -r "$token_file" ]; then
    log "DuckDNS token file is not readable: $token_file"
    return 1
  fi

  token="$(tr -d '\r\n' < "$token_file")"
  case "$token" in
    '' | *[!A-Za-z0-9-]*)
      log 'DuckDNS token file must contain only the account token'
      return 1
      ;;
  esac

  printf '%s' "$token"
}

validate_subdomain() {
  if [ "${#1}" -gt 63 ]; then
    log 'DUCKDNS_SUBDOMAIN must not exceed 63 characters'
    return 1
  fi

  case "$1" in
    '' | -* | *- | *[!a-z0-9-]*)
      log 'DUCKDNS_SUBDOMAIN must be a lowercase DuckDNS label without .duckdns.org'
      return 1
      ;;
  esac
}

update_address() {
  subdomain="$1"
  token="$2"
  status_file="$3"

  if ! response="$(curl --config - <<EOF
url = "https://www.duckdns.org/update"
get
silent
show-error
fail
connect-timeout = 5
max-time = 15
data-urlencode = "domains=$subdomain"
data-urlencode = "token=$token"
data-urlencode = "ip="
EOF
  )"; then
    log "DuckDNS update request failed for $subdomain.duckdns.org"
    return 1
  fi

  if [ "$response" != 'OK' ]; then
    log "DuckDNS rejected the update for $subdomain.duckdns.org"
    return 1
  fi

  date +%s > "$status_file"
  log "DuckDNS address updated: $subdomain.duckdns.org"
}

load_config() {
  subdomain="${DUCKDNS_SUBDOMAIN:-}"
  token="$(read_token)" || return 1
  status_file="${DUCKDNS_STATUS_FILE:-$DEFAULT_STATUS_FILE}"
  update_interval="${DUCKDNS_UPDATE_INTERVAL_SECONDS:-$DEFAULT_UPDATE_INTERVAL_SECONDS}"
  retry_interval="${DUCKDNS_RETRY_INTERVAL_SECONDS:-$DEFAULT_RETRY_INTERVAL_SECONDS}"

  validate_subdomain "$subdomain" || return 1
  validate_interval 'DUCKDNS_UPDATE_INTERVAL_SECONDS' "$update_interval" 60 || return 1
  validate_interval 'DUCKDNS_RETRY_INTERVAL_SECONDS' "$retry_interval" 10 || return 1
}

run_once() {
  load_config || return 1
  update_address "$subdomain" "$token" "$status_file"
}

run_loop() {
  load_config || return 1

  while :; do
    if update_address "$subdomain" "$token" "$status_file"; then
      sleep "$update_interval"
    else
      sleep "$retry_interval"
    fi
  done
}

case "${1:-run}" in
  healthcheck) healthcheck ;;
  once) run_once ;;
  run) run_loop ;;
  *)
    log "unsupported command: $1"
    exit 2
    ;;
esac
