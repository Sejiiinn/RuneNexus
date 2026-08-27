package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

const (
	testAccountID      = "0198b955-3656-7c40-b3cb-87f427b90be2"
	testIdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90be3"
	testSessionID      = "0198b955-3656-7c40-b3cb-87f427b90be4"
	testClientID       = "0198b955-3656-7c40-b3cb-87f427b90be5"
	validSaveBody      = `{"expectedRevision":0,"clientCompatibilityVersion":1,"data":{"version":2,"savedAtMillis":1234,"preferences":{"music":true},"progression":{"runes":30},"turretModules":{"tickets":4},"activeRun":null}}`
	validWriterBody    = `{"clientInstanceId":"0198b955-3656-7c40-b3cb-87f427b90be5","saveSchemaVersion":2,"clientCompatibilityVersion":1,"clientBuild":"test-build"}`
)

type saveServiceStub struct {
	get         func(context.Context, string) (gamesave.Snapshot, error)
	claimWriter func(context.Context, string, string, gamesave.ClaimWriterRequest) (gamesave.ClaimWriterResult, error)
	update      func(context.Context, string, string, gamesave.UpdateRequest) (gamesave.UpdateResult, error)
}

func (stub saveServiceStub) Get(
	ctx context.Context,
	accountID string,
) (gamesave.Snapshot, error) {
	if stub.get == nil {
		return gamesave.Snapshot{}, errors.New("unexpected save lookup")
	}
	return stub.get(ctx, accountID)
}

func (stub saveServiceStub) ClaimWriter(
	ctx context.Context,
	accountID string,
	sessionID string,
	request gamesave.ClaimWriterRequest,
) (gamesave.ClaimWriterResult, error) {
	if stub.claimWriter == nil {
		return gamesave.ClaimWriterResult{}, errors.New("unexpected save writer claim")
	}
	return stub.claimWriter(ctx, accountID, sessionID, request)
}

func (stub saveServiceStub) Update(
	ctx context.Context,
	accountID string,
	sessionID string,
	request gamesave.UpdateRequest,
) (gamesave.UpdateResult, error) {
	if stub.update == nil {
		return gamesave.UpdateResult{}, errors.New("unexpected save update")
	}
	return stub.update(ctx, accountID, sessionID, request)
}

func TestGetSaveRequiresBearerAuthentication(t *testing.T) {
	saveCalled := false
	handler := newSaveTestHandler(
		sessionAuthenticatorStub{access: func(
			context.Context,
			string,
		) (auth.Principal, error) {
			return auth.Principal{}, auth.ErrAccessTokenInvalid
		}},
		saveServiceStub{get: func(
			context.Context,
			string,
		) (gamesave.Snapshot, error) {
			saveCalled = true
			return gamesave.Snapshot{}, nil
		}},
		1024,
	)
	request := httptest.NewRequest(http.MethodGet, "/v1/save", nil)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if saveCalled {
		t.Fatal("save service was called without authentication")
	}
}

func TestGetSaveReturnsAuthenticatedAccountSnapshot(t *testing.T) {
	serverSavedAt := time.Date(2026, 8, 19, 1, 2, 3, 0, time.UTC)
	handler := newSaveTestHandler(
		successfulAccessAuthenticator(t),
		saveServiceStub{get: func(
			_ context.Context,
			accountID string,
		) (gamesave.Snapshot, error) {
			if accountID != testAccountID {
				t.Fatalf("accountID = %q", accountID)
			}
			return gamesave.Snapshot{
				Revision:      12,
				ServerSavedAt: serverSavedAt,
				Data: gamesave.Data{
					Version:       2,
					SavedAtMillis: 1234,
					Preferences:   json.RawMessage(`{"music":true}`),
					Progression:   json.RawMessage(`{"runes":30}`),
					TurretModules: json.RawMessage(`{"tickets":4}`),
				},
			}, nil
		}},
		1024,
	)
	request := httptest.NewRequest(http.MethodGet, "/v1/save", nil)
	request.Header.Set("Authorization", "Bearer access-token")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if response.Header().Get("ETag") != `"rn-save-12"` {
		t.Fatalf("ETag = %q", response.Header().Get("ETag"))
	}
	var body saveSnapshotResponse
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.Revision != 12 || body.Data.Version != 2 ||
		!bytes.Equal(body.Data.ActiveRun, []byte("null")) {
		t.Fatalf("body = %#v", body)
	}
}

func TestGetSaveReturnsNotModifiedForMatchingRevisionETag(t *testing.T) {
	handler := newSaveTestHandler(
		successfulAccessAuthenticator(t),
		saveServiceStub{get: func(
			context.Context,
			string,
		) (gamesave.Snapshot, error) {
			return gamesave.Snapshot{
				Revision:      12,
				ServerSavedAt: time.Date(2026, 8, 19, 1, 2, 3, 0, time.UTC),
			}, nil
		}},
		1024,
	)
	request := httptest.NewRequest(http.MethodGet, "/v1/save", nil)
	request.Header.Set("Authorization", "Bearer access-token")
	request.Header.Set("If-None-Match", `"rn-save-12"`)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusNotModified {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if response.Header().Get("ETag") != `"rn-save-12"` {
		t.Fatalf("ETag = %q", response.Header().Get("ETag"))
	}
	if response.Body.Len() != 0 {
		t.Fatalf("304 body = %q", response.Body.String())
	}
}

func TestGetSaveMapsMissingSnapshot(t *testing.T) {
	handler := newSaveTestHandler(
		successfulAccessAuthenticator(t),
		saveServiceStub{get: func(
			context.Context,
			string,
		) (gamesave.Snapshot, error) {
			return gamesave.Snapshot{}, gamesave.ErrNotFound
		}},
		1024,
	)
	request := httptest.NewRequest(http.MethodGet, "/v1/save", nil)
	request.Header.Set("Authorization", "Bearer access-token")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	requireAPIError(t, response, http.StatusNotFound, "SAVE_NOT_FOUND")
}

func TestClaimSaveWriterPassesExactBodyAndPrincipal(t *testing.T) {
	claimedAt := time.Date(2026, 8, 26, 1, 2, 3, 0, time.UTC)
	handler := newSaveTestHandler(
		successfulAccessAuthenticator(t),
		saveServiceStub{claimWriter: func(
			_ context.Context,
			accountID string,
			sessionID string,
			request gamesave.ClaimWriterRequest,
		) (gamesave.ClaimWriterResult, error) {
			if accountID != testAccountID || sessionID != testSessionID ||
				request.IdempotencyKey != testIdempotencyKey ||
				request.ClientInstanceID != testClientID ||
				string(request.RawBody) != validWriterBody {
				t.Fatalf("claim request = %#v, account = %q, session = %q", request, accountID, sessionID)
			}
			return gamesave.ClaimWriterResult{
				WriterGeneration: 7,
				ClaimedAt:        claimedAt,
			}, nil
		}},
		4096,
	)
	request := jsonRequest(http.MethodPost, "/v1/save/writer", validWriterBody)
	request.Header.Set("Authorization", "Bearer access-token")
	request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var body saveWriterClaimResponse
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.WriterGeneration != 7 || !body.ClaimedAt.Equal(claimedAt) {
		t.Fatalf("body = %#v", body)
	}
}

func TestClaimSaveWriterRejectsUnsupportedVersionBeforeService(t *testing.T) {
	serviceCalled := false
	handler := newSaveTestHandler(
		successfulAccessAuthenticator(t),
		saveServiceStub{claimWriter: func(
			context.Context,
			string,
			string,
			gamesave.ClaimWriterRequest,
		) (gamesave.ClaimWriterResult, error) {
			serviceCalled = true
			return gamesave.ClaimWriterResult{}, nil
		}},
		4096,
	)
	request := jsonRequest(
		http.MethodPost,
		"/v1/save/writer",
		strings.Replace(validWriterBody, `"saveSchemaVersion":2`, `"saveSchemaVersion":1`, 1),
	)
	request.Header.Set("Authorization", "Bearer access-token")
	request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	requireAPIError(t, response, http.StatusUnprocessableEntity, "SAVE_VERSION_UNSUPPORTED")
	if serviceCalled {
		t.Fatal("writer service was called for unsupported version")
	}
}

func TestClaimSaveWriterRejectsOutdatedClientBeforeService(t *testing.T) {
	serviceCalled := false
	handler := newSaveTestHandler(
		successfulAccessAuthenticator(t),
		saveServiceStub{claimWriter: func(
			context.Context,
			string,
			string,
			gamesave.ClaimWriterRequest,
		) (gamesave.ClaimWriterResult, error) {
			serviceCalled = true
			return gamesave.ClaimWriterResult{}, nil
		}},
		4096,
	)
	request := jsonRequest(
		http.MethodPost,
		"/v1/save/writer",
		strings.Replace(validWriterBody, `"clientCompatibilityVersion":1`, `"clientCompatibilityVersion":0`, 1),
	)
	request.Header.Set("Authorization", "Bearer access-token")
	request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	requireAPIError(t, response, http.StatusUpgradeRequired, "CLIENT_UPDATE_REQUIRED")
	if serviceCalled {
		t.Fatal("writer service was called for outdated client")
	}
}

func TestUpdateSavePassesExactBodyAndAuthenticatedAccount(t *testing.T) {
	serverSavedAt := time.Date(2026, 8, 19, 1, 2, 3, 0, time.UTC)
	handler := newSaveTestHandler(
		successfulAccessAuthenticator(t),
		saveServiceStub{update: func(
			_ context.Context,
			accountID string,
			sessionID string,
			request gamesave.UpdateRequest,
		) (gamesave.UpdateResult, error) {
			if accountID != testAccountID || sessionID != testSessionID ||
				request.IdempotencyKey != testIdempotencyKey {
				t.Fatalf("accountID = %q, sessionID = %q, idempotencyKey = %q", accountID, sessionID, request.IdempotencyKey)
			}
			if string(request.RawBody) != validSaveBody || request.ExpectedRevision != 0 ||
				request.WriterGeneration != 3 || request.Data.Version != 2 || request.Data.ActiveRun != nil {
				t.Fatalf("request = %#v", request)
			}
			return gamesave.UpdateResult{
				Revision:      1,
				ServerSavedAt: serverSavedAt,
			}, nil
		}},
		4096,
	)
	request := jsonRequest(http.MethodPut, "/v1/save", validSaveBody)
	request.Header.Set("Authorization", "Bearer access-token")
	request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
	request.Header.Set(saveWriterHeader, "3")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if response.Header().Get("ETag") != `"rn-save-1"` {
		t.Fatalf("ETag = %q", response.Header().Get("ETag"))
	}
	var body saveUpdateResponse
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.Revision != 1 || !body.ServerSavedAt.Equal(serverSavedAt) {
		t.Fatalf("body = %#v", body)
	}
}

func TestUpdateSaveRejectsInvalidRequestBeforeService(t *testing.T) {
	deepObject := strings.Repeat(`{"child":`, maxSaveJSONDepth) +
		`{}` + strings.Repeat(`}`, maxSaveJSONDepth)
	testCases := []struct {
		name     string
		body     string
		key      string
		maxBytes int64
		status   int
		code     string
	}{
		{
			name: "missing idempotency key", body: validSaveBody,
			maxBytes: 4096, status: http.StatusBadRequest, code: "INVALID_IDEMPOTENCY_KEY",
		},
		{
			name: "malformed idempotency key", body: validSaveBody, key: "not-a-uuid",
			maxBytes: 4096, status: http.StatusBadRequest, code: "INVALID_IDEMPOTENCY_KEY",
		},
		{
			name: "oversized", body: validSaveBody, key: testIdempotencyKey,
			maxBytes: 16, status: http.StatusRequestEntityTooLarge, code: "REQUEST_TOO_LARGE",
		},
		{
			name: "unknown field", key: testIdempotencyKey, maxBytes: 4096,
			body:   strings.TrimSuffix(validSaveBody, "}") + `,"accountId":"untrusted"}`,
			status: http.StatusBadRequest, code: "INVALID_REQUEST",
		},
		{
			name: "unsupported version", key: testIdempotencyKey, maxBytes: 4096,
			body:   strings.Replace(validSaveBody, `"version":2`, `"version":99`, 1),
			status: http.StatusUnprocessableEntity, code: "SAVE_VERSION_UNSUPPORTED",
		},
		{
			name: "missing section", key: testIdempotencyKey, maxBytes: 4096,
			body:   `{"expectedRevision":0,"clientCompatibilityVersion":1,"data":{"version":2,"savedAtMillis":0,"preferences":{},"progression":{},"activeRun":null}}`,
			status: http.StatusUnprocessableEntity, code: "INVALID_SAVE_DATA",
		},
		{
			name: "non-object section", key: testIdempotencyKey, maxBytes: 4096,
			body:   `{"expectedRevision":0,"clientCompatibilityVersion":1,"data":{"version":2,"savedAtMillis":0,"preferences":[],"progression":{},"turretModules":{},"activeRun":null}}`,
			status: http.StatusUnprocessableEntity, code: "INVALID_SAVE_DATA",
		},
		{
			name: "negative client timestamp", key: testIdempotencyKey, maxBytes: 4096,
			body:   strings.Replace(validSaveBody, `"savedAtMillis":1234`, `"savedAtMillis":-1`, 1),
			status: http.StatusUnprocessableEntity, code: "INVALID_SAVE_DATA",
		},
		{
			name: "excessive nesting", key: testIdempotencyKey, maxBytes: 16384,
			body: `{"expectedRevision":0,"clientCompatibilityVersion":1,"data":{"version":2,"savedAtMillis":0,"preferences":` +
				deepObject + `,"progression":{},"turretModules":{},"activeRun":null}}`,
			status: http.StatusUnprocessableEntity, code: "INVALID_SAVE_DATA",
		},
	}

	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			serviceCalled := false
			handler := newSaveTestHandler(
				successfulAccessAuthenticator(t),
				saveServiceStub{update: func(
					context.Context,
					string,
					string,
					gamesave.UpdateRequest,
				) (gamesave.UpdateResult, error) {
					serviceCalled = true
					return gamesave.UpdateResult{}, nil
				}},
				testCase.maxBytes,
			)
			request := jsonRequest(http.MethodPut, "/v1/save", testCase.body)
			request.Header.Set("Authorization", "Bearer access-token")
			request.Header.Set(saveWriterHeader, "3")
			if testCase.key != "" {
				request.Header.Set(idempotencyKeyHeader, testCase.key)
			}
			response := httptest.NewRecorder()

			handler.ServeHTTP(response, request)

			requireAPIError(t, response, testCase.status, testCase.code)
			if serviceCalled {
				t.Fatal("save service was called for an invalid request")
			}
		})
	}
}

func TestUpdateSaveRejectsOutdatedClientAfterReceiptLookup(t *testing.T) {
	serviceCalled := false
	handler := newSaveTestHandlerWithMinimum(
		successfulAccessAuthenticator(t),
		saveServiceStub{update: func(
			_ context.Context,
			_ string,
			_ string,
			request gamesave.UpdateRequest,
		) (gamesave.UpdateResult, error) {
			serviceCalled = true
			if !request.ReceiptOnly || string(request.RawBody) == "" {
				t.Fatalf("request = %#v", request)
			}
			return gamesave.UpdateResult{}, gamesave.ErrClientUpdateRequired
		}},
		4096,
		2,
	)
	legacyBody := strings.TrimSuffix(validSaveBody, "}") + `,"legacyMetadata":{"format":1}}`
	request := jsonRequest(http.MethodPut, "/v1/save", legacyBody)
	request.Header.Set("Authorization", "Bearer access-token")
	request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
	request.Header.Set(saveWriterHeader, "3")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	requireAPIError(t, response, http.StatusUpgradeRequired, "CLIENT_UPDATE_REQUIRED")
	if !serviceCalled {
		t.Fatal("save receipt lookup was not attempted for outdated client")
	}
}

func TestUpdateSaveReturnsExistingReceiptToOutdatedClient(t *testing.T) {
	serverSavedAt := time.Date(2026, 8, 28, 1, 2, 3, 0, time.UTC)
	handler := newSaveTestHandlerWithMinimum(
		successfulAccessAuthenticator(t),
		saveServiceStub{update: func(
			_ context.Context,
			_ string,
			_ string,
			request gamesave.UpdateRequest,
		) (gamesave.UpdateResult, error) {
			if !request.ReceiptOnly {
				t.Fatalf("request = %#v", request)
			}
			return gamesave.UpdateResult{Revision: 1, ServerSavedAt: serverSavedAt}, nil
		}},
		4096,
		2,
	)
	request := jsonRequest(http.MethodPut, "/v1/save", validSaveBody)
	request.Header.Set("Authorization", "Bearer access-token")
	request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
	request.Header.Set(saveWriterHeader, "3")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var body saveUpdateResponse
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.Revision != 1 || !body.ServerSavedAt.Equal(serverSavedAt) {
		t.Fatalf("body = %#v", body)
	}
}

func TestValidateSaveClientCompatibility(t *testing.T) {
	current := gamesave.CurrentClientCompatibilityVersion
	outdated := current - 1
	future := current + 1

	for _, testCase := range []struct {
		name   string
		value  *int
		status int
		code   string
	}{
		{name: "missing", value: nil, status: http.StatusUpgradeRequired, code: "CLIENT_UPDATE_REQUIRED"},
		{name: "outdated", value: &outdated, status: http.StatusUpgradeRequired, code: "CLIENT_UPDATE_REQUIRED"},
		{name: "current", value: &current},
		{name: "future", value: &future, status: http.StatusUnprocessableEntity, code: "SAVE_CLIENT_VERSION_UNSUPPORTED"},
	} {
		t.Run(testCase.name, func(t *testing.T) {
			err := validateSaveClientCompatibility(testCase.value, current)
			if testCase.code == "" {
				if err != nil {
					t.Fatalf("validateSaveClientCompatibility() error = %v", err)
				}
				return
			}
			var requestError *saveRequestError
			if !errors.As(err, &requestError) {
				t.Fatalf("error = %v", err)
			}
			if requestError.status != testCase.status || requestError.code != testCase.code {
				t.Fatalf("request error = %#v", requestError)
			}
		})
	}
}

func TestUpdateSaveRequiresWriterHeaderBeforeService(t *testing.T) {
	serviceCalled := false
	handler := newSaveTestHandler(
		successfulAccessAuthenticator(t),
		saveServiceStub{update: func(
			context.Context,
			string,
			string,
			gamesave.UpdateRequest,
		) (gamesave.UpdateResult, error) {
			serviceCalled = true
			return gamesave.UpdateResult{}, nil
		}},
		4096,
	)
	request := jsonRequest(http.MethodPut, "/v1/save", validSaveBody)
	request.Header.Set("Authorization", "Bearer access-token")
	request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	requireAPIError(t, response, http.StatusPreconditionRequired, "SAVE_WRITER_REQUIRED")
	if serviceCalled {
		t.Fatal("save service was called without writer generation")
	}
}

func TestUpdateSaveMapsConflictAndIdempotencyReuse(t *testing.T) {
	for _, testCase := range []struct {
		name string
		err  error
		code string
	}{
		{
			name: "revision conflict",
			err:  &gamesave.RevisionConflictError{CurrentRevision: 7},
			code: "SAVE_REVISION_CONFLICT",
		},
		{
			name: "idempotency reuse",
			err:  gamesave.ErrIdempotencyKeyReused,
			code: "IDEMPOTENCY_KEY_REUSED",
		},
		{
			name: "writer replaced",
			err:  &gamesave.WriterReplacedError{CurrentGeneration: 8},
			code: "SAVE_WRITER_REPLACED",
		},
	} {
		t.Run(testCase.name, func(t *testing.T) {
			handler := newSaveTestHandler(
				successfulAccessAuthenticator(t),
				saveServiceStub{update: func(
					context.Context,
					string,
					string,
					gamesave.UpdateRequest,
				) (gamesave.UpdateResult, error) {
					return gamesave.UpdateResult{}, testCase.err
				}},
				4096,
			)
			request := jsonRequest(http.MethodPut, "/v1/save", validSaveBody)
			request.Header.Set("Authorization", "Bearer access-token")
			request.Header.Set(idempotencyKeyHeader, testIdempotencyKey)
			request.Header.Set(saveWriterHeader, "3")
			response := httptest.NewRecorder()

			handler.ServeHTTP(response, request)

			if testCase.code == "SAVE_REVISION_CONFLICT" {
				if response.Code != http.StatusConflict {
					t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
				}
				var body saveConflictResponse
				if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
					t.Fatalf("decode conflict response: %v", err)
				}
				if body.Code != testCase.code || body.RequestID == "" ||
					body.CurrentRevision != 7 {
					t.Fatalf("body = %#v", body)
				}
			} else if testCase.code == "SAVE_WRITER_REPLACED" {
				if response.Code != http.StatusConflict {
					t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
				}
				var body saveWriterReplacedResponse
				if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
					t.Fatalf("decode writer response: %v", err)
				}
				if body.Code != testCase.code || body.RequestID == "" ||
					body.CurrentWriterGeneration != 8 {
					t.Fatalf("body = %#v", body)
				}
			} else {
				requireAPIError(t, response, http.StatusConflict, testCase.code)
			}
		})
	}
}

func successfulAccessAuthenticator(t *testing.T) Authenticator {
	t.Helper()
	return sessionAuthenticatorStub{access: func(
		_ context.Context,
		accessToken string,
	) (auth.Principal, error) {
		if accessToken != "access-token" {
			t.Fatalf("accessToken = %q", accessToken)
		}
		return auth.Principal{AccountID: testAccountID, SessionID: testSessionID}, nil
	}}
}

func newSaveTestHandler(
	authenticator Authenticator,
	saves SaveService,
	maxSaveBodyBytes int64,
) http.Handler {
	return newSaveTestHandlerWithMinimum(
		authenticator,
		saves,
		maxSaveBodyBytes,
		gamesave.CurrentClientCompatibilityVersion,
	)
}

func newSaveTestHandlerWithMinimum(
	authenticator Authenticator,
	saves SaveService,
	maxSaveBodyBytes int64,
	minimumClientCompatibilityVersion int,
) http.Handler {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return NewHandler(logger, Dependencies{
		Database: readinessCheckerFunc(func(context.Context) error {
			return nil
		}),
		ReadinessTimeout:                      50 * time.Millisecond,
		Authenticator:                         authenticator,
		SaveService:                           saves,
		MaxSaveBodyBytes:                      maxSaveBodyBytes,
		MinimumSaveClientCompatibilityVersion: minimumClientCompatibilityVersion,
	})
}

func requireAPIError(
	t *testing.T,
	response *httptest.ResponseRecorder,
	status int,
	code string,
) {
	t.Helper()
	if response.Code != status {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var body errorResponse
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode error response: %v", err)
	}
	if body.Code != code || body.RequestID == "" {
		t.Fatalf("body = %#v", body)
	}
}
