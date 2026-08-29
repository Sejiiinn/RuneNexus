package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/weeklyreward"
)

type weeklyRewardServiceStub struct {
	claim func(context.Context, string, string, weeklyreward.ClaimRequest) (weeklyreward.ClaimResult, error)
}

func (stub weeklyRewardServiceStub) Claim(
	ctx context.Context,
	accountID string,
	sessionID string,
	request weeklyreward.ClaimRequest,
) (weeklyreward.ClaimResult, error) {
	return stub.claim(ctx, accountID, sessionID, request)
}

func TestWeeklyRewardClaimPassesAuthenticatedPrincipalAndExactBody(t *testing.T) {
	claimedAt := time.Date(2026, 8, 29, 1, 2, 3, 0, time.UTC)
	body := `{"period":"weekly","rewardType":"quest","questType":"killEnemies"}`
	handler := newWeeklyRewardTestHandler(t, weeklyRewardServiceStub{claim: func(
		_ context.Context,
		accountID string,
		sessionID string,
		request weeklyreward.ClaimRequest,
	) (weeklyreward.ClaimResult, error) {
		if accountID != testAccountID || sessionID != testSessionID ||
			request.IdempotencyKey != testIdempotencyKey || string(request.RawBody) != body ||
			request.RewardType != weeklyreward.RewardTypeQuest || request.QuestType != "killEnemies" {
			t.Fatalf("request = %#v, account = %q, session = %q", request, accountID, sessionID)
		}
		return weeklyreward.ClaimResult{
			RewardKey:          "weekly:2026-W35:quest:killEnemies",
			PeriodKey:          "2026-W35",
			WeekKey:            2956,
			RewardType:         weeklyreward.RewardTypeQuest,
			QuestType:          "killEnemies",
			Diamonds:           20,
			SourceSaveRevision: 7,
			ClaimedAt:          claimedAt,
		}, nil
	}})
	request := jsonRequest(http.MethodPost, "/v1/economy/rewards/claim", body)
	request.Header.Set("Authorization", "Bearer access-token")
	request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var decoded weeklyRewardClaimResponse
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if decoded.RewardKey != "weekly:2026-W35:quest:killEnemies" ||
		decoded.Diamonds != 20 || decoded.SourceSaveRevision != 7 ||
		!decoded.ClaimedAt.Equal(claimedAt) {
		t.Fatalf("response = %#v", decoded)
	}
}

func TestWeeklyRewardClaimReturnsRecoverableAlreadyClaimedReceipt(t *testing.T) {
	result := weeklyreward.ClaimResult{
		RewardKey:          "weekly:2026-W35:attendance",
		PeriodKey:          "2026-W35",
		WeekKey:            2956,
		RewardType:         weeklyreward.RewardTypeAttendance,
		Diamonds:           20,
		SourceSaveRevision: 7,
		ClaimedAt:          time.Date(2026, 8, 29, 1, 2, 3, 0, time.UTC),
	}
	handler := newWeeklyRewardTestHandler(t, weeklyRewardServiceStub{claim: func(
		context.Context,
		string,
		string,
		weeklyreward.ClaimRequest,
	) (weeklyreward.ClaimResult, error) {
		return weeklyreward.ClaimResult{}, &weeklyreward.AlreadyClaimedError{Result: result}
	}})
	request := jsonRequest(
		http.MethodPost,
		"/v1/economy/rewards/claim",
		`{"period":"weekly","rewardType":"attendance"}`,
	)
	request.Header.Set("Authorization", "Bearer access-token")
	request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusConflict {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var decoded weeklyRewardAlreadyClaimedResponse
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if decoded.Code != "REWARD_ALREADY_CLAIMED" ||
		decoded.Reward.RewardKey != result.RewardKey || decoded.RequestID == "" {
		t.Fatalf("response = %#v", decoded)
	}
}

func newWeeklyRewardTestHandler(t *testing.T, rewards WeeklyRewardService) http.Handler {
	t.Helper()
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return NewHandler(logger, Dependencies{
		Database: readinessCheckerFunc(func(context.Context) error {
			return nil
		}),
		ReadinessTimeout:    50 * time.Millisecond,
		Authenticator:       successfulAccessAuthenticator(t),
		WeeklyRewardService: rewards,
	})
}
