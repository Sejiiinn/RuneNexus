package economy

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

type Service struct {
	database *pgxpool.Pool
	now      func() time.Time
}

func NewService(database *pgxpool.Pool) *Service {
	return &Service{database: database, now: time.Now}
}

func (service *Service) Get(ctx context.Context, accountID string) (Snapshot, error) {
	databaseAccountID, err := parseUUID(accountID)
	if err != nil {
		return Snapshot{}, fmt.Errorf("parse economy account ID: %w", err)
	}
	tx, err := service.database.BeginTx(ctx, pgx.TxOptions{
		IsoLevel:   pgx.RepeatableRead,
		AccessMode: pgx.ReadOnly,
	})
	if err != nil {
		return Snapshot{}, fmt.Errorf("begin economy snapshot: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	queries := dbgen.New(tx)
	economy, err := queries.GetPlayerEconomy(ctx, databaseAccountID)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && economy.AuthorityState != "server_authoritative") {
		return Snapshot{}, ErrNotBootstrapped
	}
	if err != nil {
		return Snapshot{}, fmt.Errorf("get player economy: %w", err)
	}
	snapshot, err := service.snapshot(ctx, queries, economy)
	if err != nil {
		return Snapshot{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return Snapshot{}, fmt.Errorf("commit economy snapshot: %w", err)
	}
	return snapshot, nil
}

func (service *Service) snapshot(
	ctx context.Context,
	queries *dbgen.Queries,
	economy dbgen.PlayerEconomy,
) (Snapshot, error) {
	system, err := queries.GetEconomySystemState(ctx)
	if err != nil {
		return Snapshot{}, fmt.Errorf("get economy system state: %w", err)
	}
	modules, err := queries.ListActivePlayerModules(ctx, economy.AccountID)
	if err != nil {
		return Snapshot{}, fmt.Errorf("list player modules: %w", err)
	}
	effects, err := queries.ListPendingEconomyProgressionEffects(ctx, economy.AccountID)
	if err != nil {
		return Snapshot{}, fmt.Errorf("list progression effects: %w", err)
	}
	claimKeys, err := queries.ListEconomyRewardClaimKeys(ctx, economy.AccountID)
	if err != nil {
		return Snapshot{}, fmt.Errorf("list reward claims: %w", err)
	}

	result := Snapshot{
		AuthorityEpoch:   formatUUID(system.AuthorityEpoch),
		AuthorityState:   economy.AuthorityState,
		AuthorityVersion: economy.AuthorityVersion,
		EconomyRevision:  economy.Revision,
		CatalogVersion:   CatalogVersion,
		ServerTime:       service.now().UTC(),
		Wallet: Wallet{
			FreeDiamonds:  economy.FreeDiamonds,
			PaidDiamonds:  economy.PaidDiamonds,
			ModuleTickets: economy.ModuleTickets,
		},
		PendingProgressionEffects: make([]ProgressionEffect, 0, len(effects)),
		ClaimedRewardKeys:         claimKeys,
	}
	result.TurretModules.DrawCount = economy.ModuleDrawCount
	result.TurretModules.TicketPurchaseCount = economy.ModuleTicketPurchaseCount
	result.TurretModules.Items = make([]Module, 0, len(modules))
	result.Entitlements.ResearchSlotTwoUnlocked = economy.ResearchSlotTwoUnlocked
	for _, module := range modules {
		decoded, err := moduleFromRow(module)
		if err != nil {
			return Snapshot{}, err
		}
		result.TurretModules.Items = append(result.TurretModules.Items, decoded)
	}
	for _, effect := range effects {
		var payload map[string]any
		if err := json.Unmarshal(effect.Payload, &payload); err != nil {
			return Snapshot{}, fmt.Errorf("decode progression effect: %w", err)
		}
		result.PendingProgressionEffects = append(result.PendingProgressionEffects, ProgressionEffect{
			ID: formatUUID(effect.ID), EffectType: effect.EffectType, Payload: payload,
		})
	}
	return result, nil
}

func moduleFromRow(row dbgen.PlayerModule) (Module, error) {
	var options []moduleOption
	if err := json.Unmarshal(row.Options, &options); err != nil {
		return Module{}, fmt.Errorf("decode player module options: %w", err)
	}
	legacyID := ""
	if row.LegacyItemID.Valid {
		legacyID = row.LegacyItemID.String
	}
	return Module{
		ID: formatUUID(row.ID), LegacyItemID: legacyID, TurretType: row.TurretType,
		Part: row.Part, Family: row.Family, Grade: row.Grade,
		Options: options, AcquiredOrder: row.AcquiredOrder,
	}, nil
}

func existingCommandResult[T any](
	command dbgen.EconomyCommand,
	requestHash []byte,
) (T, error) {
	var zero T
	if !bytes.Equal(command.RequestHash, requestHash) {
		return zero, ErrIdempotencyKeyReused
	}
	var result T
	if err := json.Unmarshal(command.ResponsePayload, &result); err != nil {
		return zero, fmt.Errorf("decode economy command receipt: %w", err)
	}
	return result, nil
}

func requestIdentity(idempotencyKey string, rawBody []byte) (pgtype.UUID, []byte, error) {
	key, err := parseUUID(idempotencyKey)
	if err != nil {
		return pgtype.UUID{}, nil, ErrInvalidIdempotencyKey
	}
	hash := sha256.Sum256(rawBody)
	return key, hash[:], nil
}

func parseUUID(value string) (pgtype.UUID, error) {
	if len(value) != 36 || value[8] != '-' || value[13] != '-' || value[18] != '-' || value[23] != '-' {
		return pgtype.UUID{}, errors.New("UUID must use canonical text form")
	}
	compact := value[:8] + value[9:13] + value[14:18] + value[19:23] + value[24:]
	decoded, err := hex.DecodeString(compact)
	if err != nil {
		return pgtype.UUID{}, fmt.Errorf("decode UUID: %w", err)
	}
	var result pgtype.UUID
	copy(result.Bytes[:], decoded)
	result.Valid = true
	return result, nil
}

func formatUUID(value pgtype.UUID) string {
	if !value.Valid {
		return ""
	}
	hexValue := hex.EncodeToString(value.Bytes[:])
	return hexValue[:8] + "-" + hexValue[8:12] + "-" + hexValue[12:16] + "-" + hexValue[16:20] + "-" + hexValue[20:]
}

func int4(value int32) pgtype.Int4       { return pgtype.Int4{Int32: value, Valid: true} }
func int8(value int64) pgtype.Int8       { return pgtype.Int8{Int64: value, Valid: true} }
func textValue(value string) pgtype.Text { return pgtype.Text{String: value, Valid: value != ""} }
