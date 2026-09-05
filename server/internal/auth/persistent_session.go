package auth

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5/pgtype"
)

var (
	ErrSessionPersistenceUnavailable = errors.New("persistent sessions are not configured")
	ErrRefreshRecoveryExpired        = errors.New("refresh recovery receipt expired")
	ErrRefreshRequestConflict        = errors.New("refresh request key conflicts with token")
	ErrRefreshRequestInvalid         = errors.New("refresh request key invalid")
	requestKeyPattern                = regexp.MustCompile(`^(?:[A-Za-z0-9_-]{43}|[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})$`)
)

// EnablePersistentSessions는 모든 API 인스턴스가 공유하는 고정 키로 활성화.
func (service *Service) EnablePersistentSessions(key []byte) error {
	if len(key) != 32 {
		return errors.New("session receipt key must contain 32 bytes")
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return err
	}
	service.receiptCipher, err = cipher.NewGCM(block)
	return err
}

func (service *Service) AuthenticateGooglePersistent(ctx context.Context, idToken string) (LoginResult, error) {
	if service.receiptCipher == nil {
		return LoginResult{}, ErrSessionPersistenceUnavailable
	}
	return service.authenticateGoogle(ctx, idToken, true)
}

func (service *Service) RefreshPersistent(ctx context.Context, token, requestKey string) (LoginResult, error) {
	if service.receiptCipher == nil {
		return LoginResult{}, ErrSessionPersistenceUnavailable
	}
	if !requestKeyPattern.MatchString(requestKey) {
		return LoginResult{}, ErrRefreshRequestInvalid
	}
	return service.refresh(ctx, token, requestKey)
}

func (service *Service) ClearExpiredRefreshReceipts(ctx context.Context) error {
	return dbgen.New(service.database).ClearExpiredRefreshReceipts(ctx)
}

func (service *Service) sealReceipt(result LoginResult, sessionID pgtype.UUID, requestKey string) ([]byte, error) {
	plaintext, err := json.Marshal(result)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, service.receiptCipher.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, err
	}
	// 세션과 요청을 AEAD 추가 인증 데이터에 결합.
	aad := base64.RawURLEncoding.EncodeToString(sessionID.Bytes[:]) + ":" + requestKey
	return service.receiptCipher.Seal(nonce, nonce, plaintext, []byte(aad)), nil
}

func (service *Service) openReceipt(ciphertext []byte, sessionID pgtype.UUID, requestKey string) (LoginResult, error) {
	size := service.receiptCipher.NonceSize()
	if len(ciphertext) < size {
		return LoginResult{}, ErrRefreshRecoveryExpired
	}
	aad := base64.RawURLEncoding.EncodeToString(sessionID.Bytes[:]) + ":" + requestKey
	plaintext, err := service.receiptCipher.Open(nil, ciphertext[:size], ciphertext[size:], []byte(aad))
	if err != nil {
		return LoginResult{}, fmt.Errorf("decrypt refresh receipt: %w", err)
	}
	var result LoginResult
	if err := json.Unmarshal(plaintext, &result); err != nil {
		return LoginResult{}, fmt.Errorf("decode refresh receipt: %w", err)
	}
	return result, nil
}
