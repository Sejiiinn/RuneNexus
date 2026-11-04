package httpapi

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"

	"github.com/Sejiiinn/RuneNexus/server/internal/runlog"
)

type RunLogService interface {
	Record(context.Context, string, runlog.Entry) error
}

type runLogHandler struct {
	logger  *slog.Logger
	runLogs RunLogService
}

// Analysis-only: clients send once and drop the log on any failure, so the
// response carries no data beyond success.
func (handler runLogHandler) record(response http.ResponseWriter, request *http.Request) {
	principal, _ := authenticatedPrincipalFromContext(request.Context())
	request.Body = http.MaxBytesReader(response, request.Body, runlog.MaxBodyBytes)
	raw, err := io.ReadAll(request.Body)
	if err != nil {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_RUN_LOG", "런 기록 본문을 읽을 수 없습니다.")
		return
	}
	entry, err := runlog.Parse(raw)
	if errors.Is(err, runlog.ErrInvalid) {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_RUN_LOG", "런 기록 형식이 올바르지 않습니다.")
		return
	}
	if err := handler.runLogs.Record(request.Context(), principal.AccountID, entry); err != nil {
		handler.logger.ErrorContext(request.Context(), "run_log_record_failed", slog.String("request_id", requestIDFromContext(request.Context())), slog.Any("error", err))
		writeAPIError(response, request, http.StatusInternalServerError, "INTERNAL_ERROR", "런 기록을 저장하는 중 오류가 발생했습니다.")
		return
	}
	writeJSON(response, http.StatusOK, map[string]string{"code": "OK"})
}
