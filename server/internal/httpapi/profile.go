package httpapi

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
)

type profileHandler struct {
	logger   *slog.Logger
	accounts Authenticator
}

func (handler profileHandler) get(response http.ResponseWriter, request *http.Request) {
	principal, _ := authenticatedPrincipalFromContext(request.Context())
	profile, err := handler.accounts.GetAccountProfile(request.Context(), principal.AccountID)
	if err != nil {
		handler.writeError(response, request, err)
		return
	}
	writeJSON(response, http.StatusOK, profile)
}

func (handler profileHandler) setNickname(response http.ResponseWriter, request *http.Request) {
	var input struct {
		Nickname string `json:"nickname"`
	}
	if err := decodeAuthenticationRequest(response, request, &input); err != nil {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_REQUEST", "요청 형식이 올바르지 않습니다.")
		return
	}
	principal, _ := authenticatedPrincipalFromContext(request.Context())
	profile, err := handler.accounts.SetNickname(request.Context(), principal.AccountID, input.Nickname)
	if err != nil {
		handler.writeError(response, request, err)
		return
	}
	writeJSON(response, http.StatusOK, profile)
}

func (handler profileHandler) writeError(response http.ResponseWriter, request *http.Request, err error) {
	status, code, message := http.StatusInternalServerError, "INTERNAL_ERROR", "계정 프로필 처리 중 오류가 발생했습니다."
	switch {
	case errors.Is(err, auth.ErrInvalidNickname):
		status, code, message = http.StatusBadRequest, "INVALID_NICKNAME", "닉네임은 2자 이상, 한글 최대 8자·영문 최대 16자로 입력해 주세요. 한글·영문·숫자·밑줄만 사용할 수 있으며 admin(대소문자 무관)·운영자는 포함할 수 없습니다."
	case errors.Is(err, auth.ErrNicknameAlreadySet):
		status, code, message = http.StatusConflict, "NICKNAME_ALREADY_SET", "이미 닉네임이 설정되어 있습니다."
	case errors.Is(err, auth.ErrNicknameTagsExhausted):
		status, code, message = http.StatusConflict, "NICKNAME_TAGS_EXHAUSTED", "이 닉네임의 태그가 모두 사용되었습니다. 다른 닉네임을 입력해 주세요."
	case errors.Is(err, auth.ErrAccessTokenInvalid):
		status, code, message = http.StatusUnauthorized, "ACCESS_TOKEN_INVALID", "인증 세션이 만료되었거나 유효하지 않습니다."
	case errors.Is(err, auth.ErrAccountInactive):
		status, code, message = http.StatusForbidden, "ACCOUNT_NOT_ACTIVE", "사용할 수 없는 계정입니다."
	default:
		handler.logger.ErrorContext(request.Context(), "account_profile_failed", slog.String("request_id", requestIDFromContext(request.Context())), slog.Any("error", err))
	}
	writeAPIError(response, request, status, code, message)
}

func withAccountAuthentication(logger *slog.Logger, authenticator Authenticator, next http.Handler) http.Handler {
	return withBearerAuthentication(logger, authenticator, http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		principal, _ := authenticatedPrincipalFromContext(request.Context())
		profile, err := authenticator.GetAccountProfile(request.Context(), principal.AccountID)
		if err != nil {
			(profileHandler{logger: logger, accounts: authenticator}).writeError(response, request, err)
			return
		}
		if profile.Nickname == nil || profile.Tag == nil {
			writeAPIError(response, request, http.StatusForbidden, "NICKNAME_REQUIRED", "계정 닉네임을 먼저 설정해 주세요.")
			return
		}
		next.ServeHTTP(response, request)
	}))
}
