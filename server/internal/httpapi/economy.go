package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"mime"
	"net/http"
	"strings"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

const maxEconomyBodyBytes int64 = 64 * 1024

type EconomyService interface {
	PurchaseGems(context.Context, string, string, economy.GemOfferRequest) (economy.CommandResult, error)
	StartRun(context.Context, string, string, economy.StartRunRequest) (economy.CommandResult, error)
	CloseRun(context.Context, string, string, economy.CloseRunRequest) (economy.CommandResult, error)
	OfferGems(context.Context, string, string, economy.GemOfferRequest) (economy.CommandResult, error)
	ChooseGem(context.Context, string, string, economy.GemChooseRequest) (economy.CommandResult, error)
	RerollGems(context.Context, string, string, economy.GemRerollRequest) (economy.CommandResult, error)
	Get(context.Context, string) (economy.Snapshot, error)
	Bootstrap(context.Context, string, string, economy.BootstrapRequest) (economy.BootstrapResult, error)
	DrawModules(context.Context, string, string, economy.DrawRequest) (economy.CommandResult, error)
	DisassembleModules(context.Context, string, economy.DisassembleRequest) (economy.CommandResult, error)
	CompleteResearch(context.Context, string, string, economy.ResearchCompleteRequest) (economy.CommandResult, error)
	UnlockResearchSlotTwo(context.Context, string, string, economy.ResearchSlotUnlockRequest) (economy.CommandResult, error)
	AcknowledgeProgressionEffect(context.Context, string, string, economy.EffectAckRequest) (economy.CommandResult, error)
	SettleRun(context.Context, string, string, economy.RunSettlementRequest) (economy.CommandResult, error)
}

type economyHandler struct {
	logger                            *slog.Logger
	economy                           EconomyService
	minimumClientCompatibilityVersion int
}

type economyBootstrapRequest struct {
	ExpectedSaveRevision       *int64 `json:"expectedSaveRevision"`
	WriterGeneration           *int64 `json:"writerGeneration"`
	ClientCompatibilityVersion *int   `json:"clientCompatibilityVersion"`
}

type economyGemRerollRequest struct {
	OfferID                    string `json:"offerId"`
	ExpectedOfferRevision      *int64 `json:"expectedOfferRevision"`
	ExpectedEconomyRevision    *int64 `json:"expectedEconomyRevision"`
	ExpectedCatalogVersion     *int32 `json:"expectedCatalogVersion"`
	SourceSaveRevision         *int64 `json:"sourceSaveRevision"`
	WriterGeneration           *int64 `json:"writerGeneration"`
	ClientCompatibilityVersion *int   `json:"clientCompatibilityVersion"`
	RunID                      string `json:"runId"`
	CompletedRounds            *int   `json:"completedRounds"`
	ExpectedRerollCount        *int   `json:"expectedRerollCount"`
}

func (handler economyHandler) rerollGems(response http.ResponseWriter, request *http.Request) {
	// Generation-seven exact receipts remain recoverable even when the global
	// minimum is eight. The service gates new work after receipt lookup.
	decoderHandler := handler
	decoderHandler.minimumClientCompatibilityVersion = gamesave.GemRerollClientCompatibilityVersion
	principal, key, raw, input, ok := decodeEconomyCommand[economyGemRerollRequest](decoderHandler, response, request)
	if !ok {
		return
	}
	if *input.ClientCompatibilityVersion < gamesave.GemRerollClientCompatibilityVersion {
		writeAPIError(response, request, http.StatusUpgradeRequired, "CLIENT_UPDATE_REQUIRED", "최신 버전에서 젬 재선택을 사용할 수 있습니다.")
		return
	}
	if input.ExpectedEconomyRevision == nil || input.ExpectedCatalogVersion == nil || input.SourceSaveRevision == nil || input.WriterGeneration == nil || input.CompletedRounds == nil || input.ExpectedRerollCount == nil || input.RunID == "" {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "젬 재선택 요청 정보가 부족합니다.")
		return
	}
	var offerRevision int64
	if input.ExpectedOfferRevision != nil {
		offerRevision = *input.ExpectedOfferRevision
	}
	result, err := handler.economy.RerollGems(request.Context(), principal.AccountID, principal.SessionID, economy.GemRerollRequest{
		OfferID: input.OfferID, ExpectedOfferRevision: offerRevision,
		IdempotencyKey: key, RawBody: raw, ExpectedRevision: *input.ExpectedEconomyRevision,
		ExpectedCatalogVersion: *input.ExpectedCatalogVersion, SourceSaveRevision: *input.SourceSaveRevision,
		WriterGeneration: *input.WriterGeneration, RunID: input.RunID, CompletedRounds: *input.CompletedRounds,
		ExpectedRerollCount: *input.ExpectedRerollCount,
	})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, http.StatusOK, result)
}

type economyGemOfferRequest struct {
	ExpectedEconomyRevision    *int64 `json:"expectedEconomyRevision"`
	ExpectedCatalogVersion     *int32 `json:"expectedCatalogVersion"`
	SourceSaveRevision         *int64 `json:"sourceSaveRevision"`
	WriterGeneration           *int64 `json:"writerGeneration"`
	ClientCompatibilityVersion *int   `json:"clientCompatibilityVersion"`
	RunID                      string `json:"runId"`
	CompletedRounds            *int   `json:"completedRounds"`
}

type economyGemChooseRequest struct {
	economyGemOfferRequest
	OfferID               string `json:"offerId"`
	ExpectedOfferRevision *int64 `json:"expectedOfferRevision"`
	Choice                string `json:"choice"`
}

func validGemOfferInput(input economyGemOfferRequest) bool {
	return input.ExpectedEconomyRevision != nil && input.ExpectedCatalogVersion != nil && input.SourceSaveRevision != nil && input.WriterGeneration != nil && input.CompletedRounds != nil && input.RunID != ""
}

func gemOfferCommand(input economyGemOfferRequest, key string, raw []byte) economy.GemOfferRequest {
	return economy.GemOfferRequest{IdempotencyKey: key, RawBody: raw, ExpectedRevision: *input.ExpectedEconomyRevision, ExpectedCatalogVersion: *input.ExpectedCatalogVersion, SourceSaveRevision: *input.SourceSaveRevision, WriterGeneration: *input.WriterGeneration, RunID: input.RunID, CompletedRounds: *input.CompletedRounds}
}

func (handler economyHandler) offerGems(response http.ResponseWriter, request *http.Request) {
	decoderHandler := handler
	decoderHandler.minimumClientCompatibilityVersion = gamesave.GemOfferClientCompatibilityVersion
	principal, key, raw, input, ok := decodeEconomyCommand[economyGemOfferRequest](decoderHandler, response, request)
	if !ok {
		return
	}
	if !validGemOfferInput(input) {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "젬 보상 요청 정보가 부족합니다.")
		return
	}
	result, err := handler.economy.OfferGems(request.Context(), principal.AccountID, principal.SessionID, gemOfferCommand(input, key, raw))
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, http.StatusOK, result)
}

func (handler economyHandler) chooseGem(response http.ResponseWriter, request *http.Request) {
	decoderHandler := handler
	decoderHandler.minimumClientCompatibilityVersion = gamesave.GemOfferClientCompatibilityVersion
	principal, key, raw, input, ok := decodeEconomyCommand[economyGemChooseRequest](decoderHandler, response, request)
	if !ok {
		return
	}
	if !validGemOfferInput(input.economyGemOfferRequest) || input.OfferID == "" || input.ExpectedOfferRevision == nil || input.Choice == "" {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "젬 선택 요청 정보가 부족합니다.")
		return
	}
	result, err := handler.economy.ChooseGem(request.Context(), principal.AccountID, principal.SessionID, economy.GemChooseRequest{GemOfferRequest: gemOfferCommand(input.economyGemOfferRequest, key, raw), OfferID: input.OfferID, ExpectedOfferRevision: *input.ExpectedOfferRevision, Choice: input.Choice})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, http.StatusOK, result)
}

type economyDrawRequest struct {
	ExpectedEconomyRevision       *int64 `json:"expectedEconomyRevision"`
	ExpectedCatalogVersion        *int32 `json:"expectedCatalogVersion"`
	SourceSaveRevision            *int64 `json:"sourceSaveRevision"`
	WriterGeneration              *int64 `json:"writerGeneration"`
	Count                         *int   `json:"count"`
	TurretType                    string `json:"turretType"`
	BuyMissingTicketsWithDiamonds bool   `json:"buyMissingTicketsWithDiamonds"`
	ClientCompatibilityVersion    *int   `json:"clientCompatibilityVersion"`
}

type economyDisassembleRequest struct {
	ExpectedEconomyRevision    *int64   `json:"expectedEconomyRevision"`
	ExpectedCatalogVersion     *int32   `json:"expectedCatalogVersion"`
	ModuleIDs                  []string `json:"moduleIds"`
	ClientCompatibilityVersion *int     `json:"clientCompatibilityVersion"`
}

type economyResearchRequest struct {
	ExpectedEconomyRevision    *int64 `json:"expectedEconomyRevision"`
	ExpectedCatalogVersion     *int32 `json:"expectedCatalogVersion"`
	SourceSaveRevision         *int64 `json:"sourceSaveRevision"`
	WriterGeneration           *int64 `json:"writerGeneration"`
	ClientCompatibilityVersion *int   `json:"clientCompatibilityVersion"`
}

type economyEffectAckRequest struct {
	AppliedSaveRevision        *int64 `json:"appliedSaveRevision"`
	WriterGeneration           *int64 `json:"writerGeneration"`
	ClientCompatibilityVersion *int   `json:"clientCompatibilityVersion"`
}

type economyRunSettlementRequest struct {
	RunID                      string `json:"runId"`
	WriterGeneration           *int64 `json:"writerGeneration"`
	SourceSaveRevision         *int64 `json:"sourceSaveRevision"`
	StageNumber                *int   `json:"stageNumber"`
	CompletedRounds            *int   `json:"completedRounds"`
	Success                    *bool  `json:"success"`
	PendingDiamonds            *int64 `json:"pendingDiamonds"`
	FirstClearModuleTickets    *int64 `json:"firstClearModuleTickets"`
	ClientCompatibilityVersion *int   `json:"clientCompatibilityVersion"`
}

func (handler economyHandler) get(response http.ResponseWriter, request *http.Request) {
	principal, ok := authenticatedPrincipalFromContext(request.Context())
	if !ok {
		handler.writeInternalError(response, request, errors.New("missing authenticated principal"))
		return
	}
	snapshot, err := handler.economy.Get(request.Context(), principal.AccountID)
	if errors.Is(err, economy.ErrNotBootstrapped) {
		writeAPIError(response, request, http.StatusNotFound, "ECONOMY_NOT_BOOTSTRAPPED", "계정 경제 정보를 최초 연결해야 합니다.")
		return
	}
	if err != nil {
		handler.writeInternalError(response, request, err)
		return
	}
	response.Header().Set("ETag", fmt.Sprintf("\"rn-economy-%s-%d\"", snapshot.AuthorityEpoch, snapshot.EconomyRevision))
	writeJSON(response, http.StatusOK, snapshot)
}

func (handler economyHandler) catalog(response http.ResponseWriter, _ *http.Request) {
	writeJSON(response, http.StatusOK, map[string]any{
		"catalogVersion":            economy.CatalogVersion,
		"moduleTicketDiamondCost":   economy.ModuleTicketDiamondCost,
		"researchSlotTwoUnlockCost": economy.ResearchSlotTwoUnlockCost,
		"rngAlgorithmVersion":       economy.RNGAlgorithmVersion,
	})
}

func (handler economyHandler) bootstrap(response http.ResponseWriter, request *http.Request) {
	principal, key, raw, input, ok := decodeEconomyCommand[economyBootstrapRequest](handler, response, request)
	if !ok {
		return
	}
	if input.ExpectedSaveRevision == nil || input.WriterGeneration == nil {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "저장 revision과 writer generation이 필요합니다.")
		return
	}
	result, err := handler.economy.Bootstrap(request.Context(), principal.AccountID, principal.SessionID, economy.BootstrapRequest{
		IdempotencyKey: key, RawBody: raw, WriterGeneration: *input.WriterGeneration,
		ExpectedSaveRevision: *input.ExpectedSaveRevision,
	})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, http.StatusOK, result)
}

func (handler economyHandler) draw(response http.ResponseWriter, request *http.Request) {
	principal, key, raw, input, ok := decodeEconomyCommand[economyDrawRequest](handler, response, request)
	if !ok {
		return
	}
	if input.ExpectedEconomyRevision == nil || input.ExpectedCatalogVersion == nil ||
		input.SourceSaveRevision == nil || input.WriterGeneration == nil || input.Count == nil {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "가챠 요청 정보가 부족합니다.")
		return
	}
	result, err := handler.economy.DrawModules(request.Context(), principal.AccountID, principal.SessionID, economy.DrawRequest{
		IdempotencyKey: key, RawBody: raw,
		ExpectedRevision:       *input.ExpectedEconomyRevision,
		ExpectedCatalogVersion: *input.ExpectedCatalogVersion,
		SourceSaveRevision:     *input.SourceSaveRevision, WriterGeneration: *input.WriterGeneration,
		Count: *input.Count, TurretType: strings.TrimSpace(input.TurretType),
		BuyMissingTicketsWithDiamonds: input.BuyMissingTicketsWithDiamonds,
	})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, http.StatusOK, result)
}

func (handler economyHandler) disassemble(response http.ResponseWriter, request *http.Request) {
	principal, key, raw, input, ok := decodeEconomyCommand[economyDisassembleRequest](handler, response, request)
	if !ok {
		return
	}
	if input.ExpectedEconomyRevision == nil || input.ExpectedCatalogVersion == nil {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "분해 요청 정보가 부족합니다.")
		return
	}
	result, err := handler.economy.DisassembleModules(request.Context(), principal.AccountID, economy.DisassembleRequest{
		IdempotencyKey: key, RawBody: raw,
		ExpectedRevision:       *input.ExpectedEconomyRevision,
		ExpectedCatalogVersion: *input.ExpectedCatalogVersion,
		ModuleIDs:              input.ModuleIDs,
	})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, http.StatusOK, result)
}

func (handler economyHandler) completeResearch(response http.ResponseWriter, request *http.Request) {
	principal, key, raw, input, ok := decodeEconomyCommand[economyResearchRequest](handler, response, request)
	if !ok {
		return
	}
	if !validResearchInput(input) {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "연구 요청 정보가 부족합니다.")
		return
	}
	result, err := handler.economy.CompleteResearch(request.Context(), principal.AccountID, principal.SessionID, economy.ResearchCompleteRequest{
		IdempotencyKey: key, RawBody: raw, ResearchType: request.PathValue("type"),
		ExpectedRevision:       *input.ExpectedEconomyRevision,
		ExpectedCatalogVersion: *input.ExpectedCatalogVersion,
		SourceSaveRevision:     *input.SourceSaveRevision, WriterGeneration: *input.WriterGeneration,
	})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, http.StatusOK, result)
}

func (handler economyHandler) unlockResearchSlot(response http.ResponseWriter, request *http.Request) {
	principal, key, raw, input, ok := decodeEconomyCommand[economyResearchRequest](handler, response, request)
	if !ok {
		return
	}
	if !validResearchInput(input) {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "연구 슬롯 요청 정보가 부족합니다.")
		return
	}
	result, err := handler.economy.UnlockResearchSlotTwo(request.Context(), principal.AccountID, principal.SessionID, economy.ResearchSlotUnlockRequest{
		IdempotencyKey: key, RawBody: raw,
		ExpectedRevision:       *input.ExpectedEconomyRevision,
		ExpectedCatalogVersion: *input.ExpectedCatalogVersion,
		SourceSaveRevision:     *input.SourceSaveRevision, WriterGeneration: *input.WriterGeneration,
	})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, http.StatusOK, result)
}

func (handler economyHandler) acknowledgeEffect(response http.ResponseWriter, request *http.Request) {
	principal, key, raw, input, ok := decodeEconomyCommand[economyEffectAckRequest](handler, response, request)
	if !ok {
		return
	}
	if input.AppliedSaveRevision == nil || input.WriterGeneration == nil {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "effect 적용 저장 정보가 필요합니다.")
		return
	}
	result, err := handler.economy.AcknowledgeProgressionEffect(request.Context(), principal.AccountID, principal.SessionID, economy.EffectAckRequest{
		IdempotencyKey: key, RawBody: raw, EffectID: request.PathValue("effectId"),
		AppliedSaveRevision: *input.AppliedSaveRevision, WriterGeneration: *input.WriterGeneration,
	})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, http.StatusOK, result)
}

func (handler economyHandler) settleRun(response http.ResponseWriter, request *http.Request) {
	decoderHandler := handler
	decoderHandler.minimumClientCompatibilityVersion = gamesave.EconomyClientCompatibilityVersion
	principal, key, raw, input, ok := decodeEconomyCommand[economyRunSettlementRequest](decoderHandler, response, request)
	if !ok {
		return
	}
	if input.WriterGeneration == nil || input.SourceSaveRevision == nil || input.StageNumber == nil ||
		input.CompletedRounds == nil || input.Success == nil || input.PendingDiamonds == nil ||
		input.FirstClearModuleTickets == nil {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "런 정산 요청 정보가 부족합니다.")
		return
	}
	result, err := handler.economy.SettleRun(request.Context(), principal.AccountID, principal.SessionID, economy.RunSettlementRequest{
		IdempotencyKey: key, RawBody: raw, RunID: input.RunID,
		WriterGeneration: *input.WriterGeneration, SourceSaveRevision: *input.SourceSaveRevision,
		StageNumber: *input.StageNumber, CompletedRounds: *input.CompletedRounds,
		Success: *input.Success, PendingDiamonds: *input.PendingDiamonds,
		FirstClearModuleTickets: *input.FirstClearModuleTickets,
	})
	if handler.writeEconomyError(response, request, err) {
		return
	}
	writeJSON(response, http.StatusOK, result)
}

func decodeEconomyCommand[T any](handler economyHandler, response http.ResponseWriter, request *http.Request) (auth.Principal, string, []byte, T, bool) {
	var zero T
	principal, ok := authenticatedPrincipalFromContext(request.Context())
	if !ok {
		handler.writeInternalError(response, request, errors.New("missing authenticated principal"))
		return auth.Principal{}, "", nil, zero, false
	}
	key, ok := requestIdempotencyKey(request.Header.Values(idempotencyKeyHeader))
	if !ok {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_IDEMPOTENCY_KEY", "유효한 Idempotency-Key UUID가 필요합니다.")
		return auth.Principal{}, "", nil, zero, false
	}
	mediaType, _, err := mime.ParseMediaType(request.Header.Get("Content-Type"))
	if err != nil || mediaType != "application/json" {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "Content-Type이 application/json인 요청이 필요합니다.")
		return auth.Principal{}, "", nil, zero, false
	}
	request.Body = http.MaxBytesReader(response, request.Body, maxEconomyBodyBytes)
	raw, err := io.ReadAll(request.Body)
	if err != nil {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "경제 요청 본문을 읽을 수 없습니다.")
		return auth.Principal{}, "", nil, zero, false
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	var input T
	if err := decoder.Decode(&input); err != nil {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "경제 요청 형식이 올바르지 않습니다.")
		return auth.Principal{}, "", nil, zero, false
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_ECONOMY_REQUEST", "경제 요청은 하나의 JSON 객체여야 합니다.")
		return auth.Principal{}, "", nil, zero, false
	}
	compatibility := compatibilityVersion(input)
	minimumVersion := max(
		handler.minimumClientCompatibilityVersion,
		gamesave.EconomyClientCompatibilityVersion,
	)
	if compatibility == nil || *compatibility < minimumVersion {
		writeAPIError(response, request, http.StatusUpgradeRequired, "CLIENT_UPDATE_REQUIRED", "최신 버전에서 경제 기능을 사용할 수 있습니다.")
		return auth.Principal{}, "", nil, zero, false
	}
	return principal, key, raw, input, true
}

func compatibilityVersion(value any) *int {
	switch input := value.(type) {
	case mailboxClaimRequest:
		return input.ClientCompatibilityVersion
	case mailboxBatchRequest:
		return input.ClientCompatibilityVersion
	case economyBootstrapRequest:
		return input.ClientCompatibilityVersion
	case economyGemRerollRequest:
		return input.ClientCompatibilityVersion
	case economyGemOfferRequest:
		return input.ClientCompatibilityVersion
	case economyGemChooseRequest:
		return input.ClientCompatibilityVersion
	case economyRunLifecycleRequest:
		return input.ClientCompatibilityVersion
	case economyDrawRequest:
		return input.ClientCompatibilityVersion
	case economyDisassembleRequest:
		return input.ClientCompatibilityVersion
	case economyResearchRequest:
		return input.ClientCompatibilityVersion
	case economyEffectAckRequest:
		return input.ClientCompatibilityVersion
	case economyRunSettlementRequest:
		return input.ClientCompatibilityVersion
	default:
		return nil
	}
}

func validResearchInput(input economyResearchRequest) bool {
	return input.ExpectedEconomyRevision != nil && input.ExpectedCatalogVersion != nil &&
		input.SourceSaveRevision != nil && input.WriterGeneration != nil
}

func (handler economyHandler) writeEconomyError(response http.ResponseWriter, request *http.Request, err error) bool {
	if err == nil {
		return false
	}
	status, code, message := http.StatusInternalServerError, "INTERNAL_ERROR", "경제 요청을 처리하지 못했습니다."
	switch {
	case errors.Is(err, gamesave.ErrClientUpdateRequired):
		status, code, message = http.StatusUpgradeRequired, "CLIENT_UPDATE_REQUIRED", "최신 버전에서 경제 기능을 사용할 수 있습니다."
	case errors.Is(err, economy.ErrInvalidIdempotencyKey):
		status, code, message = http.StatusBadRequest, "INVALID_IDEMPOTENCY_KEY", "유효한 Idempotency-Key UUID가 필요합니다."
	case errors.Is(err, economy.ErrIdempotencyKeyReused):
		status, code, message = http.StatusConflict, "IDEMPOTENCY_KEY_REUSED", "같은 Idempotency-Key를 다른 경제 요청에 사용할 수 없습니다."
	case errors.Is(err, economy.ErrNotBootstrapped):
		status, code, message = http.StatusConflict, "ECONOMY_BOOTSTRAP_REQUIRED", "계정 경제 정보를 먼저 연결해야 합니다."
	case errors.Is(err, economy.ErrAlreadyBootstrapped):
		status, code, message = http.StatusConflict, "ECONOMY_ALREADY_BOOTSTRAPPED", "이미 서버 경제로 전환된 계정입니다."
	case errors.Is(err, economy.ErrCatalogChanged):
		status, code, message = http.StatusConflict, "ECONOMY_CATALOG_CHANGED", "경제 정보가 갱신되었습니다. 다시 확인해 주세요."
	case errors.As(err, new(*economy.ConflictError)):
		status, code, message = http.StatusConflict, "ECONOMY_REVISION_CONFLICT", "다른 기기에서 경제 상태가 변경되었습니다."
	case errors.Is(err, economy.ErrWriterRequired), errors.Is(err, economy.ErrWriterReplaced):
		status, code, message = http.StatusConflict, "SAVE_WRITER_REPLACED", "다른 기기의 진행을 확인한 뒤 다시 시도해 주세요."
	case errors.Is(err, economy.ErrSaveRevisionConflict):
		status, code, message = http.StatusConflict, "SAVE_SYNC_REQUIRED", "최신 계정 진행을 저장한 뒤 다시 시도해 주세요."
	case errors.Is(err, economy.ErrInsufficientGemShards):
		status, code, message = http.StatusUnprocessableEntity, "INSUFFICIENT_GEM_SHARDS", "젬 파편이 부족합니다."
	case errors.Is(err, economy.ErrInsufficientDiamonds):
		status, code, message = http.StatusUnprocessableEntity, "INSUFFICIENT_DIAMONDS", "다이아가 부족합니다."
	case errors.Is(err, economy.ErrGemOfferConflict):
		status, code, message = http.StatusConflict, "GEM_OFFER_STATE_CONFLICT", "서버 젬 보상을 복구한 뒤 다시 시도해 주세요."
	case errors.Is(err, economy.ErrGemRerollLimit):
		status, code, message = http.StatusUnprocessableEntity, "GEM_REROLL_LIMIT_REACHED", "이번 도전의 젬 재선택을 모두 사용했습니다."
	case errors.Is(err, economy.ErrGemRerollConflict):
		status, code, message = http.StatusConflict, "GEM_REROLL_STATE_CONFLICT", "젬 재선택 결과를 복구한 뒤 다시 시도해 주세요."
	case errors.Is(err, economy.ErrInsufficientGemResetTickets):
		status, code, message = http.StatusUnprocessableEntity, "INSUFFICIENT_GEM_RESET_TICKETS", "젬 재설정권이 부족합니다."
	case errors.Is(err, economy.ErrInsufficientTickets):
		status, code, message = http.StatusUnprocessableEntity, "INSUFFICIENT_MODULE_TICKETS", "모듈권이 부족합니다."
	case errors.Is(err, economy.ErrModuleNotOwned):
		status, code, message = http.StatusUnprocessableEntity, "MODULE_NOT_OWNED", "소유하지 않은 모듈입니다."
	case errors.Is(err, economy.ErrModuleNotAllowed):
		status, code, message = http.StatusUnprocessableEntity, "MODULE_NOT_DISASSEMBLABLE", "분해할 수 없는 모듈이 포함되어 있습니다."
	case errors.Is(err, gamesave.ErrCoreTreeConflict):
		status, code, message = http.StatusUnprocessableEntity, "INVALID_SAVE_DATA", "코어 트리 또는 도전 시작 시점의 배분 데이터가 올바르지 않습니다."
	case errors.Is(err, economy.ErrInvalidCommand), errors.Is(err, economy.ErrProgressionEffect):
		status, code, message = http.StatusUnprocessableEntity, "ECONOMY_COMMAND_REJECTED", "현재 진행 상태로 처리할 수 없는 요청입니다."
	default:
		handler.writeInternalError(response, request, err)
		return true
	}
	// Rejections are diagnostic signals, including harmless stale/retry races.
	// Never classify these as cheating or record bodies, candidates, or credentials.
	if handler.logger != nil {
		switch request.URL.Path {
		case "/v1/economy/gems/offer", "/v1/economy/gems/reroll", "/v1/economy/gems/choose":
			handler.logger.WarnContext(request.Context(), "gem_reward_command_rejected",
				slog.String("request_id", requestIDFromContext(request.Context())),
				slog.String("code", code), slog.Int("status", status))
		}
	}
	writeAPIError(response, request, status, code, message)
	return true
}

func (handler economyHandler) writeInternalError(response http.ResponseWriter, request *http.Request, err error) {
	handler.logger.Error("economy_request_failed", slog.String("request_id", requestIDFromContext(request.Context())), slog.Any("error", err))
	writeAPIError(response, request, http.StatusInternalServerError, "INTERNAL_ERROR", "경제 요청을 처리하지 못했습니다.")
}
