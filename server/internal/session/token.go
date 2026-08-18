package session

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
)

const tokenByteLength = 32

type Token struct {
	Raw  string
	Hash []byte
}

func GenerateToken() (Token, error) {
	rawBytes := make([]byte, tokenByteLength)
	if _, err := rand.Read(rawBytes); err != nil {
		return Token{}, fmt.Errorf("generate random token: %w", err)
	}

	raw := base64.RawURLEncoding.EncodeToString(rawBytes)
	hash := sha256.Sum256([]byte(raw))
	return Token{
		Raw:  raw,
		Hash: hash[:],
	}, nil
}

func HashToken(raw string) ([]byte, error) {
	rawBytes, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil || len(rawBytes) != tokenByteLength ||
		base64.RawURLEncoding.EncodeToString(rawBytes) != raw {
		return nil, errors.New("invalid opaque token")
	}
	hash := sha256.Sum256([]byte(raw))
	return hash[:], nil
}
