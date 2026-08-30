package httpapi

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
)

func TestEconomyCommandsRequireCurrentCompatibilityGeneration(t *testing.T) {
	handler := economyHandler{
		logger:                            slog.New(slog.NewTextHandler(io.Discard, nil)),
		minimumClientCompatibilityVersion: 1,
	}
	request := economyRequest(
		http.MethodPost,
		"/v1/economy/bootstrap",
		`{"expectedSaveRevision":1,"writerGeneration":1,"clientCompatibilityVersion":1}`,
	)
	response := httptest.NewRecorder()

	handler.bootstrap(response, request)

	requireAPIError(t, response, http.StatusUpgradeRequired, "CLIENT_UPDATE_REQUIRED")
}

func TestRunSettlementRequiresDurableFirstClearRewardEvidence(t *testing.T) {
	handler := economyHandler{
		logger:                            slog.New(slog.NewTextHandler(io.Discard, nil)),
		minimumClientCompatibilityVersion: 1,
	}
	request := economyRequest(
		http.MethodPost,
		"/v1/economy/runs/settle",
		`{"runId":"0198b955-3656-7c40-b3cb-87f427b90be6","writerGeneration":1,"sourceSaveRevision":1,"stageNumber":1,"completedRounds":1,"success":false,"pendingDiamonds":0,"clientCompatibilityVersion":2}`,
	)
	response := httptest.NewRecorder()

	handler.settleRun(response, request)

	requireAPIError(t, response, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST")
}

func economyRequest(method string, path string, body string) *http.Request {
	request := jsonRequest(method, path, body)
	request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
	ctx := context.WithValue(
		request.Context(),
		authenticatedPrincipalContextKey{},
		auth.Principal{AccountID: testAccountID, SessionID: testSessionID},
	)
	ctx = context.WithValue(ctx, requestIDContextKey{}, "economy-test-request")
	return request.WithContext(ctx)
}
