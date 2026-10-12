//go:build integration

package dbtest_test

import (
	"encoding/json"
	"maps"
	"reflect"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func TestLegacyPaidPurchaseRecoveryCommitsInlineAdoption(t *testing.T) {
	ctx, save, account := openSaveService(t)
	f := &gemOfferFixture{t: t, ctx: ctx, save: save, service: economy.NewService(save.pool), account: account, compatibility: gamesave.CurrentClientCompatibilityVersion}
	legacy := map[string]any{
		"economyRunId": gemOfferRunID, "stageNumber": 1, "phase": "reward", "completedRounds": 8,
		"gemRerollsUsed": 2, "rewardOptions": []string{"range", "chain", "explosion"},
		"isPurchasedGemReward": true, "rewardReturnPhase": "wave", "gemInventory": map[string]int64{"range": 2},
		"gemShards": 7, "turrets": []any{},
	}
	seeded := seedPreAuthoritySave(t, save, account, gamesave.Data{
		Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`),
		Progression:   json.RawMessage(`{"growthVersion":1,"progressionVersion":1,"clearedStageNumbers":[3,21],"freeDiamonds":1000}`),
		TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`), ActiveRun: gemOfferJSON(t, legacy),
	})
	f.revision = seeded.Revision
	// Model an already valid pre-upgrade writer and bootstrapped wallet. Do not
	// claim a writer or bootstrap again: either would hide the inline-adoption path.
	if _, err := save.pool.Exec(ctx, `INSERT INTO player_economies(account_id,revision,free_diamonds,authority_state,bootstrap_save_revision,bootstrapped_at,gem_reroll_enabled,gem_reset_tickets,run_authority_enabled) VALUES($1,3,1000,'server_authoritative',$2,now(),true,4,false)`, account, seeded.Revision); err != nil {
		t.Fatal(err)
	}
	var err error
	f.economy, err = f.service.Get(ctx, account)
	if err != nil {
		t.Fatal(err)
	}
	if f.economy.GemOffer != nil || f.economy.Run != nil {
		t.Fatal("fixture was adopted before the direct purchase request")
	}
	before, err := save.Get(ctx, account)
	if err != nil {
		t.Fatal(err)
	}
	first, err := f.service.PurchaseGems(ctx, account, save.sessionID, f.offerRequest(8))
	if err != nil {
		t.Fatal(err)
	}
	offer := first.GemOffer
	if offer == nil || offer.OfferID == "" || offer.Kind != "purchase" || !offer.LegacyImported || offer.Status != "pending" || offer.PurchaseSequence != 1 || offer.TotalUsed != 2 || offer.GemShards != 7 {
		t.Fatalf("legacy paid recovery changed the outcome: %+v", offer)
	}
	if first.GemReceipt == nil || first.GemReceipt.EconomyRevision != 3 || first.GemReceipt.GemResetTickets != 4 || first.SaveRevision != seeded.Revision || len(first.ActiveRun) != 0 || first.Snapshot.AuthorityEpoch != "" {
		t.Fatalf("recovery mutated revisions or returned a noncompact receipt: %+v", first)
	}
	assertGemOfferJSONEqual(t, offer.GemOptions, legacy["rewardOptions"])
	var persisted []byte
	var enabled, adopted bool
	var pinned *int64
	if err = save.pool.QueryRow(ctx, `SELECT run.purchased_offer,wallet.run_authority_enabled,authority.adopted,authority.legacy_source_revision FROM economy_runs AS run JOIN player_economies AS wallet USING(account_id) JOIN account_run_authorities AS authority USING(account_id) WHERE run.account_id=$1 AND run.run_id=$2`, account, gemOfferRunID).Scan(&persisted, &enabled, &adopted, &pinned); err != nil {
		t.Fatalf("returned offer was rolled back instead of persisted: %v", err)
	}
	if !enabled || !adopted || pinned != nil {
		t.Fatalf("adoption was not committed: enabled=%t adopted=%t pin=%v", enabled, adopted, pinned)
	}
	assertGemOfferJSONEqual(t, json.RawMessage(persisted), offer)

	// Tuple versions prove ordinary fresh-key recovery does not write even an
	// unchanged row. SELECT FOR UPDATE alone does not change xmin.
	versions := func() []string {
		t.Helper()
		var rows []string
		if err := save.pool.QueryRow(ctx, `SELECT ARRAY[run.xmin::text,wallet.xmin::text,authority.xmin::text,header.xmin::text,active.xmin::text,writer.xmin::text] FROM economy_runs AS run JOIN player_economies AS wallet USING(account_id) JOIN account_run_authorities AS authority USING(account_id) JOIN save_headers AS header USING(account_id) JOIN save_active_runs AS active USING(account_id) JOIN save_writer_states AS writer USING(account_id) WHERE run.account_id=$1 AND run.run_id=$2`, account, gemOfferRunID).Scan(&rows); err != nil {
			t.Fatal(err)
		}
		return rows
	}
	adoptedVersions := versions()
	for range 2 {
		recovered, err := f.service.PurchaseGems(ctx, account, save.sessionID, f.offerRequest(8))
		if err != nil {
			t.Fatal(err)
		}
		assertGemOfferJSONEqual(t, recovered, first)
		if got := versions(); !reflect.DeepEqual(got, adoptedVersions) {
			t.Fatalf("already-adopted semantic recovery wrote database rows: %v != %v", got, adoptedVersions)
		}
	}
	current, err := f.service.Get(ctx, account)
	if err != nil || current.EconomyRevision != 3 || current.Wallet.FreeDiamonds != 1000 || current.Wallet.GemResetTickets != 4 {
		t.Fatalf("recovery changed wallet: %+v %v", current, err)
	}
	assertGemOfferJSONEqual(t, current.GemOffer, offer)
	after, err := save.Get(ctx, account)
	if err != nil || after.Revision != before.Revision || !after.ServerSavedAt.Equal(before.ServerSavedAt) {
		t.Fatalf("recovery changed canonical revision: %+v %v", after, err)
	}
	assertGemOfferJSONEqual(t, after.Data, before.Data)
	var commands int
	if err = save.pool.QueryRow(ctx, `SELECT count(*) FROM economy_commands WHERE account_id=$1`, account).Scan(&commands); err != nil || commands != 0 {
		t.Fatalf("legacy semantic recovery created a command receipt: %d %v", commands, err)
	}

	// GET exposes the durable identity; the upgraded client projects its markers
	// before choosing. Seven remaining shards cannot fund another 20-shard debit.
	f.economy = current
	projected := maps.Clone(legacy)
	projected["gemOfferId"], projected["gemOfferRevision"], projected["gemOfferStatus"] = offer.OfferID, offer.Revision, offer.Status
	projected["gemEconomyRevision"] = offer.EconomyRevision
	saveGemFloorRun(f, projected)
	chosen, err := f.service.ChooseGem(ctx, account, save.sessionID, f.chooseRequest(offer, "range"))
	if err != nil {
		t.Fatal(err)
	}
	f.accept(chosen)
	if chosen.GemOffer.GemInventory["range"] != 3 || chosen.GemOffer.GemShards != 7 || chosen.GemOffer.TotalUsed != 2 || chosen.GemReceipt.EconomyRevision != 4 {
		t.Fatalf("choice redebited shards or changed the imported budget: %+v", chosen)
	}
	if err = save.pool.QueryRow(ctx, `SELECT count(*) FROM economy_commands WHERE account_id=$1 AND command_type='gem_purchase'`, account).Scan(&commands); err != nil || commands != 0 {
		t.Fatalf("legacy purchase was charged as a new command: %d %v", commands, err)
	}
}
