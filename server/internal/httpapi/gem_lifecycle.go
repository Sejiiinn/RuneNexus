package httpapi

import (
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	"net/http"
)

type economyRunLifecycleRequest struct {
	economyResearchRequest
	RunID       string `json:"runId"`
	StageNumber *int   `json:"stageNumber"`
}

func (handler economyHandler) purchaseGems(response http.ResponseWriter, request *http.Request) {
	principal, key, raw, input, ok := decodeEconomyCommand[economyGemOfferRequest](handler, response, request)
	if !ok {
		return
	}
	if !validGemOfferInput(input) {
		writeAPIError(response, request, 400, "INVALID_ECONOMY_REQUEST", "젬 구매 요청 정보가 부족합니다.")
		return
	}
	result, err := handler.economy.PurchaseGems(request.Context(), principal.AccountID, principal.SessionID, gemOfferCommand(input, key, raw))
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, 200, result)
}

func (handler economyHandler) startRun(response http.ResponseWriter, request *http.Request) {
	principal, key, raw, input, ok := decodeEconomyCommand[economyRunLifecycleRequest](handler, response, request)
	if !ok {
		return
	}
	if !validResearchInput(input.economyResearchRequest) || input.StageNumber == nil || input.RunID != "" {
		writeAPIError(response, request, 400, "INVALID_ECONOMY_REQUEST", "도전 시작 요청 정보가 부족합니다.")
		return
	}
	result, err := handler.economy.StartRun(request.Context(), principal.AccountID, principal.SessionID, economy.StartRunRequest{IdempotencyKey: key, RawBody: raw, WriterGeneration: *input.WriterGeneration, SourceSaveRevision: *input.SourceSaveRevision, ExpectedRevision: *input.ExpectedEconomyRevision, ExpectedCatalogVersion: *input.ExpectedCatalogVersion, StageNumber: *input.StageNumber})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, 200, result)
}

func (handler economyHandler) closeRun(response http.ResponseWriter, request *http.Request) {
	principal, key, raw, input, ok := decodeEconomyCommand[economyRunLifecycleRequest](handler, response, request)
	if !ok {
		return
	}
	if !validResearchInput(input.economyResearchRequest) || input.RunID == "" || input.StageNumber != nil {
		writeAPIError(response, request, 400, "INVALID_ECONOMY_REQUEST", "도전 종료 요청 정보가 부족합니다.")
		return
	}
	result, err := handler.economy.CloseRun(request.Context(), principal.AccountID, principal.SessionID, economy.CloseRunRequest{IdempotencyKey: key, RawBody: raw, WriterGeneration: *input.WriterGeneration, SourceSaveRevision: *input.SourceSaveRevision, ExpectedRevision: *input.ExpectedEconomyRevision, ExpectedCatalogVersion: *input.ExpectedCatalogVersion, RunID: input.RunID})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, 200, result)
}
