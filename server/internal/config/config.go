package config

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"strings"
	"time"
)

const (
	defaultHTTPAddress            = ":8080"
	defaultDatabasePort           = "5432"
	defaultDatabaseConnectTimeout = 5 * time.Second
	defaultReadinessTimeout       = 2 * time.Second
	defaultShutdownTimeout        = 10 * time.Second
)

type Config struct {
	HTTPAddress            string
	DatabaseURL            string
	DatabaseConnectTimeout time.Duration
	ReadinessTimeout       time.Duration
	ShutdownTimeout        time.Duration
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

	return Config{
		HTTPAddress:            stringFromEnvironment("HTTP_ADDRESS", defaultHTTPAddress),
		DatabaseURL:            databaseURL,
		DatabaseConnectTimeout: databaseConnectTimeout,
		ReadinessTimeout:       readinessTimeout,
		ShutdownTimeout:        shutdownTimeout,
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
