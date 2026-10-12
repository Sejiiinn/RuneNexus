#!/bin/sh
# Runs ./internal/dbtest against a disposable PostgreSQL. Never uses the
# compose `db` service: that container and volume are the deployed server's.
# The database lives in tmpfs on its own network with no published port and is
# removed on exit, success or failure. Extra arguments go to `go test`.
set -eu

: "${GO_VERSION:?}" "${TERN_VERSION:?}" "${POSTGRES_IMAGE:?}"
server_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
run_id="rn-itest-$$-$(date +%s)"
network="$run_id"
database="$run_id-db"
migrate_image="rune-nexus-migrate-itest:${TERN_VERSION}"
secret_dir=$(mktemp -d)

cleanup() {
  docker rm -f "$database" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
  rm -rf "$secret_dir"
}
trap cleanup EXIT INT TERM

# Throwaway credentials; the deployed secret is never read.
od -An -N24 -tx1 /dev/urandom | tr -d ' \n' > "$secret_dir/password"
chmod 0644 "$secret_dir/password"

docker build --quiet -f "$server_dir/Dockerfile.migrate" \
  --build-arg GO_VERSION="$GO_VERSION" --build-arg TERN_VERSION="$TERN_VERSION" \
  -t "$migrate_image" "$server_dir" >/dev/null
docker network create "$network" >/dev/null
docker run -d --name "$database" --network "$network" --tmpfs /var/lib/postgresql \
  -e POSTGRES_DB=rune_nexus -e POSTGRES_USER=rune_nexus_app \
  -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password \
  -e POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256 -e TZ=UTC -e PGTZ=UTC \
  -v "$secret_dir/password:/run/secrets/postgres_password:ro" \
  "$POSTGRES_IMAGE" >/dev/null

# initdb serves only the Unix socket; TCP readiness means the final server is up.
attempt=0
until docker exec "$database" pg_isready -q -h 127.0.0.1 -U rune_nexus_app -d rune_nexus; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "disposable test database did not become ready" >&2
    docker logs "$database" >&2 || true
    exit 1
  fi
  sleep 1
done

docker run --rm --network "$network" \
  -e PGHOST="$database" -e PGPORT=5432 -e PGDATABASE=rune_nexus -e PGUSER=rune_nexus_app \
  -e PGPASSWORD_FILE=/run/secrets/postgres_password -e PGSSLMODE=disable \
  -e TERN_MIGRATIONS=/migrations \
  -v "$server_dir/db/migrations:/migrations:ro" \
  -v "$secret_dir/password:/run/secrets/postgres_password:ro" \
  "$migrate_image" migrate >/dev/null

docker run --rm --network "$network" \
  -v "$server_dir:/workspace" \
  -v "$secret_dir/password:/run/secrets/postgres_password:ro" \
  -w /workspace \
  -e RUNE_NEXUS_TEST_DATABASE_URL="postgres://rune_nexus_app@$database:5432/rune_nexus?sslmode=disable" \
  -e RUNE_NEXUS_TEST_DATABASE_PASSWORD_FILE=/run/secrets/postgres_password \
  "golang:${GO_VERSION}-alpine" go test -tags=integration "$@" ./internal/dbtest
