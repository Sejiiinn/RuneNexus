//go:build integration

package dbtest_test

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
)

func TestPersistentSessionRecoveryAndRevocation(t *testing.T) {
	ctx, pool := openTestPool(t)
	subject := fmt.Sprintf("persistent-%d", time.Now().UnixNano())
	newService := func(accessTTL time.Duration) *auth.Service {
		service := auth.NewService(pool, fixedGoogleVerifier{subject: subject}, time.Second, accessTTL, 30*24*time.Hour)
		if err := service.EnablePersistentSessions(bytes.Repeat([]byte{71}, 32)); err != nil {
			t.Fatal(err)
		}
		return service
	}
	service := newService(15 * time.Minute)
	login, err := service.AuthenticateGooglePersistent(ctx, "id-token")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, err := pool.Exec(context.Background(), "DELETE FROM accounts WHERE id=$1", login.AccountID)
		if err != nil {
			t.Error(err)
		}
	})
	if !login.RefreshExpiresAt.IsZero() {
		t.Fatal("persistent session has expiry")
	}
	const key = "00112233-4455-6677-8899-aabbccddeeff"
	first, err := newService(time.Millisecond).RefreshPersistent(ctx, login.RefreshToken, key)
	if err != nil {
		t.Fatal(err)
	}
	// 업데이트 전 10분 제한이 기록된 receipt도 최신 child가 유효하면 보존.
	if _, err := pool.Exec(ctx, "UPDATE refresh_receipts SET expires_at=now()-interval '2 days' WHERE request_key=$1", key); err != nil {
		t.Fatal(err)
	}
	if err := service.ClearExpiredRefreshReceipts(ctx); err != nil {
		t.Fatal(err)
	}
	time.Sleep(time.Until(first.AccessExpiresAt) + time.Millisecond)
	// 서버 재시작·만료 access·쿠키가 먼저 교체된 응답 유실 모두 exact 복구.
	restarted := newService(15 * time.Minute)
	for _, token := range []string{login.RefreshToken, first.RefreshToken} {
		replay, err := restarted.RefreshPersistent(ctx, token, key)
		if err != nil {
			t.Fatal(err)
		}
		if replay != first {
			t.Fatal("replay did not recover exact result")
		}
	}
	if _, err := service.AuthenticateAccessToken(ctx, first.AccessToken); !errors.Is(err, auth.ErrAccessTokenInvalid) {
		t.Fatalf("recovery extended expired access: %v", err)
	}
	second, err := restarted.RefreshPersistent(ctx, first.RefreshToken, "11112233-4455-6677-8899-aabbccddeeff")
	if err != nil {
		t.Fatal(err)
	}
	// 다음 회전 후 옛 응답은 복구하지 않으며 현재 세션도 폐기하지 않음.
	for _, token := range []string{login.RefreshToken, first.RefreshToken} {
		if _, err := restarted.RefreshPersistent(ctx, token, key); !errors.Is(err, auth.ErrRefreshRecoveryExpired) {
			t.Fatalf("superseded recovery: %v", err)
		}
	}
	if _, err := restarted.AuthenticateAccessToken(ctx, second.AccessToken); err != nil {
		t.Fatalf("old exact retry revoked current family: %v", err)
	}
	var ciphertext []byte
	if err := pool.QueryRow(ctx, "SELECT ciphertext FROM refresh_receipts WHERE request_key=$1", key).Scan(&ciphertext); err != nil || ciphertext != nil {
		t.Fatalf("superseded ciphertext cleanup: %v", err)
	}
	var retained int
	if err := pool.QueryRow(ctx, "SELECT count(*) FROM refresh_receipts WHERE session_id=(SELECT id FROM sessions WHERE account_id=$1) AND ciphertext IS NOT NULL", login.AccountID).Scan(&retained); err != nil || retained != 1 {
		t.Fatalf("expected only latest ciphertext, got %d: %v", retained, err)
	}
	if _, err := service.RefreshPersistent(ctx, login.RefreshToken, "22112233-4455-6677-8899-aabbccddeeff"); !errors.Is(err, auth.ErrRefreshTokenReused) {
		t.Fatalf("foreign replay: %v", err)
	}
	if _, err := service.AuthenticateAccessToken(ctx, second.AccessToken); !errors.Is(err, auth.ErrAccessTokenInvalid) {
		t.Fatalf("revoked access: %v", err)
	}
	if _, err := service.RefreshPersistent(ctx, second.RefreshToken, "11112233-4455-6677-8899-aabbccddeeff"); !errors.Is(err, auth.ErrRefreshTokenInvalid) {
		t.Fatalf("receipt bypassed revocation: %v", err)
	}
}

func TestPersistentConcurrentRefreshAndLogout(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := auth.NewService(pool, fixedGoogleVerifier{subject: fmt.Sprintf("concurrent-persistent-%d", time.Now().UnixNano())}, time.Second, 15*time.Minute, 30*24*time.Hour)
	if err := service.EnablePersistentSessions(bytes.Repeat([]byte{19}, 32)); err != nil {
		t.Fatal(err)
	}
	login, err := service.AuthenticateGooglePersistent(ctx, "id-token")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, err := pool.Exec(context.Background(), "DELETE FROM accounts WHERE id=$1", login.AccountID)
		if err != nil {
			t.Error(err)
		}
	})
	const key = "33112233-4455-6677-8899-aabbccddeeff"
	results := make([]auth.LoginResult, 8)
	errs := make([]error, len(results))
	var wg sync.WaitGroup
	for i := range results {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			results[i], errs[i] = service.RefreshPersistent(ctx, login.RefreshToken, key)
		}(i)
	}
	wg.Wait()
	for i := range results {
		if errs[i] != nil {
			t.Fatal(errs[i])
		}
		if results[i] != results[0] {
			t.Fatal("concurrent requests diverged")
		}
	}
	if err := service.Logout(ctx, login.RefreshToken, results[0].AccessToken); err != nil {
		t.Fatal(err)
	}
	if _, err := service.RefreshPersistent(ctx, results[0].RefreshToken, key); !errors.Is(err, auth.ErrRefreshTokenInvalid) {
		t.Fatalf("logout replay: %v", err)
	}
	var retained int
	if err := pool.QueryRow(ctx, "SELECT count(*) FROM refresh_receipts WHERE request_key=$1 AND ciphertext IS NOT NULL", key).Scan(&retained); err != nil || retained != 0 {
		t.Fatalf("logout retained ciphertext: %v", err)
	}
}

func TestPersistentSessionActivityAndAccountStatus(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := auth.NewService(pool, fixedGoogleVerifier{subject: fmt.Sprintf("persistent-status-%d", time.Now().UnixNano())}, time.Second, 15*time.Minute, 30*24*time.Hour)
	if err := service.EnablePersistentSessions(bytes.Repeat([]byte{27}, 32)); err != nil {
		t.Fatal(err)
	}
	login, err := service.AuthenticateGooglePersistent(ctx, "id-token")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, err := pool.Exec(context.Background(), "DELETE FROM accounts WHERE id=$1", login.AccountID)
		if err != nil {
			t.Error(err)
		}
	})
	activity := func() time.Time {
		var value time.Time
		if err := pool.QueryRow(ctx, "SELECT last_used_at FROM sessions WHERE account_id=$1", login.AccountID).Scan(&value); err != nil {
			t.Fatal(err)
		}
		return value
	}
	before := activity()
	if _, err := service.AuthenticateAccessToken(ctx, login.AccessToken); err != nil {
		t.Fatal(err)
	}
	if !activity().Equal(before) {
		t.Fatal("recent request wrote last_used_at")
	}
	if _, err := pool.Exec(ctx, "UPDATE sessions SET last_used_at=now()-interval '6 minutes' WHERE account_id=$1", login.AccountID); err != nil {
		t.Fatal(err)
	}
	before = activity()
	if _, err := service.AuthenticateAccessToken(ctx, login.AccessToken); err != nil {
		t.Fatal(err)
	}
	if !activity().After(before) {
		t.Fatal("stale last_used_at not updated")
	}
	const key = "44112233-4455-6677-8899-aabbccddeeff"
	refreshed, err := service.RefreshPersistent(ctx, login.RefreshToken, key)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, "UPDATE accounts SET status='suspended' WHERE id=$1", login.AccountID); err != nil {
		t.Fatal(err)
	}
	if _, err := service.RefreshPersistent(ctx, refreshed.RefreshToken, key); !errors.Is(err, auth.ErrAccountInactive) {
		t.Fatalf("receipt bypassed account suspension: %v", err)
	}
}
