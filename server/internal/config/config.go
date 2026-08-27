package config

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	defaultHTTPAddress                                 = ":8080"
	defaultDatabasePort                                = "5432"
	defaultDatabaseConnectTimeout                      = 5 * time.Second
	defaultReadinessTimeout                            = 2 * time.Second
	defaultShutdownTimeout                             = 10 * time.Second
	defaultIdentityVerifyTimeout                       = 5 * time.Second
	defaultAccessTokenTTL                              = 15 * time.Minute
	defaultRefreshTokenTTL                             = 30 * 24 * time.Hour
	defaultAuthenticationRateLimitWindow               = time.Minute
	defaultGoogleAuthenticationRateLimit               = 10
	defaultRefreshAuthenticationRateLimit              = 30
	defaultAuthenticationRateLimitMaxClients           = 10_000
	defaultMaxSaveBodyBytes                      int64 = 4 * 1024 * 1024
	defaultMinimumSaveClientCompatibilityVersion       = 1
)

type Config struct {
	HTTPAddress                           string
	DatabaseURL                           string
	DatabaseConnectTimeout                time.Duration
	ReadinessTimeout                      time.Duration
	ShutdownTimeout                       time.Duration
	GoogleAuthEnabled                     bool
	GoogleWebClientID                     string
	IdentityVerifyTimeout                 time.Duration
	AccessTokenTTL                        time.Duration
	RefreshTokenTTL                       time.Duration
	AuthenticationRateLimitWindow         time.Duration
	GoogleAuthenticationRateLimit         int
	RefreshAuthenticationRateLimit        int
	AuthenticationRateLimitMaxClients     int
	TrustProxyHeaders                     bool
	CORSAllowedOrigins                    []string
	MaxSaveBodyBytes                      int64
	MinimumSaveClientCompatibilityVersion int
}

func Load() (Config, error) {
	databaseURL, err := loadDatabaseURL()
	if err != nil {
		return Config{}, err
	}

	databaseConnectTimeout, err := durationFromEnvironment(
		"DATABASE_CONNECT_TIMEOUT",
		defaultDatabaseConnectTimeout,
	)
	if err != nil {
		return Config{}, err
	}
	readinessTimeout, err := durationFromEnvironment(
		"READINESS_TIMEOUT",
		defaultReadinessTimeout,
	)
	if err != nil {
		return Config{}, err
	}
	shutdownTimeout, err := durationFromEnvironment(
		"SHUTDOWN_TIMEOUT",
		defaultShutdownTimeout,
	)
	if err != nil {
		return Config{}, err
	}
	identityVerifyTimeout, err := durationFromEnvironment(
		"IDENTITY_VERIFY_TIMEOUT",
		defaultIdentityVerifyTimeout,
	)
	if err != nil {
		return Config{}, err
	}
	accessTokenTTL, err := durationFromEnvironment(
		"ACCESS_TOKEN_TTL",
		defaultAccessTokenTTL,
	)
	if err != nil {
		return Config{}, err
	}
	refreshTokenTTL, err := durationFromEnvironment(
		"REFRESH_TOKEN_TTL",
		defaultRefreshTokenTTL,
	)
	if err != nil {
		return Config{}, err
	}
	if refreshTokenTTL <= accessTokenTTL {
		return Config{}, errors.New("REFRESH_TOKEN_TTL must be greater than ACCESS_TOKEN_TTL")
	}
	authenticationRateLimitWindow, err := durationFromEnvironment(
		"AUTH_RATE_LIMIT_WINDOW",
		defaultAuthenticationRateLimitWindow,
	)
	if err != nil {
		return Config{}, err
	}
	googleAuthenticationRateLimit, err := positiveIntFromEnvironment(
		"GOOGLE_AUTH_RATE_LIMIT",
		defaultGoogleAuthenticationRateLimit,
	)
	if err != nil {
		return Config{}, err
	}
	refreshAuthenticationRateLimit, err := positiveIntFromEnvironment(
		"REFRESH_AUTH_RATE_LIMIT",
		defaultRefreshAuthenticationRateLimit,
	)
	if err != nil {
		return Config{}, err
	}
	authenticationRateLimitMaxClients, err := positiveIntFromEnvironment(
		"AUTH_RATE_LIMIT_MAX_CLIENTS",
		defaultAuthenticationRateLimitMaxClients,
	)
	if err != nil {
		return Config{}, err
	}
	trustProxyHeaders, err := boolFromEnvironment("TRUST_PROXY_HEADERS", false)
	if err != nil {
		return Config{}, err
	}

	googleAuthEnabled, err := boolFromEnvironment("GOOGLE_AUTH_ENABLED", false)
	if err != nil {
		return Config{}, err
	}
	googleWebClientID := strings.TrimSpace(os.Getenv("GOOGLE_WEB_CLIENT_ID"))
	if googleAuthEnabled && googleWebClientID == "" {
		return Config{}, errors.New(
			"GOOGLE_WEB_CLIENT_ID is required when GOOGLE_AUTH_ENABLED is true",
		)
	}
	corsAllowedOrigins, err := originsFromEnvironment("CORS_ALLOWED_ORIGINS")
	if err != nil {
		return Config{}, err
	}
	maxSaveBodyBytes, err := positiveInt64FromEnvironment(
		"MAX_SAVE_BODY_BYTES",
		defaultMaxSaveBodyBytes,
	)
	if err != nil {
		return Config{}, err
	}
	minimumSaveClientCompatibilityVersion, err := positiveIntFromEnvironment(
		"MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION",
		defaultMinimumSaveClientCompatibilityVersion,
	)
	if err != nil {
		return Config{}, err
	}

	return Config{
		HTTPAddress:                           stringFromEnvironment("HTTP_ADDRESS", defaultHTTPAddress),
		DatabaseURL:                           databaseURL,
		DatabaseConnectTimeout:                databaseConnectTimeout,
		ReadinessTimeout:                      readinessTimeout,
		ShutdownTimeout:                       shutdownTimeout,
		GoogleAuthEnabled:                     googleAuthEnabled,
		GoogleWebClientID:                     googleWebClientID,
		IdentityVerifyTimeout:                 identityVerifyTimeout,
		AccessTokenTTL:                        accessTokenTTL,
		RefreshTokenTTL:                       refreshTokenTTL,
		AuthenticationRateLimitWindow:         authenticationRateLimitWindow,
		GoogleAuthenticationRateLimit:         googleAuthenticationRateLimit,
		RefreshAuthenticationRateLimit:        refreshAuthenticationRateLimit,
		AuthenticationRateLimitMaxClients:     authenticationRateLimitMaxClients,
		TrustProxyHeaders:                     trustProxyHeaders,
		CORSAllowedOrigins:                    corsAllowedOrigins,
		MaxSaveBodyBytes:                      maxSaveBodyBytes,
		MinimumSaveClientCompatibilityVersion: minimumSaveClientCompatibilityVersion,
	}, nil
}

func loadDatabaseURL() (string, error) {
	if databaseURL := strings.TrimSpace(os.Getenv("DATABASE_URL")); databaseURL != "" {
		return databaseURL, nil
	}

	host, err := requiredEnvironment("DATABASE_HOST")
	if err != nil {
		return "", err
	}
	database, err := requiredEnvironment("DATABASE_NAME")
	if err != nil {
		return "", err
	}
	user, err := requiredEnvironment("DATABASE_USER")
	if err != nil {
		return "", err
	}
	password, err := databasePassword()
	if err != nil {
		return "", err
	}

	port := stringFromEnvironment("DATABASE_PORT", defaultDatabasePort)
	sslMode := stringFromEnvironment("DATABASE_SSLMODE", "disable")
	databaseURL := &url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(user, password),
		Host:   net.JoinHostPort(host, port),
		Path:   database,
	}
	query := databaseURL.Query()
	query.Set("sslmode", sslMode)
	databaseURL.RawQuery = query.Encode()
	return databaseURL.String(), nil
}

func databasePassword() (string, error) {
	password := os.Getenv("DATABASE_PASSWORD")
	passwordFile := strings.TrimSpace(os.Getenv("DATABASE_PASSWORD_FILE"))
	if password != "" && passwordFile != "" {
		return "", errors.New(
			"DATABASE_PASSWORD and DATABASE_PASSWORD_FILE cannot both be set",
		)
	}
	if password != "" {
		return password, nil
	}
	if passwordFile == "" {
		return "", errors.New(
			"DATABASE_PASSWORD or DATABASE_PASSWORD_FILE is required when DATABASE_URL is unset",
		)
	}

	contents, err := os.ReadFile(passwordFile)
	if err != nil {
		return "", fmt.Errorf("read DATABASE_PASSWORD_FILE: %w", err)
	}
	password = strings.TrimSuffix(string(contents), "\n")
	password = strings.TrimSuffix(password, "\r")
	if password == "" {
		return "", errors.New("DATABASE_PASSWORD_FILE is empty")
	}
	return password, nil
}

func requiredEnvironment(name string) (string, error) {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return "", fmt.Errorf("%s is required when DATABASE_URL is unset", name)
	}
	return value, nil
}

func stringFromEnvironment(name string, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}

func durationFromEnvironment(name string, fallback time.Duration) (time.Duration, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}
	value, err := time.ParseDuration(raw)
	if err != nil {
		return 0, fmt.Errorf("parse %s: %w", name, err)
	}
	if value <= 0 {
		return 0, fmt.Errorf("%s must be greater than zero", name)
	}
	return value, nil
}

func boolFromEnvironment(name string, fallback bool) (bool, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}
	switch strings.ToLower(raw) {
	case "true", "1":
		return true, nil
	case "false", "0":
		return false, nil
	default:
		return false, fmt.Errorf("parse %s: expected true or false", name)
	}
}

func positiveInt64FromEnvironment(name string, fallback int64) (int64, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("parse %s: %w", name, err)
	}
	if value <= 0 {
		return 0, fmt.Errorf("%s must be greater than zero", name)
	}
	return value, nil
}

func positiveIntFromEnvironment(name string, fallback int) (int, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.Atoi(raw)
	if err != nil {
		return 0, fmt.Errorf("parse %s: %w", name, err)
	}
	if value <= 0 {
		return 0, fmt.Errorf("%s must be greater than zero", name)
	}
	return value, nil
}

func originsFromEnvironment(name string) ([]string, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return []string{}, nil
	}

	origins := make([]string, 0)
	seen := make(map[string]struct{})
	for value := range strings.SplitSeq(raw, ",") {
		origin := strings.TrimSuffix(strings.TrimSpace(value), "/")
		if origin == "" {
			continue
		}
		parsed, err := url.Parse(origin)
		if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") ||
			parsed.Host == "" || parsed.User != nil || parsed.Path != "" ||
			parsed.RawQuery != "" || parsed.Fragment != "" {
			return nil, fmt.Errorf("parse %s: %q is not an HTTP origin", name, origin)
		}
		if _, exists := seen[origin]; exists {
			continue
		}
		seen[origin] = struct{}{}
		origins = append(origins, origin)
	}
	return origins, nil
}
