//go:build integration

package dbtest_test

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	"github.com/jackc/pgx/v5/pgxpool"
)

type fixedGoogleVerifier struct {
	subject string
}

func (verifier fixedGoogleVerifier) Verify(
	context.Context,
	string,
) (auth.VerifiedIdentity, error) {
	return auth.VerifiedIdentity{Subject: verifier.subject}, nil
}

func TestGoogleAuthenticationCreatesOneAccountAndRotatingSessions(t *testing.T) {
	ctx, pool := openTestPool(t)
	subject := fmt.Sprintf("integration-%d", time.Now().UnixNano())
	service := auth.NewService(
		pool,
		fixedGoogleVerifier{subject: subject},
		2*time.Second,
		15*time.Minute,
		30*24*time.Hour,
	)

	first, err := service.AuthenticateGoogle(ctx, "first-id-token")
	if err != nil {
		t.Fatalf("first AuthenticateGoogle(): %v", err)
	}
	t.Cleanup(func() {
		cleanupContext, cancel := context.WithTimeout(
			context.Background(),
			testDatabaseTimeout,
		)
		defer cancel()
		if _, err := pool.Exec(
			cleanupContext,
			"DELETE FROM accounts WHERE id = $1",
			first.AccountID,
		); err != nil {
			t.Errorf("delete authentication test account: %v", err)
		}
	})

	second, err := service.AuthenticateGoogle(ctx, "second-id-token")
	if err != nil {
		t.Fatalf("second AuthenticateGoogle(): %v", err)
	}
	if second.AccountID != first.AccountID {
		t.Fatalf("account IDs differ: %q != %q", second.AccountID, first.AccountID)
	}
	if second.AccessToken == first.AccessToken || second.RefreshToken == first.RefreshToken {
		t.Fatal("repeated login reused an opaque token")
	}

	var accountCount, identityCount, sessionCount, refreshTokenCount int
	if err := pool.QueryRow(
		ctx,
		"SELECT count(*) FROM accounts WHERE id = $1",
		first.AccountID,
	).Scan(&accountCount); err != nil {
		t.Fatalf("count accounts: %v", err)
	}
	if err := pool.QueryRow(
		ctx,
		`SELECT count(*)
         FROM auth_identities
        WHERE provider = 'google' AND subject = $1`,
		subject,
	).Scan(&identityCount); err != nil {
		t.Fatalf("count identities: %v", err)
	}
	if err := pool.QueryRow(
		ctx,
		"SELECT count(*) FROM sessions WHERE account_id = $1",
		first.AccountID,
	).Scan(&sessionCount); err != nil {
		t.Fatalf("count sessions: %v", err)
	}
	if err := pool.QueryRow(
		ctx,
		`SELECT count(*)
         FROM refresh_tokens AS token
         JOIN sessions AS session ON session.id = token.session_id
        WHERE session.account_id = $1`,
		first.AccountID,
	).Scan(&refreshTokenCount); err != nil {
		t.Fatalf("count refresh tokens: %v", err)
	}

	if accountCount != 1 || identityCount != 1 ||
		sessionCount != 2 || refreshTokenCount != 2 {
		t.Fatalf(
			"counts = account:%d identity:%d session:%d refresh:%d",
			accountCount,
			identityCount,
			sessionCount,
			refreshTokenCount,
		)
	}

	accessHash := sha256.Sum256([]byte(first.AccessToken))
	var storedAccessTokenCount int
	if err := pool.QueryRow(
		ctx,
		"SELECT count(*) FROM sessions WHERE access_token_hash = $1",
		accessHash[:],
	).Scan(&storedAccessTokenCount); err != nil {
		t.Fatalf("find stored access token hash: %v", err)
	}
	if storedAccessTokenCount != 1 {
		t.Fatalf("stored access token hash count = %d", storedAccessTokenCount)
	}

	var rawTokenStored bool
	if err := pool.QueryRow(
		ctx,
		`SELECT EXISTS (
           SELECT 1
             FROM sessions
            WHERE encode(access_token_hash, 'escape') = $1
         )`,
		first.AccessToken,
	).Scan(&rawTokenStored); err != nil {
		t.Fatalf("check raw access token storage: %v", err)
	}
	if rawTokenStored {
		t.Fatal("raw access token was stored in the database")
	}
}

func TestSessionRefreshRotatesTokensAndReplayRevokesSession(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := auth.NewService(
		pool,
		fixedGoogleVerifier{subject: fmt.Sprintf("refresh-%d", time.Now().UnixNano())},
		2*time.Second,
		15*time.Minute,
		30*24*time.Hour,
	)
	login, err := service.AuthenticateGoogle(ctx, "id-token")
	if err != nil {
		t.Fatalf("AuthenticateGoogle(): %v", err)
	}
	cleanupAuthenticationAccount(t, pool, login.AccountID)

	rotated, err := service.Refresh(ctx, login.RefreshToken)
	if err != nil {
		t.Fatalf("Refresh(): %v", err)
	}
	if rotated.AccountID != login.AccountID ||
		rotated.AccessToken == login.AccessToken ||
		rotated.RefreshToken == login.RefreshToken {
		t.Fatalf("unexpected rotated credentials: %#v", rotated)
	}
	if difference := rotated.RefreshExpiresAt.Sub(login.RefreshExpiresAt); difference < -time.Microsecond || difference > time.Microsecond {
		t.Fatalf("refresh expiry changed by %v", difference)
	}
	if _, err := service.AuthenticateAccessToken(ctx, login.AccessToken); !errors.Is(err, auth.ErrAccessTokenInvalid) {
		t.Fatalf("old access token error = %v", err)
	}
	principal, err := service.AuthenticateAccessToken(ctx, rotated.AccessToken)
	if err != nil {
		t.Fatalf("AuthenticateAccessToken(rotated): %v", err)
	}
	if principal.AccountID != login.AccountID || principal.SessionID == "" {
		t.Fatalf("principal = %#v", principal)
	}

	if _, err := service.Refresh(ctx, login.RefreshToken); !errors.Is(err, auth.ErrRefreshTokenReused) {
		t.Fatalf("replayed Refresh() error = %v", err)
	}
	if _, err := service.AuthenticateAccessToken(ctx, rotated.AccessToken); !errors.Is(err, auth.ErrAccessTokenInvalid) {
		t.Fatalf("access after replay error = %v", err)
	}
	if _, err := service.Refresh(ctx, rotated.RefreshToken); !errors.Is(err, auth.ErrRefreshTokenInvalid) {
		t.Fatalf("child refresh after replay error = %v", err)
	}

	var sessionRevoked, allTokensRevoked bool
	if err := pool.QueryRow(
		ctx,
		`SELECT session.revoked_at IS NOT NULL,
                bool_and(token.revoked_at IS NOT NULL)
           FROM sessions AS session
           JOIN refresh_tokens AS token ON token.session_id = session.id
          WHERE session.account_id = $1
          GROUP BY session.id`,
		login.AccountID,
	).Scan(&sessionRevoked, &allTokensRevoked); err != nil {
		t.Fatalf("query replay revocation: %v", err)
	}
	if !sessionRevoked || !allTokensRevoked {
		t.Fatalf("revoked session = %v, all tokens revoked = %v", sessionRevoked, allTokensRevoked)
	}
}

func TestLogoutIsIdempotentAndRevokesAccessToken(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := auth.NewService(
		pool,
		fixedGoogleVerifier{subject: fmt.Sprintf("logout-%d", time.Now().UnixNano())},
		2*time.Second,
		15*time.Minute,
		30*24*time.Hour,
	)
	login, err := service.AuthenticateGoogle(ctx, "id-token")
	if err != nil {
		t.Fatalf("AuthenticateGoogle(): %v", err)
	}
	cleanupAuthenticationAccount(t, pool, login.AccountID)

	if err := service.Logout(ctx, login.RefreshToken, login.AccessToken); err != nil {
		t.Fatalf("Logout(): %v", err)
	}
	if err := service.Logout(ctx, login.RefreshToken, login.AccessToken); err != nil {
		t.Fatalf("repeated Logout(): %v", err)
	}
	if err := service.Logout(ctx, "unknown-token", ""); err != nil {
		t.Fatalf("unknown token Logout(): %v", err)
	}
	if _, err := service.AuthenticateAccessToken(ctx, login.AccessToken); !errors.Is(err, auth.ErrAccessTokenInvalid) {
		t.Fatalf("access after logout error = %v", err)
	}
}

func TestLogoutRejectsTokensFromDifferentSessions(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := auth.NewService(
		pool,
		fixedGoogleVerifier{subject: fmt.Sprintf("logout-mismatch-%d", time.Now().UnixNano())},
		2*time.Second,
		15*time.Minute,
		30*24*time.Hour,
	)
	first, err := service.AuthenticateGoogle(ctx, "first-id-token")
	if err != nil {
		t.Fatalf("first AuthenticateGoogle(): %v", err)
	}
	cleanupAuthenticationAccount(t, pool, first.AccountID)
	second, err := service.AuthenticateGoogle(ctx, "second-id-token")
	if err != nil {
		t.Fatalf("second AuthenticateGoogle(): %v", err)
	}

	if err := service.Logout(
		ctx,
		first.RefreshToken,
		second.AccessToken,
	); !errors.Is(err, auth.ErrLogoutSessionMismatch) {
		t.Fatalf("mismatched Logout() error = %v", err)
	}
	if _, err := service.AuthenticateAccessToken(ctx, first.AccessToken); err != nil {
		t.Fatalf("first access token was revoked: %v", err)
	}
}

func cleanupAuthenticationAccount(
	t *testing.T,
	pool *pgxpool.Pool,
	accountID string,
) {
	t.Helper()
	t.Cleanup(func() {
		cleanupContext, cancel := context.WithTimeout(
			context.Background(),
			testDatabaseTimeout,
		)
		defer cancel()
		if _, err := pool.Exec(
			cleanupContext,
			"DELETE FROM accounts WHERE id = $1",
			accountID,
		); err != nil {
			t.Errorf("delete authentication test account: %v", err)
		}
	})
}

func openTestPool(t *testing.T) (context.Context, *pgxpool.Pool) {
	t.Helper()
	databaseURL := os.Getenv("RUNE_NEXUS_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("RUNE_NEXUS_TEST_DATABASE_URL is not set")
	}
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		t.Fatalf("parse test database URL: %v", err)
	}
	if passwordFile := os.Getenv("RUNE_NEXUS_TEST_DATABASE_PASSWORD_FILE"); passwordFile != "" {
		password, err := os.ReadFile(passwordFile)
		if err != nil {
			t.Fatalf("read test database password: %v", err)
		}
		config.ConnConfig.Password = strings.TrimSpace(string(password))
	}
	config.MaxConns = 4

	ctx, cancel := context.WithTimeout(context.Background(), testDatabaseTimeout)
	t.Cleanup(cancel)
	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatalf("create test database pool: %v", err)
	}
	t.Cleanup(pool.Close)
	if err := pool.Ping(ctx); err != nil {
		t.Fatalf("ping test database: %v", err)
	}
	return ctx, pool
}
