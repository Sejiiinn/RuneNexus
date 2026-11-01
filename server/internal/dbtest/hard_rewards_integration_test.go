//go:build integration

package dbtest_test

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func openHardSettlement(t *testing.T, run string, progression string, tickets int64) (context.Context, *claimedSaveService, string, *economy.Service, economy.RunSettlementRequest) {
	t.Helper()
	ctx, fixture, accountID := openSaveService(t)
	modules := json.RawMessage(`{"tickets":0,"drawCount":0,"ticketPurchaseCount":0,"itemSequence":0,"items":[]}`)
	seedPreAuthoritySave(t, fixture, accountID, gamesave.Data{Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`), Progression: json.RawMessage(`{"freeDiamonds":0,"paidDiamonds":0}`), TurretModules: modules, ActiveRun: json.RawMessage(run)})
	service := economy.NewService(fixture.pool)
	if _, err := service.Bootstrap(ctx, accountID, fixture.sessionID, economy.BootstrapRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bea", RawBody: []byte(`{"bootstrap":true,"clientCompatibilityVersion":15}`),
		WriterGeneration: fixture.writerGeneration, ExpectedSaveRevision: 1,
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := fixture.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey: secondSaveKey, ExpectedRevision: 1,
		ClientCompatibilityVersion: gamesave.CurrentClientCompatibilityVersion,
		RawBody:                    []byte(`{"expectedRevision":1,"clientCompatibilityVersion":15}`),
		Data: gamesave.Data{
			Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`),
			Progression: json.RawMessage(progression), ActiveRun: json.RawMessage(run), TurretModules: modules,
		},
	}); err != nil {
		t.Fatal(err)
	}
	return ctx, fixture, accountID, service, economy.RunSettlementRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bf3", RunID: settlementRunID,
		RawBody: []byte(`{"clientCompatibilityVersion":15,"runId":"` + settlementRunID + `"}`), WriterGeneration: fixture.writerGeneration,
		SourceSaveRevision: 2, StageNumber: 11, CompletedRounds: 40, Success: true, FirstClearModuleTickets: tickets,
	}
}

const hardTerminalRun = `{"economyRunId":"0198b955-3656-7c40-b3cb-87f427b90bf2","stageNumber":11,"phase":"success","completedRounds":40,"roundIndex":39,"difficulty":"hard","gemRerollsUsed":0,"gemInventory":{},"gemShards":0,"turrets":[],"rewardOptions":[]}`
const hardProgression = `{"bestRoundsByStage":{"11":40},"hardBestRoundsByStage":{"11":40},"clearedStageNumbers":[1,2,3,11],"hardClearedStageNumbers":[11]}`

func TestHardSettlementGrantsFirstClearTicketsAndLoot(t *testing.T) {
	ctx, fixture, accountID, service, request := openHardSettlement(t, hardTerminalRun, hardProgression, economy.HardFirstClearModuleTickets)
	result, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	if result.GrantedModuleTickets != economy.HardFirstClearModuleTickets+result.HardDropModuleTickets || result.HardDropModuleTickets > 1 || len(result.HardLootModules) > 3 {
		t.Fatalf("hard result: %+v", result)
	}
	var tickets, sequence, modules, claims int64
	if err := fixture.pool.QueryRow(ctx, `SELECT module_tickets,module_item_sequence,
 (SELECT count(*) FROM player_modules WHERE account_id=$1),
 (SELECT count(*) FROM economy_reward_claims WHERE account_id=$1 AND reward_key='stage:11:hard_first_clear')
 FROM player_economies WHERE account_id=$1`, fixture.accountUUID).Scan(&tickets, &sequence, &modules, &claims); err != nil {
		t.Fatal(err)
	}
	if tickets != result.GrantedModuleTickets || modules != int64(len(result.HardLootModules)) || sequence != modules || claims != 1 {
		t.Fatalf("hard settlement state tickets=%d sequence=%d modules=%d claims=%d", tickets, sequence, modules, claims)
	}
	for _, module := range result.HardLootModules {
		// Poison opens only at 2-8 (stage 23), which this progression lacks.
		if module.TurretType == "" || module.TurretType == "poison" {
			t.Fatalf("loot on a locked turret: %q", module.TurretType)
		}
	}
	replayed, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
	if err != nil || len(replayed.HardLootModules) != len(result.HardLootModules) || replayed.GrantedModuleTickets != result.GrantedModuleTickets {
		t.Fatalf("replay changed the hard receipt: %+v %v", replayed, err)
	}
}

func TestHardFirstClearTicketsMatchDifficulty(t *testing.T) {
	normalRun := strings.Replace(hardTerminalRun, `"difficulty":"hard",`, "", 1)
	for _, tc := range []struct {
		name    string
		run     string
		tickets int64
	}{
		{"normal run claims hard tickets", normalRun, economy.HardFirstClearModuleTickets},
		{"hard run claims the stage 11 gift", hardTerminalRun, economy.StageElevenModuleTicketGift},
	} {
		ctx, fixture, accountID, service, request := openHardSettlement(t, tc.run, hardProgression, tc.tickets)
		if _, err := service.SettleRun(ctx, accountID, fixture.sessionID, request); !errors.Is(err, economy.ErrInvalidCommand) {
			t.Fatalf("%s: %v", tc.name, err)
		}
	}
}
