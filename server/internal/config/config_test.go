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
	if cfg.MaxSaveBodyBytes != defaultMaxSaveBodyBytes {
		t.Fatalf("MaxSaveBodyBytes = %d", cfg.MaxSaveBodyBytes)
	}
	if cfg.MinimumSaveClientCompatibilityVersion != defaultMinimumSaveClientCompatibilityVersion {
		t.Fatalf(
			"MinimumSaveClientCompatibilityVersion = %d",
			cfg.MinimumSaveClientCompatibilityVersion,
		)
	}
	if cfg.AuthenticationRateLimitWindow != defaultAuthenticationRateLimitWindow ||
		cfg.GoogleAuthenticationRateLimit != defaultGoogleAuthenticationRateLimit ||
		cfg.RefreshAuthenticationRateLimit != defaultRefreshAuthenticationRateLimit ||
		cfg.AuthenticationRateLimitMaxClients != defaultAuthenticationRateLimitMaxClients ||
		cfg.TrustProxyHeaders {
		t.Fatalf("authentication rate limits = %#v", cfg)
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

func TestLoadRequiresGoogleClientIDWhenAuthIsEnabled(t *testing.T) {
	clearDatabaseEnvironment(t)
	t.Setenv("DATABASE_URL", "postgres://app:secret@localhost/rune_nexus")
	t.Setenv("GOOGLE_AUTH_ENABLED", "true")

	if _, err := Load(); err == nil {
		t.Fatal("Load() expected an error")
	}
}

func TestLoadParsesGoogleAuthAndCORSConfiguration(t *testing.T) {
	clearDatabaseEnvironment(t)
	t.Setenv("DATABASE_URL", "postgres://app:secret@localhost/rune_nexus")
	t.Setenv("GOOGLE_AUTH_ENABLED", "true")
	t.Setenv("GOOGLE_WEB_CLIENT_ID", "web-client-id")
	t.Setenv(
		"CORS_ALLOWED_ORIGINS",
		"https://sejiiinn.github.io/, http://127.0.0.1:53000, https://sejiiinn.github.io",
	)
	t.Setenv("MAX_SAVE_BODY_BYTES", "2097152")
	t.Setenv("MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION", "2")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if !cfg.GoogleAuthEnabled || cfg.GoogleWebClientID != "web-client-id" {
		t.Fatalf("Google auth configuration = %#v", cfg)
	}
	if len(cfg.CORSAllowedOrigins) != 2 {
		t.Fatalf("CORSAllowedOrigins = %#v", cfg.CORSAllowedOrigins)
	}
	if cfg.MaxSaveBodyBytes != 2097152 {
		t.Fatalf("MaxSaveBodyBytes = %d", cfg.MaxSaveBodyBytes)
	}
	if cfg.MinimumSaveClientCompatibilityVersion != 2 {
		t.Fatalf(
			"MinimumSaveClientCompatibilityVersion = %d",
			cfg.MinimumSaveClientCompatibilityVersion,
		)
	}
}

func TestLoadRejectsNonPositiveMaxSaveBodyBytes(t *testing.T) {
	clearDatabaseEnvironment(t)
	t.Setenv("DATABASE_URL", "postgres://app:secret@localhost/rune_nexus")
	t.Setenv("MAX_SAVE_BODY_BYTES", "0")

	if _, err := Load(); err == nil {
		t.Fatal("Load() expected an error")
	}
}

func TestLoadRejectsNonPositiveMinimumSaveClientCompatibilityVersion(t *testing.T) {
	clearDatabaseEnvironment(t)
	t.Setenv("DATABASE_URL", "postgres://app:secret@localhost/rune_nexus")
	t.Setenv("MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION", "0")

	if _, err := Load(); err == nil {
		t.Fatal("Load() expected an error")
	}
}

func TestLoadRejectsRefreshTTLNotGreaterThanAccessTTL(t *testing.T) {
	clearDatabaseEnvironment(t)
	t.Setenv("DATABASE_URL", "postgres://app:secret@localhost/rune_nexus")
	t.Setenv("ACCESS_TOKEN_TTL", "1h")
	t.Setenv("REFRESH_TOKEN_TTL", "1h")

	if _, err := Load(); err == nil {
		t.Fatal("Load() expected an error")
	}
}

func TestLoadParsesAuthenticationRateLimits(t *testing.T) {
	clearDatabaseEnvironment(t)
	t.Setenv("DATABASE_URL", "postgres://app:secret@localhost/rune_nexus")
	t.Setenv("AUTH_RATE_LIMIT_WINDOW", "2m")
	t.Setenv("GOOGLE_AUTH_RATE_LIMIT", "12")
	t.Setenv("REFRESH_AUTH_RATE_LIMIT", "45")
	t.Setenv("AUTH_RATE_LIMIT_MAX_CLIENTS", "2048")
	t.Setenv("TRUST_PROXY_HEADERS", "true")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.AuthenticationRateLimitWindow != 2*time.Minute ||
		cfg.GoogleAuthenticationRateLimit != 12 ||
		cfg.RefreshAuthenticationRateLimit != 45 ||
		cfg.AuthenticationRateLimitMaxClients != 2048 ||
		!cfg.TrustProxyHeaders {
		t.Fatalf("authentication rate limits = %#v", cfg)
	}
}

func TestLoadRejectsInvalidAuthenticationRateLimits(t *testing.T) {
	for _, testCase := range []struct {
		name  string
		key   string
		value string
	}{
		{name: "window", key: "AUTH_RATE_LIMIT_WINDOW", value: "0s"},
		{name: "Google requests", key: "GOOGLE_AUTH_RATE_LIMIT", value: "0"},
		{name: "refresh requests", key: "REFRESH_AUTH_RATE_LIMIT", value: "invalid"},
		{name: "client state cap", key: "AUTH_RATE_LIMIT_MAX_CLIENTS", value: "-1"},
		{name: "proxy trust", key: "TRUST_PROXY_HEADERS", value: "sometimes"},
	} {
		t.Run(testCase.name, func(t *testing.T) {
			clearDatabaseEnvironment(t)
			t.Setenv("DATABASE_URL", "postgres://app:secret@localhost/rune_nexus")
			t.Setenv(testCase.key, testCase.value)
			if _, err := Load(); err == nil {
				t.Fatal("Load() expected an error")
			}
		})
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
		"GOOGLE_AUTH_ENABLED",
		"GOOGLE_WEB_CLIENT_ID",
		"IDENTITY_VERIFY_TIMEOUT",
		"ACCESS_TOKEN_TTL",
		"REFRESH_TOKEN_TTL",
		"AUTH_RATE_LIMIT_WINDOW",
		"GOOGLE_AUTH_RATE_LIMIT",
		"REFRESH_AUTH_RATE_LIMIT",
		"AUTH_RATE_LIMIT_MAX_CLIENTS",
		"TRUST_PROXY_HEADERS",
		"CORS_ALLOWED_ORIGINS",
		"MAX_SAVE_BODY_BYTES",
		"MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION",
	} {
		t.Setenv(name, "")
	}
}
