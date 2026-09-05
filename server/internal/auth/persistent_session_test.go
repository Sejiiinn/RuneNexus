package auth

import (
	"bytes"
	"context"
	"errors"
	"github.com/jackc/pgx/v5/pgtype"
	"testing"
)

func TestPersistentSessionConfigurationAndReceiptAuthentication(t *testing.T) {
	service := &Service{}
	if _, err := service.AuthenticateGooglePersistent(context.Background(), "id-token"); !errors.Is(err, ErrSessionPersistenceUnavailable) {
		t.Fatal(err)
	}
	if err := service.EnablePersistentSessions([]byte("short")); err == nil {
		t.Fatal("accepted short key")
	}
	if err := service.EnablePersistentSessions(bytes.Repeat([]byte{21}, 32)); err != nil {
		t.Fatal(err)
	}
	if _, err := service.RefreshPersistent(context.Background(), "token", "invalid"); !errors.Is(err, ErrRefreshRequestInvalid) {
		t.Fatal(err)
	}
	sessionID := pgtype.UUID{Bytes: [16]byte{1}, Valid: true}
	result := LoginResult{AccountID: "account", RefreshToken: "secret-refresh"}
	ciphertext, err := service.sealReceipt(result, sessionID, "request")
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(ciphertext, []byte(result.RefreshToken)) {
		t.Fatal("plaintext token in receipt")
	}
	recovered, err := service.openReceipt(ciphertext, sessionID, "request")
	if err != nil || recovered != result {
		t.Fatalf("receipt recovery: %v", err)
	}
	if _, err := service.openReceipt(ciphertext, sessionID, "another-request"); err == nil {
		t.Fatal("receipt not bound to request")
	}
	anotherSession := pgtype.UUID{Bytes: [16]byte{2}, Valid: true}
	if _, err := service.openReceipt(ciphertext, anotherSession, "request"); err == nil {
		t.Fatal("receipt not bound to session")
	}
	ciphertext[len(ciphertext)-1] ^= 1
	if _, err := service.openReceipt(ciphertext, sessionID, "request"); err == nil {
		t.Fatal("accepted tampered receipt")
	}
}
