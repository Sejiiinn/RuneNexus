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
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/legacytransfer"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

const maxLegacyTransferConsumeBodyBytes int64 = 1024

type LegacyTransferService interface {
	Create(context.Context, legacytransfer.CreateRequest) (legacytransfer.CreateResult, error)
	Consume(context.Context, string, string, string) (legacytransfer.ConsumeResult, error)
}

type legacyTransferHandler struct {
	logger                            *slog.Logger
	transfers                         LegacyTransferService
	maxSaveBodyBytes                  int64
	minimumClientCompatibilityVersion int
}

type legacyTransferCreateRequest struct {
	ClientCompatibilityVersion *int             `json:"clientCompatibilityVersion"`
	Data                       *saveDataRequest `json:"data"`
}

type legacyTransferConsumeRequest struct {
	Token string `json:"token"`
}

type legacyTransferCreateResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
}

type legacyTransferConsumeResponse struct {
	Revision      int64     `json:"revision"`
	ServerSavedAt time.Time `json:"serverSavedAt"`
}

func (handler legacyTransferHandler) create(
	response http.ResponseWriter,
	request *http.Request,
) {
	input, err := decodeLegacyTransferCreateRequest(
		response,
		request,
		handler.maxSaveBodyBytes,
		handler.minimumClientCompatibilityVersion,
	)
	if err != nil {
		handler.writeRequestError(response, request, err)
		return
	}
	result, err := handler.transfers.Create(request.Context(), input)
	if errors.Is(err, legacytransfer.ErrUnsupportedPaidFunds) {
		writeAPIError(
			response,
			request,
			http.StatusUnprocessableEntity,
			"LEGACY_TRANSFER_PAID_FUNDS_UNSUPPORTED",
			"구매 재화가 포함된 로컬 진행은 자동 이전할 수 없습니다.",
		)
		return
	}
	if errors.Is(err, legacytransfer.ErrInvalidData) {
		writeAPIError(response, request, http.StatusUnprocessableEntity, "INVALID_SAVE_DATA", "이전할 저장 데이터가 올바르지 않습니다.")
		return
	}
	if err != nil {
		handler.writeInternalError(response, request, err)
		return
	}
	writeJSON(response, http.StatusCreated, legacyTransferCreateResponse{
		Token:     result.Token,
		ExpiresAt: result.ExpiresAt,
	})
}

func (handler legacyTransferHandler) consume(
	response http.ResponseWriter,
	request *http.Request,
) {
	principal, ok := authenticatedPrincipalFromContext(request.Context())
	if !ok {
		handler.writeInternalError(response, request, errors.New("missing authenticated principal"))
		return
	}
	token, err := decodeLegacyTransferConsumeRequest(response, request)
	if err != nil {
		handler.writeRequestError(response, request, err)
		return
	}
	result, err := handler.transfers.Consume(
		request.Context(),
		principal.AccountID,
		principal.SessionID,
		token,
	)
	if errors.Is(err, legacytransfer.ErrInvalidToken) {
		writeAPIError(response, request, http.StatusGone, "LEGACY_TRANSFER_INVALID", "이전 링크가 만료되었거나 유효하지 않습니다.")
		return
	}
	if errors.Is(err, legacytransfer.ErrTokenAlreadyUsed) {
		writeAPIError(response, request, http.StatusConflict, "LEGACY_TRANSFER_ALREADY_USED", "이미 다른 계정에 사용된 이전 링크입니다.")
		return
	}
	if errors.Is(err, legacytransfer.ErrTargetNotReplaceable) {
		writeAPIError(response, request, http.StatusConflict, "LEGACY_TRANSFER_TARGET_REQUIRES_MANUAL_REVIEW", "구매 재화가 있거나 백업할 수 없는 계정 진행은 자동으로 교체할 수 없습니다.")
		return
	}
	if errors.Is(err, legacytransfer.ErrSessionMismatch) {
		writeAPIError(response, request, http.StatusUnauthorized, "ACCESS_TOKEN_INVALID", "유효한 인증 세션이 필요합니다.")
		return
	}
	if errors.Is(err, legacytransfer.ErrUnsupportedPaidFunds) ||
		errors.Is(err, legacytransfer.ErrInvalidData) {
		writeAPIError(response, request, http.StatusUnprocessableEntity, "INVALID_SAVE_DATA", "이전할 저장 데이터가 올바르지 않습니다.")
		return
	}
	if err != nil {
		handler.writeInternalError(response, request, err)
		return
	}
	writeJSON(response, http.StatusOK, legacyTransferConsumeResponse{
		Revision:      result.Revision,
		ServerSavedAt: result.ServerSavedAt,
	})
}

func decodeLegacyTransferCreateRequest(
	response http.ResponseWriter,
	request *http.Request,
	maxBodyBytes int64,
	minimumClientCompatibilityVersion int,
) (legacytransfer.CreateRequest, error) {
	rawBody, err := readLegacyTransferJSONBody(
		response,
		request,
		maxBodyBytes,
		"이전할 저장 데이터 크기가 허용 범위를 초과했습니다.",
	)
	if err != nil {
		return legacytransfer.CreateRequest{}, err
	}
	if err := validateJSONDepth(rawBody, maxSaveJSONDepth); err != nil {
		return legacytransfer.CreateRequest{}, invalidSaveRequest(
			http.StatusUnprocessableEntity,
			"INVALID_SAVE_DATA",
			"저장 데이터의 JSON 중첩이 너무 깊습니다.",
			err,
		)
	}
	var wire legacyTransferCreateRequest
	decoder := json.NewDecoder(bytes.NewReader(rawBody))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&wire); err != nil {
		return legacytransfer.CreateRequest{}, invalidSaveRequest(http.StatusBadRequest, "INVALID_REQUEST", "이전 요청 JSON 형식이 올바르지 않습니다.", err)
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return legacytransfer.CreateRequest{}, invalidSaveRequest(http.StatusBadRequest, "INVALID_REQUEST", "이전 요청에는 하나의 JSON 객체만 포함할 수 있습니다.", errors.New("legacy transfer body must contain one JSON object"))
	}
	if err := validateSaveClientCompatibility(
		wire.ClientCompatibilityVersion,
		minimumClientCompatibilityVersion,
	); err != nil {
		return legacytransfer.CreateRequest{}, err
	}
	data, err := saveDataFromWire(wire.Data)
	if err != nil {
		return legacytransfer.CreateRequest{}, err
	}
	return legacytransfer.CreateRequest{RawBody: rawBody, Data: data}, nil
}

func decodeLegacyTransferConsumeRequest(
	response http.ResponseWriter,
	request *http.Request,
) (string, error) {
	rawBody, err := readLegacyTransferJSONBody(
		response,
		request,
		maxLegacyTransferConsumeBodyBytes,
		"이전 링크 요청 크기가 허용 범위를 초과했습니다.",
	)
	if err != nil {
		return "", err
	}
	var wire legacyTransferConsumeRequest
	decoder := json.NewDecoder(bytes.NewReader(rawBody))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&wire); err != nil {
		return "", invalidSaveRequest(http.StatusBadRequest, "INVALID_REQUEST", "이전 링크 요청 형식이 올바르지 않습니다.", err)
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return "", invalidSaveRequest(http.StatusBadRequest, "INVALID_REQUEST", "이전 링크 요청에는 하나의 JSON 객체만 포함할 수 있습니다.", errors.New("legacy transfer consume body must contain one JSON object"))
	}
	token := strings.TrimSpace(wire.Token)
	if token == "" || len(token) > 128 {
		return "", invalidSaveRequest(http.StatusBadRequest, "INVALID_REQUEST", "유효한 이전 링크 토큰이 필요합니다.", errors.New("legacy transfer token is invalid"))
	}
	return token, nil
}

func readLegacyTransferJSONBody(
	response http.ResponseWriter,
	request *http.Request,
	maxBodyBytes int64,
	tooLargeMessage string,
) ([]byte, error) {
	mediaType, _, err := mime.ParseMediaType(request.Header.Get("Content-Type"))
	if err != nil || mediaType != "application/json" {
		return nil, invalidSaveRequest(http.StatusBadRequest, "INVALID_REQUEST", "Content-Type이 application/json인 요청이 필요합니다.", errors.New("Content-Type must be application/json"))
	}
	request.Body = http.MaxBytesReader(response, request.Body, maxBodyBytes)
	rawBody, err := io.ReadAll(request.Body)
	if err != nil {
		var maxBytesError *http.MaxBytesError
		if errors.As(err, &maxBytesError) {
			return nil, invalidSaveRequest(http.StatusRequestEntityTooLarge, "REQUEST_TOO_LARGE", tooLargeMessage, err)
		}
		return nil, fmt.Errorf("read legacy transfer request body: %w", err)
	}
	trimmed := bytes.TrimSpace(rawBody)
	if len(trimmed) == 0 || trimmed[0] != '{' {
		return nil, invalidSaveRequest(http.StatusBadRequest, "INVALID_REQUEST", "이전 요청 JSON 형식이 올바르지 않습니다.", errors.New("legacy transfer request must be a JSON object"))
	}
	return rawBody, nil
}

func saveDataFromWire(wire *saveDataRequest) (gamesave.Data, error) {
	if wire == nil || wire.Version == nil || wire.SavedAtMillis == nil ||
		*wire.SavedAtMillis < 0 || !isJSONObject(wire.Preferences) ||
		!isJSONObject(wire.Progression) || !isJSONObject(wire.TurretModules) ||
		len(wire.ActiveRun) == 0 {
		return gamesave.Data{}, invalidSaveData("이전할 저장 데이터 구조가 올바르지 않습니다.")
	}
	if *wire.Version != gamesave.CurrentSchemaVersion {
		return gamesave.Data{}, invalidSaveRequest(
			http.StatusUnprocessableEntity,
			"SAVE_VERSION_UNSUPPORTED",
			"지원하지 않는 저장 데이터 버전입니다.",
			fmt.Errorf("unsupported legacy transfer save version: %d", *wire.Version),
		)
	}
	activeRun := wire.ActiveRun
	if bytes.Equal(bytes.TrimSpace(activeRun), []byte("null")) {
		activeRun = nil
	} else if !isJSONObject(activeRun) {
		return gamesave.Data{}, invalidSaveData("진행 중인 라운드 데이터 구조가 올바르지 않습니다.")
	}
	return gamesave.Data{
		Version:       *wire.Version,
		SavedAtMillis: *wire.SavedAtMillis,
		Preferences:   wire.Preferences,
		Progression:   wire.Progression,
		TurretModules: wire.TurretModules,
		ActiveRun:     activeRun,
	}, nil
}

func (handler legacyTransferHandler) writeRequestError(
	response http.ResponseWriter,
	request *http.Request,
	err error,
) {
	var requestError *saveRequestError
	if errors.As(err, &requestError) {
		writeAPIError(response, request, requestError.status, requestError.code, requestError.message)
		return
	}
	handler.writeInternalError(response, request, err)
}

func (handler legacyTransferHandler) writeInternalError(
	response http.ResponseWriter,
	request *http.Request,
	err error,
) {
	handler.logger.ErrorContext(
		request.Context(),
		"legacy_transfer_request_failed",
		slog.String("request_id", requestIDFromContext(request.Context())),
		slog.Any("error", err),
	)
	writeAPIError(response, request, http.StatusInternalServerError, "INTERNAL_ERROR", "기존 진행 이전 요청을 처리하지 못했습니다.")
}
