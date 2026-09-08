package httpapi

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
)

type nicknameBlockedEconomyService struct{ EconomyService }

func TestAccountProfileEndpoints(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	nickname, tag := "룬마스터", "0382"
	accounts := sessionAuthenticatorStub{
		access: func(context.Context, string) (auth.Principal, error) {
			return auth.Principal{AccountID: testAccountID}, nil
		},
		profile: func(_ context.Context, id string) (auth.AccountProfile, error) {
			if id != testAccountID {
				t.Fatalf("profile account = %s", id)
			}
			return auth.AccountProfile{AccountID: id}, nil
		},
		nickname: func(_ context.Context, id, value string) (auth.AccountProfile, error) {
			if id != testAccountID || value != nickname {
				t.Fatalf("nickname args = %s %s", id, value)
			}
			return auth.AccountProfile{AccountID: id, Nickname: &nickname, Tag: &tag}, nil
		},
	}
	handler := NewHandler(logger, Dependencies{Authenticator: accounts})
	for _, tc := range []struct {
		method, path, body, contains string
		status                       int
	}{
		{"GET", "/v1/account/profile", "", `"nickname":null,"tag":null`, 200},
		{"PUT", "/v1/account/nickname", `{"nickname":"룬마스터"}`, `"tag":"0382"`, 200},
		{"PUT", "/v1/account/nickname", `{"nickname":"룬마스터","accountId":"other"}`, `INVALID_REQUEST`, 400},
	} {
		request := httptest.NewRequest(tc.method, tc.path, strings.NewReader(tc.body))
		request.Header.Set("Authorization", "Bearer test")
		request.Header.Set("Content-Type", "application/json")
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, request)
		if recorder.Code != tc.status || !strings.Contains(recorder.Body.String(), tc.contains) {
			t.Fatalf("%s: %d %s", tc.path, recorder.Code, recorder.Body.String())
		}
	}
	request := httptest.NewRequest("GET", "/v1/account/profile", nil)
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != 401 {
		t.Fatalf("unauthenticated profile = %d", recorder.Code)
	}
}

func TestAllAccountGameplayRoutesRequireNickname(t *testing.T) {
	accounts := sessionAuthenticatorStub{
		access: func(context.Context, string) (auth.Principal, error) {
			return auth.Principal{AccountID: testAccountID}, nil
		},
		profile: func(context.Context, string) (auth.AccountProfile, error) {
			return auth.AccountProfile{AccountID: testAccountID}, nil
		},
	}
	handler := NewHandler(slog.New(slog.NewTextHandler(io.Discard, nil)), Dependencies{
		Authenticator: accounts, SaveService: saveServiceStub{}, WeeklyRewardService: weeklyRewardServiceStub{}, EconomyService: nicknameBlockedEconomyService{}, LegacyTransferService: legacyTransferServiceStub{},
	})
	for _, route := range []string{
		"GET /v1/save", "PUT /v1/save", "POST /v1/save/writer", "POST /v1/economy/rewards/claim",
		"GET /v1/economy", "GET /v1/economy/catalog", "POST /v1/economy/bootstrap",
		"POST /v1/economy/turret-modules/draw", "POST /v1/economy/turret-modules/disassemble",
		"POST /v1/economy/researches/attack/complete", "POST /v1/economy/research-slots/2/unlock",
		"POST /v1/economy/progression-effects/id/ack", "POST /v1/economy/runs/settle",
		"POST /v1/legacy-save-transfers/consume",
	} {
		parts := strings.SplitN(route, " ", 2)
		request := httptest.NewRequest(parts[0], parts[1], nil)
		request.Header.Set("Authorization", "Bearer test")
		request.Header.Set("Content-Type", "application/json")
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, request)
		if recorder.Code != http.StatusForbidden || !strings.Contains(recorder.Body.String(), "NICKNAME_REQUIRED") {
			t.Errorf("%s: %d %s", route, recorder.Code, recorder.Body.String())
		}
	}
}

func TestAccountProfileErrorsFailClosed(t *testing.T) {
	for _, tc := range []struct {
		err    error
		status int
		code   string
	}{
		{auth.ErrInvalidNickname, 400, "INVALID_NICKNAME"}, {auth.ErrNicknameAlreadySet, 409, "NICKNAME_ALREADY_SET"}, {auth.ErrNicknameTagsExhausted, 409, "NICKNAME_TAGS_EXHAUSTED"}, {errors.New("database down"), 500, "INTERNAL_ERROR"},
	} {
		accounts := sessionAuthenticatorStub{access: func(context.Context, string) (auth.Principal, error) {
			return auth.Principal{AccountID: testAccountID}, nil
		}, nickname: func(context.Context, string, string) (auth.AccountProfile, error) {
			return auth.AccountProfile{}, tc.err
		}}
		handler := NewHandler(slog.New(slog.NewTextHandler(io.Discard, nil)), Dependencies{Authenticator: accounts})
		request := httptest.NewRequest("PUT", "/v1/account/nickname", strings.NewReader(`{"nickname":"테스트"}`))
		request.Header.Set("Authorization", "Bearer test")
		request.Header.Set("Content-Type", "application/json")
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, request)
		if recorder.Code != tc.status || !strings.Contains(recorder.Body.String(), tc.code) {
			t.Fatalf("%v: %d %s", tc.err, recorder.Code, recorder.Body.String())
		}
	}
}
