package httpapi

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
)

type authenticatedPrincipalContextKey struct{}

func withBearerAuthentication(
	logger *slog.Logger,
	authenticator Authenticator,
	next http.Handler,
) http.Handler {
	return http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		token, ok := bearerToken(request.Header.Values("Authorization"))
		if !ok {
			writeAPIError(
				response,
				request,
				http.StatusUnauthorized,
				"ACCESS_TOKEN_INVALID",
				"유효한 인증 토큰이 필요합니다.",
			)
			return
		}

		principal, err := authenticator.AuthenticateAccessToken(
			request.Context(),
			token,
		)
		if errors.Is(err, auth.ErrAccessTokenInvalid) {
			writeAPIError(
				response,
				request,
				http.StatusUnauthorized,
				"ACCESS_TOKEN_INVALID",
				"인증 세션이 만료되었거나 유효하지 않습니다.",
			)
			return
		}
		if err != nil {
			logger.ErrorContext(
				request.Context(),
				"access_authentication_failed",
				slog.String("request_id", requestIDFromContext(request.Context())),
				slog.Any("error", err),
			)
			writeAPIError(
				response,
				request,
				http.StatusInternalServerError,
				"INTERNAL_ERROR",
				"인증 확인 중 오류가 발생했습니다.",
			)
			return
		}

		requestContext := context.WithValue(
			request.Context(),
			authenticatedPrincipalContextKey{},
			principal,
		)
		next.ServeHTTP(response, request.WithContext(requestContext))
	})
}

func authenticatedPrincipalFromContext(ctx context.Context) (auth.Principal, bool) {
	principal, ok := ctx.Value(authenticatedPrincipalContextKey{}).(auth.Principal)
	return principal, ok
}

func bearerToken(values []string) (string, bool) {
	if len(values) != 1 {
		return "", false
	}
	parts := strings.Fields(values[0])
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || parts[1] == "" {
		return "", false
	}
	return parts[1], true
}

func optionalBearerToken(values []string) string {
	token, ok := bearerToken(values)
	if !ok {
		return ""
	}
	return token
}
