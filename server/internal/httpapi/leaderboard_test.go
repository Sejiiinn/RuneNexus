package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	"github.com/Sejiiinn/RuneNexus/server/internal/leaderboard"
)

type leaderboardStub struct {
	get func(context.Context, string) (leaderboard.Snapshot, error)
}

func (s leaderboardStub) GetProgression(ctx context.Context, id string) (leaderboard.Snapshot, error) {
	return s.get(ctx, id)
}

func TestProgressionLeaderboardAuthenticationAndPrivacy(t *testing.T) {
	for _, tc := range []struct {
		name     string
		token    bool
		nickname bool
		failure  bool
		status   int
	}{
		{"guest", false, true, false, 401}, {"nickname required", true, false, false, 403}, {"success", true, true, false, 200}, {"query failure", true, true, true, 500},
	} {
		t.Run(tc.name, func(t *testing.T) {
			called := false
			nickname, tag := "룬기사", "0007"
			accounts := sessionAuthenticatorStub{access: func(context.Context, string) (auth.Principal, error) {
				return auth.Principal{AccountID: testAccountID}, nil
			}, profile: func(context.Context, string) (auth.AccountProfile, error) {
				if tc.nickname {
					return auth.AccountProfile{Nickname: &nickname, Tag: &tag}, nil
				}
				return auth.AccountProfile{}, nil
			}}
			service := leaderboardStub{get: func(_ context.Context, id string) (leaderboard.Snapshot, error) {
				called = true
				if id != testAccountID {
					t.Fatalf("account = %s", id)
				}
				if tc.failure {
					return leaderboard.Snapshot{}, errors.New("private database failure " + testAccountID)
				}
				now := time.Date(2026, 9, 8, 0, 0, 0, 0, time.UTC)
				entry := leaderboard.Entry{Rank: 1, DisplayName: nickname + "#" + tag, StageNumber: 4, CompletedRounds: 1, AchievedAt: now, IsMe: true}
				return leaderboard.Snapshot{RulesVersion: 1, AsOf: now, Entries: []leaderboard.Entry{entry}, MyEntry: &entry}, nil
			}}
			handler := NewHandler(slog.New(slog.NewTextHandler(io.Discard, nil)), Dependencies{Authenticator: accounts, LeaderboardService: service})
			request := httptest.NewRequest("GET", "/v1/leaderboards/progression?accountId=other", nil)
			if tc.token {
				request.Header.Set("Authorization", "Bearer test")
			}
			recorder := httptest.NewRecorder()
			handler.ServeHTTP(recorder, request)
			if recorder.Code != tc.status {
				t.Fatalf("status %d: %s", recorder.Code, recorder.Body.String())
			}
			if called != (tc.token && tc.nickname) {
				t.Fatalf("query called = %v", called)
			}
			if strings.Contains(recorder.Body.String(), testAccountID) || strings.Contains(recorder.Body.String(), "private database") {
				t.Fatal("private information leaked")
			}
			if tc.status == 200 {
				var result map[string]json.RawMessage
				if err := json.Unmarshal(recorder.Body.Bytes(), &result); err != nil {
					t.Fatal(err)
				}
				if len(result) != 4 || string(result["rulesVersion"]) != "1" || !strings.Contains(string(result["entries"]), "룬기사#0007") {
					t.Fatalf("response %s", recorder.Body.String())
				}
				var entries []map[string]json.RawMessage
				if err := json.Unmarshal(result["entries"], &entries); err != nil {
					t.Fatal(err)
				}
				if len(entries) != 1 || len(entries[0]) != 6 {
					t.Fatalf("entry fields %v", entries)
				}
			}
		})
	}
}
