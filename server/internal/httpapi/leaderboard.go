package httpapi

import (
	"context"
	"log/slog"
	"net/http"

	"github.com/Sejiiinn/RuneNexus/server/internal/leaderboard"
)

type LeaderboardService interface {
	GetProgression(context.Context, string) (leaderboard.Snapshot, error)
}

type leaderboardHandler struct {
	logger       *slog.Logger
	leaderboards LeaderboardService
}

func (handler leaderboardHandler) progression(response http.ResponseWriter, request *http.Request) {
	principal, _ := authenticatedPrincipalFromContext(request.Context())
	snapshot, err := handler.leaderboards.GetProgression(request.Context(), principal.AccountID)
	if err != nil {
		handler.logger.ErrorContext(request.Context(), "leaderboard_query_failed", slog.String("request_id", requestIDFromContext(request.Context())), slog.Any("error", err))
		writeAPIError(response, request, http.StatusInternalServerError, "INTERNAL_ERROR", "리더보드를 불러오는 중 오류가 발생했습니다.")
		return
	}
	writeJSON(response, http.StatusOK, snapshot)
}
