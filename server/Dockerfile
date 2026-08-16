# syntax=docker/dockerfile:1

ARG GO_VERSION=1.26.5
FROM golang:${GO_VERSION}-alpine AS build

WORKDIR /source

COPY go.mod go.sum ./
RUN go mod download

COPY cmd ./cmd
COPY internal ./internal

RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /output/rune-nexus-api ./cmd/api

FROM alpine:3.22

ARG GO_VERSION
RUN apk add --no-cache ca-certificates \
    && addgroup -S -g 10001 runenexus \
    && adduser -S -D -H -u 10001 -G runenexus runenexus

WORKDIR /app
COPY --from=build /output/rune-nexus-api /usr/local/bin/rune-nexus-api

LABEL org.opencontainers.image.version="${GO_VERSION}"

USER runenexus:runenexus
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/rune-nexus-api"]
