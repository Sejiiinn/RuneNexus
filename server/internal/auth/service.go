package auth

import (
	"bytes"
	"context"
	"crypto/cipher"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/Sejiiinn/RuneNexus/server/internal/session"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

const googleProvider = "google"

var (
	ErrIdentityRejected      = errors.New("external identity rejected")
	ErrIdentityUnavailable   = errors.New("external identity provider unavailable")
	ErrAccountInactive       = errors.New("account is not active")
	ErrAccessTokenInvalid    = errors.New("access token is invalid")
	ErrRefreshTokenInvalid   = errors.New("refresh token is invalid")
	ErrRefreshTokenReused    = errors.New("refresh token was reused")
	ErrLogoutSessionMismatch = errors.New("logout tokens belong to different sessions")
)

type VerifiedIdentity struct {
	Subject string
}

type GoogleIdentityVerifier interface {
	Verify(context.Context, string) (VerifiedIdentity, error)
}

type LoginResult struct {
	AccountID        string
	AccessToken      string
	AccessExpiresAt  time.Time
	RefreshToken     string
	RefreshExpiresAt time.Time
}

type Principal struct {
	AccountID string
	SessionID string
}

type Service struct {
	database            *pgxpool.Pool
	googleVerifier      GoogleIdentityVerifier
	verificationTimeout time.Duration
	accessTokenTTL      time.Duration
	refreshTokenTTL     time.Duration
	receiptCipher       cipher.AEAD
}

func NewService(
	database *pgxpool.Pool,
	googleVerifier GoogleIdentityVerifier,
	verificationTimeout time.Duration,
	accessTokenTTL time.Duration,
	refreshTokenTTL time.Duration,
) *Service {
	return &Service{
		database:            database,
		googleVerifier:      googleVerifier,
		verificationTimeout: verificationTimeout,
		accessTokenTTL:      accessTokenTTL,
		refreshTokenTTL:     refreshTokenTTL,
	}
}

func (service *Service) AuthenticateGoogle(
	ctx context.Context,
	idToken string,
) (LoginResult, error) {
	return service.authenticateGoogle(ctx, idToken, false)
}

func (service *Service) authenticateGoogle(ctx context.Context, idToken string, persistent bool) (LoginResult, error) {
	verificationContext, cancel := context.WithTimeout(
		ctx,
		service.verificationTimeout,
	)
	defer cancel()

	identity, err := service.googleVerifier.Verify(verificationContext, idToken)
	if err != nil {
		return LoginResult{}, err
	}
	if identity.Subject == "" {
		return LoginResult{}, ErrIdentityRejected
	}

	accessToken, err := session.GenerateToken()
	if err != nil {
		return LoginResult{}, err
	}
	refreshToken, err := session.GenerateToken()
	if err != nil {
		return LoginResult{}, err
	}

	now := time.Now().UTC()
	accessExpiresAt := now.Add(service.accessTokenTTL)
	refreshExpiresAt := now.Add(service.refreshTokenTTL)
	if persistent {
		refreshExpiresAt = time.Time{}
	}

	tx, err := service.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return LoginResult{}, fmt.Errorf("begin authentication transaction: %w", err)
	}
	defer func() {
		_ = tx.Rollback(ctx)
	}()

	queries := dbgen.New(tx)
	if err := queries.LockAuthIdentity(ctx, dbgen.LockAuthIdentityParams{
		Provider: googleProvider,
		Subject:  identity.Subject,
	}); err != nil {
		return LoginResult{}, fmt.Errorf("lock external identity: %w", err)
	}

	account, err := findOrCreateAccount(ctx, queries, identity.Subject)
	if err != nil {
		return LoginResult{}, err
	}
	if account.Status != "active" {
		return LoginResult{}, ErrAccountInactive
	}
	accountID, err := formatUUID(account.ID)
	if err != nil {
		return LoginResult{}, err
	}

	databaseSession, err := queries.CreateSession(ctx, dbgen.CreateSessionParams{
		AccountID:       account.ID,
		AccessTokenHash: accessToken.Hash,
		AccessExpiresAt: pgtype.Timestamptz{
			Time:  accessExpiresAt,
			Valid: true,
		},
		RefreshExpiresAt: pgtype.Timestamptz{
			Time:  refreshExpiresAt,
			Valid: !persistent,
		},
	})
	if err != nil {
		return LoginResult{}, fmt.Errorf("create session: %w", err)
	}
	if _, err := queries.CreateRefreshToken(ctx, dbgen.CreateRefreshTokenParams{
		SessionID: databaseSession.ID,
		TokenHash: refreshToken.Hash,
	}); err != nil {
		return LoginResult{}, fmt.Errorf("create refresh token: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return LoginResult{}, fmt.Errorf("commit authentication transaction: %w", err)
	}

	return LoginResult{
		AccountID:        accountID,
		AccessToken:      accessToken.Raw,
		AccessExpiresAt:  accessExpiresAt,
		RefreshToken:     refreshToken.Raw,
		RefreshExpiresAt: refreshExpiresAt,
	}, nil
}

func (service *Service) Refresh(
	ctx context.Context,
	rawRefreshToken string,
) (LoginResult, error) {
	return service.refresh(ctx, rawRefreshToken, "")
}

func (service *Service) refresh(ctx context.Context, rawRefreshToken, requestKey string) (LoginResult, error) {
	refreshTokenHash, err := session.HashToken(rawRefreshToken)
	if err != nil {
		return LoginResult{}, ErrRefreshTokenInvalid
	}

	tx, err := service.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return LoginResult{}, fmt.Errorf("begin refresh transaction: %w", err)
	}
	defer func() {
		_ = tx.Rollback(ctx)
	}()

	queries := dbgen.New(tx)
	// 세션 먼저 잠금: 부모/자식 토큰 요청과 로그아웃의 잠금 순서 통일.
	if _, err := queries.LockRefreshSession(ctx, refreshTokenHash); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return LoginResult{}, ErrRefreshTokenInvalid
		}
		return LoginResult{}, fmt.Errorf("lock refresh session: %w", err)
	}
	storedToken, err := queries.GetRefreshTokenForUpdate(ctx, refreshTokenHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return LoginResult{}, ErrRefreshTokenInvalid
	}
	if err != nil {
		return LoginResult{}, fmt.Errorf("lock refresh token: %w", err)
	}

	if storedToken.AccountStatus != "active" {
		if err := revokeSession(ctx, queries, storedToken.SessionID); err != nil {
			return LoginResult{}, err
		}
		if err := tx.Commit(ctx); err != nil {
			return LoginResult{}, fmt.Errorf("commit inactive account revocation: %w", err)
		}
		return LoginResult{}, ErrAccountInactive
	}
	now := time.Now().UTC()
	if storedToken.RevokedAt.Valid || storedToken.SessionRevokedAt.Valid {
		return LoginResult{}, ErrRefreshTokenInvalid
	}
	if !storedToken.RefreshExpiresAt.Valid && requestKey == "" {
		return LoginResult{}, ErrRefreshTokenInvalid
	}
	if storedToken.RefreshExpiresAt.Valid && !storedToken.RefreshExpiresAt.Time.After(now) {
		if err := revokeSession(ctx, queries, storedToken.SessionID); err != nil {
			return LoginResult{}, err
		}
		if err := tx.Commit(ctx); err != nil {
			return LoginResult{}, fmt.Errorf("commit expired session revocation: %w", err)
		}
		return LoginResult{}, ErrRefreshTokenInvalid
	}
	if requestKey != "" {
		receipt, err := queries.GetRefreshReceipt(ctx, dbgen.GetRefreshReceiptParams{SessionID: storedToken.SessionID, RequestKey: requestKey})
		if err == nil {
			if storedToken.ID != receipt.ParentTokenID && storedToken.ID != receipt.ChildTokenID {
				return LoginResult{}, ErrRefreshRequestConflict
			}
			if !receipt.ExpiresAt.Time.After(now) || len(receipt.Ciphertext) == 0 {
				return LoginResult{}, ErrRefreshRecoveryExpired
			}
			result, err := service.openReceipt(receipt.Ciphertext, storedToken.SessionID, requestKey)
			if err != nil {
				return LoginResult{}, err
			}
			// 이후 회전된 세션의 옛 access token을 복구하지 않음.
			accessHash, hashErr := session.HashToken(result.AccessToken)
			if hashErr != nil || !bytes.Equal(storedToken.AccessTokenHash, accessHash) || !result.AccessExpiresAt.After(now) {
				return LoginResult{}, ErrRefreshRecoveryExpired
			}
			return result, nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return LoginResult{}, fmt.Errorf("get refresh receipt: %w", err)
		}
	}
	if storedToken.ConsumedAt.Valid {
		if err := revokeSession(ctx, queries, storedToken.SessionID); err != nil {
			return LoginResult{}, err
		}
		if err := tx.Commit(ctx); err != nil {
			return LoginResult{}, fmt.Errorf("commit reused token revocation: %w", err)
		}
		return LoginResult{}, ErrRefreshTokenReused
	}

	accessToken, err := session.GenerateToken()
	if err != nil {
		return LoginResult{}, err
	}
	refreshToken, err := session.GenerateToken()
	if err != nil {
		return LoginResult{}, err
	}
	accessExpiresAt := now.Add(service.accessTokenTTL)
	refreshExpiresAt := storedToken.RefreshExpiresAt.Time.UTC()
	if storedToken.RefreshExpiresAt.Valid && !accessExpiresAt.Before(refreshExpiresAt) {
		accessExpiresAt = refreshExpiresAt.Add(-time.Nanosecond)
	}
	if !accessExpiresAt.After(now) {
		if err := revokeSession(ctx, queries, storedToken.SessionID); err != nil {
			return LoginResult{}, err
		}
		if err := tx.Commit(ctx); err != nil {
			return LoginResult{}, fmt.Errorf("commit exhausted session revocation: %w", err)
		}
		return LoginResult{}, ErrRefreshTokenInvalid
	}

	if _, err := queries.ConsumeRefreshToken(ctx, storedToken.ID); err != nil {
		return LoginResult{}, fmt.Errorf("consume refresh token: %w", err)
	}
	childToken, err := queries.CreateRefreshToken(ctx, dbgen.CreateRefreshTokenParams{
		SessionID:     storedToken.SessionID,
		TokenHash:     refreshToken.Hash,
		ParentTokenID: storedToken.ID,
	})
	if err != nil {
		return LoginResult{}, fmt.Errorf("create rotated refresh token: %w", err)
	}
	if _, err := queries.RotateSessionAccessToken(ctx, dbgen.RotateSessionAccessTokenParams{
		ID:              storedToken.SessionID,
		AccessTokenHash: accessToken.Hash,
		AccessExpiresAt: pgtype.Timestamptz{Time: accessExpiresAt, Valid: true},
	}); err != nil {
		return LoginResult{}, fmt.Errorf("rotate access token: %w", err)
	}

	accountID, err := formatUUID(storedToken.AccountID)
	if err != nil {
		return LoginResult{}, err
	}
	result := LoginResult{
		AccountID:        accountID,
		AccessToken:      accessToken.Raw,
		AccessExpiresAt:  accessExpiresAt,
		RefreshToken:     refreshToken.Raw,
		RefreshExpiresAt: refreshExpiresAt,
	}
	if requestKey != "" {
		ciphertext, err := service.sealReceipt(result, storedToken.SessionID, requestKey)
		if err != nil {
			return LoginResult{}, err
		}
		if err := queries.CreateRefreshReceipt(ctx, dbgen.CreateRefreshReceiptParams{
			SessionID: storedToken.SessionID, RequestKey: requestKey,
			ParentTokenID: storedToken.ID, ChildTokenID: childToken.ID,
			Ciphertext: ciphertext, ExpiresAt: pgtype.Timestamptz{Time: now.Add(10 * time.Minute), Valid: true},
		}); err != nil {
			return LoginResult{}, fmt.Errorf("create refresh receipt: %w", err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return LoginResult{}, fmt.Errorf("commit refresh transaction: %w", err)
	}
	return result, nil
}

func (service *Service) Logout(
	ctx context.Context,
	rawRefreshToken string,
	rawAccessToken string,
) error {
	refreshTokenHash, err := session.HashToken(rawRefreshToken)
	if err != nil {
		return nil
	}

	tx, err := service.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("begin logout transaction: %w", err)
	}
	defer func() {
		_ = tx.Rollback(ctx)
	}()

	queries := dbgen.New(tx)
	if _, err := queries.LockRefreshSession(ctx, refreshTokenHash); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		return fmt.Errorf("lock logout session: %w", err)
	}
	storedToken, err := queries.GetRefreshTokenForUpdate(ctx, refreshTokenHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("lock logout refresh token: %w", err)
	}
	if rawAccessToken != "" {
		accessTokenHash, hashErr := session.HashToken(rawAccessToken)
		if hashErr == nil {
			accessSession, accessErr := queries.GetActiveSessionByAccessTokenHash(
				ctx,
				accessTokenHash,
			)
			if accessErr == nil && accessSession.ID != storedToken.SessionID {
				return ErrLogoutSessionMismatch
			}
			if accessErr != nil && !errors.Is(accessErr, pgx.ErrNoRows) {
				return fmt.Errorf("validate logout access token: %w", accessErr)
			}
		}
	}
	if err := revokeSession(ctx, queries, storedToken.SessionID); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit logout transaction: %w", err)
	}
	return nil
}

func (service *Service) AuthenticateAccessToken(
	ctx context.Context,
	rawAccessToken string,
) (Principal, error) {
	accessTokenHash, err := session.HashToken(rawAccessToken)
	if err != nil {
		return Principal{}, ErrAccessTokenInvalid
	}

	queries := dbgen.New(service.database)
	storedSession, err := queries.GetActiveSessionByAccessTokenHash(
		ctx,
		accessTokenHash,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Principal{}, ErrAccessTokenInvalid
	}
	if err != nil {
		return Principal{}, fmt.Errorf("get active session: %w", err)
	}
	accountID, err := formatUUID(storedSession.AccountID)
	if err != nil {
		return Principal{}, err
	}
	sessionID, err := formatUUID(storedSession.ID)
	if err != nil {
		return Principal{}, err
	}
	if err := queries.TouchSession(ctx, storedSession.ID); err != nil {
		return Principal{}, fmt.Errorf("touch active session: %w", err)
	}
	return Principal{AccountID: accountID, SessionID: sessionID}, nil
}

func revokeSession(
	ctx context.Context,
	queries *dbgen.Queries,
	sessionID pgtype.UUID,
) error {
	if _, err := queries.RevokeRefreshTokensForSession(ctx, sessionID); err != nil {
		return fmt.Errorf("revoke session refresh tokens: %w", err)
	}
	if _, err := queries.RevokeSession(ctx, sessionID); err != nil {
		return fmt.Errorf("revoke session: %w", err)
	}
	return nil
}

func findOrCreateAccount(
	ctx context.Context,
	queries *dbgen.Queries,
	subject string,
) (dbgen.Account, error) {
	identity, err := queries.GetAuthIdentityForUpdate(
		ctx,
		dbgen.GetAuthIdentityForUpdateParams{
			Provider: googleProvider,
			Subject:  subject,
		},
	)
	if err == nil {
		if _, err := queries.TouchAuthIdentity(ctx, identity.ID); err != nil {
			return dbgen.Account{}, fmt.Errorf("touch external identity: %w", err)
		}
		account, err := queries.GetAccount(ctx, identity.AccountID)
		if err != nil {
			return dbgen.Account{}, fmt.Errorf("get account: %w", err)
		}
		return account, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return dbgen.Account{}, fmt.Errorf("get external identity: %w", err)
	}

	account, err := queries.CreateAccount(ctx)
	if err != nil {
		return dbgen.Account{}, fmt.Errorf("create account: %w", err)
	}
	if _, err := queries.CreateAuthIdentity(ctx, dbgen.CreateAuthIdentityParams{
		AccountID: account.ID,
		Provider:  googleProvider,
		Subject:   subject,
	}); err != nil {
		return dbgen.Account{}, fmt.Errorf("create external identity: %w", err)
	}
	return account, nil
}

func formatUUID(value pgtype.UUID) (string, error) {
	if !value.Valid {
		return "", errors.New("account UUID is invalid")
	}
	digits := hex.EncodeToString(value.Bytes[:])
	return digits[:8] + "-" + digits[8:12] + "-" + digits[12:16] + "-" +
		digits[16:20] + "-" + digits[20:], nil
}
