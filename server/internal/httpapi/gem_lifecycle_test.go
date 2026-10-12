package httpapi

import (
	"context"
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type gemLifecycleStub struct {
	EconomyService
	start    economy.StartRunRequest
	close    economy.CloseRunRequest
	purchase economy.GemOfferRequest
}

func (s *gemLifecycleStub) StartRun(_ context.Context, account, session string, r economy.StartRunRequest) (economy.CommandResult, error) {
	s.start = r
	return economy.CommandResult{Run: &economy.RunState{RunID: testAccountID, StageNumber: r.StageNumber, Status: "active"}, GemReceipt: &economy.GemCommandReceipt{Version: 1}}, nil
}
func (s *gemLifecycleStub) CloseRun(_ context.Context, account, session string, r economy.CloseRunRequest) (economy.CommandResult, error) {
	s.close = r
	return economy.CommandResult{Run: &economy.RunState{RunID: r.RunID, Status: "closed"}, GemReceipt: &economy.GemCommandReceipt{Version: 1}}, nil
}
func (s *gemLifecycleStub) PurchaseGems(_ context.Context, account, session string, r economy.GemOfferRequest) (economy.CommandResult, error) {
	s.purchase = r
	return economy.CommandResult{GemReceipt: &economy.GemCommandReceipt{Version: 1}}, nil
}
func TestGemLifecycleWireRejectsUnapprovedInputs(t *testing.T) {
	const common = `"expectedEconomyRevision":1,"expectedCatalogVersion":2,"sourceSaveRevision":1,"writerGeneration":1,"clientCompatibilityVersion":9`
	stub := &gemLifecycleStub{}
	handler := economyHandler{economy: stub, minimumClientCompatibilityVersion: 9}
	for _, test := range []struct {
		name, body string
		fn         func(http.ResponseWriter, *http.Request)
		want       int
	}{
		{"start", `{` + common + `,"stageNumber":1}`, handler.startRun, 200},
		{"client start identity", `{` + common + `,"stageNumber":1,"runId":"` + testAccountID + `"}`, handler.startRun, 400},
		{"missing start stage", `{` + common + `}`, handler.startRun, 400},
		{"client start grant", `{` + common + `,"stageNumber":1,"gemInventory":{"range":9}}`, handler.startRun, 400},
		{"close", `{` + common + `,"runId":"` + testAccountID + `"}`, handler.closeRun, 200},
		{"close extra stage", `{` + common + `,"stageNumber":1,"runId":"` + testAccountID + `"}`, handler.closeRun, 400},
		{"purchase", strings.Replace(gemOfferBody, `"clientCompatibilityVersion":8`, `"clientCompatibilityVersion":9`, 1), handler.purchaseGems, 200},
		{"client purchase price", `{` + common + `,"runId":"` + testAccountID + `","completedRounds":0,"cost":0}`, handler.purchaseGems, 400},
	} {
		t.Run(test.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			test.fn(w, economyRequest("POST", "/v1/economy/test", test.body))
			if w.Code != test.want {
				t.Fatalf("%d %s", w.Code, w.Body.String())
			}
		})
	}
	if stub.start.StageNumber != 1 || stub.start.WriterGeneration != 1 || stub.close.RunID != testAccountID || stub.purchase.CompletedRounds != 5 {
		t.Fatal("wire fields lost")
	}
}

type settlementReplayStub struct {
	EconomyService
	err    error
	called bool
}

func (s *settlementReplayStub) SettleRun(_ context.Context, _ string, _ string, r economy.RunSettlementRequest) (economy.CommandResult, error) {
	s.called = true
	return economy.CommandResult{RewardKey: "run:" + r.RunID + ":settlement"}, s.err
}
func TestOldSettlementReceiptReachesServiceAtMinimumNine(t *testing.T) {
	body := `{"runId":"` + testAccountID + `","writerGeneration":1,"sourceSaveRevision":1,"stageNumber":1,"completedRounds":5,"success":false,"pendingDiamonds":0,"firstClearModuleTickets":0,"clientCompatibilityVersion":8}`
	for _, found := range []bool{true, false} {
		stub := &settlementReplayStub{}
		if !found {
			stub.err = gamesave.ErrClientUpdateRequired
		}
		handler := economyHandler{economy: stub, minimumClientCompatibilityVersion: 9}
		w := httptest.NewRecorder()
		handler.settleRun(w, economyRequest("POST", "/v1/economy/runs/settle", body))
		if !stub.called {
			t.Fatal("old settlement receipt lookup blocked")
		}
		if found && w.Code != 200 {
			t.Fatalf("receipt %d", w.Code)
		}
		if !found {
			requireAPIError(t, w, 426, "CLIENT_UPDATE_REQUIRED")
		}
	}
}
