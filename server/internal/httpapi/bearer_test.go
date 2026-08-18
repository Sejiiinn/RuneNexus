package httpapi

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
)

func TestBearerAuthenticationAddsDatabasePrincipalToContext(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	authenticator := sessionAuthenticatorStub{access: func(
		_ context.Context,
		accessToken string,
	) (auth.Principal, error) {
		if accessToken != "access-token" {
			t.Fatalf("accessToken = %q", accessToken)
		}
		return auth.Principal{AccountID: "account-id", SessionID: "session-id"}, nil
	}}
	nextCalled := false
	handler := withRequestMetadata(
		logger,
		withBearerAuthentication(
			logger,
			authenticator,
			http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
				nextCalled = true
				principal, ok := authenticatedPrincipalFromContext(request.Context())
				if !ok || principal.AccountID != "account-id" ||
					principal.SessionID != "session-id" {
					t.Fatalf("principal = %#v, ok = %v", principal, ok)
				}
				response.WriteHeader(http.StatusNoContent)
			}),
		),
	)
	request := httptest.NewRequest(http.MethodGet, "/protected", nil)
	request.Header.Set("Authorization", "Bearer access-token")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusNoContent || !nextCalled {
		t.Fatalf("status = %d, nextCalled = %v", response.Code, nextCalled)
	}
}

func TestBearerAuthenticationRejectsMissingOrInvalidToken(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	for _, testCase := range []struct {
		name   string
		header string
		err    error
	}{
		{name: "missing"},
		{name: "malformed", header: "Basic token"},
		{name: "expired", header: "Bearer expired-token", err: auth.ErrAccessTokenInvalid},
	} {
		t.Run(testCase.name, func(t *testing.T) {
			authenticator := sessionAuthenticatorStub{access: func(
				context.Context,
				string,
			) (auth.Principal, error) {
				return auth.Principal{}, testCase.err
			}}
			handler := withRequestMetadata(
				logger,
				withBearerAuthentication(
					logger,
					authenticator,
					http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
						t.Fatal("protected handler was called")
					}),
				),
			)
			request := httptest.NewRequest(http.MethodGet, "/protected", nil)
			if testCase.header != "" {
				request.Header.Set("Authorization", testCase.header)
			}
			response := httptest.NewRecorder()

			handler.ServeHTTP(response, request)

			if response.Code != http.StatusUnauthorized {
				t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
			}
		})
	}
}
