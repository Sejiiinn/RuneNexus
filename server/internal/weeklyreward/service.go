package weeklyreward

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	RewardTypeQuest       = "quest"
	RewardTypeAllComplete = "all_complete"
	RewardTypeAttendance  = "attendance"

	weeklyQuestRewardDiamonds        int32 = 20
	weeklyAllCompleteRewardDiamonds  int32 = 60
	weeklyAllCompleteModuleTickets   int32 = 1
	weeklyAttendanceRewardDiamonds   int32 = 20
	weeklyAttendanceRequiredDayCount       = 5
	resetOffset                            = 4 * time.Hour
)

var (
	ErrInvalidIdempotencyKey = errors.New("weekly reward idempotency key is invalid")
	ErrIdempotencyKeyReused  = errors.New("weekly reward idempotency key was reused")
	ErrSaveNotFound          = errors.New("weekly reward source save was not found")
	ErrWriterRequired        = errors.New("weekly reward requires the active save writer")
	ErrPeriodMismatch        = errors.New("weekly reward source save is from another period")
	ErrNotEligible           = errors.New("weekly reward is not eligible")
	ErrInvalidReward         = errors.New("weekly reward type is invalid")
)

var weeklyQuestTargets = map[string]int64{
	"clearWaves":     150,
	"killBosses":     15,
	"killEnemies":    500,
	"buyRunUpgrades": 25,
}

type WriterReplacedError struct {
	CurrentGeneration int64
}

func (err *WriterReplacedError) Error() string {
	return fmt.Sprintf("save writer replaced: current generation is %d", err.CurrentGeneration)
}

type AlreadyClaimedError struct {
	Result ClaimResult
}

func (err *AlreadyClaimedError) Error() string {
	return "weekly reward was already claimed"
}

type ClaimRequest struct {
	IdempotencyKey string
	RawBody        []byte
	RewardType     string
	QuestType      string
}

type ClaimResult struct {
	RewardKey          string
	PeriodKey          string
	WeekKey            int64
	RewardType         string
	QuestType          string
	Diamonds           int32
	ModuleTickets      int32
	SourceSaveRevision int64
	ClaimedAt          time.Time
}

type progressionEvidence struct {
	DailyQuestClockRollbackDetected bool             `json:"dailyQuestClockRollbackDetected"`
	WeeklyQuestWeekKey              int64            `json:"weeklyQuestWeekKey"`
	WeeklyQuestProgress             map[string]int64 `json:"weeklyQuestProgress"`
	ClaimedWeeklyQuestRewards       []string         `json:"claimedWeeklyQuestRewards"`
	WeeklyQuestAllCompleteClaimed   bool             `json:"weeklyQuestAllCompleteClaimed"`
	WeeklyAttendanceDayKeys         []int64          `json:"weeklyAttendanceDayKeys"`
	WeeklyAttendanceRewardClaimed   bool             `json:"weeklyAttendanceRewardClaimed"`
}

type rewardDefinition struct {
	rewardKey     string
	diamonds      int32
	moduleTickets int32
}

type Service struct {
	database *pgxpool.Pool
	now      func() time.Time
}

func NewService(database *pgxpool.Pool) *Service {
	return &Service{database: database, now: time.Now}
}

func (service *Service) Claim(
	ctx context.Context,
	accountID string,
	sessionID string,
	request ClaimRequest,
) (ClaimResult, error) {
	databaseAccountID, err := parseUUID(accountID)
	if err != nil {
		return ClaimResult{}, fmt.Errorf("parse authenticated account ID: %w", err)
	}
	databaseSessionID, err := parseUUID(sessionID)
	if err != nil {
		return ClaimResult{}, fmt.Errorf("parse authenticated session ID: %w", err)
	}
	idempotencyKey, err := parseUUID(request.IdempotencyKey)
	if err != nil {
		return ClaimResult{}, ErrInvalidIdempotencyKey
	}
	requestHash := sha256.Sum256(request.RawBody)
	queries := dbgen.New(service.database)
	receiptParams := dbgen.GetRewardClaimByIdempotencyKeyParams{
		AccountID:      databaseAccountID,
		IdempotencyKey: idempotencyKey,
	}
	receipt, err := queries.GetRewardClaimByIdempotencyKey(ctx, receiptParams)
	if err == nil {
		return resultFromReceipt(receipt, requestHash[:])
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return ClaimResult{}, fmt.Errorf("get weekly reward receipt: %w", err)
	}

	tx, err := service.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return ClaimResult{}, fmt.Errorf("begin weekly reward transaction: %w", err)
	}
	defer func() {
		_ = tx.Rollback(ctx)
	}()
	txQueries := dbgen.New(tx)
	// 저장 PUT과 같은 writer -> header 순서로 잠금.
	writer, err := txQueries.GetSaveWriterStateForUpdate(ctx, databaseAccountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return ClaimResult{}, ErrWriterRequired
	}
	if err != nil {
		return ClaimResult{}, fmt.Errorf("lock weekly reward save writer: %w", err)
	}
	if !writer.SessionID.Valid || writer.SessionID.Bytes != databaseSessionID.Bytes {
		return ClaimResult{}, &WriterReplacedError{CurrentGeneration: writer.Generation}
	}
	if _, err := txQueries.GetSaveHeaderForUpdate(ctx, databaseAccountID); errors.Is(err, pgx.ErrNoRows) {
		return ClaimResult{}, ErrSaveNotFound
	} else if err != nil {
		return ClaimResult{}, fmt.Errorf("lock weekly reward source save: %w", err)
	}

	receipt, err = txQueries.GetRewardClaimByIdempotencyKey(ctx, receiptParams)
	if err == nil {
		return resultFromReceipt(receipt, requestHash[:])
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return ClaimResult{}, fmt.Errorf("recheck weekly reward receipt: %w", err)
	}
	snapshot, err := txQueries.GetSaveSnapshot(ctx, databaseAccountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return ClaimResult{}, ErrSaveNotFound
	}
	if err != nil {
		return ClaimResult{}, fmt.Errorf("get weekly reward source save: %w", err)
	}

	periodKey, weekKey := weeklyPeriod(service.now().UTC())
	evidence, err := decodeProgressionEvidence(snapshot.Progression)
	if err != nil {
		return ClaimResult{}, fmt.Errorf("decode weekly reward evidence: %w", err)
	}
	if evidence.WeeklyQuestWeekKey != weekKey {
		return ClaimResult{}, ErrPeriodMismatch
	}
	definition, err := rewardDefinitionForRequest(request, periodKey)
	if err != nil {
		return ClaimResult{}, err
	}

	stored, err := txQueries.GetRewardClaimByRewardKey(
		ctx,
		dbgen.GetRewardClaimByRewardKeyParams{
			AccountID: databaseAccountID,
			RewardKey: definition.rewardKey,
		},
	)
	if err == nil {
		return ClaimResult{}, &AlreadyClaimedError{Result: claimResult(stored)}
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return ClaimResult{}, fmt.Errorf("get claimed weekly reward: %w", err)
	}
	if err := validateEligibility(request, weekKey, evidence); err != nil {
		return ClaimResult{}, err
	}

	evidenceJSON, err := json.Marshal(evidence)
	if err != nil {
		return ClaimResult{}, fmt.Errorf("encode weekly reward evidence: %w", err)
	}
	receipt, err = txQueries.CreateRewardClaim(
		ctx,
		dbgen.CreateRewardClaimParams{
			AccountID:          databaseAccountID,
			RewardKey:          definition.rewardKey,
			PeriodKey:          periodKey,
			WeekKey:            weekKey,
			RewardType:         request.RewardType,
			QuestType:          nullableText(request.QuestType),
			IdempotencyKey:     idempotencyKey,
			RequestHash:        requestHash[:],
			DiamondAmount:      definition.diamonds,
			ModuleTicketAmount: definition.moduleTickets,
			WriterGeneration:   writer.Generation,
			SourceSaveRevision: snapshot.Revision,
			Evidence:           evidenceJSON,
		},
	)
	if err != nil {
		return ClaimResult{}, fmt.Errorf("create weekly reward receipt: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return ClaimResult{}, fmt.Errorf("commit weekly reward transaction: %w", err)
	}
	return claimResult(receipt), nil
}

func rewardDefinitionForRequest(
	request ClaimRequest,
	periodKey string,
) (rewardDefinition, error) {
	prefix := "weekly:" + periodKey + ":"
	switch request.RewardType {
	case RewardTypeQuest:
		_, exists := weeklyQuestTargets[request.QuestType]
		if !exists {
			return rewardDefinition{}, ErrInvalidReward
		}
		return rewardDefinition{
			rewardKey: prefix + "quest:" + request.QuestType,
			diamonds:  weeklyQuestRewardDiamonds,
		}, nil
	case RewardTypeAllComplete:
		if request.QuestType != "" {
			return rewardDefinition{}, ErrInvalidReward
		}
		return rewardDefinition{
			rewardKey:     prefix + "all_complete",
			diamonds:      weeklyAllCompleteRewardDiamonds,
			moduleTickets: weeklyAllCompleteModuleTickets,
		}, nil
	case RewardTypeAttendance:
		if request.QuestType != "" {
			return rewardDefinition{}, ErrInvalidReward
		}
		return rewardDefinition{
			rewardKey: prefix + "attendance",
			diamonds:  weeklyAttendanceRewardDiamonds,
		}, nil
	default:
		return rewardDefinition{}, ErrInvalidReward
	}
}

func validateEligibility(
	request ClaimRequest,
	weekKey int64,
	evidence progressionEvidence,
) error {
	if evidence.DailyQuestClockRollbackDetected {
		return ErrNotEligible
	}
	switch request.RewardType {
	case RewardTypeQuest:
		target := weeklyQuestTargets[request.QuestType]
		if evidence.WeeklyQuestProgress[request.QuestType] < target ||
			contains(evidence.ClaimedWeeklyQuestRewards, request.QuestType) {
			return ErrNotEligible
		}
	case RewardTypeAllComplete:
		if evidence.WeeklyQuestAllCompleteClaimed {
			return ErrNotEligible
		}
		for questType, target := range weeklyQuestTargets {
			if evidence.WeeklyQuestProgress[questType] < target {
				return ErrNotEligible
			}
		}
	case RewardTypeAttendance:
		if evidence.WeeklyAttendanceRewardClaimed ||
			distinctCurrentWeekDays(evidence.WeeklyAttendanceDayKeys, weekKey) < weeklyAttendanceRequiredDayCount {
			return ErrNotEligible
		}
	default:
		return ErrInvalidReward
	}
	return nil
}

func decodeProgressionEvidence(source []byte) (progressionEvidence, error) {
	var evidence progressionEvidence
	decoder := json.NewDecoder(bytes.NewReader(source))
	if err := decoder.Decode(&evidence); err != nil {
		return progressionEvidence{}, err
	}
	if evidence.WeeklyQuestProgress == nil {
		evidence.WeeklyQuestProgress = map[string]int64{}
	}
	return evidence, nil
}

func weeklyPeriod(now time.Time) (string, int64) {
	adjusted := now.UTC().Add(resetOffset)
	year, week := adjusted.ISOWeek()
	dayKey := adjusted.UnixMilli() / int64((24*time.Hour)/time.Millisecond)
	return fmt.Sprintf("%04d-W%02d", year, week), (dayKey + 3) / 7
}

func distinctCurrentWeekDays(dayKeys []int64, weekKey int64) int {
	distinct := make(map[int64]struct{}, len(dayKeys))
	for _, dayKey := range dayKeys {
		if dayKey >= 0 && (dayKey+3)/7 == weekKey {
			distinct[dayKey] = struct{}{}
		}
	}
	return len(distinct)
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func resultFromReceipt(receipt dbgen.RewardClaim, requestHash []byte) (ClaimResult, error) {
	if !bytes.Equal(receipt.RequestHash, requestHash) {
		return ClaimResult{}, ErrIdempotencyKeyReused
	}
	return claimResult(receipt), nil
}

func claimResult(receipt dbgen.RewardClaim) ClaimResult {
	return ClaimResult{
		RewardKey:          receipt.RewardKey,
		PeriodKey:          receipt.PeriodKey,
		WeekKey:            receipt.WeekKey,
		RewardType:         receipt.RewardType,
		QuestType:          receipt.QuestType.String,
		Diamonds:           receipt.DiamondAmount,
		ModuleTickets:      receipt.ModuleTicketAmount,
		SourceSaveRevision: receipt.SourceSaveRevision,
		ClaimedAt:          receipt.ClaimedAt.Time.UTC(),
	}
}

func nullableText(value string) pgtype.Text {
	return pgtype.Text{String: value, Valid: value != ""}
}

func parseUUID(value string) (pgtype.UUID, error) {
	var parsed pgtype.UUID
	if err := parsed.Scan(value); err != nil || !parsed.Valid {
		if err == nil {
			err = errors.New("UUID is null")
		}
		return pgtype.UUID{}, err
	}
	return parsed, nil
}
