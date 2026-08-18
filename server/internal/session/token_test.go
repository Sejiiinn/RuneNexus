package session

import (
	"crypto/sha256"
	"encoding/base64"
	"testing"
)

func TestGenerateTokenReturnsOpaqueTokenAndHash(t *testing.T) {
	token, err := GenerateToken()
	if err != nil {
		t.Fatalf("GenerateToken() error = %v", err)
	}

	rawBytes, err := base64.RawURLEncoding.DecodeString(token.Raw)
	if err != nil {
		t.Fatalf("decode raw token: %v", err)
	}
	if len(rawBytes) != tokenByteLength {
		t.Fatalf("raw token byte length = %d", len(rawBytes))
	}

	wantHash := sha256.Sum256([]byte(token.Raw))
	if string(token.Hash) != string(wantHash[:]) {
		t.Fatal("token hash does not match raw token")
	}
}

func TestGenerateTokenReturnsUniqueValues(t *testing.T) {
	first, err := GenerateToken()
	if err != nil {
		t.Fatalf("first GenerateToken() error = %v", err)
	}
	second, err := GenerateToken()
	if err != nil {
		t.Fatalf("second GenerateToken() error = %v", err)
	}
	if first.Raw == second.Raw {
		t.Fatal("GenerateToken() returned duplicate values")
	}
}

func TestHashTokenAcceptsGeneratedToken(t *testing.T) {
	token, err := GenerateToken()
	if err != nil {
		t.Fatalf("GenerateToken() error = %v", err)
	}

	hash, err := HashToken(token.Raw)
	if err != nil {
		t.Fatalf("HashToken() error = %v", err)
	}
	if string(hash) != string(token.Hash) {
		t.Fatal("HashToken() returned a different hash")
	}
}

func TestHashTokenRejectsMalformedToken(t *testing.T) {
	for _, raw := range []string{"", "not-base64!", base64.RawURLEncoding.EncodeToString(make([]byte, tokenByteLength-1))} {
		if _, err := HashToken(raw); err == nil {
			t.Fatalf("HashToken(%q) unexpectedly succeeded", raw)
		}
	}
}
