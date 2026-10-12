GO_VERSION := 1.26.5
SQLC_VERSION := 1.31.1
TERN_VERSION := 2.4.1
POSTGRES_IMAGE := postgres:18

.PHONY: format test vet integration-test sqlc-generate sqlc-vet sqlc-version tern-version

format:
	docker run --rm -v "$(CURDIR):/workspace" -w /workspace golang:$(GO_VERSION)-alpine go fmt ./...

test:
	docker run --rm -v "$(CURDIR):/workspace" -v "$(abspath ../godot/content/source):/godot/content/source:ro" -v "$(abspath ../test/fixtures):/test/fixtures:ro" -w /workspace golang:$(GO_VERSION)-alpine go test ./...

vet:
	docker run --rm -v "$(CURDIR):/workspace" -v "$(abspath ../godot/content/source):/godot/content/source:ro" -v "$(abspath ../test/fixtures):/test/fixtures:ro" -w /workspace golang:$(GO_VERSION)-alpine go vet ./...

# Disposable tmpfs database; the compose db service is the deployed server's.
# Match POSTGRES_IMAGE to compose.yaml. Example: make integration-test ARGS='-run Mailbox'
integration-test:
	GO_VERSION=$(GO_VERSION) TERN_VERSION=$(TERN_VERSION) POSTGRES_IMAGE=$(POSTGRES_IMAGE) \
		sh docker/integration-test.sh $(ARGS)

sqlc-generate:
	docker run --rm -v "$(CURDIR):/src" -w /src sqlc/sqlc:$(SQLC_VERSION) generate

sqlc-vet:
	docker run --rm -v "$(CURDIR):/src" -w /src sqlc/sqlc:$(SQLC_VERSION) vet

sqlc-version:
	docker run --rm sqlc/sqlc:$(SQLC_VERSION) version

tern-version:
	docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' rune-nexus-migrate
