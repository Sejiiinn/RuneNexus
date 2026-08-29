package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"mime"
	"net/http"
	"strings"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/weeklyreward"
)

const maxWeeklyRewardBodyBytes int64 = 2048

type WeeklyRewardService interface {
	Claim(context.Context, string, string, weeklyreward.ClaimRequest) (weeklyreward.ClaimResult, error)
}

type weeklyRewardHandler struct {
	logger  *slog.Logger
	rewards WeeklyRewardService
}

type weeklyRewardClaimRequest struct {
	Period     string `json:"period"`
	RewardType string `json:"rewardType"`
	QuestType  string `json:"questType,omitempty"`
}

type weeklyRewardClaimResponse struct {
	RewardKey          string    `json:"rewardKey"`
	PeriodKey          string    `json:"periodKey"`
	WeekKey            int64     `json:"weekKey"`
	RewardType         string    `json:"rewardType"`
	QuestType          string    `json:"questType,omitempty"`
	Diamonds           int32     `json:"diamonds"`
	ModuleTickets      int32     `json:"moduleTickets"`
	SourceSaveRevision int64     `json:"sourceSaveRevision"`
	ClaimedAt          time.Time `json:"claimedAt"`
}

type weeklyRewardAlreadyClaimedResponse struct {
	Code      string                    `json:"code"`
	Message   string                    `json:"message"`
	RequestID string                    `json:"requestId"`
	Reward    weeklyRewardClaimResponse `json:"reward"`
}

func (handler weeklyRewardHandler) claim(response http.ResponseWriter, request *http.Request) {
	principal, ok := authenticatedPrincipalFromContext(request.Context())
	if !ok {
		handler.writeInternalError(response, request, errors.New("missing authenticated principal"))
		return
	}
	idempotencyKey, ok := requestIdempotencyKey(request.Header.Values(idempotencyKeyHeader))
	if !ok {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_IDEMPOTENCY_KEY", "유효한 Idempotency-Key UUID가 필요합니다.")
		return
	}
	input, rawBody, err := decodeWeeklyRewardClaimRequest(response, request)
	if err != nil {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_REWARD_REQUEST", err.Error())
		return
	}
	result, err := handler.rewards.Claim(
		request.Context(),
		principal.AccountID,
		principal.SessionID,
		weeklyreward.ClaimRequest{
			IdempotencyKey: idempotencyKey,
			RawBody:        rawBody,
			RewardType:     input.RewardType,
			QuestType:      input.QuestType,
		},
	)
	if errors.Is(err, weeklyreward.ErrInvalidIdempotencyKey) {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_IDEMPOTENCY_KEY", "유효한 Idempotency-Key UUID가 필요합니다.")
		return
	}
	if errors.Is(err, weeklyreward.ErrIdempotencyKeyReused) {
		writeAPIError(response, request, http.StatusConflict, "IDEMPOTENCY_KEY_REUSED", "같은 Idempotency-Key를 다른 보상 요청에 사용할 수 없습니다.")
		return
	}
	var alreadyClaimed *weeklyreward.AlreadyClaimedError
	if errors.As(err, &alreadyClaimed) {
		writeJSON(response, http.StatusConflict, weeklyRewardAlreadyClaimedResponse{
			Code:      "REWARD_ALREADY_CLAIMED",
			Message:   "이미 수령한 주간 보상입니다.",
			RequestID: requestIDFromContext(request.Context()),
			Reward:    weeklyRewardResponse(alreadyClaimed.Result),
		})
		return
	}
	var replaced *weeklyreward.WriterReplacedError
	if errors.As(err, &replaced) {
		writeJSON(response, http.StatusConflict, saveWriterReplacedResponse{
			Code:                    "SAVE_WRITER_REPLACED",
			Message:                 "다른 기기에서 계정 진행을 사용 중입니다.",
			RequestID:               requestIDFromContext(request.Context()),
			CurrentWriterGeneration: replaced.CurrentGeneration,
		})
		return
	}
	if errors.Is(err, weeklyreward.ErrWriterRequired) || errors.Is(err, weeklyreward.ErrSaveNotFound) {
		writeAPIError(response, request, http.StatusConflict, "SAVE_SYNC_REQUIRED", "최신 계정 진행을 서버에 저장한 뒤 다시 시도해 주세요.")
		return
	}
	if errors.Is(err, weeklyreward.ErrPeriodMismatch) {
		writeAPIError(response, request, http.StatusConflict, "WEEKLY_REWARD_PERIOD_MISMATCH", "서버 주간 정보와 진행 데이터가 다릅니다. 동기화 후 다시 시도해 주세요.")
		return
	}
	if errors.Is(err, weeklyreward.ErrNotEligible) {
		writeAPIError(response, request, http.StatusUnprocessableEntity, "WEEKLY_REWARD_NOT_ELIGIBLE", "현재 저장된 진행으로는 이 주간 보상을 받을 수 없습니다.")
		return
	}
	if errors.Is(err, weeklyreward.ErrInvalidReward) {
		writeAPIError(response, request, http.StatusBadRequest, "INVALID_REWARD_REQUEST", "지원하지 않는 주간 보상입니다.")
		return
	}
	if err != nil {
		handler.writeInternalError(response, request, err)
		return
	}
	writeJSON(response, http.StatusOK, weeklyRewardResponse(result))
}

func decodeWeeklyRewardClaimRequest(
	response http.ResponseWriter,
	request *http.Request,
) (weeklyRewardClaimRequest, []byte, error) {
	mediaType, _, err := mime.ParseMediaType(request.Header.Get("Content-Type"))
	if err != nil || mediaType != "application/json" {
		return weeklyRewardClaimRequest{}, nil, errors.New("Content-Type이 application/json인 요청이 필요합니다")
	}
	request.Body = http.MaxBytesReader(response, request.Body, maxWeeklyRewardBodyBytes)
	rawBody, err := io.ReadAll(request.Body)
	if err != nil {
		return weeklyRewardClaimRequest{}, nil, errors.New("주간 보상 요청 본문을 읽을 수 없습니다")
	}
	decoder := json.NewDecoder(bytes.NewReader(rawBody))
	decoder.DisallowUnknownFields()
	var input weeklyRewardClaimRequest
	if err := decoder.Decode(&input); err != nil {
		return weeklyRewardClaimRequest{}, nil, errors.New("주간 보상 요청 형식이 올바르지 않습니다")
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return weeklyRewardClaimRequest{}, nil, errors.New("주간 보상 요청은 하나의 JSON 객체여야 합니다")
	}
	input.Period = strings.TrimSpace(input.Period)
	input.RewardType = strings.TrimSpace(input.RewardType)
	input.QuestType = strings.TrimSpace(input.QuestType)
	if input.Period != "weekly" || input.RewardType == "" {
		return weeklyRewardClaimRequest{}, nil, errors.New("유효한 주간 reward 요청이 필요합니다")
	}
	return input, rawBody, nil
}

func weeklyRewardResponse(result weeklyreward.ClaimResult) weeklyRewardClaimResponse {
	return weeklyRewardClaimResponse{
		RewardKey:          result.RewardKey,
		PeriodKey:          result.PeriodKey,
		WeekKey:            result.WeekKey,
		RewardType:         result.RewardType,
		QuestType:          result.QuestType,
		Diamonds:           result.Diamonds,
		ModuleTickets:      result.ModuleTickets,
		SourceSaveRevision: result.SourceSaveRevision,
		ClaimedAt:          result.ClaimedAt,
	}
}

func (handler weeklyRewardHandler) writeInternalError(
	response http.ResponseWriter,
	request *http.Request,
	err error,
) {
	handler.logger.Error(
		"weekly_reward_request_failed",
		slog.String("request_id", requestIDFromContext(request.Context())),
		slog.Any("error", err),
	)
	writeAPIError(response, request, http.StatusInternalServerError, "INTERNAL_ERROR", "주간 보상 요청을 처리하지 못했습니다.")
}
