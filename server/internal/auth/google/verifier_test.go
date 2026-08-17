package google

import (
	"context"
	"errors"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	"google.golang.org/api/idtoken"
)

type payloadValidatorFunc func(context.Context, string, string) (*idtoken.Payload, error)

func (validate payloadValidatorFunc) Validate(
	ctx context.Context,
	rawToken string,
	audience string,
) (*idtoken.Payload, error) {
	return validate(ctx, rawToken, audience)
}

func TestVerifierReturnsGoogleSubject(t *testing.T) {
	verifier := Verifier{
		audience: "web-client-id",
		validator: payloadValidatorFunc(func(
			_ context.Context,
			rawToken string,
			audience string,
		) (*idtoken.Payload, error) {
			if rawToken != "id-token" || audience != "web-client-id" {
				t.Fatalf("Validate(%q, %q)", rawToken, audience)
			}
			return &idtoken.Payload{
				Issuer:  "https://accounts.google.com",
				Subject: "google-subject",
			}, nil
		}),
	}

	identity, err := verifier.Verify(context.Background(), "id-token")
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if identity.Subject != "google-subject" {
		t.Fatalf("Subject = %q", identity.Subject)
	}
}

func TestVerifierRejectsInvalidIssuer(t *testing.T) {
	verifier := Verifier{
		audience: "web-client-id",
		validator: payloadValidatorFunc(func(
			context.Context,
			string,
			string,
		) (*idtoken.Payload, error) {
			return &idtoken.Payload{
				Issuer:  "https://example.com",
				Subject: "subject",
			}, nil
		}),
	}

	_, err := verifier.Verify(context.Background(), "id-token")
	if !errors.Is(err, auth.ErrIdentityRejected) {
		t.Fatalf("Verify() error = %v", err)
	}
}

func TestVerifierRejectsEmptyTokenWithoutValidation(t *testing.T) {
	validatorCalled := false
	verifier := Verifier{
		audience: "web-client-id",
		validator: payloadValidatorFunc(func(
			context.Context,
			string,
			string,
		) (*idtoken.Payload, error) {
			validatorCalled = true
			return nil, errors.New("unexpected call")
		}),
	}

	_, err := verifier.Verify(context.Background(), "  ")
	if !errors.Is(err, auth.ErrIdentityRejected) {
		t.Fatalf("Verify() error = %v", err)
	}
	if validatorCalled {
		t.Fatal("validator was called for an empty token")
	}
}
