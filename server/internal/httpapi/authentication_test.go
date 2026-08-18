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

func (googleAuthenticatorFunc) Refresh(
	context.Context,
	string,
) (auth.LoginResult, error) {
	return auth.LoginResult{}, errors.New("unexpected session refresh")
}

func (googleAuthenticatorFunc) Logout(context.Context, string, string) error {
	return errors.New("unexpected logout")
}

func (googleAuthenticatorFunc) AuthenticateAccessToken(
	context.Context,
	string,
) (auth.Principal, error) {
	return auth.Principal{}, errors.New("unexpected access authentication")
}

type sessionAuthenticatorStub struct {
	refresh func(context.Context, string) (auth.LoginResult, error)
	logout  func(context.Context, string, string) error
	access  func(context.Context, string) (auth.Principal, error)
}

func (sessionAuthenticatorStub) AuthenticateGoogle(
	context.Context,
	string,
) (auth.LoginResult, error) {
	return auth.LoginResult{}, errors.New("unexpected Google authentication")
}

func (stub sessionAuthenticatorStub) Refresh(
	ctx context.Context,
	refreshToken string,
) (auth.LoginResult, error) {
	if stub.refresh == nil {
		return auth.LoginResult{}, errors.New("unexpected session refresh")
	}
	return stub.refresh(ctx, refreshToken)
}

func (stub sessionAuthenticatorStub) Logout(
	ctx context.Context,
	refreshToken string,
	accessToken string,
) error {
	if stub.logout == nil {
		return errors.New("unexpected logout")
	}
	return stub.logout(ctx, refreshToken, accessToken)
}

func (stub sessionAuthenticatorStub) AuthenticateAccessToken(
	ctx context.Context,
	accessToken string,
) (auth.Principal, error) {
	if stub.access == nil {
		return auth.Principal{}, errors.New("unexpected access authentication")
	}
	return stub.access(ctx, accessToken)
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

func TestRefreshAuthenticationRotatesSession(t *testing.T) {
	expiresAt := time.Date(2026, 8, 18, 1, 2, 3, 0, time.UTC)
	handler := newAuthenticationTestHandler(
		sessionAuthenticatorStub{refresh: func(
			_ context.Context,
			refreshToken string,
		) (auth.LoginResult, error) {
			if refreshToken != "old-refresh-token" {
				t.Fatalf("refreshToken = %q", refreshToken)
			}
			return auth.LoginResult{
				AccountID:        "0198b955-3656-7c40-b3cb-87f427b90be2",
				AccessToken:      "new-access-token",
				AccessExpiresAt:  expiresAt,
				RefreshToken:     "new-refresh-token",
				RefreshExpiresAt: expiresAt.Add(30 * 24 * time.Hour),
			}, nil
		}},
		nil,
	)

	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/refresh",
		`{"refreshToken":"old-refresh-token"}`,
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
	if body.AccessToken != "new-access-token" ||
		body.RefreshToken != "new-refresh-token" {
		t.Fatalf("body = %#v", body)
	}
}

func TestRefreshAuthenticationMapsTokenErrors(t *testing.T) {
	for _, testCase := range []struct {
		name string
		err  error
		code string
	}{
		{name: "invalid", err: auth.ErrRefreshTokenInvalid, code: "REFRESH_TOKEN_INVALID"},
		{name: "reused", err: auth.ErrRefreshTokenReused, code: "REFRESH_TOKEN_REUSED"},
	} {
		t.Run(testCase.name, func(t *testing.T) {
			handler := newAuthenticationTestHandler(
				sessionAuthenticatorStub{refresh: func(
					context.Context,
					string,
				) (auth.LoginResult, error) {
					return auth.LoginResult{}, testCase.err
				}},
				nil,
			)
			request := jsonRequest(
				http.MethodPost,
				"/v1/auth/refresh",
				`{"refreshToken":"refresh-token"}`,
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
			if body.Code != testCase.code {
				t.Fatalf("code = %q", body.Code)
			}
		})
	}
}

func TestLogoutRevokesSessionAndReturnsNoContent(t *testing.T) {
	logoutCalled := false
	handler := newAuthenticationTestHandler(
		sessionAuthenticatorStub{logout: func(
			_ context.Context,
			refreshToken string,
			accessToken string,
		) error {
			logoutCalled = true
			if refreshToken != "refresh-token" {
				t.Fatalf("refreshToken = %q", refreshToken)
			}
			if accessToken != "access-token" {
				t.Fatalf("accessToken = %q", accessToken)
			}
			return nil
		}},
		nil,
	)
	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/logout",
		`{"refreshToken":"refresh-token"}`,
	)
	request.Header.Set("Authorization", "Bearer access-token")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusNoContent {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if !logoutCalled {
		t.Fatal("logout was not called")
	}
	if response.Body.Len() != 0 {
		t.Fatalf("body = %q", response.Body.String())
	}
}

func TestLogoutRejectsTokensFromDifferentSessions(t *testing.T) {
	handler := newAuthenticationTestHandler(
		sessionAuthenticatorStub{logout: func(
			context.Context,
			string,
			string,
		) error {
			return auth.ErrLogoutSessionMismatch
		}},
		nil,
	)
	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/logout",
		`{"refreshToken":"refresh-token"}`,
	)
	request.Header.Set("Authorization", "Bearer other-session-access-token")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var body errorResponse
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.Code != "ACCESS_TOKEN_SESSION_MISMATCH" {
		t.Fatalf("code = %q", body.Code)
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
	authenticator Authenticator,
	allowedOrigins []string,
) http.Handler {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return NewHandler(logger, Dependencies{
		Database: readinessCheckerFunc(func(context.Context) error {
			return nil
		}),
		ReadinessTimeout:   50 * time.Millisecond,
		Authenticator:      authenticator,
		CORSAllowedOrigins: allowedOrigins,
	})
}

func jsonRequest(method string, path string, body string) *http.Request {
	request := httptest.NewRequest(method, path, strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	return request
}
