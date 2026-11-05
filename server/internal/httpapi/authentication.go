package httpapi

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"mime"
	"net/http"
	"strings"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
)

const maxAuthenticationBodyBytes = 16 * 1024

type authenticationHandler struct {
	logger        *slog.Logger
	authenticator Authenticator
}

type googleAuthenticationRequest struct {
	IDToken string `json:"idToken"`
}

type refreshTokenRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type accountResponse struct {
	ID string `json:"id"`
}

type authenticationResponse struct {
	Account          accountResponse `json:"account"`
	AccessToken      string          `json:"accessToken"`
	AccessExpiresAt  time.Time       `json:"accessExpiresAt"`
	RefreshToken     string          `json:"refreshToken,omitempty"`
	RefreshExpiresAt *time.Time      `json:"refreshExpiresAt"`
}

type errorResponse struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	RequestID string `json:"requestId"`
}

func (handler authenticationHandler) google(response http.ResponseWriter, request *http.Request) {
	response.Header().Set("Cache-Control", "no-store")
	var input googleAuthenticationRequest
	if err := decodeAuthenticationRequest(response, request, &input); err != nil || strings.TrimSpace(input.IDToken) == "" {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_REQUEST", "Google ID 토큰이 필요합니다.")
		return
	}
	result, err := handler.authenticator.AuthenticateGooglePersistent(request.Context(), input.IDToken)
	handler.writeLoginResult(response, request, result, err)
}

func (handler authenticationHandler) refresh(response http.ResponseWriter, request *http.Request) {
	response.Header().Set("Cache-Control", "no-store")
	input, ok := decodeRefreshTokenRequest(response, request)
	if !ok {
		return
	}
	keys := request.Header.Values("Idempotency-Key")
	if len(keys) != 1 {
		handler.writeAuthenticationError(response, request, auth.ErrRefreshRequestInvalid)
		return
	}
	result, err := handler.authenticator.RefreshPersistent(request.Context(), input.RefreshToken, keys[0])
	handler.writeLoginResult(response, request, result, err)
}

func (handler authenticationHandler) logout(response http.ResponseWriter, request *http.Request) {
	response.Header().Set("Cache-Control", "no-store")
	input, ok := decodeRefreshTokenRequest(response, request)
	if !ok {
		return
	}
	if err := handler.authenticator.Logout(request.Context(), input.RefreshToken, optionalBearerToken(request.Header.Values("Authorization"))); err != nil {
		handler.writeAuthenticationError(response, request, err)
		return
	}
	response.WriteHeader(http.StatusNoContent)
}

func (handler authenticationHandler) writeLoginResult(response http.ResponseWriter, request *http.Request, result auth.LoginResult, err error) {
	if err != nil {
		handler.writeAuthenticationError(response, request, err)
		return
	}
	var refreshExpiry *time.Time
	if !result.RefreshExpiresAt.IsZero() {
		refreshExpiry = &result.RefreshExpiresAt
	}
	writeJSON(response, http.StatusOK, authenticationResponse{
		Account:          accountResponse{ID: result.AccountID},
		AccessToken:      result.AccessToken,
		AccessExpiresAt:  result.AccessExpiresAt,
		RefreshToken:     result.RefreshToken,
		RefreshExpiresAt: refreshExpiry,
	})
}

func decodeRefreshTokenRequest(
	response http.ResponseWriter,
	request *http.Request,
) (refreshTokenRequest, bool) {
	var input refreshTokenRequest
	if err := decodeAuthenticationRequest(response, request, &input); err != nil {
		status := http.StatusBadRequest
		code := "INVALID_REQUEST"
		message := "요청 형식이 올바르지 않습니다."
		var maxBytesError *http.MaxBytesError
		if errors.As(err, &maxBytesError) {
			status = http.StatusRequestEntityTooLarge
			code = "REQUEST_TOO_LARGE"
			message = "요청 크기가 허용 범위를 초과했습니다."
		}
		writeAPIError(response, request, status, code, message)
		return refreshTokenRequest{}, false
	}
	if strings.TrimSpace(input.RefreshToken) == "" {
		writeAPIError(
			response,
			request,
			http.StatusBadRequest,
			"INVALID_REQUEST",
			"Refresh 토큰이 필요합니다.",
		)
		return refreshTokenRequest{}, false
	}
	return input, true
}

func (handler authenticationHandler) writeAuthenticationError(
	response http.ResponseWriter,
	request *http.Request,
	err error,
) {
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
	case errors.Is(err, auth.ErrRefreshTokenInvalid):
		writeAPIError(
			response,
			request,
			http.StatusUnauthorized,
			"REFRESH_TOKEN_INVALID",
			"인증 세션을 갱신할 수 없습니다.",
		)
	case errors.Is(err, auth.ErrRefreshTokenReused):
		writeAPIError(
			response,
			request,
			http.StatusUnauthorized,
			"REFRESH_TOKEN_REUSED",
			"인증 세션이 안전을 위해 종료되었습니다.",
		)
	case errors.Is(err, auth.ErrIdentityRejected):
		writeAPIError(
			response,
			request,
			http.StatusUnauthorized,
			"GOOGLE_AUTH_REJECTED",
			"Google 로그인을 확인할 수 없습니다.",
		)
	case errors.Is(err, auth.ErrAccountInactive):
		writeAPIError(
			response,
			request,
			http.StatusForbidden,
			"ACCOUNT_NOT_ACTIVE",
			"현재 사용할 수 없는 계정입니다.",
		)
	case errors.Is(err, auth.ErrIdentityUnavailable):
		handler.logger.WarnContext(
			request.Context(),
			"google_auth_provider_unavailable",
			slog.String("request_id", requestIDFromContext(request.Context())),
		)
		writeAPIError(
			response,
			request,
			http.StatusServiceUnavailable,
			"AUTH_PROVIDER_UNAVAILABLE",
			"Google 로그인 서버에 잠시 연결할 수 없습니다.",
		)
	default:
		handler.logger.ErrorContext(
			request.Context(),
			"authentication_failed",
			slog.String("request_id", requestIDFromContext(request.Context())),
			slog.Any("error", err),
		)
		writeAPIError(
			response,
			request,
			http.StatusInternalServerError,
			"INTERNAL_ERROR",
			"인증 처리 중 오류가 발생했습니다.",
		)
	}
}

func decodeAuthenticationRequest(
	response http.ResponseWriter,
	request *http.Request,
	destination any,
) error {
	mediaType, _, err := mime.ParseMediaType(request.Header.Get("Content-Type"))
	if err != nil || mediaType != "application/json" {
		return errors.New("Content-Type must be application/json")
	}

	request.Body = http.MaxBytesReader(
		response,
		request.Body,
		maxAuthenticationBodyBytes,
	)
	decoder := json.NewDecoder(request.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(destination); err != nil {
		return fmt.Errorf("decode JSON body: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return errors.New("request body must contain one JSON value")
	}
	return nil
}

func writeAPIError(
	response http.ResponseWriter,
	request *http.Request,
	status int,
	code string,
	message string,
) {
	writeJSON(response, status, errorResponse{
		Code:      code,
		Message:   message,
		RequestID: requestIDFromContext(request.Context()),
	})
}
