package httpapi

import (
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
)

type googleAuthenticatorFunc func(context.Context, string) (auth.LoginResult, error)

func (authenticate googleAuthenticatorFunc) AuthenticateGoogle(
	ctx context.Context,
	idToken string,
) (auth.LoginResult, error) {
	return authenticate(ctx, idToken)
}

func TestGoogleAuthenticationReturnsSession(t *testing.T) {
	expiresAt := time.Date(2026, 8, 18, 1, 2, 3, 0, time.UTC)
	handler := newAuthenticationTestHandler(
		googleAuthenticatorFunc(func(
			_ context.Context,
			idToken string,
		) (auth.LoginResult, error) {
			if idToken != "google-id-token" {
				t.Fatalf("idToken = %q", idToken)
			}
			return auth.LoginResult{
				AccountID:        "0198b955-3656-7c40-b3cb-87f427b90be2",
				AccessToken:      "access-token",
				AccessExpiresAt:  expiresAt,
				RefreshToken:     "refresh-token",
				RefreshExpiresAt: expiresAt.Add(30 * 24 * time.Hour),
			}, nil
		}),
		nil,
	)

	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/google",
		`{"idToken":"google-id-token"}`,
	)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var body authenticationResponse
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.Account.ID != "0198b955-3656-7c40-b3cb-87f427b90be2" ||
		body.AccessToken != "access-token" || body.RefreshToken != "refresh-token" {
		t.Fatalf("body = %#v", body)
	}
	if response.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("Cache-Control = %q", response.Header().Get("Cache-Control"))
	}
}

func TestGoogleAuthenticationMapsRejectedIdentity(t *testing.T) {
	handler := newAuthenticationTestHandler(
		googleAuthenticatorFunc(func(
			context.Context,
			string,
		) (auth.LoginResult, error) {
			return auth.LoginResult{}, auth.ErrIdentityRejected
		}),
		nil,
	)

	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/google",
		`{"idToken":"rejected-token"}`,
	)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d", response.Code)
	}
	var body errorResponse
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.Code != "GOOGLE_AUTH_REJECTED" || body.RequestID == "" {
		t.Fatalf("body = %#v", body)
	}
	if strings.Contains(response.Body.String(), "rejected-token") {
		t.Fatal("response exposed the Google ID token")
	}
}

func TestGoogleAuthenticationRejectsUnknownJSONField(t *testing.T) {
	authenticatorCalled := false
	handler := newAuthenticationTestHandler(
		googleAuthenticatorFunc(func(
			context.Context,
			string,
		) (auth.LoginResult, error) {
			authenticatorCalled = true
			return auth.LoginResult{}, errors.New("unexpected call")
		}),
		nil,
	)

	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/google",
		`{"idToken":"token","accountId":"untrusted"}`,
	)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d", response.Code)
	}
	if authenticatorCalled {
		t.Fatal("authenticator was called for invalid JSON")
	}
}

func TestGoogleAuthenticationRejectsOversizedBody(t *testing.T) {
	handler := newAuthenticationTestHandler(
		googleAuthenticatorFunc(func(
			context.Context,
			string,
		) (auth.LoginResult, error) {
			return auth.LoginResult{}, errors.New("unexpected call")
		}),
		nil,
	)

	body := `{"idToken":"` + strings.Repeat("x", maxAuthenticationBodyBytes) + `"}`
	request := jsonRequest(http.MethodPost, "/v1/auth/google", body)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
}

func TestCORSPreflightAllowsConfiguredOrigin(t *testing.T) {
	handler := newAuthenticationTestHandler(nil, []string{"https://sejiiinn.github.io"})
	request := httptest.NewRequest(http.MethodOptions, "/v1/auth/google", nil)
	request.Header.Set("Origin", "https://sejiiinn.github.io")
	request.Header.Set("Access-Control-Request-Method", http.MethodPost)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusNoContent {
		t.Fatalf("status = %d", response.Code)
	}
	if response.Header().Get("Access-Control-Allow-Origin") !=
		"https://sejiiinn.github.io" {
		t.Fatalf(
			"Access-Control-Allow-Origin = %q",
			response.Header().Get("Access-Control-Allow-Origin"),
		)
	}
}

func TestCORSRejectsUnconfiguredOrigin(t *testing.T) {
	handler := newAuthenticationTestHandler(nil, []string{"https://sejiiinn.github.io"})
	request := httptest.NewRequest(http.MethodOptions, "/v1/auth/google", nil)
	request.Header.Set("Origin", "https://attacker.example")
	request.Header.Set("Access-Control-Request-Method", http.MethodPost)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusForbidden {
		t.Fatalf("status = %d", response.Code)
	}
	if response.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Fatal("disallowed origin received an allow-origin header")
	}
}

func newAuthenticationTestHandler(
	authenticator GoogleAuthenticator,
	allowedOrigins []string,
) http.Handler {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return NewHandler(logger, Dependencies{
		Database: readinessCheckerFunc(func(context.Context) error {
			return nil
		}),
		ReadinessTimeout:    50 * time.Millisecond,
		GoogleAuthenticator: authenticator,
		CORSAllowedOrigins:  allowedOrigins,
	})
}

func jsonRequest(method string, path string, body string) *http.Request {
	request := httptest.NewRequest(method, path, strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	return request
}
