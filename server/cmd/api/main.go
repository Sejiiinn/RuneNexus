package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	googleauth "github.com/Sejiiinn/RuneNexus/server/internal/auth/google"
	"github.com/Sejiiinn/RuneNexus/server/internal/config"
	"github.com/Sejiiinn/RuneNexus/server/internal/httpapi"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if err := run(logger); err != nil {
		logger.Error("api_stopped", slog.Any("error", err))
		os.Exit(1)
	}
}

func run(logger *slog.Logger) error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}

	rootContext, stop := signal.NotifyContext(
		context.Background(),
		syscall.SIGINT,
		syscall.SIGTERM,
	)
	defer stop()

	poolConfig, err := pgxpool.ParseConfig(cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("parse database config: %w", err)
	}
	poolConfig.ConnConfig.ConnectTimeout = cfg.DatabaseConnectTimeout
	poolConfig.ConnConfig.RuntimeParams["application_name"] = "rune_nexus_api"

	connectContext, cancelConnect := context.WithTimeout(
		rootContext,
		cfg.DatabaseConnectTimeout,
	)
	defer cancelConnect()

	pool, err := pgxpool.NewWithConfig(connectContext, poolConfig)
	if err != nil {
		return fmt.Errorf("create database pool: %w", err)
	}
	defer pool.Close()

	if err := pool.Ping(connectContext); err != nil {
		return fmt.Errorf("connect database: %w", err)
	}

	var googleAuthenticator httpapi.GoogleAuthenticator
	if cfg.GoogleAuthEnabled {
		googleVerifier, err := googleauth.NewVerifier(
			rootContext,
			cfg.GoogleWebClientID,
		)
		if err != nil {
			return fmt.Errorf("configure Google authentication: %w", err)
		}
		googleAuthenticator = auth.NewService(
			pool,
			googleVerifier,
			cfg.IdentityVerifyTimeout,
			cfg.AccessTokenTTL,
			cfg.RefreshTokenTTL,
		)
	}

	server := &http.Server{
		Addr: cfg.HTTPAddress,
		Handler: httpapi.NewHandler(logger, httpapi.Dependencies{
			Database:            pool,
			ReadinessTimeout:    cfg.ReadinessTimeout,
			GoogleAuthenticator: googleAuthenticator,
			CORSAllowedOrigins:  cfg.CORSAllowedOrigins,
		}),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}

	serverErrors := make(chan error, 1)
	go func() {
		logger.Info("api_started", slog.String("address", cfg.HTTPAddress))
		serverErrors <- server.ListenAndServe()
	}()

	select {
	case err := <-serverErrors:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return fmt.Errorf("serve http: %w", err)
	case <-rootContext.Done():
		logger.Info("api_shutdown_started")
	}

	shutdownContext, cancelShutdown := context.WithTimeout(
		context.Background(),
		cfg.ShutdownTimeout,
	)
	defer cancelShutdown()

	if err := server.Shutdown(shutdownContext); err != nil {
		_ = server.Close()
		return fmt.Errorf("shutdown http server: %w", err)
	}

	if err := <-serverErrors; !errors.Is(err, http.ErrServerClosed) {
		return fmt.Errorf("stop http server: %w", err)
	}
	logger.Info("api_shutdown_completed")
	return nil
}
