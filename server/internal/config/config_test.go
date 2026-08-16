package config

import (
	"net/url"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestLoadUsesDatabaseURL(t *testing.T) {
	clearDatabaseEnvironment(t)
	t.Setenv("DATABASE_URL", "postgres://app:secret@localhost:5432/rune_nexus?sslmode=disable")
	t.Setenv("HTTP_ADDRESS", "127.0.0.1:9090")
	t.Setenv("READINESS_TIMEOUT", "750ms")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.HTTPAddress != "127.0.0.1:9090" {
		t.Fatalf("HTTPAddress = %q", cfg.HTTPAddress)
	}
	if cfg.ReadinessTimeout != 750*time.Millisecond {
		t.Fatalf("ReadinessTimeout = %v", cfg.ReadinessTimeout)
	}
}

func TestLoadBuildsDatabaseURLFromPasswordFile(t *testing.T) {
	clearDatabaseEnvironment(t)
	passwordFile := filepath.Join(t.TempDir(), "database_password")
	if err := os.WriteFile(passwordFile, []byte("s/ecret value\n"), 0o600); err != nil {
		t.Fatalf("write password file: %v", err)
	}
	t.Setenv("DATABASE_HOST", "db")
	t.Setenv("DATABASE_NAME", "rune_nexus")
	t.Setenv("DATABASE_USER", "rune_nexus_app")
	t.Setenv("DATABASE_PASSWORD_FILE", passwordFile)
	t.Setenv("DATABASE_SSLMODE", "verify-full")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	parsed, err := url.Parse(cfg.DatabaseURL)
	if err != nil {
		t.Fatalf("parse generated URL: %v", err)
	}
	if parsed.Host != "db:5432" || parsed.Path != "/rune_nexus" {
		t.Fatalf("generated database target = %q%q", parsed.Host, parsed.Path)
	}
	password, ok := parsed.User.Password()
	if !ok || password != "s/ecret value" {
		t.Fatalf("generated password was not preserved")
	}
	if parsed.Query().Get("sslmode") != "verify-full" {
		t.Fatalf("sslmode = %q", parsed.Query().Get("sslmode"))
	}
}

func TestLoadRejectsInvalidDuration(t *testing.T) {
	clearDatabaseEnvironment(t)
	t.Setenv("DATABASE_URL", "postgres://app:secret@localhost/rune_nexus")
	t.Setenv("SHUTDOWN_TIMEOUT", "0s")

	if _, err := Load(); err == nil {
		t.Fatal("Load() expected an error")
	}
}

func clearDatabaseEnvironment(t *testing.T) {
	t.Helper()
	for _, name := range []string{
		"DATABASE_URL",
		"DATABASE_HOST",
		"DATABASE_PORT",
		"DATABASE_NAME",
		"DATABASE_USER",
		"DATABASE_PASSWORD",
		"DATABASE_PASSWORD_FILE",
		"DATABASE_SSLMODE",
		"DATABASE_CONNECT_TIMEOUT",
		"READINESS_TIMEOUT",
		"SHUTDOWN_TIMEOUT",
		"HTTP_ADDRESS",
	} {
		t.Setenv(name, "")
	}
}
