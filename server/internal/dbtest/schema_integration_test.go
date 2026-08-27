//go:build integration

package dbtest_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
)

const (
	uniqueViolation     = "23505"
	checkViolation      = "23514"
	testDatabaseTimeout = 10 * time.Second
)

func TestAccountSessionAndRefreshConstraints(t *testing.T) {
	ctx, tx, queries := openTestTransaction(t)
	account, err := queries.CreateAccount(ctx)
	if err != nil {
		t.Fatalf("create account: %v", err)
	}
	if !account.ID.Valid || account.ID.Bytes[6]>>4 != 7 {
		t.Fatalf("account ID is not UUIDv7: %v", account.ID)
	}

	identity, err := queries.CreateAuthIdentity(ctx, dbgen.CreateAuthIdentityParams{
		AccountID: account.ID,
		Provider:  "play_games",
		Subject:   "player-123",
	})
	if err != nil {
		t.Fatalf("create identity: %v", err)
	}
	resolvedAccount, err := queries.GetAccountByIdentity(
		ctx,
		dbgen.GetAccountByIdentityParams{
			Provider: "play_games",
			Subject:  "player-123",
		},
	)
	if err != nil {
		t.Fatalf("get account by identity: %v", err)
	}
	if resolvedAccount.ID != account.ID || identity.AccountID != account.ID {
		t.Fatal("identity resolved to a different account")
	}

	now := time.Now().UTC()
	accessHash := repeatedHash(1)
	session, err := queries.CreateSession(ctx, dbgen.CreateSessionParams{
		AccountID:        account.ID,
		AccessTokenHash:  accessHash,
		AccessExpiresAt:  timestamptz(now.Add(15 * time.Minute)),
		RefreshExpiresAt: timestamptz(now.Add(30 * 24 * time.Hour)),
	})
	if err != nil {
		t.Fatalf("create session: %v", err)
	}
	if _, err := queries.GetActiveSessionByAccessTokenHash(ctx, accessHash); err != nil {
		t.Fatalf("get active session: %v", err)
	}

	rootToken, err := queries.CreateRefreshToken(ctx, dbgen.CreateRefreshTokenParams{
		SessionID: session.ID,
		TokenHash: repeatedHash(2),
	})
	if err != nil {
		t.Fatalf("create refresh token: %v", err)
	}

	if _, err := tx.Exec(ctx, "SAVEPOINT duplicate_active_token"); err != nil {
		t.Fatalf("create savepoint: %v", err)
	}
	_, duplicateErr := queries.CreateRefreshToken(ctx, dbgen.CreateRefreshTokenParams{
		SessionID: session.ID,
		TokenHash: repeatedHash(3),
	})
	requirePostgresError(t, duplicateErr, uniqueViolation, "refresh_tokens_active_session_key")
	if _, err := tx.Exec(ctx, "ROLLBACK TO SAVEPOINT duplicate_active_token"); err != nil {
		t.Fatalf("rollback savepoint: %v", err)
	}

	if _, err := queries.ConsumeRefreshToken(ctx, rootToken.ID); err != nil {
		t.Fatalf("consume refresh token: %v", err)
	}
	childHash := repeatedHash(4)
	childToken, err := queries.CreateRefreshToken(ctx, dbgen.CreateRefreshTokenParams{
		SessionID:     session.ID,
		TokenHash:     childHash,
		ParentTokenID: rootToken.ID,
	})
	if err != nil {
		t.Fatalf("create child refresh token: %v", err)
	}
	lockedToken, err := queries.GetRefreshTokenForUpdate(ctx, childHash)
	if err != nil {
		t.Fatalf("lock refresh token and session: %v", err)
	}
	if lockedToken.ID != childToken.ID || lockedToken.AccountStatus != "active" {
		t.Fatal("locked refresh state does not match the active session")
	}

	_, err = queries.UpdateAccountStatus(ctx, dbgen.UpdateAccountStatusParams{
		ID:     account.ID,
		Status: "suspended",
	})
	if err != nil {
		t.Fatalf("suspend account: %v", err)
	}
	_, err = queries.GetActiveSessionByAccessTokenHash(ctx, accessHash)
	if !errors.Is(err, pgx.ErrNoRows) {
		t.Fatalf("suspended account access error = %v, want no rows", err)
	}
}

func TestOnlineSaveQueriesPreserveRevisionAndReceipt(t *testing.T) {
	ctx, tx, queries := openTestTransaction(t)
	account, err := queries.CreateAccount(ctx)
	if err != nil {
		t.Fatalf("create account: %v", err)
	}
	if err := queries.EnsureSaveHeader(ctx, account.ID); err != nil {
		t.Fatalf("ensure save header: %v", err)
	}
	header, err := queries.GetSaveHeaderForUpdate(ctx, account.ID)
	if err != nil {
		t.Fatalf("lock save header: %v", err)
	}
	if header.Revision != 0 {
		t.Fatalf("initial revision = %d, want 0", header.Revision)
	}

	preferences := []byte(`{"selectedStageNumber":2}`)
	progression := []byte(`{"runes":30}`)
	turretModules := []byte(`{"tickets":4}`)
	activeRun := []byte(`{"roundIndex":3}`)
	if err := queries.UpsertSavePreferences(ctx, dbgen.UpsertSavePreferencesParams{
		AccountID: account.ID,
		Payload:   preferences,
	}); err != nil {
		t.Fatalf("upsert preferences: %v", err)
	}
	if err := queries.UpsertSaveProgression(ctx, dbgen.UpsertSaveProgressionParams{
		AccountID: account.ID,
		Payload:   progression,
	}); err != nil {
		t.Fatalf("upsert progression: %v", err)
	}
	if err := queries.UpsertSaveTurretModules(ctx, dbgen.UpsertSaveTurretModulesParams{
		AccountID: account.ID,
		Payload:   turretModules,
	}); err != nil {
		t.Fatalf("upsert turret modules: %v", err)
	}
	if err := queries.UpsertSaveActiveRun(ctx, dbgen.UpsertSaveActiveRunParams{
		AccountID: account.ID,
		Payload:   activeRun,
	}); err != nil {
		t.Fatalf("upsert active run: %v", err)
	}

	advanced, err := queries.AdvanceSaveHeader(ctx, dbgen.AdvanceSaveHeaderParams{
		AccountID:           account.ID,
		SchemaVersion:       2,
		ClientSavedAtMillis: 1234,
		Revision:            0,
	})
	if err != nil {
		t.Fatalf("advance save header: %v", err)
	}
	if advanced.Revision != 1 {
		t.Fatalf("resulting revision = %d, want 1", advanced.Revision)
	}

	idempotencyKey := testUUID(1)
	receipt, err := queries.CreateSaveRequest(ctx, dbgen.CreateSaveRequestParams{
		AccountID:         account.ID,
		IdempotencyKey:    idempotencyKey,
		RequestHash:       repeatedHash(5),
		WriterGeneration: 1,
		ExpectedRevision:  0,
		ResultingRevision: advanced.Revision,
		ResultSavedAt:     advanced.UpdatedAt,
	})
	if err != nil {
		t.Fatalf("create save receipt: %v", err)
	}
	storedReceipt, err := queries.GetSaveRequest(ctx, dbgen.GetSaveRequestParams{
		AccountID:      account.ID,
		IdempotencyKey: idempotencyKey,
	})
	if err != nil {
		t.Fatalf("get save receipt: %v", err)
	}
	if storedReceipt.ResultingRevision != receipt.ResultingRevision ||
		!bytes.Equal(storedReceipt.RequestHash, receipt.RequestHash) {
		t.Fatal("stored save receipt differs from the created receipt")
	}

	snapshot, err := queries.GetSaveSnapshot(ctx, account.ID)
	if err != nil {
		t.Fatalf("get save snapshot: %v", err)
	}
	if snapshot.SchemaVersion != 2 || snapshot.Revision != 1 ||
		snapshot.ClientSavedAtMillis != 1234 {
		t.Fatalf("unexpected snapshot header: %+v", snapshot)
	}
	requireSameJSON(t, snapshot.Preferences, preferences)
	requireSameJSON(t, snapshot.Progression, progression)
	requireSameJSON(t, snapshot.TurretModules, turretModules)
	requireSameJSON(t, snapshot.ActiveRun, activeRun)

	_, err = queries.AdvanceSaveHeader(ctx, dbgen.AdvanceSaveHeaderParams{
		AccountID:           account.ID,
		SchemaVersion:       2,
		ClientSavedAtMillis: 5678,
		Revision:            0,
	})
	if !errors.Is(err, pgx.ErrNoRows) {
		t.Fatalf("stale revision error = %v, want no rows", err)
	}

	if err := queries.DeleteSaveActiveRun(ctx, account.ID); err != nil {
		t.Fatalf("delete active run: %v", err)
	}
	snapshot, err = queries.GetSaveSnapshot(ctx, account.ID)
	if err != nil {
		t.Fatalf("get save snapshot without active run: %v", err)
	}
	if snapshot.ActiveRun != nil {
		t.Fatalf("active run = %s, want nil", snapshot.ActiveRun)
	}

	if _, err := tx.Exec(ctx, "DELETE FROM accounts WHERE id = $1", account.ID); err != nil {
		t.Fatalf("delete account: %v", err)
	}
	var saveHeaderCount int
	if err := tx.QueryRow(
		ctx,
		"SELECT count(*) FROM save_headers WHERE account_id = $1",
		account.ID,
	).Scan(&saveHeaderCount); err != nil {
		t.Fatalf("count cascaded save headers: %v", err)
	}
	if saveHeaderCount != 0 {
		t.Fatalf("save header count after account delete = %d", saveHeaderCount)
	}
}

func TestSavePayloadMustBeJSONObject(t *testing.T) {
	ctx, tx, queries := openTestTransaction(t)
	account, err := queries.CreateAccount(ctx)
	if err != nil {
		t.Fatalf("create account: %v", err)
	}
	if err := queries.EnsureSaveHeader(ctx, account.ID); err != nil {
		t.Fatalf("ensure save header: %v", err)
	}
	_, err = tx.Exec(
		ctx,
		"INSERT INTO save_preferences (account_id, payload) VALUES ($1, '[]'::jsonb)",
		account.ID,
	)
	requirePostgresError(t, err, checkViolation, "save_preferences_payload_check")
}

func openTestTransaction(t *testing.T) (context.Context, pgx.Tx, *dbgen.Queries) {
	t.Helper()
	databaseURL := os.Getenv("RUNE_NEXUS_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("RUNE_NEXUS_TEST_DATABASE_URL is not set")
	}
	config, err := pgx.ParseConfig(databaseURL)
	if err != nil {
		t.Fatalf("parse test database URL: %v", err)
	}
	if passwordFile := os.Getenv("RUNE_NEXUS_TEST_DATABASE_PASSWORD_FILE"); passwordFile != "" {
		password, err := os.ReadFile(passwordFile)
		if err != nil {
			t.Fatalf("read test database password: %v", err)
		}
		config.Password = strings.TrimSpace(string(password))
	}

	ctx, cancel := context.WithTimeout(context.Background(), testDatabaseTimeout)
	t.Cleanup(cancel)
	connection, err := pgx.ConnectConfig(ctx, config)
	if err != nil {
		t.Fatalf("connect test database: %v", err)
	}
	t.Cleanup(func() {
		closeContext, closeCancel := context.WithTimeout(
			context.Background(),
			testDatabaseTimeout,
		)
		defer closeCancel()
		if err := connection.Close(closeContext); err != nil {
			t.Errorf("close test database: %v", err)
		}
	})
	tx, err := connection.Begin(ctx)
	if err != nil {
		t.Fatalf("begin test transaction: %v", err)
	}
	t.Cleanup(func() {
		rollbackContext, rollbackCancel := context.WithTimeout(
			context.Background(),
			testDatabaseTimeout,
		)
		defer rollbackCancel()
		if err := tx.Rollback(rollbackContext);
			err != nil && !errors.Is(err, pgx.ErrTxClosed) {
			t.Errorf("rollback test transaction: %v", err)
		}
	})
	return ctx, tx, dbgen.New(tx)
}

func requirePostgresError(t *testing.T, err error, code string, constraint string) {
	t.Helper()
	var postgresError *pgconn.PgError
	if !errors.As(err, &postgresError) {
		t.Fatalf("error = %v, want PostgreSQL error", err)
	}
	if postgresError.Code != code || postgresError.ConstraintName != constraint {
		t.Fatalf(
			"PostgreSQL error = (%s, %s), want (%s, %s)",
			postgresError.Code,
			postgresError.ConstraintName,
			code,
			constraint,
		)
	}
}

func requireSameJSON(t *testing.T, actual []byte, expected []byte) {
	t.Helper()
	var actualValue any
	if err := json.Unmarshal(actual, &actualValue); err != nil {
		t.Fatalf("decode actual JSON: %v", err)
	}
	var expectedValue any
	if err := json.Unmarshal(expected, &expectedValue); err != nil {
		t.Fatalf("decode expected JSON: %v", err)
	}
	actualJSON, err := json.Marshal(actualValue)
	if err != nil {
		t.Fatalf("encode actual JSON: %v", err)
	}
	expectedJSON, err := json.Marshal(expectedValue)
	if err != nil {
		t.Fatalf("encode expected JSON: %v", err)
	}
	if !bytes.Equal(actualJSON, expectedJSON) {
		t.Fatalf("JSON = %s, want %s", actualJSON, expectedJSON)
	}
}

func repeatedHash(value byte) []byte {
	return bytes.Repeat([]byte{value}, 32)
}

func testUUID(lastByte byte) pgtype.UUID {
	value := [16]byte{6: 0x70, 8: 0x80, 15: lastByte}
	return pgtype.UUID{Bytes: value, Valid: true}
}

func timestamptz(value time.Time) pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: value, Valid: true}
}
