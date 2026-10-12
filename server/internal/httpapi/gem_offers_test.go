package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

type gemOfferEconomyStub struct {
	EconomyService
	offer  economy.GemOfferRequest
	choose economy.GemChooseRequest
	err    error
}

func (s *gemOfferEconomyStub) OfferGems(_ context.Context, account, session string, request economy.GemOfferRequest) (economy.CommandResult, error) {
	if account != testAccountID || session != testSessionID {
		return economy.CommandResult{}, errors.New("wrong principal")
	}
	s.offer = request
	return gemOfferHandlerResult(request.RunID, request.CompletedRounds), s.err
}
func (s *gemOfferEconomyStub) ChooseGem(_ context.Context, account, session string, request economy.GemChooseRequest) (economy.CommandResult, error) {
	if account != testAccountID || session != testSessionID {
		return economy.CommandResult{}, errors.New("wrong principal")
	}
	s.choose = request
	result := gemOfferHandlerResult(request.RunID, request.CompletedRounds)
	result.GemOffer.Status = "chosen"
	result.GemOffer.Revision = 2
	result.GemOffer.Choice = request.Choice
	if request.Choice == "shards" {
		result.GemOffer.GrantedShards = 10
		result.GemOffer.GemShards = 10
	} else {
		result.GemOffer.GrantedGem = request.Choice
		result.GemOffer.GemInventory[request.Choice] = 1
	}
	return result, s.err
}
func gemOfferHandlerResult(run string, wave int) economy.CommandResult {
	offer := &economy.GemOfferState{OfferID: "0198b955-3656-7c40-b3cb-87f427b90bea", RunID: run, RewardWave: wave, Revision: 1, Status: "pending", GemOptions: []string{"range", "chain", "explosion"}, GemInventory: map[string]int64{}}
	return economy.CommandResult{GemOffer: offer, SaveRevision: 2, ActiveRun: json.RawMessage(`{"phase":"reward"}`), Snapshot: economy.Snapshot{GemOfferVersion: 1, GemOffer: offer}}
}

const gemOfferBody = `{"runId":"0198b955-3656-7c40-b3cb-87f427b90be6","completedRounds":5,"expectedEconomyRevision":1,"expectedCatalogVersion":2,"sourceSaveRevision":1,"writerGeneration":1,"clientCompatibilityVersion":8}`

func gemChooseBody(choice string) string {
	return strings.TrimSuffix(gemOfferBody, "}") + `,"offerId":"0198b955-3656-7c40-b3cb-87f427b90bea","expectedOfferRevision":1,"choice":"` + choice + `"}`
}

func TestGemOfferHandlerContract(t *testing.T) {
	stub := &gemOfferEconomyStub{}
	handler := economyHandler{economy: stub}
	response := httptest.NewRecorder()
	handler.offerGems(response, economyRequest(http.MethodPost, "/v1/economy/gems/offer", gemOfferBody))
	if response.Code != http.StatusOK || string(stub.offer.RawBody) != gemOfferBody || stub.offer.SourceSaveRevision != 1 || stub.offer.CompletedRounds != 5 {
		t.Fatalf("response=%d body=%s request=%+v", response.Code, response.Body.String(), stub.offer)
	}
	var result economy.CommandResult
	if err := json.Unmarshal(response.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.Snapshot.GemOfferVersion != 1 || result.GemOffer == nil || result.GemOffer.TotalUsed != 0 || result.SaveRevision != 2 || len(result.ActiveRun) == 0 {
		t.Fatalf("missing wire state: %+v", result)
	}
}

func TestGemChooseHandlerContract(t *testing.T) {
	for _, choice := range []string{"chain", "shards"} {
		t.Run(choice, func(t *testing.T) {
			stub := &gemOfferEconomyStub{}
			handler := economyHandler{economy: stub}
			response := httptest.NewRecorder()
			raw := gemChooseBody(choice)
			handler.chooseGem(response, economyRequest(http.MethodPost, "/v1/economy/gems/choose", raw))
			if response.Code != http.StatusOK || string(stub.choose.RawBody) != raw || stub.choose.Choice != choice || stub.choose.OfferID == "" || stub.choose.ExpectedOfferRevision != 1 {
				t.Fatalf("response=%d body=%s request=%+v", response.Code, response.Body.String(), stub.choose)
			}
		})
	}
}

func TestGemOfferHandlersRejectIncompleteOrClientCandidates(t *testing.T) {
	for _, test := range []struct {
		name, path, body string
		choose           bool
	}{
		{"missing wave", "offer", `{"clientCompatibilityVersion":8}`, false},
		{"client candidates", "offer", strings.TrimSuffix(gemOfferBody, "}") + `,"gemOptions":["range","chain","explosion"]}`, false},
		{"missing choice", "choose", gemOfferBody, true},
		{"client shard amount", "choose", strings.TrimSuffix(gemChooseBody("shards"), "}") + `,"grantedShards":100}`, true},
		{"ambiguous alternative", "choose", strings.TrimSuffix(gemChooseBody("chain"), "}") + `,"alternative":true}`, true},
	} {
		t.Run(test.name, func(t *testing.T) {
			response := httptest.NewRecorder()
			handler := economyHandler{}
			request := economyRequest(http.MethodPost, "/v1/economy/gems/"+test.path, test.body)
			if test.choose {
				handler.chooseGem(response, request)
			} else {
				handler.offerGems(response, request)
			}
			requireAPIError(t, response, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST")
		})
	}
}

func TestGemOfferServiceConflictsAndCompatibilityMapToAPI(t *testing.T) {
	for _, test := range []struct {
		err    error
		status int
		code   string
	}{
		{economy.ErrGemOfferConflict, 409, "GEM_OFFER_STATE_CONFLICT"},
		{economy.ErrInvalidCommand, 422, "ECONOMY_COMMAND_REJECTED"},
		{gamesave.ErrClientUpdateRequired, 426, "CLIENT_UPDATE_REQUIRED"},
	} {
		response := httptest.NewRecorder()
		handler := economyHandler{economy: &gemOfferEconomyStub{err: test.err}}
		handler.chooseGem(response, economyRequest(http.MethodPost, "/v1/economy/gems/choose", gemChooseBody("shards")))
		requireAPIError(t, response, test.status, test.code)
	}
}

func TestGenerationSevenRerollReceiptReachesServiceAtMinimumEight(t *testing.T) {
	stub := &rerollEconomyStub{}
	var log bytes.Buffer
	handler := economyHandler{economy: stub, minimumClientCompatibilityVersion: 8, logger: slog.New(slog.NewJSONHandler(&log, nil))}
	response := httptest.NewRecorder()
	handler.rerollGems(response, economyRequest(http.MethodPost, "/v1/economy/gems/reroll", rerollBody))
	if response.Code != 200 || string(stub.request.RawBody) != rerollBody || log.Len() != 0 {
		t.Fatalf("old exact receipt blocked at HTTP boundary: %d %s", response.Code, response.Body.String())
	}
	// No matching old receipt must still fail in the service, before any mutation.
	stub.err = gamesave.ErrClientUpdateRequired
	response = httptest.NewRecorder()
	handler.rerollGems(response, economyRequest(http.MethodPost, "/v1/economy/gems/reroll", rerollBody))
	requireAPIError(t, response, 426, "CLIENT_UPDATE_REQUIRED")
}

func TestGemCommandRejectionDiagnosticsAreScopedAndRedacted(t *testing.T) {
	for _, path := range []string{"offer", "reroll", "choose"} {
		t.Run(path, func(t *testing.T) {
			var log bytes.Buffer
			handler := economyHandler{logger: slog.New(slog.NewJSONHandler(&log, nil))}
			request := economyRequest(http.MethodPost, "/v1/economy/gems/"+path, `{"choice":"private-candidate","gemInventory":{"private-gem":42}}`)
			request.Header.Set("Authorization", "Bearer private-token")
			response := httptest.NewRecorder()
			if !handler.writeEconomyError(response, request, economy.ErrInvalidCommand) {
				t.Fatal("rejection was not handled")
			}
			var event map[string]any
			if err := json.Unmarshal(log.Bytes(), &event); err != nil {
				t.Fatalf("missing structured diagnostic: %s %v", log.String(), err)
			}
			if event["msg"] != "gem_reward_command_rejected" || event["request_id"] != "economy-test-request" || event["code"] != "ECONOMY_COMMAND_REJECTED" || event["status"] != float64(422) {
				t.Fatalf("incorrect diagnostic %v", event)
			}
			for _, secret := range []string{"private-token", "private-candidate", "private-gem", "gemInventory", "Authorization", "choice", "body", "hacking", "cheating"} {
				if strings.Contains(log.String(), secret) {
					t.Fatalf("diagnostic exposed or misclassified %q: %s", secret, log.String())
				}
			}
			log.Reset()
			// Stale revisions are ordinary conflicts, with no punitive classification.
			handler.writeEconomyError(httptest.NewRecorder(), request, economy.ErrGemOfferConflict)
			if !strings.Contains(log.String(), `"code":"GEM_OFFER_STATE_CONFLICT"`) || !strings.Contains(log.String(), `"status":409`) {
				t.Fatalf("conflict diagnostic absent: %s", log.String())
			}
			log.Reset()
			if handler.writeEconomyError(httptest.NewRecorder(), request, nil) || log.Len() != 0 {
				t.Fatal("successful exact replay logged as rejection")
			}
		})
	}
	var log bytes.Buffer
	handler := economyHandler{logger: slog.New(slog.NewJSONHandler(&log, nil))}
	handler.writeEconomyError(httptest.NewRecorder(), economyRequest(http.MethodPost, "/v1/economy/modules/draw", gemOfferBody), economy.ErrInvalidCommand)
	if log.Len() != 0 {
		t.Fatalf("gem diagnostic leaked onto unrelated endpoint: %s", log.String())
	}
}

func TestGenerationEightOfferAndChoiceReceiptReachServiceAtMinimumNine(t *testing.T) {
	for _, choose := range []bool{false, true} {
		stub := &gemOfferEconomyStub{}
		handler := economyHandler{economy: stub, minimumClientCompatibilityVersion: 9}
		response := httptest.NewRecorder()
		if choose {
			handler.chooseGem(response, economyRequest(http.MethodPost, "/v1/economy/gems/choose", gemChooseBody("shards")))
		} else {
			handler.offerGems(response, economyRequest(http.MethodPost, "/v1/economy/gems/offer", gemOfferBody))
		}
		if response.Code != 200 {
			t.Fatalf("gen8 receipt rejected before service lookup: %d %s", response.Code, response.Body.String())
		}
		stub.err = gamesave.ErrClientUpdateRequired
		response = httptest.NewRecorder()
		if choose {
			handler.chooseGem(response, economyRequest(http.MethodPost, "/v1/economy/gems/choose", gemChooseBody("shards")))
		} else {
			handler.offerGems(response, economyRequest(http.MethodPost, "/v1/economy/gems/offer", gemOfferBody))
		}
		requireAPIError(t, response, 426, "CLIENT_UPDATE_REQUIRED")
	}
}
