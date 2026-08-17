GO_VERSION := 1.26.5
SQLC_VERSION := 1.31.1
TERN_VERSION := 2.4.1

.PHONY: format test vet integration-test sqlc-generate sqlc-vet sqlc-version tern-version

format:
	docker run --rm -v "$(CURDIR):/workspace" -w /workspace golang:$(GO_VERSION)-alpine go fmt ./...

test:
	docker run --rm -v "$(CURDIR):/workspace" -w /workspace golang:$(GO_VERSION)-alpine go test ./...

vet:
	docker run --rm -v "$(CURDIR):/workspace" -w /workspace golang:$(GO_VERSION)-alpine go vet ./...

integration-test:
	docker compose -f ../compose.yaml up -d db
	docker compose -f ../compose.yaml run --rm migrate migrate
	docker run --rm \
		--network rune-nexus_default \
		-v "$(CURDIR):/workspace" \
		-v "$(abspath ../.secrets/postgres_password):/run/secrets/postgres_password:ro" \
		-w /workspace \
		-e RUNE_NEXUS_TEST_DATABASE_URL="postgres://rune_nexus_app@db:5432/rune_nexus?sslmode=disable" \
		-e RUNE_NEXUS_TEST_DATABASE_PASSWORD_FILE=/run/secrets/postgres_password \
		golang:$(GO_VERSION)-alpine go test -tags=integration ./internal/dbtest

sqlc-generate:
	docker run --rm -v "$(CURDIR):/src" -w /src sqlc/sqlc:$(SQLC_VERSION) generate

sqlc-vet:
	docker run --rm -v "$(CURDIR):/src" -w /src sqlc/sqlc:$(SQLC_VERSION) vet

sqlc-version:
	docker run --rm sqlc/sqlc:$(SQLC_VERSION) version

tern-version:
	docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' rune-nexus-migrate
