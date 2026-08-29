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

	"github.com/Sejiiinn/RuneNexus/server/internal/legacytransfer"
)

type legacyTransferServiceStub struct {
	create  func(context.Context, legacytransfer.CreateRequest) (legacytransfer.CreateResult, error)
	consume func(context.Context, string, string, string) (legacytransfer.ConsumeResult, error)
}

func (stub legacyTransferServiceStub) Create(
	ctx context.Context,
	request legacytransfer.CreateRequest,
) (legacytransfer.CreateResult, error) {
	return stub.create(ctx, request)
}

func (stub legacyTransferServiceStub) Consume(
	ctx context.Context,
	accountID string,
	sessionID string,
	token string,
) (legacytransfer.ConsumeResult, error) {
	return stub.consume(ctx, accountID, sessionID, token)
}

func TestLegacyTransferCreateAcceptsCanonicalSaveWithoutAuthentication(t *testing.T) {
	expiresAt := time.Date(2026, 8, 29, 3, 15, 0, 0, time.UTC)
	body := legacyTransferCreateBody()
	handler := newLegacyTransferTestHandler(t, legacyTransferServiceStub{
		create: func(
			_ context.Context,
			request legacytransfer.CreateRequest,
		) (legacytransfer.CreateResult, error) {
			if string(request.RawBody) != body || request.Data.Version != 2 ||
				request.Data.SavedAtMillis != 123 {
				t.Fatalf("request = %#v", request)
			}
			return legacytransfer.CreateResult{
				Token:     "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
				ExpiresAt: expiresAt,
			}, nil
		},
		consume: unusedLegacyTransferConsume(t),
	})
	request := jsonRequest(http.MethodPost, "/v1/legacy-save-transfers", body)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var decoded legacyTransferCreateResponse
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if decoded.Token == "" || !decoded.ExpiresAt.Equal(expiresAt) {
		t.Fatalf("response = %#v", decoded)
	}
}

func TestLegacyTransferConsumeUsesAuthenticatedPrincipal(t *testing.T) {
	savedAt := time.Date(2026, 8, 29, 3, 1, 2, 0, time.UTC)
	token := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
	handler := newLegacyTransferTestHandler(t, legacyTransferServiceStub{
		create: unusedLegacyTransferCreate(t),
		consume: func(
			_ context.Context,
			accountID string,
			sessionID string,
			actualToken string,
		) (legacytransfer.ConsumeResult, error) {
			if accountID != testAccountID || sessionID != testSessionID || actualToken != token {
				t.Fatalf("account = %q, session = %q, token = %q", accountID, sessionID, actualToken)
			}
			return legacytransfer.ConsumeResult{
				Revision:      1,
				ServerSavedAt: savedAt,
			}, nil
		},
	})
	request := jsonRequest(
		http.MethodPost,
		"/v1/legacy-save-transfers/consume",
		`{"token":"`+token+`"}`,
	)
	request.Header.Set("Authorization", "Bearer access-token")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var decoded legacyTransferConsumeResponse
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if decoded.Revision != 1 || !decoded.ServerSavedAt.Equal(savedAt) {
		t.Fatalf("response = %#v", decoded)
	}
}

func TestLegacyTransferConsumeDoesNotOverwriteExistingAccount(t *testing.T) {
	handler := newLegacyTransferTestHandler(t, legacyTransferServiceStub{
		create: unusedLegacyTransferCreate(t),
		consume: func(
			context.Context,
			string,
			string,
			string,
		) (legacytransfer.ConsumeResult, error) {
			return legacytransfer.ConsumeResult{}, legacytransfer.ErrTargetSaveExists
		},
	})
	request := jsonRequest(
		http.MethodPost,
		"/v1/legacy-save-transfers/consume",
		`{"token":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}`,
	)
	request.Header.Set("Authorization", "Bearer access-token")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusConflict {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var decoded errorResponse
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if decoded.Code != "LEGACY_TRANSFER_TARGET_NOT_EMPTY" {
		t.Fatalf("response = %#v", decoded)
	}
}

func newLegacyTransferTestHandler(
	t *testing.T,
	transfers LegacyTransferService,
) http.Handler {
	t.Helper()
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return NewHandler(logger, Dependencies{
		Database: readinessCheckerFunc(func(context.Context) error {
			return nil
		}),
		ReadinessTimeout:                      50 * time.Millisecond,
		Authenticator:                         successfulAccessAuthenticator(t),
		LegacyTransferService:                 transfers,
		MaxSaveBodyBytes:                      4 * 1024 * 1024,
		MinimumSaveClientCompatibilityVersion: 1,
	})
}

func legacyTransferCreateBody() string {
	return `{"clientCompatibilityVersion":1,"data":{"version":2,"savedAtMillis":123,"preferences":{},"progression":{"runes":10,"freeDiamonds":20,"paidDiamonds":0},"turretModules":{"tickets":1,"items":[]},"activeRun":null}}`
}

func unusedLegacyTransferCreate(
	t *testing.T,
) func(context.Context, legacytransfer.CreateRequest) (legacytransfer.CreateResult, error) {
	t.Helper()
	return func(context.Context, legacytransfer.CreateRequest) (legacytransfer.CreateResult, error) {
		t.Fatal("unexpected legacy transfer create")
		return legacytransfer.CreateResult{}, nil
	}
}

func unusedLegacyTransferConsume(
	t *testing.T,
) func(context.Context, string, string, string) (legacytransfer.ConsumeResult, error) {
	t.Helper()
	return func(context.Context, string, string, string) (legacytransfer.ConsumeResult, error) {
		t.Fatal("unexpected legacy transfer consume")
		return legacytransfer.ConsumeResult{}, nil
	}
}
