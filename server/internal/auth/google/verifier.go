package google

import (
	"context"
	"errors"
	"fmt"
	"net"
	"strings"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	"google.golang.org/api/idtoken"
)

type payloadValidator interface {
	Validate(context.Context, string, string) (*idtoken.Payload, error)
}

type Verifier struct {
	validator payloadValidator
	audience  string
}

func NewVerifier(ctx context.Context, audience string) (*Verifier, error) {
	validator, err := idtoken.NewValidator(ctx)
	if err != nil {
		return nil, fmt.Errorf("create Google ID token validator: %w", err)
	}
	return &Verifier{
		validator: validator,
		audience:  audience,
	}, nil
}

func (verifier *Verifier) Verify(
	ctx context.Context,
	rawToken string,
) (auth.VerifiedIdentity, error) {
	if strings.TrimSpace(rawToken) == "" {
		return auth.VerifiedIdentity{}, auth.ErrIdentityRejected
	}

	payload, err := verifier.validator.Validate(ctx, rawToken, verifier.audience)
	if err != nil {
		var networkError net.Error
		if errors.Is(err, context.DeadlineExceeded) || errors.As(err, &networkError) {
			return auth.VerifiedIdentity{}, fmt.Errorf(
				"%w: validate Google ID token",
				auth.ErrIdentityUnavailable,
			)
		}
		return auth.VerifiedIdentity{}, fmt.Errorf(
			"%w: validate Google ID token",
			auth.ErrIdentityRejected,
		)
	}

	if payload.Subject == "" || !isGoogleIssuer(payload.Issuer) {
		return auth.VerifiedIdentity{}, auth.ErrIdentityRejected
	}
	return auth.VerifiedIdentity{Subject: payload.Subject}, nil
}

func isGoogleIssuer(issuer string) bool {
	return issuer == "accounts.google.com" || issuer == "https://accounts.google.com"
}
