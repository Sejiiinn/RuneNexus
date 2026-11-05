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

type sessionAuthenticatorStub struct {
	profile  func(context.Context, string) (auth.AccountProfile, error)
	nickname func(context.Context, string, string) (auth.AccountProfile, error)
	google   func(context.Context, string) (auth.LoginResult, error)
	refresh  func(context.Context, string, string) (auth.LoginResult, error)
	logout   func(context.Context, string, string) error
	access   func(context.Context, string) (auth.Principal, error)
}

func (stub sessionAuthenticatorStub) AuthenticateGooglePersistent(ctx context.Context, idToken string) (auth.LoginResult, error) {
	if stub.google == nil {
		return auth.LoginResult{}, errors.New("unexpected Google authentication")
	}
	return stub.google(ctx, idToken)
}

func (stub sessionAuthenticatorStub) RefreshPersistent(ctx context.Context, refreshToken, requestKey string) (auth.LoginResult, error) {
	if stub.refresh == nil {
		return auth.LoginResult{}, errors.New("unexpected session refresh")
	}
	return stub.refresh(ctx, refreshToken, requestKey)
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
	handler := newAuthenticationTestHandler(sessionAuthenticatorStub{google: func(
		_ context.Context,
		idToken string,
	) (auth.LoginResult, error) {
		if idToken != "google-id-token" {
			t.Fatalf("idToken = %q", idToken)
		}
		return auth.LoginResult{
			AccountID:       "0198b955-3656-7c40-b3cb-87f427b90be2",
			AccessToken:     "access-token",
			AccessExpiresAt: expiresAt,
			RefreshToken:    "refresh-token",
		}, nil
	}})

	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/native/google",
		`{"idToken":"google-id-token"}`,
	)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var body map[string]any
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	account, _ := body["account"].(map[string]any)
	if account["id"] != "0198b955-3656-7c40-b3cb-87f427b90be2" ||
		body["accessToken"] != "access-token" || body["refreshToken"] != "refresh-token" {
		t.Fatalf("body = %#v", body)
	}
	if expiry, exists := body["refreshExpiresAt"]; !exists || expiry != nil {
		t.Fatalf("persistent refreshExpiresAt = %#v", expiry)
	}
	if response.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("Cache-Control = %q", response.Header().Get("Cache-Control"))
	}
	if len(response.Result().Cookies()) != 0 {
		t.Fatal("native login set a cookie")
	}
}

func TestGoogleAuthenticationMapsRejectedIdentity(t *testing.T) {
	handler := newAuthenticationTestHandler(sessionAuthenticatorStub{google: func(
		context.Context,
		string,
	) (auth.LoginResult, error) {
		return auth.LoginResult{}, auth.ErrIdentityRejected
	}})

	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/native/google",
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

func TestGoogleAuthenticationRejectsInvalidBodies(t *testing.T) {
	for name, body := range map[string]string{
		"unknown field": `{"idToken":"token","accountId":"untrusted"}`,
		"oversized":     `{"idToken":"` + strings.Repeat("x", maxAuthenticationBodyBytes) + `"}`,
		"empty token":   `{"idToken":" "}`,
	} {
		t.Run(name, func(t *testing.T) {
			authenticatorCalled := false
			handler := newAuthenticationTestHandler(sessionAuthenticatorStub{google: func(
				context.Context,
				string,
			) (auth.LoginResult, error) {
				authenticatorCalled = true
				return auth.LoginResult{}, errors.New("unexpected call")
			}})
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, jsonRequest(http.MethodPost, "/v1/auth/native/google", body))

			if response.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
			}
			if authenticatorCalled {
				t.Fatal("authenticator was called for an invalid body")
			}
		})
	}
}

func TestRefreshAuthenticationRotatesSession(t *testing.T) {
	handler := newAuthenticationTestHandler(sessionAuthenticatorStub{refresh: func(
		_ context.Context,
		refreshToken string,
		requestKey string,
	) (auth.LoginResult, error) {
		if refreshToken != "old-refresh-token" || requestKey != "request-key" {
			t.Fatalf("refreshToken = %q, requestKey = %q", refreshToken, requestKey)
		}
		return auth.LoginResult{
			AccountID:    "0198b955-3656-7c40-b3cb-87f427b90be2",
			AccessToken:  "new-access-token",
			RefreshToken: "new-refresh-token",
		}, nil
	}})

	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/native/refresh",
		`{"refreshToken":"old-refresh-token"}`,
	)
	request.Header.Set("Idempotency-Key", "request-key")
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

func TestRefreshAuthenticationRequiresOneIdempotencyKey(t *testing.T) {
	handler := newAuthenticationTestHandler(sessionAuthenticatorStub{})
	for _, keys := range [][]string{nil, {"first", "second"}} {
		request := jsonRequest(http.MethodPost, "/v1/auth/native/refresh", `{"refreshToken":"refresh-token"}`)
		for _, key := range keys {
			request.Header.Add("Idempotency-Key", key)
		}
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, request)
		if response.Code != http.StatusBadRequest || !strings.Contains(response.Body.String(), "INVALID_IDEMPOTENCY_KEY") {
			t.Fatalf("keys %v: status = %d, body = %s", keys, response.Code, response.Body.String())
		}
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
		{name: "recovery expired", err: auth.ErrRefreshRecoveryExpired, code: "REFRESH_RECOVERY_EXPIRED"},
	} {
		t.Run(testCase.name, func(t *testing.T) {
			handler := newAuthenticationTestHandler(sessionAuthenticatorStub{refresh: func(
				context.Context,
				string,
				string,
			) (auth.LoginResult, error) {
				return auth.LoginResult{}, testCase.err
			}})
			request := jsonRequest(
				http.MethodPost,
				"/v1/auth/native/refresh",
				`{"refreshToken":"refresh-token"}`,
			)
			request.Header.Set("Idempotency-Key", "request-key")
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
	handler := newAuthenticationTestHandler(sessionAuthenticatorStub{logout: func(
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
	}})
	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/native/logout",
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
	handler := newAuthenticationTestHandler(sessionAuthenticatorStub{logout: func(
		context.Context,
		string,
		string,
	) error {
		return auth.ErrLogoutSessionMismatch
	}})
	request := jsonRequest(
		http.MethodPost,
		"/v1/auth/native/logout",
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

func TestRemovedAuthenticationRoutesAreNotServed(t *testing.T) {
	handler := newAuthenticationTestHandler(sessionAuthenticatorStub{})
	for _, path := range []string{"/v1/auth/google", "/v1/auth/refresh", "/v1/auth/logout", "/v1/auth/web/google", "/v1/auth/web/refresh", "/v1/auth/web/logout"} {
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, jsonRequest(http.MethodPost, path, `{}`))
		if response.Code != http.StatusNotFound {
			t.Fatalf("%s status = %d", path, response.Code)
		}
	}
}

func newAuthenticationTestHandler(authenticator Authenticator) http.Handler {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return NewHandler(logger, Dependencies{
		Database: readinessCheckerFunc(func(context.Context) error {
			return nil
		}),
		ReadinessTimeout: 50 * time.Millisecond,
		Authenticator:    authenticator,
	})
}

func jsonRequest(method string, path string, body string) *http.Request {
	request := httptest.NewRequest(method, path, strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	return request
}

func (stub sessionAuthenticatorStub) GetAccountProfile(ctx context.Context, id string) (auth.AccountProfile, error) {
	if stub.profile != nil {
		return stub.profile(ctx, id)
	}
	nickname, tag := "테스트", "0000"
	return auth.AccountProfile{AccountID: id, Nickname: &nickname, Tag: &tag}, nil
}
func (stub sessionAuthenticatorStub) SetNickname(ctx context.Context, id, nickname string) (auth.AccountProfile, error) {
	if stub.nickname != nil {
		return stub.nickname(ctx, id, nickname)
	}
	return auth.AccountProfile{}, errors.New("unexpected nickname set")
}
