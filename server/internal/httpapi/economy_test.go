package httpapi

import (
	"context"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
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

func TestGrowthCompatibilityEconomyErrorRequiresClientUpdate(t *testing.T) {
	response := httptest.NewRecorder()
	handler := economyHandler{}
	if !handler.writeEconomyError(response, economyRequest(http.MethodPost, "/v1/economy/researches/criticalChance/complete", `{}`), gamesave.ErrClientUpdateRequired) {
		t.Fatal("error was not handled")
	}
	requireAPIError(t, response, http.StatusUpgradeRequired, "CLIENT_UPDATE_REQUIRED")
}

type challengeClaimStub struct {
	EconomyService
	request economy.StageChallengeClaimRequest
	called  bool
}

func (stub *challengeClaimStub) ClaimStageChallenge(_ context.Context, _ string, _ string, request economy.StageChallengeClaimRequest) (economy.CommandResult, error) {
	stub.called, stub.request = true, request
	return economy.CommandResult{RewardKey: "stage:11:challenge:normal", GrantedDiamonds: 300}, nil
}

// The client sends the common economy fields with every command.
func TestChallengeClaimAcceptsCurrentClientBody(t *testing.T) {
	stub := &challengeClaimStub{}
	handler := economyHandler{economy: stub, logger: slog.New(slog.NewTextHandler(io.Discard, nil)), minimumClientCompatibilityVersion: 1}
	response := httptest.NewRecorder()
	handler.claimStageChallenge(response, economyRequest(http.MethodPost, "/v1/economy/challenges/claim",
		`{"expectedEconomyRevision":3,"expectedCatalogVersion":2,"stageNumber":11,"difficulty":"normal","sourceSaveRevision":2,"writerGeneration":1,"clientCompatibilityVersion":16}`))
	if response.Code != http.StatusOK || !stub.called || stub.request.ExpectedRevision != 3 || stub.request.ExpectedCatalogVersion != 2 || stub.request.StageNumber != 11 {
		t.Fatalf("status=%d called=%v request=%+v body=%s", response.Code, stub.called, stub.request, response.Body.String())
	}
	missing := httptest.NewRecorder()
	handler.claimStageChallenge(missing, economyRequest(http.MethodPost, "/v1/economy/challenges/claim",
		`{"stageNumber":11,"difficulty":"normal","sourceSaveRevision":2,"writerGeneration":1,"clientCompatibilityVersion":16}`))
	requireAPIError(t, missing, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST")
}
