package legacytransfer

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/Sejiiinn/RuneNexus/server/internal/session"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	maxImportedFreeDiamonds  int64 = 1_000_000
	maxImportedRunes         int64 = 2_000_000_000
	maxImportedModuleTickets int64 = 1_000_000
	maxImportedModuleItems         = 10_000
)

var (
	ErrInvalidData          = errors.New("legacy transfer data is invalid")
	ErrInvalidToken         = errors.New("legacy transfer token is invalid or expired")
	ErrTokenAlreadyUsed     = errors.New("legacy transfer token was consumed by another account")
	ErrTargetNotReplaceable = errors.New("target account save cannot be safely replaced")
	ErrSessionMismatch      = errors.New("session does not belong to target account")
	ErrUnsupportedPaidFunds = errors.New("paid diamonds cannot be imported")
)

type CreateRequest struct {
	RawBody []byte
	Data    gamesave.Data
}

type CreateResult struct {
	Token     string
	ExpiresAt time.Time
}

type ConsumeResult struct {
	Revision      int64
	ServerSavedAt time.Time
}

type progressionBounds struct {
	Runes        *int64 `json:"runes"`
	FreeDiamonds *int64 `json:"freeDiamonds"`
	PaidDiamonds *int64 `json:"paidDiamonds"`
}

type turretModuleBounds struct {
	Tickets *int64            `json:"tickets"`
	Items   []json.RawMessage `json:"items"`
}

type previousSave struct {
	replaced            bool
	schemaVersion       pgtype.Int4
	revision            pgtype.Int8
	clientSavedAtMillis pgtype.Int8
	preferences         []byte
	progression         []byte
	turretModules       []byte
	activeRun           []byte
}

type Service struct {
	database *pgxpool.Pool
	ttl      time.Duration
	now      func() time.Time
}

func NewService(database *pgxpool.Pool, ttl time.Duration) *Service {
	return &Service{database: database, ttl: ttl, now: time.Now}
}

func (service *Service) Create(
	ctx context.Context,
	request CreateRequest,
) (CreateResult, error) {
	if service.ttl <= 0 || len(request.RawBody) == 0 {
		return CreateResult{}, ErrInvalidData
	}
	if err := validateImportedData(request.Data); err != nil {
		return CreateResult{}, err
	}
	token, err := session.GenerateToken()
	if err != nil {
		return CreateResult{}, fmt.Errorf("generate legacy transfer token: %w", err)
	}
	now := service.now().UTC()
	expiresAt := now.Add(service.ttl)
	payloadHash := sha256.Sum256(request.RawBody)
	queries := dbgen.New(service.database)
	if _, err := queries.DeleteExpiredLegacySaveTransfers(
		ctx,
		timestamptz(now),
	); err != nil {
		return CreateResult{}, fmt.Errorf("delete expired legacy transfers: %w", err)
	}
	if _, err := queries.CreateLegacySaveTransfer(
		ctx,
		dbgen.CreateLegacySaveTransferParams{
			TokenHash:           token.Hash,
			PayloadHash:         payloadHash[:],
			SchemaVersion:       request.Data.Version,
			ClientSavedAtMillis: request.Data.SavedAtMillis,
			Preferences:         request.Data.Preferences,
			Progression:         request.Data.Progression,
			TurretModules:       request.Data.TurretModules,
			ActiveRun:           request.Data.ActiveRun,
			CreatedAt:           timestamptz(now),
			ExpiresAt:           timestamptz(expiresAt),
		},
	); err != nil {
		return CreateResult{}, fmt.Errorf("create legacy transfer: %w", err)
	}
	return CreateResult{Token: token.Raw, ExpiresAt: expiresAt}, nil
}

func (service *Service) Consume(
	ctx context.Context,
	accountID string,
	sessionID string,
	rawToken string,
) (ConsumeResult, error) {
	tokenHash, err := session.HashToken(rawToken)
	if err != nil {
		return ConsumeResult{}, ErrInvalidToken
	}
	databaseAccountID, err := parseUUID(accountID)
	if err != nil {
		return ConsumeResult{}, fmt.Errorf("parse target account ID: %w", err)
	}
	databaseSessionID, err := parseUUID(sessionID)
	if err != nil {
		return ConsumeResult{}, fmt.Errorf("parse target session ID: %w", err)
	}

	queries := dbgen.New(service.database)
	receipt, err := queries.GetLegacySaveTransferReceipt(ctx, tokenHash)
	if err == nil {
		return consumeResultFromReceipt(receipt, databaseAccountID)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return ConsumeResult{}, fmt.Errorf("get legacy transfer receipt: %w", err)
	}

	tx, err := service.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return ConsumeResult{}, fmt.Errorf("begin legacy transfer transaction: %w", err)
	}
	defer func() {
		_ = tx.Rollback(ctx)
	}()
	txQueries := dbgen.New(tx)
	transfer, err := txQueries.GetLegacySaveTransferForUpdate(ctx, tokenHash)
	if errors.Is(err, pgx.ErrNoRows) {
		receipt, receiptErr := txQueries.GetLegacySaveTransferReceipt(ctx, tokenHash)
		if receiptErr == nil {
			return consumeResultFromReceipt(receipt, databaseAccountID)
		}
		if !errors.Is(receiptErr, pgx.ErrNoRows) {
			return ConsumeResult{}, fmt.Errorf("recheck legacy transfer receipt: %w", receiptErr)
		}
		return ConsumeResult{}, ErrInvalidToken
	}
	if err != nil {
		return ConsumeResult{}, fmt.Errorf("lock legacy transfer: %w", err)
	}
	now := service.now().UTC()
	if !transfer.ExpiresAt.Valid || !transfer.ExpiresAt.Time.After(now) {
		if err := txQueries.DeleteLegacySaveTransfer(ctx, transfer.ID); err != nil {
			return ConsumeResult{}, fmt.Errorf("delete expired legacy transfer: %w", err)
		}
		if err := tx.Commit(ctx); err != nil {
			return ConsumeResult{}, fmt.Errorf("commit expired legacy transfer deletion: %w", err)
		}
		return ConsumeResult{}, ErrInvalidToken
	}

	activeSession, err := txQueries.IsActiveSessionForAccount(
		ctx,
		dbgen.IsActiveSessionForAccountParams{
			ID:        databaseSessionID,
			AccountID: databaseAccountID,
		},
	)
	if err != nil {
		return ConsumeResult{}, fmt.Errorf("validate legacy transfer session: %w", err)
	}
	if !activeSession {
		return ConsumeResult{}, ErrSessionMismatch
	}

	// 일반 저장과 같은 writer -> header 순서로 잠가 최초 저장 경쟁을 차단한다.
	if err := txQueries.EnsureSaveWriterState(ctx, databaseAccountID); err != nil {
		return ConsumeResult{}, fmt.Errorf("ensure legacy transfer save writer: %w", err)
	}
	if _, err := txQueries.GetSaveWriterStateForUpdate(ctx, databaseAccountID); err != nil {
		return ConsumeResult{}, fmt.Errorf("lock legacy transfer save writer: %w", err)
	}
	header, err := txQueries.GetSaveHeaderForUpdate(ctx, databaseAccountID)
	expectedRevision := int64(0)
	backup := previousSave{}
	if err == nil {
		snapshot, snapshotErr := txQueries.GetSaveSnapshot(ctx, databaseAccountID)
		if snapshotErr != nil {
			return ConsumeResult{}, fmt.Errorf("read target save backup: %w", snapshotErr)
		}
		if snapshot.Revision != header.Revision || validateReplaceableTarget(snapshot.Progression) != nil {
			return ConsumeResult{}, ErrTargetNotReplaceable
		}
		// 기존 브라우저의 writer를 무효화해 이전 직후 오래된 저장이 재전송되지 않게 한다.
		if _, err := txQueries.AdvanceSaveWriter(ctx, dbgen.AdvanceSaveWriterParams{
			AccountID:        databaseAccountID,
			SessionID:        databaseSessionID,
			ClientInstanceID: pgtype.UUID{},
		}); err != nil {
			return ConsumeResult{}, fmt.Errorf("invalidate previous save writer: %w", err)
		}
		expectedRevision = header.Revision
		backup = previousSave{
			replaced:            true,
			schemaVersion:       int4(header.SchemaVersion),
			revision:            int8(header.Revision),
			clientSavedAtMillis: int8(header.ClientSavedAtMillis),
			preferences:         snapshot.Preferences,
			progression:         snapshot.Progression,
			turretModules:       snapshot.TurretModules,
			activeRun:           snapshot.ActiveRun,
		}
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return ConsumeResult{}, fmt.Errorf("check target save: %w", err)
	}

	data := gamesave.Data{
		Version:       transfer.SchemaVersion,
		SavedAtMillis: transfer.ClientSavedAtMillis,
		Preferences:   transfer.Preferences,
		Progression:   transfer.Progression,
		TurretModules: transfer.TurretModules,
		ActiveRun:     transfer.ActiveRun,
	}
	if err := validateImportedData(data); err != nil {
		return ConsumeResult{}, err
	}
	if err := txQueries.EnsureSaveHeader(ctx, databaseAccountID); err != nil {
		return ConsumeResult{}, fmt.Errorf("ensure imported save header: %w", err)
	}
	if _, err := txQueries.GetSaveHeaderForUpdate(ctx, databaseAccountID); err != nil {
		return ConsumeResult{}, fmt.Errorf("lock imported save header: %w", err)
	}
	if err := storeImportedData(ctx, txQueries, databaseAccountID, data); err != nil {
		return ConsumeResult{}, err
	}
	advanced, err := txQueries.AdvanceSaveHeader(
		ctx,
		dbgen.AdvanceSaveHeaderParams{
			AccountID:           databaseAccountID,
			SchemaVersion:       data.Version,
			ClientSavedAtMillis: data.SavedAtMillis,
			Revision:            expectedRevision,
		},
	)
	if err != nil {
		return ConsumeResult{}, fmt.Errorf("advance imported save header: %w", err)
	}
	if !advanced.UpdatedAt.Valid {
		return ConsumeResult{}, errors.New("imported save has no server timestamp")
	}
	receipt, err = txQueries.CreateLegacySaveTransferReceipt(
		ctx,
		dbgen.CreateLegacySaveTransferReceiptParams{
			TransferID:                  transfer.ID,
			TokenHash:                   transfer.TokenHash,
			PayloadHash:                 transfer.PayloadHash,
			ConsumedAccountID:           databaseAccountID,
			ConsumedAt:                  timestamptz(now),
			ResultRevision:              advanced.Revision,
			ResultSavedAt:               advanced.UpdatedAt,
			ReplacedExistingSave:        backup.replaced,
			PreviousSchemaVersion:       backup.schemaVersion,
			PreviousRevision:            backup.revision,
			PreviousClientSavedAtMillis: backup.clientSavedAtMillis,
			PreviousPreferences:         backup.preferences,
			PreviousProgression:         backup.progression,
			PreviousTurretModules:       backup.turretModules,
			PreviousActiveRun:           backup.activeRun,
		},
	)
	if err != nil {
		return ConsumeResult{}, fmt.Errorf("create legacy transfer receipt: %w", err)
	}
	// 이전 원문은 계정 저장 반영과 같은 트랜잭션에서 즉시 제거한다.
	if err := txQueries.DeleteLegacySaveTransfer(ctx, transfer.ID); err != nil {
		return ConsumeResult{}, fmt.Errorf("delete consumed legacy transfer: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return ConsumeResult{}, fmt.Errorf("commit legacy transfer: %w", err)
	}
	return consumeResultFromReceipt(receipt, databaseAccountID)
}

func validateImportedData(data gamesave.Data) error {
	if data.Version != gamesave.CurrentSchemaVersion || data.SavedAtMillis < 0 ||
		!isJSONObject(data.Preferences) || !isJSONObject(data.Progression) ||
		!isJSONObject(data.TurretModules) ||
		(data.ActiveRun != nil && !isJSONObject(data.ActiveRun)) {
		return ErrInvalidData
	}
	var progression progressionBounds
	if err := json.Unmarshal(data.Progression, &progression); err != nil ||
		progression.Runes == nil || progression.FreeDiamonds == nil ||
		progression.PaidDiamonds == nil || *progression.Runes < 0 ||
		*progression.Runes > maxImportedRunes || *progression.FreeDiamonds < 0 ||
		*progression.FreeDiamonds > maxImportedFreeDiamonds {
		return ErrInvalidData
	}
	if *progression.PaidDiamonds != 0 {
		return ErrUnsupportedPaidFunds
	}
	var modules turretModuleBounds
	if err := json.Unmarshal(data.TurretModules, &modules); err != nil ||
		modules.Tickets == nil || *modules.Tickets < 0 ||
		*modules.Tickets > maxImportedModuleTickets || modules.Items == nil ||
		len(modules.Items) > maxImportedModuleItems {
		return ErrInvalidData
	}
	return nil
}

func validateReplaceableTarget(progression []byte) error {
	var bounds progressionBounds
	if err := json.Unmarshal(progression, &bounds); err != nil ||
		bounds.PaidDiamonds == nil || *bounds.PaidDiamonds != 0 {
		return ErrTargetNotReplaceable
	}
	return nil
}

func storeImportedData(
	ctx context.Context,
	queries *dbgen.Queries,
	accountID pgtype.UUID,
	data gamesave.Data,
) error {
	if err := queries.UpsertSavePreferences(ctx, dbgen.UpsertSavePreferencesParams{
		AccountID: accountID,
		Payload:   data.Preferences,
	}); err != nil {
		return fmt.Errorf("store imported preferences: %w", err)
	}
	if err := queries.UpsertSaveProgression(ctx, dbgen.UpsertSaveProgressionParams{
		AccountID: accountID,
		Payload:   data.Progression,
	}); err != nil {
		return fmt.Errorf("store imported progression: %w", err)
	}
	if err := queries.UpsertSaveTurretModules(ctx, dbgen.UpsertSaveTurretModulesParams{
		AccountID: accountID,
		Payload:   data.TurretModules,
	}); err != nil {
		return fmt.Errorf("store imported turret modules: %w", err)
	}
	if data.ActiveRun != nil {
		if err := queries.UpsertSaveActiveRun(ctx, dbgen.UpsertSaveActiveRunParams{
			AccountID: accountID,
			Payload:   data.ActiveRun,
		}); err != nil {
			return fmt.Errorf("store imported active run: %w", err)
		}
	} else if err := queries.DeleteSaveActiveRun(ctx, accountID); err != nil {
		return fmt.Errorf("clear imported active run: %w", err)
	}
	return nil
}

func consumeResultFromReceipt(
	receipt dbgen.LegacySaveTransferReceipt,
	accountID pgtype.UUID,
) (ConsumeResult, error) {
	if !receipt.ConsumedAccountID.Valid || receipt.ConsumedAccountID != accountID {
		return ConsumeResult{}, ErrTokenAlreadyUsed
	}
	if !receipt.ResultSavedAt.Valid {
		return ConsumeResult{}, errors.New("legacy transfer receipt has no save timestamp")
	}
	return ConsumeResult{
		Revision:      receipt.ResultRevision,
		ServerSavedAt: receipt.ResultSavedAt.Time.UTC(),
	}, nil
}

func isJSONObject(value []byte) bool {
	if len(value) == 0 {
		return false
	}
	var object map[string]json.RawMessage
	return json.Unmarshal(value, &object) == nil && object != nil
}

func parseUUID(value string) (pgtype.UUID, error) {
	if gamesave.ValidateUUID(value) != nil {
		return pgtype.UUID{}, errors.New("UUID must use canonical text form")
	}
	var parsed pgtype.UUID
	if err := parsed.Scan(value); err != nil || !parsed.Valid {
		return pgtype.UUID{}, errors.New("invalid UUID")
	}
	return parsed, nil
}

func timestamptz(value time.Time) pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: value.UTC(), Valid: true}
}

func int4(value int32) pgtype.Int4 {
	return pgtype.Int4{Int32: value, Valid: true}
}

func int8(value int64) pgtype.Int8 {
	return pgtype.Int8{Int64: value, Valid: true}
}
