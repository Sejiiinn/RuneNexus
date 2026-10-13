//go:build integration

package dbtest_test

import (
	"errors"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func (f *gemOfferFixture) refreshEconomy() {
	f.t.Helper()
	var err error
	if f.economy, err = f.service.Get(f.ctx, f.account); err != nil {
		f.t.Fatal(err)
	}
}

// openDeckRun closes the fixture's legacy run and starts a generation-ten run.
func openDeckRun(t *testing.T) (*gemOfferFixture, economy.CommandResult, map[string]any) {
	t.Helper()
	f := openGemOfferFixture(t)
	closed, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, economy.CloseRunRequest{
		IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":10}`), RunID: gemOfferRunID,
		WriterGeneration: f.save.writerGeneration, SourceSaveRevision: f.revision,
		ExpectedRevision: f.economy.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion,
	})
	if err != nil {
		t.Fatal(err)
	}
	f.revision = closed.SaveRevision
	f.refreshEconomy()
	saveGemFloorRun(f, map[string]any{"economyRunId": "", "stageNumber": 1, "phase": "preparation", "completedRounds": 0, "roundIndex": 0, "gemRerollsUsed": 0, "gemInventory": map[string]int{}, "gemShards": 0, "turrets": []any{}, "rewardOptions": []string{}})
	start := economy.StartRunRequest{IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":10}`), WriterGeneration: f.save.writerGeneration, SourceSaveRevision: f.revision, ExpectedRevision: f.economy.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion, StageNumber: 1}
	started, err := f.service.StartRun(f.ctx, f.account, f.save.sessionID, start)
	if err != nil {
		t.Fatal(err)
	}
	if started.GemDeck == nil || started.Run == nil || started.GemDeck.RunID != started.Run.RunID || len(started.GemDeck.Waves) != 7 {
		t.Fatalf("generation-ten start issued no deck: %+v", started)
	}
	replay, err := f.service.StartRun(f.ctx, f.account, f.save.sessionID, start)
	if err != nil {
		t.Fatal(err)
	}
	assertGemOfferJSONEqual(t, replay, started)
	f.revision = started.SaveRevision
	f.refreshEconomy()
	current, err := f.save.Get(f.ctx, f.account)
	if err != nil {
		t.Fatal(err)
	}
	return f, started, gemFloorRun(t, current.Data.ActiveRun)
}

func TestDeckRunIsRecoverableFromTheEconomySnapshot(t *testing.T) {
	f, started, _ := openDeckRun(t)
	if f.economy.GemDeckVersion != economy.GemDeckVersion || f.economy.Run == nil || f.economy.Run.RunID != started.Run.RunID {
		t.Fatalf("snapshot run: %+v", f.economy)
	}
	assertGemOfferJSONEqual(t, f.economy.GemDeck, started.GemDeck)
	if f.economy.GemOffer != nil || f.economy.GemReroll != nil {
		t.Fatal("deck runs keep no server offer rows")
	}
}

func TestDeckRunCheckpointsCarryTheirHistoryAndCloseChargesRerolls(t *testing.T) {
	f, started, run := openDeckRun(t)
	f.grantTickets(5)
	f.refreshEconomy()
	wave := started.GemDeck.Waves["5"]
	run["completedRounds"], run["roundIndex"], run["phase"] = 5, 5, "reward"
	run["rewardOptions"], run["gemRerollsUsed"] = wave.Options[3], 3
	run["gemOfferId"], run["gemOfferRevision"], run["gemOfferStatus"] = wave.OfferID, 4, "pending"
	run["gemDeckLog"] = []any{map[string]any{"kind": "wave", "wave": 5, "rerolls": 3, "choice": ""}}
	saveGemFloorRun(f, run)

	// Server offer commands never apply to a deck run.
	legacy := economy.GemOfferRequest{IdempotencyKey: f.key(), ExpectedRevision: f.economy.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion, SourceSaveRevision: f.revision, WriterGeneration: f.save.writerGeneration, RunID: started.Run.RunID, CompletedRounds: 5}
	legacy.RawBody = f.body(legacy, nil)
	if _, err := f.service.OfferGems(f.ctx, f.account, f.save.sessionID, legacy); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("legacy offer on deck run: %v", err)
	}

	gem := wave.Options[3][0]
	run["phase"], run["rewardOptions"], run["gemInventory"] = "preparation", []string{}, map[string]int{gem: 1}
	run["gemOfferRevision"], run["gemOfferStatus"] = 5, "chosen"
	run["gemDeckLog"] = []any{map[string]any{"kind": "wave", "wave": 5, "rerolls": 3, "choice": gem}}
	saveGemFloorRun(f, run)

	closed, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, economy.CloseRunRequest{
		IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":10}`), RunID: started.Run.RunID,
		WriterGeneration: f.save.writerGeneration, SourceSaveRevision: f.revision,
		ExpectedRevision: f.economy.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion,
	})
	if err != nil {
		t.Fatal(err)
	}
	// Three rerolls: the first is free, the other two spend a ticket each.
	if closed.GemReceipt == nil || closed.GemReceipt.GemResetTickets != 3 {
		t.Fatalf("close charge: %+v", closed.GemReceipt)
	}
	var debit int64
	if err = f.save.pool.QueryRow(f.ctx, `SELECT COALESCE(sum(l.delta),0) FROM economy_ledger_entries l JOIN economy_commands c ON c.id=l.command_id WHERE c.account_id=$1 AND l.asset_type='gem_reset_ticket' AND l.reason='gem_reroll'`, f.account).Scan(&debit); err != nil || debit != -2 {
		t.Fatalf("ledger debit %d %v", debit, err)
	}
	f.revision = closed.SaveRevision
	f.refreshEconomy()
	if f.economy.Wallet.GemResetTickets != 3 || f.economy.GemDeck != nil {
		t.Fatalf("closed deck run economy: %+v", f.economy)
	}
}

func TestDeckRunSettlementChargesRecordedRerollsOnce(t *testing.T) {
	f, started, run := openDeckRun(t)
	f.grantTickets(1)
	f.refreshEconomy()
	// A generation-ten body is a conflict, never an update prompt.
	current := economy.GemOfferRequest{IdempotencyKey: f.key(), ExpectedRevision: f.economy.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion, SourceSaveRevision: f.revision, WriterGeneration: f.save.writerGeneration, RunID: started.Run.RunID, CompletedRounds: 5}
	current.RawBody = f.body(current, map[string]any{"clientCompatibilityVersion": 10})
	if _, err := f.service.OfferGems(f.ctx, f.account, f.save.sessionID, current); !errors.Is(err, economy.ErrGemOfferConflict) {
		t.Fatalf("current client offer on deck run: %v", err)
	}
	// Three recorded rerolls cost two tickets; only one is left, so the debit stops at zero.
	run["phase"], run["gemRerollsUsed"] = "failure", 3
	run["gemDeckLog"] = []any{map[string]any{"kind": "wave", "wave": 5, "rerolls": 3, "choice": "shards"}}
	saveGemFloorRun(f, run)
	request := economy.RunSettlementRequest{IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":10}`), RunID: started.Run.RunID, WriterGeneration: f.save.writerGeneration, SourceSaveRevision: f.revision, StageNumber: 1}
	settled, err := f.service.SettleRun(f.ctx, f.account, f.save.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	if settled.Run == nil || settled.Run.Status != "closed" || settled.Snapshot.Wallet.GemResetTickets != 0 {
		t.Fatalf("settlement charge: %+v", settled)
	}
	replay, err := f.service.SettleRun(f.ctx, f.account, f.save.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	assertGemOfferJSONEqual(t, replay, settled)
	f.grantTickets(4)
	f.refreshEconomy()
	if f.economy.Wallet.GemResetTickets != 4 {
		t.Fatalf("settled run charged again: %+v", f.economy.Wallet)
	}
}
