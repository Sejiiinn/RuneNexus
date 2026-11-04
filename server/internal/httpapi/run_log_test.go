package httpapi

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	"github.com/Sejiiinn/RuneNexus/server/internal/runlog"
)

type runLogStub struct {
	record func(context.Context, string, runlog.Entry) error
}

func (s runLogStub) Record(ctx context.Context, id string, entry runlog.Entry) error {
	return s.record(ctx, id, entry)
}

func TestRunLogRoute(t *testing.T) {
	valid := `{"schemaVersion":1,"runId":"0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a71","clientBuild":6062,"stageId":23}`
	for _, tc := range []struct {
		name    string
		token   bool
		body    string
		failure bool
		status  int
		stored  bool
	}{
		{"no token", false, valid, false, 401, false},
		{"stored", true, valid, false, 200, true},
		{"invalid", true, `{"schemaVersion":1}`, false, 400, false},
		// Valid apart from its size, so only the body limit can reject it.
		{"oversized", true, strings.TrimSuffix(valid, "}") + `,"pad":"` + strings.Repeat("x", runlog.MaxBodyBytes) + `"}`, false, 400, false},
		{"store failure", true, valid, true, 500, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			stored := false
			accounts := sessionAuthenticatorStub{access: func(context.Context, string) (auth.Principal, error) {
				return auth.Principal{AccountID: testAccountID}, nil
			}, profile: func(context.Context, string) (auth.AccountProfile, error) {
				nickname, tag := "룬기사", "0007"
				return auth.AccountProfile{Nickname: &nickname, Tag: &tag}, nil
			}}
			service := runLogStub{record: func(_ context.Context, id string, entry runlog.Entry) error {
				stored = true
				if id != testAccountID || entry.StageID != 23 || string(entry.Payload) != valid {
					t.Fatalf("record %s %+v", id, entry)
				}
				if tc.failure {
					return errors.New("private database failure")
				}
				return nil
			}}
			handler := NewHandler(slog.New(slog.NewTextHandler(io.Discard, nil)), Dependencies{Authenticator: accounts, RunLogService: service})
			request := httptest.NewRequest("POST", "/v1/telemetry/run-logs", strings.NewReader(tc.body))
			request.Header.Set("Content-Type", "application/json")
			if tc.token {
				request.Header.Set("Authorization", "Bearer test")
			}
			recorder := httptest.NewRecorder()
			handler.ServeHTTP(recorder, request)
			if recorder.Code != tc.status || stored != tc.stored {
				t.Fatalf("status %d stored %v: %s", recorder.Code, stored, recorder.Body.String())
			}
			if tc.status == 200 && strings.TrimSpace(recorder.Body.String()) != `{"code":"OK"}` {
				t.Fatalf("body = %s", recorder.Body.String())
			}
			if strings.Contains(recorder.Body.String(), "private database") {
				t.Fatal("internal error leaked")
			}
		})
	}
}
