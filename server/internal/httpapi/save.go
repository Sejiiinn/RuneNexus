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
	"strconv"
	"strings"
	"time"

	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

const (
	idempotencyKeyHeader = "Idempotency-Key"
	ifNoneMatchHeader    = "If-None-Match"
	saveWriterHeader     = "Rune-Nexus-Save-Writer"
	maxSaveJSONDepth     = 64
)

type SaveService interface {
	Get(context.Context, string) (gamesave.Snapshot, error)
	ClaimWriter(context.Context, string, string, gamesave.ClaimWriterRequest) (gamesave.ClaimWriterResult, error)
	Update(context.Context, string, string, gamesave.UpdateRequest) (gamesave.UpdateResult, error)
}

type saveHandler struct {
	logger                            *slog.Logger
	saves                             SaveService
	maxSaveBodyBytes                  int64
	minimumClientCompatibilityVersion int
}

type saveDataRequest struct {
	Version       *int32          `json:"version"`
	SavedAtMillis *int64          `json:"savedAtMillis"`
	Preferences   json.RawMessage `json:"preferences"`
	Progression   json.RawMessage `json:"progression"`
	TurretModules json.RawMessage `json:"turretModules"`
	ActiveRun     json.RawMessage `json:"activeRun"`
}

type saveUpdateRequest struct {
	ExpectedRevision           *int64           `json:"expectedRevision"`
	ClientCompatibilityVersion *int             `json:"clientCompatibilityVersion"`
	Data                       *saveDataRequest `json:"data"`
}

type saveWriterClaimRequest struct {
	ClientInstanceID           string `json:"clientInstanceId"`
	SaveSchemaVersion          *int32 `json:"saveSchemaVersion"`
	ClientCompatibilityVersion *int   `json:"clientCompatibilityVersion"`
	ClientBuild                string `json:"clientBuild"`
}

type saveDataResponse struct {
	Version       int32           `json:"version"`
	SavedAtMillis int64           `json:"savedAtMillis"`
	Preferences   json.RawMessage `json:"preferences"`
	Progression   json.RawMessage `json:"progression"`
	TurretModules json.RawMessage `json:"turretModules"`
	ActiveRun     json.RawMessage `json:"activeRun"`
}

type saveSnapshotResponse struct {
	Revision      int64            `json:"revision"`
	ServerSavedAt time.Time        `json:"serverSavedAt"`
	Data          saveDataResponse `json:"data"`
}

type saveUpdateResponse struct {
	Revision      int64     `json:"revision"`
	ServerSavedAt time.Time `json:"serverSavedAt"`
}

type saveWriterClaimResponse struct {
	WriterGeneration int64     `json:"writerGeneration"`
	ClaimedAt        time.Time `json:"claimedAt"`
}

type saveWriterReplacedResponse struct {
	Code                    string `json:"code"`
	Message                 string `json:"message"`
	RequestID               string `json:"requestId"`
	CurrentWriterGeneration int64  `json:"currentWriterGeneration"`
}

type saveConflictResponse struct {
	Code            string `json:"code"`
	Message         string `json:"message"`
	RequestID       string `json:"requestId"`
	CurrentRevision int64  `json:"currentRevision"`
}

type saveRequestError struct {
	status  int
	code    string
	message string
	err     error
}

func (err *saveRequestError) Error() string {
	return err.err.Error()
}

func (handler saveHandler) get(response http.ResponseWriter, request *http.Request) {
	principal, ok := authenticatedPrincipalFromContext(request.Context())
	if !ok {
		handler.writeInternalError(response, request, errors.New("missing authenticated principal"))
		return
	}
	snapshot, err := handler.saves.Get(request.Context(), principal.AccountID)
	if errors.Is(err, gamesave.ErrNotFound) {
		writeAPIError(
			response,
			request,
			http.StatusNotFound,
			"SAVE_NOT_FOUND",
			"원격 저장 데이터가 없습니다.",
		)
		return
	}
	if err != nil {
		handler.writeInternalError(response, request, err)
		return
	}
	etag := saveRevisionETag(snapshot.Revision)
	response.Header().Set("ETag", etag)
	if matchesSaveETag(request.Header.Get(ifNoneMatchHeader), etag) {
		response.Header().Set("Cache-Control", "no-store")
		response.WriteHeader(http.StatusNotModified)
		return
	}
	writeJSON(response, http.StatusOK, saveSnapshotResponse{
		Revision:      snapshot.Revision,
		ServerSavedAt: snapshot.ServerSavedAt,
		Data:          saveDataResponseFromData(snapshot.Data),
	})
}

func saveRevisionETag(revision int64) string {
	return fmt.Sprintf("\"rn-save-%d\"", revision)
}

func matchesSaveETag(header string, current string) bool {
	for value := range strings.SplitSeq(header, ",") {
		candidate := strings.TrimSpace(value)
		if candidate == "*" || candidate == current ||
			strings.TrimPrefix(candidate, "W/") == current {
			return true
		}
	}
	return false
}

func (handler saveHandler) claimWriter(response http.ResponseWriter, request *http.Request) {
	principal, ok := authenticatedPrincipalFromContext(request.Context())
	if !ok {
		handler.writeInternalError(response, request, errors.New("missing authenticated principal"))
		return
	}
	idempotencyKey, ok := requestIdempotencyKey(request.Header.Values(idempotencyKeyHeader))
	if !ok {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_IDEMPOTENCY_KEY", "유효한 Idempotency-Key UUID가 필요합니다.")
		return
	}
	input, err := decodeSaveWriterClaimRequest(
		response,
		request,
		handler.maxSaveBodyBytes,
		handler.minimumClientCompatibilityVersion,
	)
	if err != nil {
		var requestError *saveRequestError
		if errors.As(err, &requestError) {
			writeAPIError(response, request, requestError.status, requestError.code, requestError.message)
			return
		}
		handler.writeInternalError(response, request, err)
		return
	}
	input.IdempotencyKey = idempotencyKey

	result, err := handler.saves.ClaimWriter(
		request.Context(),
		principal.AccountID,
		principal.SessionID,
		input,
	)
	if errors.Is(err, gamesave.ErrIdempotencyKeyInvalid) {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_IDEMPOTENCY_KEY", "유효한 Idempotency-Key UUID가 필요합니다.")
		return
	}
	if errors.Is(err, gamesave.ErrIdempotencyKeyReused) {
		writeAPIError(response, request, http.StatusConflict, "IDEMPOTENCY_KEY_REUSED", "같은 Idempotency-Key를 다른 writer 요청에 사용할 수 없습니다.")
		return
	}
	if errors.Is(err, gamesave.ErrSessionAccountMismatch) {
		writeAPIError(response, request, http.StatusUnauthorized, "UNAUTHORIZED", "유효한 인증 세션이 필요합니다.")
		return
	}
	if err != nil {
		handler.writeInternalError(response, request, err)
		return
	}
	writeJSON(response, http.StatusOK, saveWriterClaimResponse{
		WriterGeneration: result.WriterGeneration,
		ClaimedAt:        result.ClaimedAt,
	})
}

func (handler saveHandler) update(response http.ResponseWriter, request *http.Request) {
	principal, ok := authenticatedPrincipalFromContext(request.Context())
	if !ok {
		handler.writeInternalError(response, request, errors.New("missing authenticated principal"))
		return
	}
	idempotencyKey, ok := requestIdempotencyKey(request.Header.Values(idempotencyKeyHeader))
	if !ok {
		writeAPIError(
			response,
			request,
			http.StatusBadRequest,
			"INVALID_IDEMPOTENCY_KEY",
			"유효한 Idempotency-Key UUID가 필요합니다.",
		)
		return
	}
	writerGeneration, ok := requestWriterGeneration(request.Header.Values(saveWriterHeader))
	if !ok {
		writeAPIError(
			response,
			request,
			http.StatusPreconditionRequired,
			"SAVE_WRITER_REQUIRED",
			"계정 저장 writer를 먼저 획득해야 합니다.",
		)
		return
	}

	input, err := decodeSaveUpdateRequest(
		response,
		request,
		handler.maxSaveBodyBytes,
		handler.minimumClientCompatibilityVersion,
	)
	if err != nil {
		var requestError *saveRequestError
		if errors.As(err, &requestError) {
			writeAPIError(
				response,
				request,
				requestError.status,
				requestError.code,
				requestError.message,
			)
			return
		}
		handler.writeInternalError(response, request, err)
		return
	}
	input.IdempotencyKey = idempotencyKey
	input.WriterGeneration = writerGeneration

	result, err := handler.saves.Update(
		request.Context(),
		principal.AccountID,
		principal.SessionID,
		input,
	)
	if errors.Is(err, gamesave.ErrClientUpdateRequired) {
		writeAPIError(
			response,
			request,
			http.StatusUpgradeRequired,
			"CLIENT_UPDATE_REQUIRED",
			"최신 버전에서 계정 진행을 사용할 수 있습니다.",
		)
		return
	}
	if errors.Is(err, gamesave.ErrIdempotencyKeyInvalid) {
		writeAPIError(
			response,
			request,
			http.StatusBadRequest,
			"INVALID_IDEMPOTENCY_KEY",
			"유효한 Idempotency-Key UUID가 필요합니다.",
		)
		return
	}
	if errors.Is(err, gamesave.ErrIdempotencyKeyReused) {
		writeAPIError(
			response,
			request,
			http.StatusConflict,
			"IDEMPOTENCY_KEY_REUSED",
			"같은 Idempotency-Key를 다른 저장 요청에 사용할 수 없습니다.",
		)
		return
	}
	if errors.Is(err, gamesave.ErrWriterRequired) {
		writeAPIError(response, request, http.StatusPreconditionRequired, "SAVE_WRITER_REQUIRED", "계정 저장 writer를 먼저 획득해야 합니다.")
		return
	}
	var writerReplaced *gamesave.WriterReplacedError
	if errors.As(err, &writerReplaced) {
		writeJSON(response, http.StatusConflict, saveWriterReplacedResponse{
			Code:                    "SAVE_WRITER_REPLACED",
			Message:                 "다른 기기에서 계정 플레이가 시작되었습니다.",
			RequestID:               requestIDFromContext(request.Context()),
			CurrentWriterGeneration: writerReplaced.CurrentGeneration,
		})
		return
	}
	var conflict *gamesave.RevisionConflictError
	if errors.As(err, &conflict) {
		writeJSON(response, http.StatusConflict, saveConflictResponse{
			Code:            "SAVE_REVISION_CONFLICT",
			Message:         "원격 저장 데이터가 다른 기기에서 변경되었습니다.",
			RequestID:       requestIDFromContext(request.Context()),
			CurrentRevision: conflict.CurrentRevision,
		})
		return
	}
	if err != nil {
		handler.writeInternalError(response, request, err)
		return
	}
	response.Header().Set("ETag", saveRevisionETag(result.Revision))
	writeJSON(response, http.StatusOK, saveUpdateResponse{
		Revision:      result.Revision,
		ServerSavedAt: result.ServerSavedAt,
	})
}

func decodeSaveWriterClaimRequest(
	response http.ResponseWriter,
	request *http.Request,
	maxBodyBytes int64,
	minimumClientCompatibilityVersion int,
) (gamesave.ClaimWriterRequest, error) {
	mediaType, _, err := mime.ParseMediaType(request.Header.Get("Content-Type"))
	if err != nil || mediaType != "application/json" {
		return gamesave.ClaimWriterRequest{}, invalidSaveRequest(
			http.StatusBadRequest,
			"INVALID_REQUEST",
			"Content-Type이 application/json인 요청이 필요합니다.",
			errors.New("Content-Type must be application/json"),
		)
	}
	request.Body = http.MaxBytesReader(response, request.Body, maxBodyBytes)
	rawBody, err := io.ReadAll(request.Body)
	if err != nil {
		var maxBytesError *http.MaxBytesError
		if errors.As(err, &maxBytesError) {
			return gamesave.ClaimWriterRequest{}, invalidSaveRequest(
				http.StatusRequestEntityTooLarge,
				"REQUEST_TOO_LARGE",
				"writer 요청 크기가 허용 범위를 초과했습니다.",
				err,
			)
		}
		return gamesave.ClaimWriterRequest{}, fmt.Errorf("read save writer request body: %w", err)
	}
	var wire saveWriterClaimRequest
	decoder := json.NewDecoder(bytes.NewReader(rawBody))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&wire); err != nil {
		return gamesave.ClaimWriterRequest{}, invalidSaveRequest(http.StatusBadRequest, "INVALID_REQUEST", "writer 요청 JSON 형식이 올바르지 않습니다.", err)
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return gamesave.ClaimWriterRequest{}, invalidSaveRequest(http.StatusBadRequest, "INVALID_REQUEST", "writer 요청에는 하나의 JSON 값만 포함할 수 있습니다.", errors.New("writer body must contain one JSON value"))
	}
	if err := validateSaveClientCompatibility(
		wire.ClientCompatibilityVersion,
		minimumClientCompatibilityVersion,
	); err != nil {
		return gamesave.ClaimWriterRequest{}, err
	}
	if wire.SaveSchemaVersion == nil || *wire.SaveSchemaVersion != gamesave.CurrentSchemaVersion {
		return gamesave.ClaimWriterRequest{}, invalidSaveRequest(http.StatusUnprocessableEntity, "SAVE_VERSION_UNSUPPORTED", "지원하지 않는 저장 데이터 버전입니다.", errors.New("unsupported writer save schema version"))
	}
	clientBuild := strings.TrimSpace(wire.ClientBuild)
	if gamesave.ValidateUUID(wire.ClientInstanceID) != nil || clientBuild == "" || len(clientBuild) > 128 {
		return gamesave.ClaimWriterRequest{}, invalidSaveRequest(http.StatusBadRequest, "INVALID_REQUEST", "writer 클라이언트 정보가 올바르지 않습니다.", errors.New("invalid writer client metadata"))
	}
	return gamesave.ClaimWriterRequest{
		ClientInstanceID: wire.ClientInstanceID,
		RawBody:          rawBody,
	}, nil
}

func (handler saveHandler) writeInternalError(
	response http.ResponseWriter,
	request *http.Request,
	err error,
) {
	handler.logger.ErrorContext(
		request.Context(),
		"save_request_failed",
		slog.String("request_id", requestIDFromContext(request.Context())),
		slog.Any("error", err),
	)
	writeAPIError(
		response,
		request,
		http.StatusInternalServerError,
		"INTERNAL_ERROR",
		"저장 데이터 처리 중 오류가 발생했습니다.",
	)
}

func decodeSaveUpdateRequest(
	response http.ResponseWriter,
	request *http.Request,
	maxBodyBytes int64,
	minimumClientCompatibilityVersion int,
) (gamesave.UpdateRequest, error) {
	mediaType, _, err := mime.ParseMediaType(request.Header.Get("Content-Type"))
	if err != nil || mediaType != "application/json" {
		return gamesave.UpdateRequest{}, invalidSaveRequest(
			http.StatusBadRequest,
			"INVALID_REQUEST",
			"Content-Type이 application/json인 요청이 필요합니다.",
			errors.New("Content-Type must be application/json"),
		)
	}
	request.Body = http.MaxBytesReader(response, request.Body, maxBodyBytes)
	rawBody, err := io.ReadAll(request.Body)
	if err != nil {
		var maxBytesError *http.MaxBytesError
		if errors.As(err, &maxBytesError) {
			return gamesave.UpdateRequest{}, invalidSaveRequest(
				http.StatusRequestEntityTooLarge,
				"REQUEST_TOO_LARGE",
				"저장 데이터 크기가 허용 범위를 초과했습니다.",
				err,
			)
		}
		return gamesave.UpdateRequest{}, fmt.Errorf("read save request body: %w", err)
	}
	trimmedBody := bytes.TrimSpace(rawBody)
	if len(trimmedBody) == 0 || trimmedBody[0] != '{' {
		return gamesave.UpdateRequest{}, invalidSaveRequest(
			http.StatusBadRequest,
			"INVALID_REQUEST",
			"저장 요청 JSON 형식이 올바르지 않습니다.",
			errors.New("save request must be a JSON object"),
		)
	}
	if err := validateJSONDepth(rawBody, maxSaveJSONDepth); err != nil {
		return gamesave.UpdateRequest{}, invalidSaveRequest(
			http.StatusUnprocessableEntity,
			"INVALID_SAVE_DATA",
			"저장 데이터의 JSON 중첩이 너무 깊습니다.",
			err,
		)
	}

	var compatibilityEnvelope saveUpdateRequest
	if err := json.Unmarshal(rawBody, &compatibilityEnvelope); err != nil {
		return gamesave.UpdateRequest{}, invalidSaveRequest(
			http.StatusBadRequest,
			"INVALID_REQUEST",
			"저장 요청 JSON 형식이 올바르지 않습니다.",
			err,
		)
	}
	if err := validateSaveClientCompatibility(
		compatibilityEnvelope.ClientCompatibilityVersion,
		minimumClientCompatibilityVersion,
	); err != nil {
		var requestError *saveRequestError
		if errors.As(err, &requestError) &&
			requestError.code == "CLIENT_UPDATE_REQUIRED" {
			// 과거 exact PUT의 성공 영수증만 확인하고 새 저장은 허용하지 않는다.
			return gamesave.UpdateRequest{
				RawBody:     rawBody,
				ReceiptOnly: true,
			}, nil
		}
		return gamesave.UpdateRequest{}, err
	}

	var wire saveUpdateRequest
	decoder := json.NewDecoder(bytes.NewReader(rawBody))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&wire); err != nil {
		return gamesave.UpdateRequest{}, invalidSaveRequest(
			http.StatusBadRequest,
			"INVALID_REQUEST",
			"저장 요청 JSON 형식이 올바르지 않습니다.",
			err,
		)
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return gamesave.UpdateRequest{}, invalidSaveRequest(
			http.StatusBadRequest,
			"INVALID_REQUEST",
			"저장 요청에는 하나의 JSON 값만 포함할 수 있습니다.",
			errors.New("save body must contain one JSON value"),
		)
	}
	if wire.ExpectedRevision == nil || *wire.ExpectedRevision < 0 || wire.Data == nil {
		return gamesave.UpdateRequest{}, invalidSaveData("필수 저장 메타데이터가 올바르지 않습니다.")
	}
	if wire.Data.Version == nil {
		return gamesave.UpdateRequest{}, invalidSaveData("저장 데이터 버전이 필요합니다.")
	}
	if *wire.Data.Version != gamesave.CurrentSchemaVersion {
		return gamesave.UpdateRequest{}, invalidSaveRequest(
			http.StatusUnprocessableEntity,
			"SAVE_VERSION_UNSUPPORTED",
			"지원하지 않는 저장 데이터 버전입니다.",
			fmt.Errorf("unsupported save version: %d", *wire.Data.Version),
		)
	}
	if wire.Data.SavedAtMillis == nil || *wire.Data.SavedAtMillis < 0 ||
		!isJSONObject(wire.Data.Preferences) ||
		!isJSONObject(wire.Data.Progression) ||
		!isJSONObject(wire.Data.TurretModules) ||
		len(wire.Data.ActiveRun) == 0 {
		return gamesave.UpdateRequest{}, invalidSaveData("저장 데이터 구조가 올바르지 않습니다.")
	}

	activeRun := wire.Data.ActiveRun
	if bytes.Equal(bytes.TrimSpace(activeRun), []byte("null")) {
		activeRun = nil
	} else if !isJSONObject(activeRun) {
		return gamesave.UpdateRequest{}, invalidSaveData("진행 중인 라운드 데이터 구조가 올바르지 않습니다.")
	}
	return gamesave.UpdateRequest{
		ExpectedRevision: *wire.ExpectedRevision,
		RawBody:          rawBody,
		Data: gamesave.Data{
			Version:       *wire.Data.Version,
			SavedAtMillis: *wire.Data.SavedAtMillis,
			Preferences:   wire.Data.Preferences,
			Progression:   wire.Data.Progression,
			TurretModules: wire.Data.TurretModules,
			ActiveRun:     activeRun,
		},
	}, nil
}

func validateSaveClientCompatibility(
	clientVersion *int,
	minimumVersion int,
) error {
	if clientVersion == nil || *clientVersion < minimumVersion {
		return invalidSaveRequest(
			http.StatusUpgradeRequired,
			"CLIENT_UPDATE_REQUIRED",
			"최신 버전에서 계정 진행을 사용할 수 있습니다.",
			errors.New("save client compatibility version is below minimum"),
		)
	}
	if *clientVersion > gamesave.CurrentClientCompatibilityVersion {
		return invalidSaveRequest(
			http.StatusUnprocessableEntity,
			"SAVE_CLIENT_VERSION_UNSUPPORTED",
			"서버가 지원하지 않는 저장 클라이언트 버전입니다.",
			errors.New("save client compatibility version is newer than server"),
		)
	}
	return nil
}

func validateJSONDepth(rawJSON []byte, maximum int) error {
	decoder := json.NewDecoder(bytes.NewReader(rawJSON))
	depth := 0
	for {
		token, err := decoder.Token()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("scan JSON nesting: %w", err)
		}
		delimiter, ok := token.(json.Delim)
		if !ok {
			continue
		}
		switch delimiter {
		case '{', '[':
			depth++
			if depth > maximum {
				return fmt.Errorf("JSON nesting exceeds %d", maximum)
			}
		case '}', ']':
			depth--
		}
	}
}

func isJSONObject(rawJSON json.RawMessage) bool {
	if len(rawJSON) == 0 {
		return false
	}
	var object map[string]json.RawMessage
	return json.Unmarshal(rawJSON, &object) == nil && object != nil
}

func requestIdempotencyKey(values []string) (string, bool) {
	if len(values) != 1 {
		return "", false
	}
	value := strings.TrimSpace(values[0])
	if value == "" || gamesave.ValidateIdempotencyKey(value) != nil {
		return "", false
	}
	return value, true
}

func requestWriterGeneration(values []string) (int64, bool) {
	if len(values) != 1 {
		return 0, false
	}
	generation, err := strconv.ParseInt(strings.TrimSpace(values[0]), 10, 64)
	return generation, err == nil && generation > 0
}

func saveDataResponseFromData(data gamesave.Data) saveDataResponse {
	return saveDataResponse{
		Version:       data.Version,
		SavedAtMillis: data.SavedAtMillis,
		Preferences:   data.Preferences,
		Progression:   data.Progression,
		TurretModules: data.TurretModules,
		ActiveRun:     data.ActiveRun,
	}
}

func invalidSaveData(message string) *saveRequestError {
	return invalidSaveRequest(
		http.StatusUnprocessableEntity,
		"INVALID_SAVE_DATA",
		message,
		errors.New(message),
	)
}

func invalidSaveRequest(
	status int,
	code string,
	message string,
	err error,
) *saveRequestError {
	return &saveRequestError{
		status:  status,
		code:    code,
		message: message,
		err:     err,
	}
}
