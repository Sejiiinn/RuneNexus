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

// commandIdentity names one economy command receipt. A stored receipt replays
// only for the same command type and the same request hash; the hash binds the
// URL target (research type, effect, mail), when the route has one, to the body.
type commandIdentity struct {
	key         pgtype.UUID
	commandType string
	requestHash []byte
	// Body-only hash that research completion and effect acknowledgement stored
	// before their URL target was bound. Such receipts still replay for the same
	// type and body; their target was never recorded.
	legacyHash []byte
}

// Command types whose receipts once hashed the body without their URL target.
var bodyOnlyLegacyCommandTypes = map[string]bool{
	"research_complete":      true,
	"progression_effect_ack": true,
}

func newCommandIdentity(idempotencyKey, commandType, target string, rawBody []byte) (commandIdentity, error) {
	key, err := parseUUID(idempotencyKey)
	if err != nil {
		return commandIdentity{}, ErrInvalidIdempotencyKey
	}
	identity := commandIdentity{key: key, commandType: commandType}
	if target == "" {
		hash := sha256.Sum256(rawBody)
		identity.requestHash = hash[:]
		return identity, nil
	}
	hash := sha256.Sum256(append([]byte(target+"\n"), rawBody...))
	identity.requestHash = hash[:]
	if bodyOnlyLegacyCommandTypes[commandType] {
		legacy := sha256.Sum256(rawBody)
		identity.legacyHash = legacy[:]
	}
	return identity, nil
}

func (identity commandIdentity) matches(command dbgen.EconomyCommand) bool {
	if command.CommandType != identity.commandType {
		return false
	}
	return bytes.Equal(command.RequestHash, identity.requestHash) ||
		(identity.legacyHash != nil && bytes.Equal(command.RequestHash, identity.legacyHash))
}

// storedCommandResult replays the receipt stored under the identity's key.
// found is false when the key has no receipt yet; a receipt for a different
// command, target or body is ErrIdempotencyKeyReused.
func storedCommandResult[T any](
	ctx context.Context,
	queries *dbgen.Queries,
	accountID pgtype.UUID,
	identity commandIdentity,
) (result T, found bool, err error) {
	command, err := queries.GetEconomyCommand(ctx, dbgen.GetEconomyCommandParams{AccountID: accountID, IdempotencyKey: identity.key})
	if errors.Is(err, pgx.ErrNoRows) {
		return result, false, nil
	}
	if err != nil {
		return result, false, fmt.Errorf("get %s receipt: %w", identity.commandType, err)
	}
	if !identity.matches(command) {
		return result, true, ErrIdempotencyKeyReused
	}
	if err := json.Unmarshal(command.ResponsePayload, &result); err != nil {
		return result, true, fmt.Errorf("decode %s receipt: %w", identity.commandType, err)
	}
	return result, true, nil
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
