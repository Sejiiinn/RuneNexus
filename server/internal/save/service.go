package save

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

const CurrentSchemaVersion int32 = 2

var (
	ErrNotFound              = errors.New("save not found")
	ErrIdempotencyKeyInvalid = errors.New("idempotency key is invalid")
	ErrIdempotencyKeyReused  = errors.New("idempotency key was reused with another body")
)

type RevisionConflictError struct {
	CurrentRevision int64
}

func (err *RevisionConflictError) Error() string {
	return fmt.Sprintf("save revision conflict: current revision is %d", err.CurrentRevision)
}

type Data struct {
	Version       int32
	SavedAtMillis int64
	Preferences   json.RawMessage
	Progression   json.RawMessage
	TurretModules json.RawMessage
	ActiveRun     json.RawMessage
}

type Snapshot struct {
	Revision      int64
	ServerSavedAt time.Time
	Data          Data
}

type UpdateRequest struct {
	IdempotencyKey   string
	ExpectedRevision int64
	RawBody          []byte
	Data             Data
}

type UpdateResult struct {
	Revision      int64
	ServerSavedAt time.Time
}

type Service struct {
	database *pgxpool.Pool
}

func NewService(database *pgxpool.Pool) *Service {
	return &Service{database: database}
}

func ValidateIdempotencyKey(value string) error {
	_, err := parseUUID(value)
	return err
}

func (service *Service) Get(ctx context.Context, accountID string) (Snapshot, error) {
	databaseAccountID, err := parseUUID(accountID)
	if err != nil {
		return Snapshot{}, fmt.Errorf("parse authenticated account ID: %w", err)
	}
	snapshot, err := dbgen.New(service.database).GetSaveSnapshot(ctx, databaseAccountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return Snapshot{}, ErrNotFound
	}
	if err != nil {
		return Snapshot{}, fmt.Errorf("get save snapshot: %w", err)
	}
	if !snapshot.UpdatedAt.Valid {
		return Snapshot{}, errors.New("save snapshot has no server timestamp")
	}
	return Snapshot{
		Revision:      snapshot.Revision,
		ServerSavedAt: snapshot.UpdatedAt.Time.UTC(),
		Data: Data{
			Version:       snapshot.SchemaVersion,
			SavedAtMillis: snapshot.ClientSavedAtMillis,
			Preferences:   snapshot.Preferences,
			Progression:   snapshot.Progression,
			TurretModules: snapshot.TurretModules,
			ActiveRun:     snapshot.ActiveRun,
		},
	}, nil
}

func (service *Service) Update(
	ctx context.Context,
	accountID string,
	request UpdateRequest,
) (UpdateResult, error) {
	databaseAccountID, err := parseUUID(accountID)
	if err != nil {
		return UpdateResult{}, fmt.Errorf("parse authenticated account ID: %w", err)
	}
	idempotencyKey, err := parseUUID(request.IdempotencyKey)
	if err != nil {
		return UpdateResult{}, ErrIdempotencyKeyInvalid
	}
	requestHash := sha256.Sum256(request.RawBody)

	queries := dbgen.New(service.database)
	storedRequest, err := queries.GetSaveRequest(ctx, dbgen.GetSaveRequestParams{
		AccountID:      databaseAccountID,
		IdempotencyKey: idempotencyKey,
	})
	if err == nil {
		return resultFromReceipt(storedRequest, requestHash[:])
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return UpdateResult{}, fmt.Errorf("get save request receipt: %w", err)
	}

	tx, err := service.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return UpdateResult{}, fmt.Errorf("begin save transaction: %w", err)
	}
	defer func() {
		_ = tx.Rollback(ctx)
	}()
	txQueries := dbgen.New(tx)

	if err := txQueries.EnsureSaveHeader(ctx, databaseAccountID); err != nil {
		return UpdateResult{}, fmt.Errorf("ensure save header: %w", err)
	}
	header, err := txQueries.GetSaveHeaderForUpdate(ctx, databaseAccountID)
	if err != nil {
		return UpdateResult{}, fmt.Errorf("lock save header: %w", err)
	}

	storedRequest, err = txQueries.GetSaveRequest(ctx, dbgen.GetSaveRequestParams{
		AccountID:      databaseAccountID,
		IdempotencyKey: idempotencyKey,
	})
	if err == nil {
		return resultFromReceipt(storedRequest, requestHash[:])
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return UpdateResult{}, fmt.Errorf("recheck save request receipt: %w", err)
	}
	if header.Revision != request.ExpectedRevision {
		return UpdateResult{}, &RevisionConflictError{
			CurrentRevision: header.Revision,
		}
	}

	if err := txQueries.UpsertSavePreferences(
		ctx,
		dbgen.UpsertSavePreferencesParams{
			AccountID: databaseAccountID,
			Payload:   request.Data.Preferences,
		},
	); err != nil {
		return UpdateResult{}, fmt.Errorf("upsert save preferences: %w", err)
	}
	if err := txQueries.UpsertSaveProgression(
		ctx,
		dbgen.UpsertSaveProgressionParams{
			AccountID: databaseAccountID,
			Payload:   request.Data.Progression,
		},
	); err != nil {
		return UpdateResult{}, fmt.Errorf("upsert save progression: %w", err)
	}
	if err := txQueries.UpsertSaveTurretModules(
		ctx,
		dbgen.UpsertSaveTurretModulesParams{
			AccountID: databaseAccountID,
			Payload:   request.Data.TurretModules,
		},
	); err != nil {
		return UpdateResult{}, fmt.Errorf("upsert save turret modules: %w", err)
	}
	if request.Data.ActiveRun == nil {
		if err := txQueries.DeleteSaveActiveRun(ctx, databaseAccountID); err != nil {
			return UpdateResult{}, fmt.Errorf("delete save active run: %w", err)
		}
	} else if err := txQueries.UpsertSaveActiveRun(
		ctx,
		dbgen.UpsertSaveActiveRunParams{
			AccountID: databaseAccountID,
			Payload:   request.Data.ActiveRun,
		},
	); err != nil {
		return UpdateResult{}, fmt.Errorf("upsert save active run: %w", err)
	}

	advanced, err := txQueries.AdvanceSaveHeader(ctx, dbgen.AdvanceSaveHeaderParams{
		AccountID:           databaseAccountID,
		SchemaVersion:       request.Data.Version,
		ClientSavedAtMillis: request.Data.SavedAtMillis,
		Revision:            request.ExpectedRevision,
	})
	if err != nil {
		return UpdateResult{}, fmt.Errorf("advance save header: %w", err)
	}
	if !advanced.UpdatedAt.Valid {
		return UpdateResult{}, errors.New("advanced save has no server timestamp")
	}
	if _, err := txQueries.CreateSaveRequest(ctx, dbgen.CreateSaveRequestParams{
		AccountID:         databaseAccountID,
		IdempotencyKey:    idempotencyKey,
		RequestHash:       requestHash[:],
		ExpectedRevision:  request.ExpectedRevision,
		ResultingRevision: advanced.Revision,
		ResultSavedAt:     advanced.UpdatedAt,
	}); err != nil {
		return UpdateResult{}, fmt.Errorf("create save request receipt: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return UpdateResult{}, fmt.Errorf("commit save transaction: %w", err)
	}
	return UpdateResult{
		Revision:      advanced.Revision,
		ServerSavedAt: advanced.UpdatedAt.Time.UTC(),
	}, nil
}

func resultFromReceipt(
	receipt dbgen.SaveRequest,
	requestHash []byte,
) (UpdateResult, error) {
	if !bytes.Equal(receipt.RequestHash, requestHash) {
		return UpdateResult{}, ErrIdempotencyKeyReused
	}
	if !receipt.ResultSavedAt.Valid {
		return UpdateResult{}, errors.New("save request receipt has no server timestamp")
	}
	return UpdateResult{
		Revision:      receipt.ResultingRevision,
		ServerSavedAt: receipt.ResultSavedAt.Time.UTC(),
	}, nil
}

func parseUUID(value string) (pgtype.UUID, error) {
	if len(value) != 36 || value[8] != '-' || value[13] != '-' ||
		value[18] != '-' || value[23] != '-' {
		return pgtype.UUID{}, errors.New("UUID must use canonical text form")
	}
	compact := value[:8] + value[9:13] + value[14:18] +
		value[19:23] + value[24:]
	decoded, err := hex.DecodeString(compact)
	if err != nil {
		return pgtype.UUID{}, fmt.Errorf("decode UUID: %w", err)
	}
	var result pgtype.UUID
	copy(result.Bytes[:], decoded)
	result.Valid = true
	return result, nil
}
