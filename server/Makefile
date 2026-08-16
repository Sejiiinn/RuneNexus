GO_VERSION := 1.26.5
SQLC_VERSION := 1.31.1
TERN_VERSION := 2.4.1

.PHONY: format test vet sqlc-version tern-version

format:
	docker run --rm -v "$(CURDIR):/workspace" -w /workspace golang:$(GO_VERSION)-alpine go fmt ./...

test:
	docker run --rm -v "$(CURDIR):/workspace" -w /workspace golang:$(GO_VERSION)-alpine go test ./...

vet:
	docker run --rm -v "$(CURDIR):/workspace" -w /workspace golang:$(GO_VERSION)-alpine go vet ./...

sqlc-version:
	docker run --rm sqlc/sqlc:$(SQLC_VERSION) version

tern-version:
	docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' rune-nexus-migrate
