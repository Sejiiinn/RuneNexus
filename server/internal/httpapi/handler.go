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

type Authenticator interface {
	AuthenticateGoogle(context.Context, string) (auth.LoginResult, error)
	Refresh(context.Context, string) (auth.LoginResult, error)
	Logout(context.Context, string, string) error
	AuthenticateAccessToken(context.Context, string) (auth.Principal, error)
}

type Dependencies struct {
	Database                 ReadinessChecker
	ReadinessTimeout         time.Duration
	Authenticator            Authenticator
	AuthenticationRateLimits AuthenticationRateLimits
	SaveService              SaveService
	MaxSaveBodyBytes         int64
	CORSAllowedOrigins       []string
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
	if dependencies.Authenticator != nil {
		authentication := authenticationHandler{
			logger:        logger,
			authenticator: dependencies.Authenticator,
		}
		mux.HandleFunc("POST /v1/auth/google", authentication.google)
		mux.HandleFunc("POST /v1/auth/refresh", authentication.refresh)
		mux.HandleFunc("POST /v1/auth/logout", authentication.logout)
		if dependencies.SaveService != nil {
			saves := saveHandler{
				logger:           logger,
				saves:            dependencies.SaveService,
				maxSaveBodyBytes: dependencies.MaxSaveBodyBytes,
			}
			mux.Handle(
				"GET /v1/save",
				withBearerAuthentication(
					logger,
					dependencies.Authenticator,
					http.HandlerFunc(saves.get),
				),
			)
			mux.Handle(
				"PUT /v1/save",
				withBearerAuthentication(
					logger,
					dependencies.Authenticator,
					http.HandlerFunc(saves.update),
				),
			)
		}
	}
	apiHandler := withAuthenticationRateLimits(
		dependencies.AuthenticationRateLimits,
		mux,
	)
	return withRequestMetadata(
		logger,
		withCORS(dependencies.CORSAllowedOrigins, apiHandler),
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
