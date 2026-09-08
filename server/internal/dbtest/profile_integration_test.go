//go:build integration

package dbtest_test

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	"github.com/Sejiiinn/RuneNexus/server/internal/httpapi"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func TestNicknameConcurrentAssignmentAndRetry(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := auth.NewService(pool, nil, time.Second, time.Minute, time.Hour)
	ids := make([]string, 8)
	for i := range ids {
		if err := pool.QueryRow(ctx, "INSERT INTO accounts DEFAULT VALUES RETURNING id::text").Scan(&ids[i]); err != nil {
			t.Fatal(err)
		}
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), "DELETE FROM accounts WHERE id::text = ANY($1::text[])", ids)
	})
	profile, err := service.GetAccountProfile(ctx, ids[0])
	if err != nil || profile.Nickname != nil || profile.Tag != nil {
		t.Fatalf("new profile = %+v %v", profile, err)
	}
	nickname := fmt.Sprintf("N%x", time.Now().UnixNano()%0xffffffffff)
	results := make([]auth.AccountProfile, len(ids))
	errs := make([]error, len(ids))
	var wg sync.WaitGroup
	for i := range ids {
		wg.Add(1)
		go func(i int) { defer wg.Done(); results[i], errs[i] = service.SetNickname(ctx, ids[i], nickname) }(i)
	}
	wg.Wait()
	seen := map[string]bool{}
	for i, result := range results {
		if errs[i] != nil || result.Nickname == nil || result.Tag == nil || len(*result.Tag) != 4 {
			t.Fatalf("result %d = %+v %v", i, result, errs[i])
		}
		if seen[*result.Tag] {
			t.Fatal("duplicate combination")
		}
		seen[*result.Tag] = true
	}
	originalTag := *results[0].Tag
	for i := range ids {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			results[i], errs[i] = service.SetNickname(ctx, ids[0], "  "+nickname+" ")
		}(i)
	}
	wg.Wait()
	for i, result := range results {
		if errs[i] != nil || *result.Tag != originalTag {
			t.Fatalf("retry %d = %+v %v", i, result, errs[i])
		}
	}
	if _, err := service.SetNickname(ctx, ids[0], "다른이름"); !errors.Is(err, auth.ErrNicknameAlreadySet) {
		t.Fatalf("rename error = %v", err)
	}
	if _, err := service.SetNickname(ctx, ids[0], "가나다라마바사아자"); !errors.Is(err, auth.ErrInvalidNickname) {
		t.Fatalf("invalid error = %v", err)
	}
	stored, err := service.GetAccountProfile(ctx, ids[0])
	if err != nil || *stored.Tag != *results[0].Tag {
		t.Fatalf("stored = %+v %v", stored, err)
	}
}

func TestNicknameTagExhaustionAndCaseSensitivity(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := auth.NewService(pool, nil, time.Second, time.Minute, time.Hour)
	nickname := fmt.Sprintf("N%x", time.Now().UnixNano()%0xffffffffff)
	var id string
	if err := pool.QueryRow(ctx, "INSERT INTO accounts DEFAULT VALUES RETURNING id::text").Scan(&id); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), "DELETE FROM accounts WHERE nickname=$1 OR nickname=$2 OR id::text=$3", nickname, "n"+nickname[1:], id)
	})
	if _, err := pool.Exec(ctx, "INSERT INTO accounts (nickname,nickname_tag) SELECT $1, lpad(n::text,4,'0') FROM generate_series(0,9998) n", nickname); err != nil {
		t.Fatal(err)
	}
	profile, err := service.SetNickname(ctx, id, nickname)
	if err != nil || *profile.Tag != "9999" {
		t.Fatalf("last tag = %+v %v", profile, err)
	}
	var next string
	if err := pool.QueryRow(ctx, "INSERT INTO accounts DEFAULT VALUES RETURNING id::text").Scan(&next); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _, _ = pool.Exec(context.Background(), "DELETE FROM accounts WHERE id::text=$1", next) })
	if _, err := service.SetNickname(ctx, next, nickname); !errors.Is(err, auth.ErrNicknameTagsExhausted) {
		t.Fatalf("exhausted = %v", err)
	}
	profile, err = service.GetAccountProfile(ctx, next)
	if err != nil || profile.Nickname != nil {
		t.Fatalf("exhausted modified account = %+v %v", profile, err)
	}
	if _, err := service.SetNickname(ctx, next, "n"+nickname[1:]); err != nil {
		t.Fatalf("case-sensitive identity = %v", err)
	}
}

func TestNicknameDatabaseConstraints(t *testing.T) {
	ctx, pool := openTestPool(t)
	for _, tc := range []struct{ nickname, tag any }{
		{"가", "0000"}, {"가나다라마바사아자", "0000"}, {"abcdefghijklmnopq", "0000"},
		{"ab ", "0000"}, {"a b", "0000"}, {"ab#", "0000"}, {"ㄱㄴ", "0000"},
		{"ab", nil}, {nil, "0000"}, {"ab", "000"}, {"ab", "00000"}, {"ab", "abcd"},
	} {
		_, err := pool.Exec(ctx, "INSERT INTO accounts (nickname,nickname_tag) VALUES ($1,$2)", tc.nickname, tc.tag)
		requirePostgresError(t, err, checkViolation, "accounts_nickname_pair_check")
	}
	nickname := fmt.Sprintf("N%x", time.Now().UnixNano()%0xffffffffff)
	t.Cleanup(func() { _, _ = pool.Exec(context.Background(), "DELETE FROM accounts WHERE nickname=$1", nickname) })
	if _, err := pool.Exec(ctx, "INSERT INTO accounts (nickname,nickname_tag) VALUES ($1,'0000')", nickname); err != nil {
		t.Fatal(err)
	}
	_, err := pool.Exec(ctx, "INSERT INTO accounts (nickname,nickname_tag) VALUES ($1,'0000')", nickname)
	requirePostgresError(t, err, uniqueViolation, "accounts_nickname_tag_key")
}

func TestNicknameHTTPGateReadsCurrentDatabaseState(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := auth.NewService(pool, fixedGoogleVerifier{subject: fmt.Sprintf("nickname-http-%d", time.Now().UnixNano())}, time.Second, time.Minute, time.Hour)
	login, err := service.AuthenticateGoogle(ctx, "test")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), "DELETE FROM accounts WHERE id::text=$1", login.AccountID)
	})
	handler := httpapi.NewHandler(slog.New(slog.NewTextHandler(io.Discard, nil)), httpapi.Dependencies{Authenticator: service, SaveService: gamesave.NewService(pool)})
	for _, tc := range []struct {
		method, path, body, contains string
		status                       int
	}{
		{"GET", "/v1/save", "", "NICKNAME_REQUIRED", 403},
		{"GET", "/v1/account/profile", "", `"nickname":null`, 200},
		{"PUT", "/v1/account/nickname", `{"nickname":"룬기사"}`, `"nickname":"룬기사"`, 200},
		{"GET", "/v1/save", "", "SAVE_NOT_FOUND", 404},
	} {
		request := httptest.NewRequest(tc.method, tc.path, strings.NewReader(tc.body))
		request.Header.Set("Authorization", "Bearer "+login.AccessToken)
		request.Header.Set("Content-Type", "application/json")
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, request)
		if response.Code != tc.status || !strings.Contains(response.Body.String(), tc.contains) {
			t.Fatalf("%s %s: %d %s", tc.method, tc.path, response.Code, response.Body.String())
		}
	}
}
