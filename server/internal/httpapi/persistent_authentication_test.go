package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
)

type persistentAuthenticatorStub struct{ sessionAuthenticatorStub }

func (persistentAuthenticatorStub) AuthenticateGooglePersistent(context.Context, string) (auth.LoginResult, error) {
	return auth.LoginResult{AccountID: "account", AccessToken: "access", AccessExpiresAt: time.Now().Add(15 * time.Minute), RefreshToken: "secret-refresh"}, nil
}
func (persistentAuthenticatorStub) RefreshPersistent(context.Context, string, string) (auth.LoginResult, error) {
	return auth.LoginResult{AccountID: "account", AccessToken: "access", RefreshToken: "rotated-secret"}, nil
}

func TestPersistentWebAuthenticationCookieAndCSRF(t *testing.T) {
	handler := NewHandler(slog.New(slog.NewTextHandler(io.Discard, nil)), Dependencies{Authenticator: persistentAuthenticatorStub{}, CORSAllowedOrigins: []string{"https://play.example.com"}})
	for _, origin := range []string{"", "null", "https://evil.example.com", "https://play.example.com"} {
		request := httptest.NewRequest(http.MethodPost, "/v1/auth/web/google", strings.NewReader(`{"idToken":"google"}`))
		request.Header.Set("Content-Type", "application/json")
		if origin != "" {
			request.Header.Set("Origin", origin)
		}
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, request)
		if origin != "https://play.example.com" {
			if response.Code != 403 {
				t.Fatalf("origin %q status %d", origin, response.Code)
			}
			continue
		}
		if response.Code != 200 {
			t.Fatal(response.Body.String())
		}
		var body map[string]any
		if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
			t.Fatal(err)
		}
		if _, exists := body["refreshToken"]; exists {
			t.Fatal("web exposed refresh token")
		}
		if body["refreshExpiresAt"] != nil {
			t.Fatal("persistent expiry not null")
		}
		cookies := response.Result().Cookies()
		if len(cookies) != 1 {
			t.Fatal("cookie missing")
		}
		cookie := cookies[0]
		if cookie.Name != refreshCookieName || !cookie.Secure || !cookie.HttpOnly || cookie.SameSite != http.SameSiteLaxMode || cookie.Domain != "" || cookie.Path != "/" || cookie.MaxAge <= 0 {
			t.Fatalf("insecure cookie: %s", cookie)
		}
	}
	request := httptest.NewRequest(http.MethodPost, "/v1/auth/web/refresh", strings.NewReader(`{}`))
	request.Header.Set("Origin", "https://play.example.com")
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != 400 {
		t.Fatalf("missing request key: %d", response.Code)
	}
}

func TestPersistentNativeAuthenticationReturnsToken(t *testing.T) {
	handler := NewHandler(slog.New(slog.NewTextHandler(io.Discard, nil)), Dependencies{Authenticator: persistentAuthenticatorStub{}})
	request := httptest.NewRequest(http.MethodPost, "/v1/auth/native/google", strings.NewReader(`{"idToken":"google"}`))
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != 200 || !strings.Contains(response.Body.String(), `"refreshToken":"secret-refresh"`) || len(response.Result().Cookies()) != 0 {
		t.Fatalf("native response: %s", response.Body.String())
	}
}
