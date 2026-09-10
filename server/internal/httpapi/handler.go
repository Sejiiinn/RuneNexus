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
	GetAccountProfile(context.Context, string) (auth.AccountProfile, error)
	SetNickname(context.Context, string, string) (auth.AccountProfile, error)
}

type Dependencies struct {
	Database                              ReadinessChecker
	ReadinessTimeout                      time.Duration
	Authenticator                         Authenticator
	AuthenticationRateLimits              AuthenticationRateLimits
	SaveService                           SaveService
	WeeklyRewardService                   WeeklyRewardService
	EconomyService                        EconomyService
	MailboxService                        MailboxService
	LeaderboardService                    LeaderboardService
	LegacyTransferService                 LegacyTransferService
	MaxSaveBodyBytes                      int64
	MinimumSaveClientCompatibilityVersion int
	CORSAllowedOrigins                    []string
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
			logger:         logger,
			authenticator:  dependencies.Authenticator,
			allowedOrigins: dependencies.CORSAllowedOrigins,
		}
		mux.HandleFunc("POST /v1/auth/google", authentication.google)
		mux.HandleFunc("POST /v1/auth/refresh", authentication.refresh)
		mux.HandleFunc("POST /v1/auth/logout", authentication.logout)
		for _, platform := range []string{"web", "native"} {
			for _, operation := range []string{"google", "refresh", "logout"} {
				mux.HandleFunc("POST /v1/auth/"+platform+"/"+operation, authentication.persistent)
			}
		}
		profiles := profileHandler{logger: logger, accounts: dependencies.Authenticator}
		mux.Handle("GET /v1/account/profile", withBearerAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(profiles.get)))
		mux.Handle("PUT /v1/account/nickname", withBearerAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(profiles.setNickname)))
		if dependencies.SaveService != nil {
			saves := saveHandler{
				logger:                            logger,
				saves:                             dependencies.SaveService,
				maxSaveBodyBytes:                  dependencies.MaxSaveBodyBytes,
				minimumClientCompatibilityVersion: dependencies.MinimumSaveClientCompatibilityVersion,
			}
			mux.Handle(
				"POST /v1/save/writer",
				withAccountAuthentication(
					logger,
					dependencies.Authenticator,
					http.HandlerFunc(saves.claimWriter),
				),
			)
			mux.Handle(
				"GET /v1/save",
				withAccountAuthentication(
					logger,
					dependencies.Authenticator,
					http.HandlerFunc(saves.get),
				),
			)
			mux.Handle(
				"PUT /v1/save",
				withAccountAuthentication(
					logger,
					dependencies.Authenticator,
					http.HandlerFunc(saves.update),
				),
			)
		}
		if dependencies.WeeklyRewardService != nil {
			rewards := weeklyRewardHandler{
				logger:                            logger,
				rewards:                           dependencies.WeeklyRewardService,
				minimumClientCompatibilityVersion: dependencies.MinimumSaveClientCompatibilityVersion,
			}
			mux.Handle(
				"POST /v1/economy/rewards/claim",
				withAccountAuthentication(
					logger,
					dependencies.Authenticator,
					http.HandlerFunc(rewards.claim),
				),
			)
		}
		if dependencies.LeaderboardService != nil {
			leaderboards := leaderboardHandler{logger: logger, leaderboards: dependencies.LeaderboardService}
			mux.Handle("GET /v1/leaderboards/progression", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(leaderboards.progression)))
		}
		if dependencies.MailboxService != nil {
			mailbox := mailboxHandler{economyHandler: economyHandler{logger: logger, minimumClientCompatibilityVersion: dependencies.MinimumSaveClientCompatibilityVersion}, mailbox: dependencies.MailboxService}
			mux.Handle("GET /v1/mailbox", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(mailbox.list)))
			mux.Handle("GET /v1/mailbox/summary", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(mailbox.summary)))
			mux.Handle("POST /v1/mailbox/{mailId}/read", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(mailbox.read)))
			mux.Handle("POST /v1/mailbox/{mailId}/claim", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(mailbox.claim)))
			mux.Handle("POST /v1/mailbox/claim-all", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(mailbox.claimAll)))
		}
		if dependencies.EconomyService != nil {
			economyAPI := economyHandler{
				logger:                            logger,
				economy:                           dependencies.EconomyService,
				minimumClientCompatibilityVersion: dependencies.MinimumSaveClientCompatibilityVersion,
			}
			mux.Handle("GET /v1/economy", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(economyAPI.get)))
			mux.Handle("GET /v1/economy/catalog", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(economyAPI.catalog)))
			mux.Handle("POST /v1/economy/bootstrap", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(economyAPI.bootstrap)))
			mux.Handle("POST /v1/economy/turret-modules/draw", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(economyAPI.draw)))
			mux.Handle("POST /v1/economy/turret-modules/disassemble", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(economyAPI.disassemble)))
			mux.Handle("POST /v1/economy/researches/{type}/complete", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(economyAPI.completeResearch)))
			mux.Handle("POST /v1/economy/research-slots/2/unlock", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(economyAPI.unlockResearchSlot)))
			mux.Handle("POST /v1/economy/progression-effects/{effectId}/ack", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(economyAPI.acknowledgeEffect)))
			mux.Handle("POST /v1/economy/runs/settle", withAccountAuthentication(logger, dependencies.Authenticator, http.HandlerFunc(economyAPI.settleRun)))
		}
		if dependencies.LegacyTransferService != nil {
			transfers := legacyTransferHandler{
				logger:                            logger,
				transfers:                         dependencies.LegacyTransferService,
				maxSaveBodyBytes:                  dependencies.MaxSaveBodyBytes,
				minimumClientCompatibilityVersion: dependencies.MinimumSaveClientCompatibilityVersion,
			}
			mux.HandleFunc("POST /v1/legacy-save-transfers", transfers.create)
			mux.Handle(
				"POST /v1/legacy-save-transfers/consume",
				withAccountAuthentication(
					logger,
					dependencies.Authenticator,
					http.HandlerFunc(transfers.consume),
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
