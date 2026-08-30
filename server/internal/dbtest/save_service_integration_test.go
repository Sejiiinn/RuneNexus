//go:build integration

package dbtest_test

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	"github.com/Sejiiinn/RuneNexus/server/internal/legacytransfer"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/Sejiiinn/RuneNexus/server/internal/session"
	"github.com/Sejiiinn/RuneNexus/server/internal/weeklyreward"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	firstSaveKey     = "0198b955-3656-7c40-b3cb-87f427b90be4"
	secondSaveKey    = "0198b955-3656-7c40-b3cb-87f427b90be5"
	writerClaimKey   = "0198b955-3656-7c40-b3cb-87f427b90be6"
	clientInstanceID = "0198b955-3656-7c40-b3cb-87f427b90be7"
	secondClaimKey   = "0198b955-3656-7c40-b3cb-87f427b90be8"
	secondClientID   = "0198b955-3656-7c40-b3cb-87f427b90be9"
)

type claimedSaveService struct {
	service          *gamesave.Service
	pool             *pgxpool.Pool
	accountUUID      pgtype.UUID
	sessionID        string
	writerGeneration int64
}

func (fixture *claimedSaveService) Get(
	ctx context.Context,
	accountID string,
) (gamesave.Snapshot, error) {
	return fixture.service.Get(ctx, accountID)
}

func (fixture *claimedSaveService) Update(
	ctx context.Context,
	accountID string,
	request gamesave.UpdateRequest,
) (gamesave.UpdateResult, error) {
	request.WriterGeneration = fixture.writerGeneration
	return fixture.service.Update(ctx, accountID, fixture.sessionID, request)
}

func TestSaveWriterClaimIsIdempotentAndRejectsPreviousWriter(t *testing.T) {
	ctx, fixture, accountID := openSaveService(t)
	claimBody := []byte(`{"clientInstanceId":"` + clientInstanceID + `","saveSchemaVersion":2,"clientBuild":"integration-test"}`)
	replayed, err := fixture.service.ClaimWriter(ctx, accountID, fixture.sessionID, gamesave.ClaimWriterRequest{
		IdempotencyKey:   writerClaimKey,
		ClientInstanceID: clientInstanceID,
		RawBody:          claimBody,
	})
	if err != nil {
		t.Fatalf("replay writer claim: %v", err)
	}
	if replayed.WriterGeneration != fixture.writerGeneration {
		t.Fatalf("replayed generation = %d", replayed.WriterGeneration)
	}
	changedBody := append([]byte(nil), claimBody...)
	changedBody[len(changedBody)-2] = ' '
	if _, err := fixture.service.ClaimWriter(ctx, accountID, fixture.sessionID, gamesave.ClaimWriterRequest{
		IdempotencyKey:   writerClaimKey,
		ClientInstanceID: clientInstanceID,
		RawBody:          changedBody,
	}); !errors.Is(err, gamesave.ErrIdempotencyKeyReused) {
		t.Fatalf("changed writer claim error = %v", err)
	}

	otherAccount, err := dbgen.New(fixture.pool).CreateAccount(ctx)
	if err != nil {
		t.Fatalf("create other account: %v", err)
	}
	t.Cleanup(func() {
		cleanupContext, cancel := context.WithTimeout(context.Background(), testDatabaseTimeout)
		defer cancel()
		if _, err := fixture.pool.Exec(cleanupContext, "DELETE FROM accounts WHERE id = $1", otherAccount.ID); err != nil {
			t.Errorf("delete other account: %v", err)
		}
	})
	otherAccessHash := sha256.Sum256(append(otherAccount.ID.Bytes[:], 2))
	otherSession, err := dbgen.New(fixture.pool).CreateSession(ctx, dbgen.CreateSessionParams{
		AccountID:        otherAccount.ID,
		AccessTokenHash:  otherAccessHash[:],
		AccessExpiresAt:  pgtype.Timestamptz{Time: time.Now().UTC().Add(15 * time.Minute), Valid: true},
		RefreshExpiresAt: pgtype.Timestamptz{Time: time.Now().UTC().Add(24 * time.Hour), Valid: true},
	})
	if err != nil {
		t.Fatalf("create other session: %v", err)
	}
	var otherSessionID string
	if err := fixture.pool.QueryRow(ctx, "SELECT $1::uuid::text", otherSession.ID).Scan(&otherSessionID); err != nil {
		t.Fatalf("format other session ID: %v", err)
	}
	if _, err := fixture.service.ClaimWriter(ctx, accountID, otherSessionID, gamesave.ClaimWriterRequest{
		IdempotencyKey:   "0198b955-3656-7c40-b3cb-87f427b90bea",
		ClientInstanceID: "0198b955-3656-7c40-b3cb-87f427b90beb",
		RawBody:          []byte(`{"clientInstanceId":"0198b955-3656-7c40-b3cb-87f427b90beb","saveSchemaVersion":2,"clientBuild":"integration-test"}`),
	}); !errors.Is(err, gamesave.ErrSessionAccountMismatch) {
		t.Fatalf("cross-account writer claim error = %v", err)
	}

	acceptedRequest := gamesave.UpdateRequest{
		IdempotencyKey:   firstSaveKey,
		WriterGeneration: fixture.writerGeneration,
		ExpectedRevision: 0,
		RawBody:          []byte(`{"expectedRevision":0,"data":{"version":2}}`),
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			Preferences:   json.RawMessage(`{}`),
			Progression:   json.RawMessage(`{}`),
			TurretModules: json.RawMessage(`{}`),
		},
	}
	accepted, err := fixture.service.Update(ctx, accountID, fixture.sessionID, acceptedRequest)
	if err != nil {
		t.Fatalf("save before writer replacement: %v", err)
	}

	now := time.Now().UTC()
	secondAccessHash := sha256.Sum256(append(fixture.accountUUID.Bytes[:], 1))
	secondSession, err := dbgen.New(fixture.pool).CreateSession(ctx, dbgen.CreateSessionParams{
		AccountID:        fixture.accountUUID,
		AccessTokenHash:  secondAccessHash[:],
		AccessExpiresAt:  pgtype.Timestamptz{Time: now.Add(15 * time.Minute), Valid: true},
		RefreshExpiresAt: pgtype.Timestamptz{Time: now.Add(24 * time.Hour), Valid: true},
	})
	if err != nil {
		t.Fatalf("create second writer session: %v", err)
	}
	var secondSessionID string
	if err := fixture.pool.QueryRow(ctx, "SELECT $1::uuid::text", secondSession.ID).Scan(&secondSessionID); err != nil {
		t.Fatalf("format second session ID: %v", err)
	}
	secondBody := []byte(`{"clientInstanceId":"` + secondClientID + `","saveSchemaVersion":2,"clientBuild":"integration-test"}`)
	secondClaim, err := fixture.service.ClaimWriter(ctx, accountID, secondSessionID, gamesave.ClaimWriterRequest{
		IdempotencyKey:   secondClaimKey,
		ClientInstanceID: secondClientID,
		RawBody:          secondBody,
	})
	if err != nil {
		t.Fatalf("claim second writer: %v", err)
	}
	if secondClaim.WriterGeneration != fixture.writerGeneration+1 {
		t.Fatalf("second generation = %d", secondClaim.WriterGeneration)
	}

	replayedSave, err := fixture.service.Update(ctx, accountID, fixture.sessionID, acceptedRequest)
	if err != nil || replayedSave != accepted {
		t.Fatalf("replay accepted save after replacement = %#v, %v", replayedSave, err)
	}
	receiptOnlyReplay := acceptedRequest
	receiptOnlyReplay.ReceiptOnly = true
	replayedSave, err = fixture.service.Update(ctx, accountID, fixture.sessionID, receiptOnlyReplay)
	if err != nil || replayedSave != accepted {
		t.Fatalf("receipt-only replay = %#v, %v", replayedSave, err)
	}
	receiptOnlyMiss := acceptedRequest
	receiptOnlyMiss.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90bec"
	receiptOnlyMiss.ReceiptOnly = true
	if _, err := fixture.service.Update(ctx, accountID, fixture.sessionID, receiptOnlyMiss); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("receipt-only miss error = %v", err)
	}
	staleRequest := acceptedRequest
	staleRequest.IdempotencyKey = secondSaveKey
	staleRequest.ExpectedRevision = 1
	staleRequest.RawBody = []byte(`{"expectedRevision":1,"data":{"version":2}}`)
	if _, err := fixture.service.Update(ctx, accountID, fixture.sessionID, staleRequest); err == nil {
		t.Fatal("previous writer saved after replacement")
	} else {
		var replaced *gamesave.WriterReplacedError
		if !errors.As(err, &replaced) || replaced.CurrentGeneration != secondClaim.WriterGeneration {
			t.Fatalf("previous writer error = %v", err)
		}
	}
}

func TestWeeklyRewardClaimUsesCurrentSaveAndIsAccountIdempotent(t *testing.T) {
	ctx, fixture, accountID := openSaveService(t)
	adjustedNow := time.Now().UTC().Add(4 * time.Hour)
	dayKey := adjustedNow.UnixMilli() / int64((24*time.Hour)/time.Millisecond)
	weekKey := (dayKey + 3) / 7
	progression, err := json.Marshal(map[string]any{
		"freeDiamonds":     100,
		"paidDiamonds":     0,
		"dailyQuestDayKey": dayKey,
		"dailyQuestProgress": map[string]int{
			"clearWaves": 30, "killBosses": 3, "killEnemies": 100, "buyRunUpgrades": 5,
		},
		"claimedDailyQuestRewards":     []string{},
		"dailyQuestAllCompleteClaimed": false,
		"dailyAttendanceRewardClaimed": false,
		"weeklyQuestWeekKey":           weekKey,
		"weeklyQuestProgress": map[string]int{
			"clearWaves":     150,
			"killBosses":     15,
			"killEnemies":    500,
			"buyRunUpgrades": 25,
		},
		"claimedWeeklyQuestRewards":       []string{},
		"weeklyQuestAllCompleteClaimed":   false,
		"weeklyAttendanceDayKeys":         []int64{},
		"weeklyAttendanceRewardClaimed":   false,
		"dailyQuestClockRollbackDetected": false,
	})
	if err != nil {
		t.Fatalf("encode progression: %v", err)
	}
	if _, err := fixture.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey:   firstSaveKey,
		ExpectedRevision: 0,
		RawBody:          []byte(`{"expectedRevision":0,"data":{"version":2}}`),
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			Preferences:   json.RawMessage(`{}`),
			Progression:   progression,
			TurretModules: json.RawMessage(`{"tickets":2,"drawCount":0,"ticketPurchaseCount":0,"itemSequence":0,"items":[]}`),
		},
	}); err != nil {
		t.Fatalf("save weekly progression: %v", err)
	}
	bootstrapBody := []byte(`{"expectedSaveRevision":1,"writerGeneration":1,"clientCompatibilityVersion":2}`)
	bootstrap, err := economy.NewService(fixture.pool).Bootstrap(
		ctx,
		accountID,
		fixture.sessionID,
		economy.BootstrapRequest{
			IdempotencyKey:       "0198b955-3656-7c40-b3cb-87f427b90bea",
			RawBody:              bootstrapBody,
			WriterGeneration:     fixture.writerGeneration,
			ExpectedSaveRevision: 1,
		},
	)
	if err != nil || bootstrap.Snapshot.EconomyRevision != 1 {
		t.Fatalf("bootstrap authoritative economy: %#v, %v", bootstrap, err)
	}
	if _, err := fixture.service.ClaimWriter(ctx, accountID, fixture.sessionID, gamesave.ClaimWriterRequest{
		IdempotencyKey:             "0198b955-3656-7c40-b3cb-87f427b90bf0",
		ClientInstanceID:           clientInstanceID,
		ClientCompatibilityVersion: 1,
		RawBody:                    []byte(`{"clientCompatibilityVersion":1}`),
	}); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("outdated writer claim after economy bootstrap = %v", err)
	}
	drawService := economy.NewService(fixture.pool)
	draw, err := drawService.DrawModules(ctx, accountID, fixture.sessionID, economy.DrawRequest{
		IdempotencyKey:   "0198b955-3656-7c40-b3cb-87f427b90beb",
		RawBody:          []byte(`{"expectedEconomyRevision":1,"count":1}`),
		ExpectedRevision: 1, ExpectedCatalogVersion: economy.CatalogVersion,
		SourceSaveRevision: 1, WriterGeneration: fixture.writerGeneration,
		Count: 1, TurretType: "arrow",
	})
	if err != nil || draw.Snapshot.EconomyRevision != 2 || len(draw.DrawnModules) != 1 || draw.Snapshot.Wallet.ModuleTickets != 1 {
		t.Fatalf("draw authoritative module: %#v, %v", draw, err)
	}
	disassembled, err := drawService.DisassembleModules(ctx, accountID, economy.DisassembleRequest{
		IdempotencyKey:   "0198b955-3656-7c40-b3cb-87f427b90bec",
		RawBody:          []byte(`{"expectedEconomyRevision":2,"moduleIds":["` + draw.DrawnModules[0].ID + `"]}`),
		ExpectedRevision: 2, ExpectedCatalogVersion: economy.CatalogVersion,
		ModuleIDs: []string{draw.DrawnModules[0].ID},
	})
	if err != nil || disassembled.Snapshot.EconomyRevision != 3 || len(disassembled.Snapshot.TurretModules.Items) != 0 {
		t.Fatalf("disassemble authoritative module: %#v, %v", disassembled, err)
	}

	service := weeklyreward.NewService(fixture.pool)
	body := []byte(`{"period":"weekly","rewardType":"quest","questType":"killEnemies"}`)
	request := weeklyreward.ClaimRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bed",
		RawBody:        body,
		RewardType:     weeklyreward.RewardTypeQuest,
		QuestType:      "killEnemies",
	}
	claimed, err := service.Claim(ctx, accountID, fixture.sessionID, request)
	if err != nil {
		t.Fatalf("claim weekly reward: %v", err)
	}
	if claimed.Diamonds != 20 || claimed.WeekKey != weekKey ||
		claimed.SourceSaveRevision != 1 {
		t.Fatalf("claimed reward = %#v", claimed)
	}
	replayed, err := service.Claim(ctx, accountID, fixture.sessionID, request)
	if err != nil || replayed != claimed {
		t.Fatalf("replayed reward = %#v, %v", replayed, err)
	}

	changedBody := request
	changedBody.RawBody = []byte(`{"period":"weekly","rewardType":"quest", "questType":"killEnemies"}`)
	if _, err := service.Claim(ctx, accountID, fixture.sessionID, changedBody); !errors.Is(err, weeklyreward.ErrIdempotencyKeyReused) {
		t.Fatalf("changed-body replay error = %v", err)
	}
	differentKey := request
	differentKey.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90bee"
	if _, err := service.Claim(ctx, accountID, fixture.sessionID, differentKey); err == nil {
		t.Fatal("duplicate reward claim succeeded")
	} else {
		var alreadyClaimed *weeklyreward.AlreadyClaimedError
		if !errors.As(err, &alreadyClaimed) || alreadyClaimed.Result != claimed {
			t.Fatalf("duplicate reward error = %v", err)
		}
	}
	dailyBody := []byte(`{"period":"daily","rewardType":"attendance"}`)
	daily, err := service.Claim(ctx, accountID, fixture.sessionID, weeklyreward.ClaimRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bef",
		RawBody:        dailyBody, Period: "daily", RewardType: weeklyreward.RewardTypeAttendance,
	})
	if err != nil || daily.Diamonds != 10 || daily.WeekKey != dayKey || daily.EconomyRevision != 5 {
		t.Fatalf("daily authoritative reward = %#v, %v", daily, err)
	}
	var settledProgression map[string]any
	if err := json.Unmarshal(progression, &settledProgression); err != nil {
		t.Fatalf("decode run settlement progression: %v", err)
	}
	settledProgression["bestRoundsByStage"] = map[string]int{"11": 40}
	settledProgression["clearedStageNumbers"] = []int{11}
	// 다른 런이 마지막 보상 표시를 덮어써도 Outbox의 run 증거를 사용한다.
	settledProgression["lastRunTurretModuleTicketReward"] = 0
	settledProgressionJSON, err := json.Marshal(settledProgression)
	if err != nil {
		t.Fatalf("encode run settlement progression: %v", err)
	}
	if _, err := fixture.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey:             "0198b955-3656-7c40-b3cb-87f427b90bf1",
		WriterGeneration:           fixture.writerGeneration,
		ExpectedRevision:           1,
		ClientCompatibilityVersion: gamesave.CurrentClientCompatibilityVersion,
		RawBody:                    []byte(`{"expectedRevision":1,"clientCompatibilityVersion":2,"data":{"version":2}}`),
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			Preferences:   json.RawMessage(`{}`),
			Progression:   settledProgressionJSON,
			TurretModules: json.RawMessage(`{"tickets":2,"drawCount":0,"ticketPurchaseCount":0,"itemSequence":0,"items":[]}`),
		},
	}); err != nil {
		t.Fatalf("save stage 11 settlement proof: %v", err)
	}
	runBody := []byte(`{"runId":"0198b955-3656-7c40-b3cb-87f427b90bf2","writerGeneration":1,"sourceSaveRevision":2,"stageNumber":11,"completedRounds":40,"success":true,"pendingDiamonds":0,"firstClearModuleTickets":5,"clientCompatibilityVersion":2}`)
	runResult, err := drawService.SettleRun(ctx, accountID, fixture.sessionID, economy.RunSettlementRequest{
		IdempotencyKey:          "0198b955-3656-7c40-b3cb-87f427b90bf3",
		RawBody:                 runBody,
		RunID:                   "0198b955-3656-7c40-b3cb-87f427b90bf2",
		WriterGeneration:        fixture.writerGeneration,
		SourceSaveRevision:      2,
		StageNumber:             11,
		CompletedRounds:         40,
		Success:                 true,
		PendingDiamonds:         0,
		FirstClearModuleTickets: economy.StageElevenModuleTicketGift,
	})
	if err != nil || runResult.GrantedModuleTickets != economy.StageElevenModuleTicketGift ||
		runResult.Snapshot.Wallet.ModuleTickets != 6 || runResult.Snapshot.EconomyRevision != 6 {
		t.Fatalf("settle durable stage reward: %#v, %v", runResult, err)
	}
	settledProgression["activeResearches"] = []map[string]any{{
		"type": "researchEfficiency", "targetLevel": 1,
		"startedAtMillis": time.Now().UTC().UnixMilli(), "durationMillis": int64(600_000),
		"initialElapsedMillis": int64(0),
	}}
	researchProgressionJSON, err := json.Marshal(settledProgression)
	if err != nil {
		t.Fatalf("encode active research progression: %v", err)
	}
	if _, err := fixture.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey:             "0198b955-3656-7c40-b3cb-87f427b90bf4",
		WriterGeneration:           fixture.writerGeneration,
		ExpectedRevision:           2,
		ClientCompatibilityVersion: gamesave.CurrentClientCompatibilityVersion,
		RawBody:                    []byte(`{"expectedRevision":2,"clientCompatibilityVersion":2,"data":{"version":2}}`),
		Data: gamesave.Data{
			Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`),
			Progression:   researchProgressionJSON,
			TurretModules: json.RawMessage(`{"tickets":2,"drawCount":0,"ticketPurchaseCount":0,"itemSequence":0,"items":[]}`),
		},
	}); err != nil {
		t.Fatalf("save active research: %v", err)
	}
	researchResult, err := drawService.CompleteResearch(ctx, accountID, fixture.sessionID, economy.ResearchCompleteRequest{
		IdempotencyKey:   "0198b955-3656-7c40-b3cb-87f427b90bf5",
		RawBody:          []byte(`{"expectedEconomyRevision":6,"sourceSaveRevision":3,"researchType":"researchEfficiency"}`),
		ExpectedRevision: 6, ExpectedCatalogVersion: economy.CatalogVersion,
		WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 3,
		ResearchType: "researchEfficiency",
	})
	if err != nil || researchResult.Snapshot.EconomyRevision != 7 || researchResult.ProgressionEffect == nil {
		t.Fatalf("complete authoritative research: %#v, %v", researchResult, err)
	}
	if _, err := drawService.CompleteResearch(ctx, accountID, fixture.sessionID, economy.ResearchCompleteRequest{
		IdempotencyKey:   "0198b955-3656-7c40-b3cb-87f427b90bf6",
		RawBody:          []byte(`{"expectedEconomyRevision":7,"sourceSaveRevision":3,"researchType":"researchEfficiency"}`),
		ExpectedRevision: 7, ExpectedCatalogVersion: economy.CatalogVersion,
		WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 3,
		ResearchType: "researchEfficiency",
	}); !errors.Is(err, economy.ErrProgressionEffect) {
		t.Fatalf("duplicate pending research effect error = %v", err)
	}
}

func TestLegacyTransferBacksUpAndReplacesExistingAccountSave(t *testing.T) {
	ctx, fixture, accountID := openSaveService(t)
	service := legacytransfer.NewService(fixture.pool, 15*time.Minute)
	data := gamesave.Data{
		Version:       gamesave.CurrentSchemaVersion,
		SavedAtMillis: 1234,
		Preferences:   json.RawMessage(`{"music":true}`),
		Progression:   json.RawMessage(`{"runes":30,"freeDiamonds":40,"paidDiamonds":0}`),
		TurretModules: json.RawMessage(`{"tickets":2,"items":[]}`),
		ActiveRun:     json.RawMessage(`{"roundIndex":3}`),
	}
	created, err := service.Create(ctx, legacytransfer.CreateRequest{
		RawBody: []byte(`{"clientCompatibilityVersion":1,"data":{"version":2}}`),
		Data:    data,
	})
	if err != nil {
		t.Fatalf("create legacy transfer: %v", err)
	}
	tokenHash, err := session.HashToken(created.Token)
	if err != nil {
		t.Fatalf("hash legacy transfer token: %v", err)
	}
	t.Cleanup(func() {
		cleanupContext, cancel := context.WithTimeout(context.Background(), testDatabaseTimeout)
		defer cancel()
		if _, err := fixture.pool.Exec(
			cleanupContext,
			"DELETE FROM legacy_save_transfer_receipts WHERE token_hash = $1",
			tokenHash,
		); err != nil {
			t.Errorf("delete legacy transfer receipt: %v", err)
		}
		if _, err := fixture.pool.Exec(
			cleanupContext,
			"DELETE FROM legacy_save_transfers WHERE token_hash = $1",
			tokenHash,
		); err != nil {
			t.Errorf("delete legacy transfer: %v", err)
		}
	})

	consumed, err := service.Consume(ctx, accountID, fixture.sessionID, created.Token)
	if err != nil {
		t.Fatalf("consume legacy transfer: %v", err)
	}
	if consumed.Revision != 1 || consumed.ServerSavedAt.IsZero() {
		t.Fatalf("consumed = %#v", consumed)
	}
	replayed, err := service.Consume(ctx, accountID, fixture.sessionID, created.Token)
	if err != nil || replayed != consumed {
		t.Fatalf("replayed consume = %#v, %v", replayed, err)
	}
	snapshot, err := fixture.service.Get(ctx, accountID)
	if err != nil {
		t.Fatalf("get imported save: %v", err)
	}
	if snapshot.Revision != 1 || snapshot.Data.SavedAtMillis != data.SavedAtMillis {
		t.Fatalf("snapshot = %#v", snapshot)
	}
	requireSameJSON(t, snapshot.Data.Progression, data.Progression)
	var pendingCount int
	if err := fixture.pool.QueryRow(
		ctx,
		"SELECT count(*) FROM legacy_save_transfers WHERE token_hash = $1",
		tokenHash,
	).Scan(&pendingCount); err != nil {
		t.Fatalf("count pending legacy payload: %v", err)
	}
	if pendingCount != 0 {
		t.Fatalf("pending legacy payload count = %d", pendingCount)
	}

	replacementData := gamesave.Data{
		Version:       gamesave.CurrentSchemaVersion,
		SavedAtMillis: 5678,
		Preferences:   json.RawMessage(`{"music":false}`),
		Progression:   json.RawMessage(`{"runes":90,"freeDiamonds":120,"paidDiamonds":0}`),
		TurretModules: json.RawMessage(`{"tickets":7,"items":[]}`),
	}
	second, err := service.Create(ctx, legacytransfer.CreateRequest{
		RawBody: []byte(`{"clientCompatibilityVersion":1,"data":{"version":2,"retry":true}}`),
		Data:    replacementData,
	})
	if err != nil {
		t.Fatalf("create second legacy transfer: %v", err)
	}
	secondHash, err := session.HashToken(second.Token)
	if err != nil {
		t.Fatalf("hash second legacy transfer token: %v", err)
	}
	t.Cleanup(func() {
		cleanupContext, cancel := context.WithTimeout(context.Background(), testDatabaseTimeout)
		defer cancel()
		if _, err := fixture.pool.Exec(
			cleanupContext,
			"DELETE FROM legacy_save_transfer_receipts WHERE token_hash = $1",
			secondHash,
		); err != nil {
			t.Errorf("delete second legacy transfer receipt: %v", err)
		}
		if _, err := fixture.pool.Exec(
			cleanupContext,
			"DELETE FROM legacy_save_transfers WHERE token_hash = $1",
			secondHash,
		); err != nil {
			t.Errorf("delete second legacy transfer: %v", err)
		}
	})
	replaced, err := service.Consume(
		ctx,
		accountID,
		fixture.sessionID,
		second.Token,
	)
	if err != nil {
		t.Fatalf("replace existing target: %v", err)
	}
	if replaced.Revision != 2 || replaced.ServerSavedAt.IsZero() {
		t.Fatalf("replaced = %#v", replaced)
	}
	replacedSnapshot, err := fixture.service.Get(ctx, accountID)
	if err != nil {
		t.Fatalf("get replaced save: %v", err)
	}
	if replacedSnapshot.Revision != 2 ||
		replacedSnapshot.Data.SavedAtMillis != replacementData.SavedAtMillis ||
		replacedSnapshot.Data.ActiveRun != nil {
		t.Fatalf("replaced snapshot = %#v", replacedSnapshot)
	}
	requireSameJSON(t, replacedSnapshot.Data.Progression, replacementData.Progression)

	var replacedExisting bool
	var previousRevision int64
	var previousProgression []byte
	var previousActiveRun []byte
	if err := fixture.pool.QueryRow(
		ctx,
		`SELECT replaced_existing_save, previous_revision,
                previous_progression, previous_active_run
           FROM legacy_save_transfer_receipts
          WHERE token_hash = $1`,
		secondHash,
	).Scan(
		&replacedExisting,
		&previousRevision,
		&previousProgression,
		&previousActiveRun,
	); err != nil {
		t.Fatalf("read replaced save backup: %v", err)
	}
	if !replacedExisting || previousRevision != 1 {
		t.Fatalf("backup metadata = replaced %t, revision %d", replacedExisting, previousRevision)
	}
	requireSameJSON(t, previousProgression, data.Progression)
	requireSameJSON(t, previousActiveRun, data.ActiveRun)

	writer, err := dbgen.New(fixture.pool).GetSaveWriterStateForUpdate(ctx, fixture.accountUUID)
	if err != nil {
		t.Fatalf("get invalidated writer: %v", err)
	}
	if writer.Generation != fixture.writerGeneration+1 ||
		writer.SessionID.Valid == false || writer.ClientInstanceID.Valid {
		t.Fatalf("invalidated writer = %#v", writer)
	}
	if _, err := fixture.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey:   secondSaveKey,
		ExpectedRevision: 2,
		RawBody:          []byte(`{"expectedRevision":2,"data":{"version":2}}`),
		Data:             replacementData,
	}); err == nil {
		t.Fatal("previous writer saved after legacy replacement")
	} else {
		var writerReplaced *gamesave.WriterReplacedError
		if !errors.As(err, &writerReplaced) ||
			writerReplaced.CurrentGeneration != fixture.writerGeneration+1 {
			t.Fatalf("previous writer error = %v", err)
		}
	}
}

func TestSaveWriterClaimAndUpdateUseOneLockOrder(t *testing.T) {
	ctx, fixture, accountID := openSaveService(t)
	now := time.Now().UTC()
	secondAccessHash := sha256.Sum256(append(fixture.accountUUID.Bytes[:], 3))
	secondSession, err := dbgen.New(fixture.pool).CreateSession(ctx, dbgen.CreateSessionParams{
		AccountID:        fixture.accountUUID,
		AccessTokenHash:  secondAccessHash[:],
		AccessExpiresAt:  pgtype.Timestamptz{Time: now.Add(15 * time.Minute), Valid: true},
		RefreshExpiresAt: pgtype.Timestamptz{Time: now.Add(24 * time.Hour), Valid: true},
	})
	if err != nil {
		t.Fatalf("create concurrent writer session: %v", err)
	}
	var secondSessionID string
	if err := fixture.pool.QueryRow(ctx, "SELECT $1::uuid::text", secondSession.ID).Scan(&secondSessionID); err != nil {
		t.Fatalf("format concurrent writer session ID: %v", err)
	}

	start := make(chan struct{})
	claimResults := make(chan gamesave.ClaimWriterResult, 1)
	claimErrors := make(chan error, 1)
	updateErrors := make(chan error, 1)
	go func() {
		<-start
		result, err := fixture.service.ClaimWriter(ctx, accountID, secondSessionID, gamesave.ClaimWriterRequest{
			IdempotencyKey:   secondClaimKey,
			ClientInstanceID: secondClientID,
			RawBody:          []byte(`{"clientInstanceId":"` + secondClientID + `","saveSchemaVersion":2,"clientBuild":"integration-test"}`),
		})
		claimResults <- result
		claimErrors <- err
	}()
	go func() {
		<-start
		_, err := fixture.service.Update(ctx, accountID, fixture.sessionID, gamesave.UpdateRequest{
			IdempotencyKey:   firstSaveKey,
			WriterGeneration: fixture.writerGeneration,
			ExpectedRevision: 0,
			RawBody:          []byte(`{"expectedRevision":0,"data":{"version":2}}`),
			Data: gamesave.Data{
				Version:       gamesave.CurrentSchemaVersion,
				Preferences:   json.RawMessage(`{}`),
				Progression:   json.RawMessage(`{}`),
				TurretModules: json.RawMessage(`{}`),
			},
		})
		updateErrors <- err
	}()
	close(start)

	claimResult := <-claimResults
	if err := <-claimErrors; err != nil {
		t.Fatalf("concurrent writer claim: %v", err)
	}
	if claimResult.WriterGeneration != fixture.writerGeneration+1 {
		t.Fatalf("concurrent claim generation = %d", claimResult.WriterGeneration)
	}
	updateErr := <-updateErrors
	if updateErr != nil {
		var replaced *gamesave.WriterReplacedError
		if !errors.As(updateErr, &replaced) || replaced.CurrentGeneration != claimResult.WriterGeneration {
			t.Fatalf("concurrent update error = %v", updateErr)
		}
		if _, err := fixture.service.Get(ctx, accountID); !errors.Is(err, gamesave.ErrNotFound) {
			t.Fatalf("save exists after rejected concurrent update: %v", err)
		}
		return
	}
	snapshot, err := fixture.service.Get(ctx, accountID)
	if err != nil {
		t.Fatalf("get concurrent accepted save: %v", err)
	}
	if snapshot.Revision != 1 {
		t.Fatalf("concurrent accepted revision = %d", snapshot.Revision)
	}
}

func TestSaveServicePersistsSnapshotAndEnforcesRequestContract(t *testing.T) {
	ctx, service, accountID := openSaveService(t)
	firstBody := []byte(`{"expectedRevision":0,"data":{"version":2,"savedAtMillis":1234,"preferences":{"music":true},"progression":{"runes":30},"turretModules":{"tickets":4},"activeRun":{"roundIndex":3}}}`)
	firstRequest := gamesave.UpdateRequest{
		IdempotencyKey:   firstSaveKey,
		ExpectedRevision: 0,
		RawBody:          firstBody,
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			SavedAtMillis: 1234,
			Preferences:   json.RawMessage(`{"music":true}`),
			Progression:   json.RawMessage(`{"runes":30}`),
			TurretModules: json.RawMessage(`{"tickets":4}`),
			ActiveRun:     json.RawMessage(`{"roundIndex":3}`),
		},
	}

	created, err := service.Update(ctx, accountID, firstRequest)
	if err != nil {
		t.Fatalf("create save: %v", err)
	}
	if created.Revision != 1 || created.ServerSavedAt.IsZero() {
		t.Fatalf("created = %#v", created)
	}
	replayed, err := service.Update(ctx, accountID, firstRequest)
	if err != nil {
		t.Fatalf("replay save: %v", err)
	}
	if replayed != created {
		t.Fatalf("replayed = %#v, want %#v", replayed, created)
	}

	changedBody := firstRequest
	changedBody.RawBody = append([]byte(nil), firstBody...)
	changedBody.RawBody[len(changedBody.RawBody)-2] = ' '
	if _, err := service.Update(ctx, accountID, changedBody); !errors.Is(
		err,
		gamesave.ErrIdempotencyKeyReused,
	) {
		t.Fatalf("changed body error = %v", err)
	}

	if _, err := service.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey:   secondSaveKey,
		ExpectedRevision: 0,
		RawBody:          []byte(`{"expectedRevision":0}`),
		Data:             firstRequest.Data,
	}); err == nil {
		t.Fatal("stale revision update succeeded")
	} else {
		var conflict *gamesave.RevisionConflictError
		if !errors.As(err, &conflict) || conflict.CurrentRevision != 1 {
			t.Fatalf("stale revision error = %v", err)
		}
	}

	snapshot, err := service.Get(ctx, accountID)
	if err != nil {
		t.Fatalf("get save: %v", err)
	}
	if snapshot.Revision != 1 || snapshot.Data.SavedAtMillis != 1234 {
		t.Fatalf("snapshot = %#v", snapshot)
	}
	requireSameJSON(t, snapshot.Data.Preferences, firstRequest.Data.Preferences)
	requireSameJSON(t, snapshot.Data.Progression, firstRequest.Data.Progression)
	requireSameJSON(t, snapshot.Data.TurretModules, firstRequest.Data.TurretModules)
	requireSameJSON(t, snapshot.Data.ActiveRun, firstRequest.Data.ActiveRun)

	secondBody := []byte(`{"expectedRevision":1,"data":{"version":2,"savedAtMillis":5678,"preferences":{},"progression":{},"turretModules":{},"activeRun":null}}`)
	updated, err := service.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey:   secondSaveKey,
		ExpectedRevision: 1,
		RawBody:          secondBody,
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			SavedAtMillis: 5678,
			Preferences:   json.RawMessage(`{}`),
			Progression:   json.RawMessage(`{}`),
			TurretModules: json.RawMessage(`{}`),
		},
	})
	if err != nil {
		t.Fatalf("remove active run: %v", err)
	}
	if updated.Revision != 2 {
		t.Fatalf("updated revision = %d", updated.Revision)
	}
	snapshot, err = service.Get(ctx, accountID)
	if err != nil {
		t.Fatalf("get updated save: %v", err)
	}
	if snapshot.Data.ActiveRun != nil {
		t.Fatalf("active run = %s, want nil", snapshot.Data.ActiveRun)
	}
}

func TestSaveServiceConcurrentIdenticalRequestReturnsOneRevision(t *testing.T) {
	ctx, service, accountID := openSaveService(t)
	request := gamesave.UpdateRequest{
		IdempotencyKey:   firstSaveKey,
		ExpectedRevision: 0,
		RawBody:          []byte(`{"expectedRevision":0,"data":{"version":2}}`),
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			Preferences:   json.RawMessage(`{}`),
			Progression:   json.RawMessage(`{}`),
			TurretModules: json.RawMessage(`{}`),
		},
	}

	start := make(chan struct{})
	results := make(chan gamesave.UpdateResult, 2)
	errorsChannel := make(chan error, 2)
	var group sync.WaitGroup
	for range 2 {
		group.Add(1)
		go func() {
			defer group.Done()
			<-start
			result, err := service.Update(ctx, accountID, request)
			results <- result
			errorsChannel <- err
		}()
	}
	close(start)
	group.Wait()
	close(results)
	close(errorsChannel)

	for err := range errorsChannel {
		if err != nil {
			t.Fatalf("concurrent update: %v", err)
		}
	}
	for result := range results {
		if result.Revision != 1 {
			t.Fatalf("result revision = %d", result.Revision)
		}
	}
	snapshot, err := service.Get(ctx, accountID)
	if err != nil {
		t.Fatalf("get save: %v", err)
	}
	if snapshot.Revision != 1 {
		t.Fatalf("snapshot revision = %d", snapshot.Revision)
	}
}

func TestSaveServiceConcurrentDifferentBodiesRejectsIdempotencyKeyReuse(t *testing.T) {
	ctx, service, accountID := openSaveService(t)
	requests := []gamesave.UpdateRequest{
		{
			IdempotencyKey:   firstSaveKey,
			ExpectedRevision: 0,
			RawBody:          []byte(`{"expectedRevision":0,"value":"first"}`),
			Data: gamesave.Data{
				Version:       gamesave.CurrentSchemaVersion,
				Preferences:   json.RawMessage(`{"value":"first"}`),
				Progression:   json.RawMessage(`{}`),
				TurretModules: json.RawMessage(`{}`),
			},
		},
		{
			IdempotencyKey:   firstSaveKey,
			ExpectedRevision: 0,
			RawBody:          []byte(`{"expectedRevision":0,"value":"second"}`),
			Data: gamesave.Data{
				Version:       gamesave.CurrentSchemaVersion,
				Preferences:   json.RawMessage(`{"value":"second"}`),
				Progression:   json.RawMessage(`{}`),
				TurretModules: json.RawMessage(`{}`),
			},
		},
	}

	start := make(chan struct{})
	errorsChannel := make(chan error, len(requests))
	var group sync.WaitGroup
	for _, request := range requests {
		group.Add(1)
		go func() {
			defer group.Done()
			<-start
			_, err := service.Update(ctx, accountID, request)
			errorsChannel <- err
		}()
	}
	close(start)
	group.Wait()
	close(errorsChannel)

	successCount := 0
	reuseCount := 0
	for err := range errorsChannel {
		switch {
		case err == nil:
			successCount++
		case errors.Is(err, gamesave.ErrIdempotencyKeyReused):
			reuseCount++
		default:
			t.Fatalf("concurrent update error = %v", err)
		}
	}
	if successCount != 1 || reuseCount != 1 {
		t.Fatalf("successes = %d, key reuses = %d", successCount, reuseCount)
	}
}

func TestSaveServiceConcurrentRevisionsAllowsOnlyOneWriter(t *testing.T) {
	ctx, service, accountID := openSaveService(t)
	requests := []gamesave.UpdateRequest{
		{
			IdempotencyKey:   firstSaveKey,
			ExpectedRevision: 0,
			RawBody:          []byte(`{"expectedRevision":0,"value":"first"}`),
			Data: gamesave.Data{
				Version:       gamesave.CurrentSchemaVersion,
				Preferences:   json.RawMessage(`{"value":"first"}`),
				Progression:   json.RawMessage(`{}`),
				TurretModules: json.RawMessage(`{}`),
			},
		},
		{
			IdempotencyKey:   secondSaveKey,
			ExpectedRevision: 0,
			RawBody:          []byte(`{"expectedRevision":0,"value":"second"}`),
			Data: gamesave.Data{
				Version:       gamesave.CurrentSchemaVersion,
				Preferences:   json.RawMessage(`{"value":"second"}`),
				Progression:   json.RawMessage(`{}`),
				TurretModules: json.RawMessage(`{}`),
			},
		},
	}

	start := make(chan struct{})
	errorsChannel := make(chan error, len(requests))
	var group sync.WaitGroup
	for _, request := range requests {
		group.Add(1)
		go func() {
			defer group.Done()
			<-start
			_, err := service.Update(ctx, accountID, request)
			errorsChannel <- err
		}()
	}
	close(start)
	group.Wait()
	close(errorsChannel)

	successCount := 0
	conflictCount := 0
	for err := range errorsChannel {
		if err == nil {
			successCount++
			continue
		}
		var conflict *gamesave.RevisionConflictError
		if !errors.As(err, &conflict) || conflict.CurrentRevision != 1 {
			t.Fatalf("concurrent update error = %v", err)
		}
		conflictCount++
	}
	if successCount != 1 || conflictCount != 1 {
		t.Fatalf("successes = %d, conflicts = %d", successCount, conflictCount)
	}
}

func TestSaveServiceRollsBackWholeTransactionOnPayloadFailure(t *testing.T) {
	ctx, service, accountID := openSaveService(t)
	_, err := service.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey:   firstSaveKey,
		ExpectedRevision: 0,
		RawBody:          []byte(`{"expectedRevision":0}`),
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			Preferences:   json.RawMessage(`[]`),
			Progression:   json.RawMessage(`{}`),
			TurretModules: json.RawMessage(`{}`),
		},
	})
	if err == nil {
		t.Fatal("invalid payload update succeeded")
	}
	if _, err := service.Get(ctx, accountID); !errors.Is(err, gamesave.ErrNotFound) {
		t.Fatalf("get rolled back save error = %v", err)
	}
}

func openSaveService(t *testing.T) (context.Context, *claimedSaveService, string) {
	t.Helper()
	databaseURL := os.Getenv("RUNE_NEXUS_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("RUNE_NEXUS_TEST_DATABASE_URL is not set")
	}
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		t.Fatalf("parse test database URL: %v", err)
	}
	if passwordFile := os.Getenv("RUNE_NEXUS_TEST_DATABASE_PASSWORD_FILE"); passwordFile != "" {
		password, err := os.ReadFile(passwordFile)
		if err != nil {
			t.Fatalf("read test database password: %v", err)
		}
		config.ConnConfig.Password = strings.TrimSpace(string(password))
	}

	ctx, cancel := context.WithTimeout(context.Background(), testDatabaseTimeout)
	t.Cleanup(cancel)
	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatalf("connect test database: %v", err)
	}
	t.Cleanup(pool.Close)
	account, err := dbgen.New(pool).CreateAccount(ctx)
	if err != nil {
		t.Fatalf("create account: %v", err)
	}
	var accountID string
	if err := pool.QueryRow(
		ctx,
		"SELECT $1::uuid::text",
		account.ID,
	).Scan(&accountID); err != nil {
		t.Fatalf("format account ID: %v", err)
	}
	now := time.Now().UTC()
	accessHash := sha256.Sum256(account.ID.Bytes[:])
	session, err := dbgen.New(pool).CreateSession(ctx, dbgen.CreateSessionParams{
		AccountID:        account.ID,
		AccessTokenHash:  accessHash[:],
		AccessExpiresAt:  pgtype.Timestamptz{Time: now.Add(15 * time.Minute), Valid: true},
		RefreshExpiresAt: pgtype.Timestamptz{Time: now.Add(24 * time.Hour), Valid: true},
	})
	if err != nil {
		t.Fatalf("create save test session: %v", err)
	}
	var sessionID string
	if err := pool.QueryRow(ctx, "SELECT $1::uuid::text", session.ID).Scan(&sessionID); err != nil {
		t.Fatalf("format session ID: %v", err)
	}
	service := gamesave.NewService(pool)
	claimBody := []byte(`{"clientInstanceId":"` + clientInstanceID + `","saveSchemaVersion":2,"clientBuild":"integration-test"}`)
	claim, err := service.ClaimWriter(ctx, accountID, sessionID, gamesave.ClaimWriterRequest{
		IdempotencyKey:   writerClaimKey,
		ClientInstanceID: clientInstanceID,
		RawBody:          claimBody,
	})
	if err != nil {
		t.Fatalf("claim save writer: %v", err)
	}
	t.Cleanup(func() {
		cleanupContext, cleanupCancel := context.WithTimeout(
			context.Background(),
			testDatabaseTimeout,
		)
		defer cleanupCancel()
		if _, err := pool.Exec(
			cleanupContext,
			"DELETE FROM accounts WHERE id = $1",
			account.ID,
		); err != nil {
			t.Errorf("delete test account: %v", err)
		}
	})
	return ctx, &claimedSaveService{
		service:          service,
		pool:             pool,
		accountUUID:      account.ID,
		sessionID:        sessionID,
		writerGeneration: claim.WriterGeneration,
	}, accountID
}
