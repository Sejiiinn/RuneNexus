//go:build integration

package dbtest_test

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/Sejiiinn/RuneNexus/server/internal/leaderboard"
	"github.com/jackc/pgx/v5/pgtype"
)

func TestLeaderboardRankingSnapshotAndEligibility(t *testing.T) {
	ctx, tx, q := openTestTransaction(t)
	service := leaderboard.NewService(tx)
	var ownID string
	for i := 0; i < 105; i++ {
		var accountID, commandID pgtype.UUID
		err := tx.QueryRow(ctx, `INSERT INTO accounts(nickname,nickname_tag) VALUES ('Player',$1) RETURNING id`, fmt.Sprintf("%04d", i)).Scan(&accountID)
		if err != nil {
			t.Fatal(err)
		}
		err = tx.QueryRow(ctx, `INSERT INTO economy_commands(account_id,idempotency_key,command_type,request_hash,resulting_revision,authority_epoch,response_payload) VALUES ($1,uuidv7(),'run_settlement',decode(repeat('00',32),'hex'),1,uuidv7(),'{}') RETURNING id`, accountID).Scan(&commandID)
		if err != nil {
			t.Fatal(err)
		}
		stage, round := int32(3), int32(40)
		if i < 4 {
			stage = 4
			round = 1
		}
		if i == 0 {
			round = 2
		}
		if err := q.UpsertProgressionLeaderboardRecord(ctx, dbgen.UpsertProgressionLeaderboardRecordParams{AccountID: accountID, StageNumber: stage, CompletedRounds: round, SourceCommandID: commandID}); err != nil {
			t.Fatal(err)
		}
		// 1·2번은 시각까지 같은 공동 기록, 3번은 같은 진행도의 후발 기록.
		achieved := time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC)
		if i >= 3 {
			achieved = achieved.Add(time.Duration(i) * time.Second)
		}
		if _, err := tx.Exec(ctx, `UPDATE leaderboard_records SET achieved_at=$2 WHERE account_id=$1`, accountID, achieved); err != nil {
			t.Fatal(err)
		}
		if i == 104 {
			if err := tx.QueryRow(ctx, `SELECT $1::uuid::text`, accountID).Scan(&ownID); err != nil {
				t.Fatal(err)
			}
		}
	}
	// 순위 계산 전에 정지·삭제 대기·닉네임 미설정 계정 제외.
	if _, err := tx.Exec(ctx, `UPDATE accounts SET status='suspended' WHERE nickname='Player' AND nickname_tag='0100'; UPDATE accounts SET status='deletion_pending' WHERE nickname='Player' AND nickname_tag='0101'; UPDATE accounts SET nickname=NULL,nickname_tag=NULL WHERE nickname='Player' AND nickname_tag='0102'`); err != nil {
		t.Fatal(err)
	}
	result, err := service.GetProgression(ctx, ownID)
	if err != nil {
		t.Fatal(err)
	}
	if len(result.Entries) != 100 || result.MyEntry == nil || result.MyEntry.Rank != 102 || !result.MyEntry.IsMe {
		t.Fatalf("top=%d own=%+v", len(result.Entries), result.MyEntry)
	}
	for i, want := range []int64{1, 2, 2, 4, 5} {
		if result.Entries[i].Rank != want {
			t.Fatalf("entry %d = %+v", i, result.Entries[i])
		}
	}
	if result.Entries[0].StageNumber != 4 || result.Entries[0].CompletedRounds != 2 || result.Entries[4].StageNumber != 3 {
		t.Fatal("stage/round ordering")
	}
	if result.AsOf.Location() != time.UTC || result.Entries[0].AchievedAt.Location() != time.UTC {
		t.Fatal("timestamps not UTC")
	}
	if result.Entries[1].DisplayName != "Player#0001" || result.Entries[2].DisplayName != "Player#0002" {
		t.Fatal("exact tie unstable ordering")
	}
	if _, err := tx.Exec(ctx, `UPDATE accounts SET status='suspended' WHERE id=$1`, ownID); err != nil {
		t.Fatal(err)
	}
	result, err = service.GetProgression(ctx, ownID)
	if err != nil || result.MyEntry != nil {
		t.Fatalf("ineligible own record: %+v %v", result.MyEntry, err)
	}
	if _, err := tx.Exec(ctx, `DELETE FROM leaderboard_records`); err != nil {
		t.Fatal(err)
	}
	result, err = service.GetProgression(ctx, ownID)
	if err != nil || result.Entries == nil || len(result.Entries) != 0 || result.MyEntry != nil {
		t.Fatalf("empty response: %+v %v", result, err)
	}
}

func TestLeaderboardConditionalUpsertAndConcurrentBest(t *testing.T) {
	ctx, fixture, _ := openSaveService(t)
	q := dbgen.New(fixture.pool)
	var commands []pgtype.UUID
	for i := 1; i <= 3; i++ {
		var id pgtype.UUID
		err := fixture.pool.QueryRow(ctx, `INSERT INTO economy_commands(account_id,idempotency_key,command_type,request_hash,resulting_revision,authority_epoch,response_payload) VALUES ($1,uuidv7(),'run_settlement',decode(repeat('00',32),'hex'),$2,uuidv7(),'{}') RETURNING id`, fixture.accountUUID, i).Scan(&id)
		if err != nil {
			t.Fatal(err)
		}
		commands = append(commands, id)
	}
	first := dbgen.UpsertProgressionLeaderboardRecordParams{AccountID: fixture.accountUUID, StageNumber: 4, CompletedRounds: 20, SourceCommandID: commands[0]}
	if err := q.UpsertProgressionLeaderboardRecord(ctx, first); err != nil {
		t.Fatal(err)
	}
	var timestamp time.Time
	if err := fixture.pool.QueryRow(ctx, `SELECT achieved_at FROM leaderboard_records WHERE account_id=$1`, fixture.accountUUID).Scan(&timestamp); err != nil {
		t.Fatal(err)
	}
	for _, v := range [][2]int32{{4, 20}, {4, 19}, {3, 40}} {
		arg := first
		arg.StageNumber = v[0]
		arg.CompletedRounds = v[1]
		arg.SourceCommandID = commands[1]
		if err := q.UpsertProgressionLeaderboardRecord(ctx, arg); err != nil {
			t.Fatal(err)
		}
	}
	var preserved time.Time
	var source pgtype.UUID
	if err := fixture.pool.QueryRow(ctx, `SELECT achieved_at,source_command_id FROM leaderboard_records WHERE account_id=$1`, fixture.accountUUID).Scan(&preserved, &source); err != nil {
		t.Fatal(err)
	}
	if !timestamp.Equal(preserved) || source != commands[0] {
		t.Fatal("equal/lower replaced first evidence")
	}
	var wg sync.WaitGroup
	errs := make(chan error, 2)
	for i, v := range [][2]int32{{5, 1}, {4, 40}} {
		wg.Add(1)
		go func(i int, v [2]int32) {
			defer wg.Done()
			arg := first
			arg.StageNumber = v[0]
			arg.CompletedRounds = v[1]
			arg.SourceCommandID = commands[i+1]
			errs <- q.UpsertProgressionLeaderboardRecord(ctx, arg)
		}(i, v)
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			t.Fatal(err)
		}
	}
	var stage, round int
	if err := fixture.pool.QueryRow(ctx, `SELECT stage_number,completed_rounds,achieved_at,source_command_id FROM leaderboard_records WHERE account_id=$1`, fixture.accountUUID).Scan(&stage, &round, &preserved, &source); err != nil {
		t.Fatal(err)
	}
	if stage != 5 || round != 1 || !preserved.After(timestamp) || source != commands[1] {
		t.Fatalf("concurrent best = %d/%d %v", stage, round, preserved)
	}
}

func TestLeaderboardRunSettlementAtomicityAndReceiptBoundary(t *testing.T) {
	ctx, fixture, accountID := openSaveService(t)
	_, err := fixture.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey: firstSaveKey, ExpectedRevision: 0, RawBody: []byte(`{"expectedRevision":0}`),
		Data: gamesave.Data{Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`), Progression: json.RawMessage(`{"freeDiamonds":0,"paidDiamonds":0,"bestRoundsByStage":{"4":20}}`), TurretModules: json.RawMessage(`{"tickets":0,"drawCount":0,"ticketPurchaseCount":0,"itemSequence":0,"items":[]}`)},
	})
	if err != nil {
		t.Fatal(err)
	}
	service := economy.NewService(fixture.pool)
	_, err = service.Bootstrap(ctx, accountID, fixture.sessionID, economy.BootstrapRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bea", RawBody: []byte(`{"bootstrap":true}`), WriterGeneration: fixture.writerGeneration, ExpectedSaveRevision: 1})
	if err != nil {
		t.Fatal(err)
	}
	request := economy.RunSettlementRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bf3", RunID: "0198b955-3656-7c40-b3cb-87f427b90bf2", RawBody: []byte(`{"run":1}`), WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 1, StageNumber: 4, CompletedRounds: 20, PendingDiamonds: 5}
	// 계정 한정 CHECK 실패로 정산의 마지막 쓰기 실패와 전체 롤백 검증.
	constraint := "leaderboard_fail_" + strings.ReplaceAll(accountID, "-", "")
	_, err = fixture.pool.Exec(ctx, `ALTER TABLE leaderboard_records ADD CONSTRAINT `+constraint+` CHECK(account_id <> '`+accountID+`'::uuid)`)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = fixture.pool.Exec(context.Background(), `ALTER TABLE leaderboard_records DROP CONSTRAINT IF EXISTS `+constraint)
	})
	if _, err := service.SettleRun(ctx, accountID, fixture.sessionID, request); err == nil {
		t.Fatal("failed leaderboard write committed settlement")
	}
	var revision, diamonds, claims int
	if err := fixture.pool.QueryRow(ctx, `SELECT revision,free_diamonds,(SELECT count(*) FROM economy_reward_claims WHERE account_id=$1) FROM player_economies WHERE account_id=$1`, accountID).Scan(&revision, &diamonds, &claims); err != nil {
		t.Fatal(err)
	}
	if revision != 1 || diamonds != 0 || claims != 0 {
		t.Fatalf("partial commit %d %d %d", revision, diamonds, claims)
	}
	if _, err := fixture.pool.Exec(ctx, `ALTER TABLE leaderboard_records DROP CONSTRAINT `+constraint); err != nil {
		t.Fatal(err)
	}
	result, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	var achieved time.Time
	if err := fixture.pool.QueryRow(ctx, `SELECT achieved_at FROM leaderboard_records WHERE account_id=$1`, accountID).Scan(&achieved); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 2; i++ {
		if i == 1 {
			request.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90bf4"
		}
		replay, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
		if err != nil || replay.Snapshot.EconomyRevision != result.Snapshot.EconomyRevision {
			t.Fatalf("replay %+v %v", replay, err)
		}
		var after time.Time
		if err := fixture.pool.QueryRow(ctx, `SELECT achieved_at FROM leaderboard_records WHERE account_id=$1`, accountID).Scan(&after); err != nil || !after.Equal(achieved) {
			t.Fatalf("receipt changed timestamp %v", err)
		}
	}
	// 활성화 전 영수증 상태 재현: 기존 영수증만 남아 있으면 재시도로 소급 등록하지 않음.
	if _, err := fixture.pool.Exec(ctx, `DELETE FROM leaderboard_records WHERE account_id=$1`, accountID); err != nil {
		t.Fatal(err)
	}
	if _, err := service.SettleRun(ctx, accountID, fixture.sessionID, request); err != nil {
		t.Fatal(err)
	}
	request.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90bf3"
	if _, err := service.SettleRun(ctx, accountID, fixture.sessionID, request); err != nil {
		t.Fatal(err)
	}
	request.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90bf5"
	request.RunID = "0198b955-3656-7c40-b3cb-87f427b90bf6"
	request.RawBody = []byte(`{"run":2}`)
	request.CompletedRounds = 0
	request.PendingDiamonds = 0
	if _, err := service.SettleRun(ctx, accountID, fixture.sessionID, request); err != nil {
		t.Fatal(err)
	}
	var count int
	if err := fixture.pool.QueryRow(ctx, `SELECT count(*) FROM leaderboard_records WHERE account_id=$1`, accountID).Scan(&count); err != nil || count != 0 {
		t.Fatalf("zero-round/old receipt record count=%d err=%v", count, err)
	}
	request.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90bf7"
	request.RunID = "0198b955-3656-7c40-b3cb-87f427b90bf8"
	request.RawBody = []byte(`{"run":3}`)
	request.CompletedRounds = 21
	if _, err := service.SettleRun(ctx, accountID, fixture.sessionID, request); !errors.Is(err, economy.ErrInvalidCommand) {
		t.Fatalf("invalid evidence error=%v", err)
	}
	if err := fixture.pool.QueryRow(ctx, `SELECT count(*) FROM leaderboard_records WHERE account_id=$1`, accountID).Scan(&count); err != nil || count != 0 {
		t.Fatalf("invalid evidence ranked: %d %v", count, err)
	}
}
