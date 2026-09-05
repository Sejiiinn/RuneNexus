package httpapi

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
)

const refreshCookieName = "__Host-rune_nexus_refresh"

type PersistentAuthenticator interface {
	AuthenticateGooglePersistent(context.Context, string) (auth.LoginResult, error)
	RefreshPersistent(context.Context, string, string) (auth.LoginResult, error)
}

func (handler authenticationHandler) persistent(response http.ResponseWriter, request *http.Request) {
	response.Header().Set("Cache-Control", "no-store")
	web := strings.HasPrefix(request.URL.Path, "/v1/auth/web/")
	if web {
		origins := request.Header.Values("Origin")
		allowed := len(origins) == 1 && origins[0] != "" && origins[0] != "null"
		found := false
		for _, origin := range handler.allowedOrigins {
			found = found || origin == request.Header.Get("Origin")
		}
		if !allowed || !found {
			writeAPIError(response, request, http.StatusForbidden, "ORIGIN_NOT_ALLOWED", "허용되지 않은 요청 출처입니다.")
			return
		}
	}
	persistent, ok := handler.authenticator.(PersistentAuthenticator)
	if !ok {
		handler.writeAuthenticationError(response, request, auth.ErrSessionPersistenceUnavailable)
		return
	}
	operation := request.URL.Path[strings.LastIndex(request.URL.Path, "/")+1:]
	var result auth.LoginResult
	var err error
	if operation == "google" {
		var input googleAuthenticationRequest
		if err := decodeAuthenticationRequest(response, request, &input); err != nil || strings.TrimSpace(input.IDToken) == "" {
			writeAPIError(response, request, http.StatusBadRequest, "INVALID_REQUEST", "Google ID 토큰이 필요합니다.")
			return
		}
		result, err = persistent.AuthenticateGooglePersistent(request.Context(), input.IDToken)
	} else {
		var token string
		if web {
			var input struct{}
			if err := decodeAuthenticationRequest(response, request, &input); err != nil {
				writeAPIError(response, request, http.StatusBadRequest, "INVALID_REQUEST", "요청 형식이 올바르지 않습니다.")
				return
			}
			cookies := request.CookiesNamed(refreshCookieName)
			if len(cookies) > 1 {
				writeAPIError(response, request, http.StatusBadRequest, "INVALID_REQUEST", "인증 쿠키가 중복되었습니다.")
				return
			}
			if len(cookies) == 1 {
				token = cookies[0].Value
			}
		} else {
			input, ok := decodeRefreshTokenRequest(response, request)
			if !ok {
				return
			}
			token = input.RefreshToken
		}
		if operation == "logout" {
			err = handler.authenticator.Logout(request.Context(), token, optionalBearerToken(request.Header.Values("Authorization")))
			if err == nil {
				if web {
					setRefreshCookie(response, "")
				}
				response.WriteHeader(http.StatusNoContent)
				return
			}
		} else {
			keys := request.Header.Values("Idempotency-Key")
			if len(keys) != 1 {
				handler.writeAuthenticationError(response, request, auth.ErrRefreshRequestInvalid)
				return
			}
			result, err = persistent.RefreshPersistent(request.Context(), token, keys[0])
		}
	}
	if err != nil {
		// 병렬 로그인에서 새로 발급된 쿠키를 늦은 실패 응답이 지우지 않음.
		handler.writeAuthenticationError(response, request, err)
		return
	}
	var refreshExpiry *time.Time
	if !result.RefreshExpiresAt.IsZero() {
		refreshExpiry = &result.RefreshExpiresAt
	}
	body := struct {
		Account          accountResponse `json:"account"`
		AccessToken      string          `json:"accessToken"`
		AccessExpiresAt  time.Time       `json:"accessExpiresAt"`
		RefreshToken     string          `json:"refreshToken,omitempty"`
		RefreshExpiresAt *time.Time      `json:"refreshExpiresAt"`
	}{Account: accountResponse{ID: result.AccountID}, AccessToken: result.AccessToken,
		AccessExpiresAt: result.AccessExpiresAt, RefreshExpiresAt: refreshExpiry}
	if web {
		setRefreshCookie(response, result.RefreshToken)
	} else {
		body.RefreshToken = result.RefreshToken
	}
	writeJSON(response, http.StatusOK, body)
}

func setRefreshCookie(response http.ResponseWriter, token string) {
	cookie := &http.Cookie{Name: refreshCookieName, Value: token, Path: "/", Secure: true, HttpOnly: true, SameSite: http.SameSiteLaxMode, MaxAge: 365 * 24 * 60 * 60}
	if token == "" {
		cookie.MaxAge = -1
	}
	http.SetCookie(response, cookie)
}

func writePersistentAuthenticationError(response http.ResponseWriter, request *http.Request, err error) bool {
	switch {
	case errors.Is(err, auth.ErrSessionPersistenceUnavailable):
		writeAPIError(response, request, http.StatusServiceUnavailable, "SESSION_PERSISTENCE_UNAVAILABLE", "자동 로그인 준비가 완료되지 않았습니다.")
	case errors.Is(err, auth.ErrRefreshRecoveryExpired):
		writeAPIError(response, request, http.StatusUnauthorized, "REFRESH_RECOVERY_EXPIRED", "인증 세션을 복구하려면 다시 로그인해 주세요.")
	case errors.Is(err, auth.ErrRefreshRequestInvalid):
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_IDEMPOTENCY_KEY", "세션 갱신 요청 식별자가 올바르지 않습니다.")
	case errors.Is(err, auth.ErrRefreshRequestConflict):
		writeAPIError(response, request, http.StatusConflict, "REFRESH_REQUEST_CONFLICT", "세션 갱신 요청이 현재 세션과 일치하지 않습니다.")
	case errors.Is(err, auth.ErrLogoutSessionMismatch):
		writeAPIError(response, request, http.StatusUnauthorized, "ACCESS_TOKEN_SESSION_MISMATCH", "로그아웃 토큰이 같은 인증 세션에 속하지 않습니다.")
	default:
		return false
	}
	return true
}
