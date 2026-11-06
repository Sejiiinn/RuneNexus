#!/bin/sh
set -eu

if [ -n "${PGPASSWORD_FILE:-}" ]; then
  if [ -n "${PGPASSWORD:-}" ]; then
    echo "PGPASSWORD and PGPASSWORD_FILE cannot both be set" >&2
    exit 1
  fi
  if [ ! -s "${PGPASSWORD_FILE}" ]; then
    echo "PGPASSWORD_FILE is missing or empty" >&2
    exit 1
  fi
  PGPASSWORD="$(cat "${PGPASSWORD_FILE}")"
  export PGPASSWORD
fi

apply_api_role() {
  API_PASSWORD="$(cat "${API_PASSWORD_FILE}")"
  if [ -z "${API_PASSWORD}" ]; then
    echo "API_PASSWORD_FILE is empty" >&2
    exit 1
  fi
  export API_PASSWORD
  exec psql --no-psqlrc --quiet --single-transaction --file=/usr/local/share/rune-nexus/api-role.sql
}

if [ "${1:-}" = "api-role" ]; then
  apply_api_role
fi

if [ "${1:-}" = "migrate" ]; then
  migrations_found=false
  for migration in "${TERN_MIGRATIONS:-.}"/[0-9]*.sql; do
    if [ -f "${migration}" ]; then
      migrations_found=true
      break
    fi
  done
  if [ "${migrations_found}" = false ]; then
    echo "No application migrations to apply"
    exit 0
  fi
fi

if [ "${1:-}" != "migrate" ] || [ -z "${API_PASSWORD_FILE:-}" ]; then
  exec /usr/local/bin/tern "$@"
fi

/usr/local/bin/tern "$@"
apply_api_role
