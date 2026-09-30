//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/jackc/pgx/v5/pgtype"
)

func TestExpandedLeaderboardKeepsFixedIDsAndLogicalOrdering(t *testing.T) {
	ctx, tx, q := openTestTransaction(t)
	var account, command pgtype.UUID
	if err := tx.QueryRow(ctx, `INSERT INTO accounts(nickname,nickname_tag) VALUES ('Expanded','0001') RETURNING id`).Scan(&account); err != nil {
		t.Fatal(err)
	}
	if err := tx.QueryRow(ctx, `INSERT INTO economy_commands(account_id,idempotency_key,command_type,request_hash,resulting_revision,authority_epoch,response_payload) VALUES ($1,uuidv7(),'run_settlement',decode(repeat('00',32),'hex'),1,uuidv7(),'{}') RETURNING id`, account).Scan(&command); err != nil {
		t.Fatal(err)
	}
	order := []int32{1, 2, 3, 4, 5, 16, 17, 18, 19, 20, 6, 7, 8, 9, 10, 21, 22, 23, 24, 25, 11, 12, 13, 14, 15}
	for i, stage := range order {
		var ordinal int
		if err := tx.QueryRow(ctx, `SELECT stage_progression_ordinal($1)`, stage).Scan(&ordinal); err != nil {
			t.Fatal(err)
		}
		if ordinal != i+1 {
			t.Fatalf("stage %d ordinal=%d want %d", stage, ordinal, i+1)
		}
		arg := dbgen.UpsertProgressionLeaderboardRecordParams{AccountID: account, StageNumber: stage, CompletedRounds: 1, SourceCommandID: command}
		if err := q.UpsertProgressionLeaderboardRecord(ctx, arg); err != nil {
			t.Fatal(err)
		}
		var stored int32
		if err := tx.QueryRow(ctx, `SELECT stage_number FROM leaderboard_records WHERE account_id=$1`, account).Scan(&stored); err != nil {
			t.Fatal(err)
		}
		if stored != stage {
			t.Fatalf("fixed ID %d did not advance from logical predecessor: stored %d", stage, stored)
		}
	}
	// An ID that is numerically larger must not replace chapter 3's final map.
	if err := q.UpsertProgressionLeaderboardRecord(ctx, dbgen.UpsertProgressionLeaderboardRecordParams{AccountID: account, StageNumber: 25, CompletedRounds: 40, SourceCommandID: command}); err != nil {
		t.Fatal(err)
	}
	row, err := q.GetProgressionLeaderboard(ctx, account)
	if err != nil {
		t.Fatal(err)
	}
	var own struct {
		StageNumber     int `json:"stageNumber"`
		CompletedRounds int `json:"completedRounds"`
	}
	if err = json.Unmarshal(row.MyEntry, &own); err != nil {
		t.Fatal(err)
	}
	if own.StageNumber != 15 || own.CompletedRounds != 1 {
		t.Fatalf("chapter 3 record overwritten by chapter 2: %+v", own)
	}
}

func TestExpandedSaveMigrationAndNewStageSettlement(t *testing.T) {
	ctx, fixture, accountID := openSaveService(t)
	original := gamesave.UpdateRequest{IdempotencyKey: firstSaveKey, ClientCompatibilityVersion: 3, RawBody: []byte(`{"clientCompatibilityVersion":3}`), Data: gamesave.Data{Version: 2, Preferences: json.RawMessage(`{}`), Progression: json.RawMessage(`{"growthVersion":1,"freeDiamonds":100,"clearedStageNumbers":[6],"unlockedStageCount":7}`), TurretModules: json.RawMessage(`{"tickets":2,"items":[]}`)}}
	if _, err := fixture.Update(ctx, accountID, original); err != nil {
		t.Fatal(err)
	}
	migrated := original
	migrated.ExpectedRevision = 1
	migrated.IdempotencyKey = secondSaveKey
	migrated.ClientCompatibilityVersion = 4
	migrated.RawBody = []byte(`{"clientCompatibilityVersion":4,"expectedRevision":1}`)
	migrated.Data.Progression = json.RawMessage(`{"growthVersion":1,"progressionVersion":1,"unlockedStageIds":[1,2,3,4,5,6,7,16],"grandfatherUnlocks":["turret:lightning"],"freeDiamonds":100,"clearedStageNumbers":[6,16],"bestRoundsByStage":{"16":40}}`)
	migrated.Data.ActiveRun = json.RawMessage(`{"stageNumber":16,"completedRounds":40}`)
	if _, err := fixture.Update(ctx, accountID, migrated); err != nil {
		t.Fatal(err)
	}
	if _, err := fixture.Update(ctx, accountID, original); err != nil {
		t.Fatalf("old exact receipt unrecoverable: %v", err)
	}
	old := original
	old.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90bc1"
	old.ExpectedRevision = 2
	old.RawBody = []byte(`{"clientCompatibilityVersion":3,"expectedRevision":2}`)
	if _, err := fixture.Update(ctx, accountID, old); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old write error=%v", err)
	}
	if _, err := fixture.service.ClaimWriter(ctx, accountID, fixture.sessionID, gamesave.ClaimWriterRequest{IdempotencyKey: secondClaimKey, ClientInstanceID: clientInstanceID, ClientCompatibilityVersion: 3, RawBody: []byte(`{"clientCompatibilityVersion":3}`)}); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old claim error=%v", err)
	}
	var ranked int
	if err := fixture.pool.QueryRow(ctx, `SELECT stage_number FROM leaderboard_records WHERE account_id=$1`, accountID).Scan(&ranked); err != nil || ranked != 16 {
		t.Fatalf("new active run missing: %d %v", ranked, err)
	}
	svc := economy.NewService(fixture.pool)
	bootstrap := economy.BootstrapRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bc2", RawBody: []byte(`{"clientCompatibilityVersion":4}`), WriterGeneration: fixture.writerGeneration, ExpectedSaveRevision: 2}
	if _, err := svc.Bootstrap(ctx, accountID, fixture.sessionID, bootstrap); err != nil {
		t.Fatal(err)
	}
	settlement := economy.RunSettlementRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bc3", RunID: "0198b955-3656-7c40-b3cb-87f427b90bc4", RawBody: []byte(`{"clientCompatibilityVersion":4,"stageNumber":16}`), WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 2, StageNumber: 16, CompletedRounds: 40, Success: true, PendingDiamonds: 10}
	first, err := svc.SettleRun(ctx, accountID, fixture.sessionID, settlement)
	if err != nil {
		t.Fatal(err)
	}
	again, err := svc.SettleRun(ctx, accountID, fixture.sessionID, settlement)
	if err != nil {
		t.Fatal(err)
	}
	if first.Snapshot.EconomyRevision != again.Snapshot.EconomyRevision || first.Snapshot.Wallet.FreeDiamonds != 110 || first.Snapshot.Wallet.ModuleTickets != 2 {
		t.Fatalf("new settlement changed old rights or duplicate reward: %+v %+v", first, again)
	}
}
