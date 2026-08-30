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
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
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
	dailyQuestRewardDiamonds         int32 = 10
	dailyAllCompleteRewardDiamonds   int32 = 20
	dailyAttendanceRewardDiamonds    int32 = 10
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
	ErrEconomyNotReady       = errors.New("server authoritative economy is not ready")
)

var weeklyQuestTargets = map[string]int64{
	"clearWaves":     150,
	"killBosses":     15,
	"killEnemies":    500,
	"buyRunUpgrades": 25,
}

var dailyQuestTargets = map[string]int64{
	"clearWaves": 30, "killBosses": 3, "killEnemies": 100, "buyRunUpgrades": 5,
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
	Period         string
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
	EconomyRevision    int64
	AuthorityEpoch     string
}

type progressionEvidence struct {
	DailyQuestClockRollbackDetected bool             `json:"dailyQuestClockRollbackDetected"`
	DailyQuestDayKey                int64            `json:"dailyQuestDayKey"`
	DailyQuestProgress              map[string]int64 `json:"dailyQuestProgress"`
	ClaimedDailyQuestRewards        []string         `json:"claimedDailyQuestRewards"`
	DailyQuestAllCompleteClaimed    bool             `json:"dailyQuestAllCompleteClaimed"`
	DailyAttendanceRewardClaimed    bool             `json:"dailyAttendanceRewardClaimed"`
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
	if request.Period == "" {
		request.Period = "weekly"
	}
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
	economyReceipt, err := queries.GetEconomyCommand(ctx, dbgen.GetEconomyCommandParams{
		AccountID: databaseAccountID, IdempotencyKey: idempotencyKey,
	})
	if err == nil {
		if economyReceipt.CommandType != "reward_claim" || !bytes.Equal(economyReceipt.RequestHash, requestHash[:]) {
			return ClaimResult{}, ErrIdempotencyKeyReused
		}
		var result ClaimResult
		if decodeErr := json.Unmarshal(economyReceipt.ResponsePayload, &result); decodeErr != nil {
			return ClaimResult{}, fmt.Errorf("decode reward economy receipt: %w", decodeErr)
		}
		return result, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return ClaimResult{}, fmt.Errorf("get reward economy receipt: %w", err)
	}
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
	playerEconomy, err := txQueries.GetPlayerEconomyForUpdate(ctx, databaseAccountID)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && playerEconomy.AuthorityState != "server_authoritative") {
		return ClaimResult{}, ErrEconomyNotReady
	}
	if err != nil {
		return ClaimResult{}, fmt.Errorf("lock weekly reward economy: %w", err)
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

	periodKey, weekKey := rewardPeriod(request.Period, service.now().UTC())
	evidence, err := decodeProgressionEvidence(snapshot.Progression)
	if err != nil {
		return ClaimResult{}, fmt.Errorf("decode weekly reward evidence: %w", err)
	}
	if (request.Period == "weekly" && evidence.WeeklyQuestWeekKey != weekKey) ||
		(request.Period == "daily" && evidence.DailyQuestDayKey != weekKey) {
		return ClaimResult{}, ErrPeriodMismatch
	}
	definition, err := rewardDefinitionForRequest(request, periodKey)
	if err != nil {
		return ClaimResult{}, err
	}
	authoritativeClaim, err := txQueries.GetEconomyRewardClaim(ctx, dbgen.GetEconomyRewardClaimParams{
		AccountID: databaseAccountID, RewardKey: definition.rewardKey,
	})
	if err == nil {
		var result ClaimResult
		if decodeErr := json.Unmarshal(authoritativeClaim.ResponsePayload, &result); decodeErr != nil {
			return ClaimResult{}, fmt.Errorf("decode claimed reward response: %w", decodeErr)
		}
		return ClaimResult{}, &AlreadyClaimedError{Result: result}
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return ClaimResult{}, fmt.Errorf("get authoritative claimed reward: %w", err)
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
	system, err := txQueries.GetEconomySystemState(ctx)
	if err != nil {
		return ClaimResult{}, fmt.Errorf("get weekly reward authority epoch: %w", err)
	}
	resultingRevision := playerEconomy.Revision + 1
	command, err := txQueries.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{
		AccountID: databaseAccountID, IdempotencyKey: idempotencyKey,
		CommandType: "reward_claim", RequestHash: requestHash[:],
		ResultingRevision: resultingRevision, AuthorityEpoch: system.AuthorityEpoch,
		CatalogVersion:  pgtype.Int4{Int32: economy.CatalogVersion, Valid: true},
		ResponsePayload: []byte(`{}`),
	})
	if err != nil {
		return ClaimResult{}, fmt.Errorf("create weekly reward economy command: %w", err)
	}
	updatedEconomy, err := txQueries.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{
		AccountID: databaseAccountID, Revision: resultingRevision,
		FreeDiamonds:              playerEconomy.FreeDiamonds + int64(definition.diamonds),
		PaidDiamonds:              playerEconomy.PaidDiamonds,
		ModuleTickets:             playerEconomy.ModuleTickets + int64(definition.moduleTickets),
		ModuleDrawCount:           playerEconomy.ModuleDrawCount,
		ModuleTicketPurchaseCount: playerEconomy.ModuleTicketPurchaseCount,
		ModuleItemSequence:        playerEconomy.ModuleItemSequence,
		ResearchSlotTwoUnlocked:   playerEconomy.ResearchSlotTwoUnlocked,
		Revision_2:                playerEconomy.Revision,
	})
	if err != nil {
		return ClaimResult{}, fmt.Errorf("update weekly reward economy: %w", err)
	}
	entryOrder := int16(0)
	if definition.diamonds > 0 {
		if err := txQueries.CreateEconomyLedgerEntry(ctx, dbgen.CreateEconomyLedgerEntryParams{
			CommandID: command.ID, EntryOrder: entryOrder, AssetType: "free_diamond",
			Delta: int64(definition.diamonds), BalanceAfter: updatedEconomy.FreeDiamonds,
			Reason: request.Period + "_reward_claim",
		}); err != nil {
			return ClaimResult{}, fmt.Errorf("create weekly diamond ledger: %w", err)
		}
		entryOrder++
	}
	if definition.moduleTickets > 0 {
		if err := txQueries.CreateEconomyLedgerEntry(ctx, dbgen.CreateEconomyLedgerEntryParams{
			CommandID: command.ID, EntryOrder: entryOrder, AssetType: "module_ticket",
			Delta: int64(definition.moduleTickets), BalanceAfter: updatedEconomy.ModuleTickets,
			Reason: request.Period + "_reward_claim",
		}); err != nil {
			return ClaimResult{}, fmt.Errorf("create weekly ticket ledger: %w", err)
		}
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
	if err := txQueries.CreateEconomyRewardClaim(ctx, dbgen.CreateEconomyRewardClaimParams{
		AccountID: databaseAccountID, RewardKey: definition.rewardKey,
		CommandID: command.ID, WriterGeneration: pgtype.Int8{Int64: writer.Generation, Valid: true},
		OriginSaveRevision: pgtype.Int8{Int64: snapshot.Revision, Valid: true}, Evidence: evidenceJSON,
	}); err != nil {
		return ClaimResult{}, fmt.Errorf("create authoritative weekly reward claim: %w", err)
	}
	claim := claimResult(receipt)
	claim.EconomyRevision = resultingRevision
	claim.AuthorityEpoch = formatUUID(system.AuthorityEpoch)
	responsePayload, err := json.Marshal(claim)
	if err != nil {
		return ClaimResult{}, fmt.Errorf("encode weekly reward command response: %w", err)
	}
	if _, err := txQueries.UpdateEconomyCommandResponse(ctx, dbgen.UpdateEconomyCommandResponseParams{
		ID: command.ID, ResponsePayload: responsePayload,
	}); err != nil {
		return ClaimResult{}, fmt.Errorf("store weekly reward command response: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return ClaimResult{}, fmt.Errorf("commit weekly reward transaction: %w", err)
	}
	return claim, nil
}

func rewardDefinitionForRequest(
	request ClaimRequest,
	periodKey string,
) (rewardDefinition, error) {
	if request.Period == "" {
		request.Period = "weekly"
	}
	if request.Period == "daily" {
		prefix := "daily:" + periodKey + ":"
		switch request.RewardType {
		case RewardTypeQuest:
			if _, exists := dailyQuestTargets[request.QuestType]; !exists {
				return rewardDefinition{}, ErrInvalidReward
			}
			return rewardDefinition{rewardKey: prefix + "quest:" + request.QuestType, diamonds: dailyQuestRewardDiamonds}, nil
		case RewardTypeAllComplete:
			if request.QuestType != "" {
				return rewardDefinition{}, ErrInvalidReward
			}
			return rewardDefinition{rewardKey: prefix + "all_complete", diamonds: dailyAllCompleteRewardDiamonds}, nil
		case RewardTypeAttendance:
			if request.QuestType != "" {
				return rewardDefinition{}, ErrInvalidReward
			}
			return rewardDefinition{rewardKey: prefix + "attendance", diamonds: dailyAttendanceRewardDiamonds}, nil
		default:
			return rewardDefinition{}, ErrInvalidReward
		}
	}
	if request.Period != "weekly" {
		return rewardDefinition{}, ErrInvalidReward
	}
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
	if request.Period == "" {
		request.Period = "weekly"
	}
	if evidence.DailyQuestClockRollbackDetected {
		return ErrNotEligible
	}
	if request.Period == "daily" {
		switch request.RewardType {
		case RewardTypeQuest:
			if evidence.DailyQuestProgress[request.QuestType] < dailyQuestTargets[request.QuestType] ||
				contains(evidence.ClaimedDailyQuestRewards, request.QuestType) {
				return ErrNotEligible
			}
		case RewardTypeAllComplete:
			if evidence.DailyQuestAllCompleteClaimed {
				return ErrNotEligible
			}
			for questType, target := range dailyQuestTargets {
				if evidence.DailyQuestProgress[questType] < target {
					return ErrNotEligible
				}
			}
		case RewardTypeAttendance:
			if evidence.DailyAttendanceRewardClaimed {
				return ErrNotEligible
			}
		default:
			return ErrInvalidReward
		}
		return nil
	}
	if request.Period != "weekly" {
		return ErrInvalidReward
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
	if evidence.DailyQuestProgress == nil {
		evidence.DailyQuestProgress = map[string]int64{}
	}
	return evidence, nil
}

func rewardPeriod(period string, now time.Time) (string, int64) {
	if period == "daily" {
		adjusted := now.UTC().Add(resetOffset)
		return adjusted.Format("2006-01-02"), adjusted.UnixMilli() / int64((24*time.Hour)/time.Millisecond)
	}
	return weeklyPeriod(now)
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

func formatUUID(value pgtype.UUID) string {
	if !value.Valid {
		return ""
	}
	return fmt.Sprintf("%x-%x-%x-%x-%x", value.Bytes[0:4], value.Bytes[4:6], value.Bytes[6:8], value.Bytes[8:10], value.Bytes[10:16])
}
