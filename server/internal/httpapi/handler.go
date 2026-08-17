package httpapi

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
)

const requestIDHeader = "X-Request-ID"

type requestIDContextKey struct{}

type ReadinessChecker interface {
	Ping(context.Context) error
}

type GoogleAuthenticator interface {
	AuthenticateGoogle(context.Context, string) (auth.LoginResult, error)
}

type Dependencies struct {
	Database            ReadinessChecker
	ReadinessTimeout    time.Duration
	GoogleAuthenticator GoogleAuthenticator
	CORSAllowedOrigins  []string
}

type healthHandler struct {
	database         ReadinessChecker
	readinessTimeout time.Duration
}

func NewHandler(
	logger *slog.Logger,
	dependencies Dependencies,
) http.Handler {
	health := healthHandler{
		database:         dependencies.Database,
		readinessTimeout: dependencies.ReadinessTimeout,
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health/live", health.live)
	mux.HandleFunc("GET /health/ready", health.ready)
	if dependencies.GoogleAuthenticator != nil {
		authentication := authenticationHandler{
			logger:        logger,
			authenticator: dependencies.GoogleAuthenticator,
		}
		mux.HandleFunc("POST /v1/auth/google", authentication.google)
	}
	return withRequestMetadata(
		logger,
		withCORS(dependencies.CORSAllowedOrigins, mux),
	)
}

func (health healthHandler) live(response http.ResponseWriter, _ *http.Request) {
	writeJSON(response, http.StatusOK, map[string]string{"status": "ok"})
}

func (health healthHandler) ready(response http.ResponseWriter, request *http.Request) {
	ctx, cancel := context.WithTimeout(request.Context(), health.readinessTimeout)
	defer cancel()
	if err := health.database.Ping(ctx); err != nil {
		writeJSON(
			response,
			http.StatusServiceUnavailable,
			map[string]string{"status": "unavailable"},
		)
		return
	}
	writeJSON(response, http.StatusOK, map[string]string{"status": "ok"})
}

func withRequestMetadata(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		requestID := rand.Text()
		response.Header().Set(requestIDHeader, requestID)
		startedAt := time.Now()
		requestContext := context.WithValue(
			request.Context(),
			requestIDContextKey{},
			requestID,
		)
		next.ServeHTTP(response, request.WithContext(requestContext))

		level := slog.LevelInfo
		if request.URL.Path == "/health/live" || request.URL.Path == "/health/ready" {
			level = slog.LevelDebug
		}
		logger.LogAttrs(
			request.Context(),
			level,
			"http_request",
			slog.String("request_id", requestID),
			slog.String("method", request.Method),
			slog.String("path", request.URL.Path),
			slog.Duration("duration", time.Since(startedAt)),
		)
	})
}

func requestIDFromContext(ctx context.Context) string {
	requestID, _ := ctx.Value(requestIDContextKey{}).(string)
	return requestID
}

func writeJSON(response http.ResponseWriter, status int, value any) {
	response.Header().Set("Content-Type", "application/json; charset=utf-8")
	response.Header().Set("Cache-Control", "no-store")
	response.WriteHeader(status)
	_ = json.NewEncoder(response).Encode(value)
}
