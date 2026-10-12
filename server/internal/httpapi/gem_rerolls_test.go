package httpapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
)

type rerollEconomyStub struct {
	EconomyService
	request economy.GemRerollRequest
	err     error
}

func (s *rerollEconomyStub) RerollGems(_ context.Context, account, session string, request economy.GemRerollRequest) (economy.CommandResult, error) {
	if account != testAccountID || session != testSessionID {
		return economy.CommandResult{}, errors.New("wrong principal")
	}
	s.request = request
	state := &economy.GemRerollState{RunID: request.RunID, RewardWave: request.CompletedRounds, TotalUsed: 1, GemOptions: []string{"chain", "explosion", "heavyWeapon"}}
	return economy.CommandResult{Snapshot: economy.Snapshot{GemRerollVersion: 1, GemReroll: state}, GemReroll: state}, s.err
}

const rerollBody = `{"runId":"0198b955-3656-7c40-b3cb-87f427b90be6","completedRounds":5,"expectedRerollCount":0,"expectedEconomyRevision":1,"expectedCatalogVersion":2,"sourceSaveRevision":1,"writerGeneration":1,"clientCompatibilityVersion":7}`

func TestGemRerollHandlerContract(t *testing.T) {
	stub := &rerollEconomyStub{}
	handler := economyHandler{economy: stub}
	response := httptest.NewRecorder()
	handler.rerollGems(response, economyRequest(http.MethodPost, "/v1/economy/gems/reroll", rerollBody))
	if response.Code != http.StatusOK || string(stub.request.RawBody) != rerollBody || stub.request.CompletedRounds != 5 || stub.request.ExpectedRerollCount != 0 {
		t.Fatalf("response=%d body=%s request=%+v", response.Code, response.Body.String(), stub.request)
	}
}
func TestGemRerollHandlerRejectsIncompleteAndOldBodies(t *testing.T) {
	for _, test := range []struct {
		body   string
		status int
		code   string
	}{
		{`{"clientCompatibilityVersion":7}`, 400, "INVALID_ECONOMY_REQUEST"},
		{`{"clientCompatibilityVersion":6}`, 426, "CLIENT_UPDATE_REQUIRED"},
		{`{"clientCompatibilityVersion":7,"rewardWave":5}`, 400, "INVALID_ECONOMY_REQUEST"},
		{`{"clientCompatibilityVersion":7,"ticketCost":0}`, 400, "INVALID_ECONOMY_REQUEST"},
	} {
		response := httptest.NewRecorder()
		economyHandler{}.rerollGems(response, economyRequest(http.MethodPost, "/v1/economy/gems/reroll", test.body))
		requireAPIError(t, response, test.status, test.code)
	}
}
func TestGemRerollErrors(t *testing.T) {
	for _, test := range []struct {
		err    error
		status int
		code   string
	}{
		{economy.ErrInsufficientGemResetTickets, 422, "INSUFFICIENT_GEM_RESET_TICKETS"},
		{economy.ErrGemRerollLimit, 422, "GEM_REROLL_LIMIT_REACHED"},
		{economy.ErrGemRerollConflict, 409, "GEM_REROLL_STATE_CONFLICT"},
	} {
		handler := economyHandler{economy: &rerollEconomyStub{err: test.err}}
		response := httptest.NewRecorder()
		handler.rerollGems(response, economyRequest(http.MethodPost, "/v1/economy/gems/reroll", rerollBody))
		requireAPIError(t, response, test.status, test.code)
	}
}
