//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"maps"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func gemFloorRun(t *testing.T, raw []byte) map[string]any {
	t.Helper()
	var run map[string]any
	if err := json.Unmarshal(raw, &run); err != nil {
		t.Fatal(err)
	}
	return run
}
func gemFloorTurret(id int, slots ...any) map[string]any {
	return map[string]any{"id": id, "type": "arrow", "slotLimit": len(slots), "equippedGemSlots": slots}
}
func chooseGemFloorOffer(f *gemOfferFixture, offer economy.CommandResult, gem string) economy.CommandResult {
	f.t.Helper()
	result, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, f.chooseRequest(offer.GemOffer, gem))
	if err != nil {
		f.t.Fatal(err)
	}
	f.accept(result)
	return result
}
func saveGemFloorRun(f *gemOfferFixture, run any) {
	f.t.Helper()
	if err := f.saveRun(run); err != nil {
		f.t.Fatalf("valid exact allocation rejected: %v", err)
	}
}
func rejectGemFloorRun(f *gemOfferFixture, run any) {
	f.t.Helper()
	before, err := f.save.Get(f.ctx, f.account)
	if err != nil {
		f.t.Fatal(err)
	}
	if err = f.saveRun(run); !errors.Is(err, gamesave.ErrGemOfferConflict) {
		f.t.Fatalf("invalid run must conflict, got %v", err)
	}
	after, err := f.save.Get(f.ctx, f.account)
	if err != nil || after.Revision != before.Revision {
		f.t.Fatalf("rejected upload changed save: %v", err)
	}
	assertGemOfferJSONEqual(f.t, after.Data, before.Data)
}
func looseGems(t *testing.T, run map[string]any) map[string]int64 {
	t.Helper()
	var owned map[string]int64
	if err := json.Unmarshal(gemOfferJSON(t, run["gemInventory"]), &owned); err != nil {
		t.Fatal(err)
	}
	return owned
}

func TestExactGemOwnershipConservesEquipUnequipReplacementAndSale(t *testing.T) {
	f := openGemOfferFixture(t)
	offer := f.issue(5)
	gem := offer.GemOffer.GemOptions[0]
	chosen := chooseGemFloorOffer(f, offer, gem)
	run := gemFloorRun(t, f.runFor(chosen))
	all := looseGems(t, run) // Includes the canonical imported range:2 baseline.
	inventory := maps.Clone(all)
	inventory[gem]--
	run["gemInventory"] = inventory
	run["turrets"] = []any{gemFloorTurret(1, gem, nil)}
	saveGemFloorRun(f, run)
	run["turrets"] = []any{gemFloorTurret(2, nil, gem)}
	saveGemFloorRun(f, run)
	// Replace equipped grant with one legacy range, returning the grant to loose inventory.
	inventory[gem]++
	inventory["range"]--
	run["turrets"] = []any{gemFloorTurret(2, "range", nil)}
	saveGemFloorRun(f, run)
	inventory["range"]++
	run["turrets"] = []any{}
	saveGemFloorRun(f, run)
	extra := maps.Clone(all)
	extra[gem]++
	run["gemInventory"] = extra
	rejectGemFloorRun(f, run)
	missing := maps.Clone(all)
	missing[gem]--
	run["gemInventory"] = missing
	rejectGemFloorRun(f, run)
	// Equal total with a changed gem type is also invalid.
	missing["explosion"]++
	if gem == "explosion" {
		missing["explosion"]--
		missing["chain"]++
	}
	rejectGemFloorRun(f, run)
	run["gemInventory"] = all
	saveGemFloorRun(f, run)
}

func TestExactGemOwnershipRetainsEarlierAwardsWhileNextOfferPending(t *testing.T) {
	f := openGemOfferFixture(t)
	first := f.issue(5)
	a := first.GemOffer.GemOptions[0]
	first = chooseGemFloorOffer(f, first, a)
	run := gemFloorRun(t, f.runFor(first))
	inventory := looseGems(t, run)
	inventory[a]--
	run["gemInventory"] = inventory
	run["turrets"] = []any{gemFloorTurret(1, a, nil)}
	run["phase"], run["completedRounds"] = "reward", 10
	saveGemFloorRun(f, run)
	next := f.issue(10)
	run = gemFloorRun(t, f.runFor(next))
	run["turrets"] = []any{}
	rejectGemFloorRun(f, run)
	run = gemFloorRun(t, f.runFor(next))
	inventory = looseGems(t, run)
	inventory[a]++
	run["gemInventory"] = inventory
	run["turrets"] = []any{}
	saveGemFloorRun(f, run) // Allocation may change while pending.
	chosen := chooseGemFloorOffer(f, next, next.GemOffer.GemOptions[0])
	current := gemFloorRun(t, f.runFor(chosen))
	if len(current["turrets"].([]any)) != 0 {
		t.Fatal("choice restored obsolete equipment")
	}
}

func TestExactGemOwnershipCountsCopiesAndIgnoresMirror(t *testing.T) {
	f := openGemOfferFixture(t)
	chosen := chooseGemFloorOffer(f, f.issue(5), "shards")
	run := gemFloorRun(t, f.runFor(chosen))
	run["gemInventory"] = map[string]int64{}
	run["turrets"] = []any{gemFloorTurret(1, "range"), gemFloorTurret(2, "range")}
	saveGemFloorRun(f, run)
	run["turrets"] = []any{map[string]any{"type": "arrow", "slotLimit": 1, "equippedGemSlots": []any{"range"}, "equippedGems": []any{"range"}}}
	rejectGemFloorRun(f, run)
	run["gemInventory"] = map[string]int64{"range": 1}
	saveGemFloorRun(f, run)
	run["gemInventory"] = map[string]int64{}
	run["turrets"] = []any{gemFloorTurret(1, "range", "range")}
	rejectGemFloorRun(f, run)
}

func TestExactGemOwnershipRejectsMalformedSlotsAndPurchasedFlagBypass(t *testing.T) {
	f := openGemOfferFixture(t)
	offer := f.issue(5)
	chosen := chooseGemFloorOffer(f, offer, "shards")
	for _, change := range []func(map[string]any){
		func(r map[string]any) { r["gemInventory"] = map[string]int64{"range": 3} },
		func(r map[string]any) {
			r["isPurchasedGemReward"] = true
			r["phase"] = "reward"
			r["rewardOptions"] = offer.GemOffer.GemOptions
		},
		func(r map[string]any) { r["paidGemRoll"] = true },
		func(r map[string]any) {
			r["turrets"] = []any{map[string]any{"type": "arrow", "slotLimit": nil, "equippedGemSlots": []any{}}}
		},
		func(r map[string]any) {
			r["turrets"] = []any{map[string]any{"type": "unknown", "equippedGemSlots": []any{}}}
		},
	} {
		run := gemFloorRun(t, f.runFor(chosen))
		change(run)
		rejectGemFloorRun(f, run)
	}
}

func TestRunIdentityRejectsNullReplacementAndReopenAfterClose(t *testing.T) {
	f := openGemOfferFixture(t)
	offer := f.issue(5)
	rejectGemFloorRun(f, nil)
	for _, id := range []string{"", "0198b955-3656-7c40-b3cb-87f427b90bfb"} {
		run := gemFloorRun(t, f.runFor(offer))
		run["economyRunId"] = id
		rejectGemFloorRun(f, run)
	}
	request := economy.CloseRunRequest{IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":9}`), RunID: gemOfferRunID, WriterGeneration: f.save.writerGeneration, SourceSaveRevision: f.revision, ExpectedRevision: f.economy.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion}
	closed, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	if closed.Run == nil || closed.Run.Status != "closed" || closed.GemReceipt == nil || len(closed.ActiveRun) != 0 || closed.Snapshot.AuthorityEpoch != "" {
		t.Fatalf("invalid compact close: %+v", closed)
	}
	f.revision = closed.SaveRevision
	f.economy, err = f.service.Get(f.ctx, f.account)
	if err != nil {
		t.Fatal(err)
	}
	rejectGemFloorRun(f, gemFloorRun(t, f.runFor(offer)))
	replay, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	assertGemOfferJSONEqual(t, replay, closed)
	request.IdempotencyKey = f.key()
	request.SourceSaveRevision = f.revision
	request.ExpectedRevision = f.economy.EconomyRevision
	recovered, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, request)
	if err != nil || recovered.SaveRevision != closed.SaveRevision || recovered.GemReceipt.EconomyRevision != closed.GemReceipt.EconomyRevision {
		t.Fatalf("read-only close recovery: %+v %v", recovered, err)
	}
	// A new server run binds a pristine provisional checkpoint, never a submitted UUID.
	provisional := map[string]any{"economyRunId": "", "stageNumber": 1, "phase": "preparation", "completedRounds": 0, "roundIndex": 0, "gemRerollsUsed": 0, "gemInventory": map[string]int{}, "gemShards": 0, "turrets": []any{}, "rewardOptions": []string{}}
	saveGemFloorRun(f, provisional)
	startRequest := economy.StartRunRequest{IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":9}`), WriterGeneration: f.save.writerGeneration, SourceSaveRevision: f.revision, ExpectedRevision: f.economy.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion, StageNumber: 1}
	started, err := f.service.StartRun(f.ctx, f.account, f.save.sessionID, startRequest)
	if err != nil {
		t.Fatal(err)
	}
	if started.Run == nil || started.Run.RunID == gemOfferRunID || started.Run.RunID == "" || started.Run.LegacyImported || started.Run.Status != "active" {
		t.Fatalf("server did not issue a new run: %+v", started)
	}
	f.revision = started.SaveRevision
	fresh, err := f.save.Get(f.ctx, f.account)
	if err != nil {
		t.Fatal(err)
	}
	forged := gemFloorRun(t, fresh.Data.ActiveRun)
	forged["gemInventory"] = map[string]int64{"range": 1}
	rejectGemFloorRun(f, forged)
	f.economy, err = f.service.Get(f.ctx, f.account)
	if err != nil {
		t.Fatal(err)
	}
	startRequest.IdempotencyKey = f.key()
	startRequest.SourceSaveRevision = f.revision
	startRequest.ExpectedRevision = f.economy.EconomyRevision
	if _, err = f.service.StartRun(f.ctx, f.account, f.save.sessionID, startRequest); !errors.Is(err, economy.ErrGemOfferConflict) {
		t.Fatalf("second simultaneous active run accepted: %v", err)
	}
}

func TestLegacyCanonicalBaselineImportsOnceAndRequiresGenerationNine(t *testing.T) {
	f := openGemOfferFixture(t)
	// The first command imports the existing canonical range:2, never the incoming save.
	offer := f.issue(5)
	var imported bool
	var owned []byte
	if err := f.save.pool.QueryRow(f.ctx, `SELECT legacy_imported,owned_gems FROM economy_runs WHERE account_id=$1 AND run_id=$2`, f.account, gemOfferRunID).Scan(&imported, &owned); err != nil {
		t.Fatal(err)
	}
	if !imported {
		t.Fatal("canonical provenance not recorded")
	}
	assertGemOfferJSONEqual(t, json.RawMessage(owned), map[string]int{"range": 2})
	current, err := f.save.Get(f.ctx, f.account)
	if err != nil {
		t.Fatal(err)
	}
	_, err = f.save.Update(f.ctx, f.account, gamesave.UpdateRequest{IdempotencyKey: f.key(), ExpectedRevision: f.revision, ClientCompatibilityVersion: 8, RawBody: []byte(`{"clientCompatibilityVersion":8}`), Data: current.Data})
	if !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old client overwrote adopted run: %v", err)
	}
	run := gemFloorRun(t, f.runFor(offer))
	run["gemInventory"] = map[string]int64{"range": 200}
	rejectGemFloorRun(f, run)
}

func TestMigrationPinnedLegacyPurchasedChoicePreservesDebitCandidatesAndUsage(t *testing.T) {
	ctx, save, account := openSaveService(t)
	f := &gemOfferFixture{t: t, ctx: ctx, save: save, service: economy.NewService(save.pool), account: account}
	legacy := map[string]any{"economyRunId": gemOfferRunID, "stageNumber": 1, "phase": "reward", "completedRounds": 8, "gemRerollsUsed": 2, "rewardOptions": []string{"range", "chain", "explosion"}, "isPurchasedGemReward": true, "rewardReturnPhase": "wave", "gemInventory": map[string]int64{"range": 2}, "gemShards": 7, "turrets": []any{}}
	initial := gamesave.UpdateRequest{IdempotencyKey: f.key(), ExpectedRevision: 0, ClientCompatibilityVersion: 8, RawBody: []byte(`{"clientCompatibilityVersion":8,"legacyFixture":true}`), Data: gamesave.Data{Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`), Progression: json.RawMessage(`{"growthVersion":1,"progressionVersion":1,"clearedStageNumbers":[3,21],"freeDiamonds":1000}`), TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`), ActiveRun: gemOfferJSON(t, legacy)}}
	saved := seedPreAuthoritySave(t, save, account, initial.Data)
	seedLegacySaveReceipt(t, save, initial, saved)
	f.revision = saved.Revision
	var err error
	blocked := initial
	blocked.IdempotencyKey = f.key()
	blocked.ExpectedRevision = f.revision
	if _, err = save.Update(ctx, account, blocked); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old write changed pinned revision: %v", err)
	}
	replay, err := save.Update(ctx, account, initial)
	if err != nil || replay.Revision != saved.Revision {
		t.Fatalf("legacy exact receipt lost: %+v %v", replay, err)
	}
	claim, err := save.service.ClaimWriter(ctx, account, save.sessionID, gamesave.ClaimWriterRequest{IdempotencyKey: f.key(), ClientInstanceID: clientInstanceID, RawBody: []byte(`{"clientCompatibilityVersion":9}`), ClientCompatibilityVersion: 9})
	if err != nil {
		t.Fatal(err)
	}
	save.writerGeneration = claim.WriterGeneration
	boot, err := f.service.Bootstrap(ctx, account, save.sessionID, economy.BootstrapRequest{IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":9}`), WriterGeneration: save.writerGeneration, ExpectedSaveRevision: f.revision})
	if err != nil {
		t.Fatal(err)
	}
	f.economy = boot.Snapshot
	offer := boot.Snapshot.GemOffer
	if offer == nil || offer.Kind != "purchase" || !offer.LegacyImported || offer.TotalUsed != 2 || offer.GemShards != 7 || offer.PurchaseSequence != 1 || offer.Status != "pending" {
		t.Fatalf("legacy paid choice was not preserved: %+v", offer)
	}
	assertGemOfferJSONEqual(t, offer.GemOptions, legacy["rewardOptions"])
	saveGemFloorRun(f, legacy) // Canonical old markers may bridge once to a server offer without a re-debit.
	forged := maps.Clone(legacy)
	forged["rewardOptions"] = []string{"attackSpeed", "chain", "range"}
	rejectGemFloorRun(f, forged)
	forged = maps.Clone(legacy)
	forged["gemInventory"] = map[string]int64{"range": 3}
	rejectGemFloorRun(f, forged)
	// The current economy snapshot supplies the newly issued identity; the
	// client syncs that projection before submitting its choice command.
	projected := maps.Clone(legacy)
	projected["gemOfferId"], projected["gemOfferRevision"], projected["gemOfferStatus"] = offer.OfferID, offer.Revision, offer.Status
	projected["gemEconomyRevision"] = offer.EconomyRevision
	saveGemFloorRun(f, projected)
	chosen, err := f.service.ChooseGem(ctx, account, save.sessionID, f.chooseRequest(offer, "range"))
	if err != nil {
		t.Fatal(err)
	}
	f.accept(chosen)
	if chosen.GemOffer.GemInventory["range"] != 3 || chosen.GemOffer.GemShards != 7 || chosen.GemOffer.TotalUsed != 2 {
		t.Fatalf("legacy choice redebited or reset budget: %+v", chosen.GemOffer)
	}
	var adopted bool
	var revision *int64
	if err = save.pool.QueryRow(ctx, `SELECT adopted,legacy_source_revision FROM account_run_authorities WHERE account_id=$1`, account).Scan(&adopted, &revision); err != nil || !adopted || revision != nil {
		t.Fatalf("legacy provenance was not consumed atomically: %v", err)
	}
}

func TestPostMigrationCanonicalUploadCannotBecomeLegacyImport(t *testing.T) {
	ctx, save, account := openSaveService(t)
	legacy := gamesave.Data{Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`), Progression: json.RawMessage(`{}`), TurretModules: json.RawMessage(`{}`), ActiveRun: json.RawMessage(`{"economyRunId":"` + gemOfferRunID + `","stageNumber":1,"phase":"preparation","gemInventory":{"range":999},"gemRerollsUsed":0}`)}
	// Fresh old writes fail before they can strand a post-migration account.
	_, err := save.Update(ctx, account, gamesave.UpdateRequest{IdempotencyKey: firstSaveKey, ExpectedRevision: 0, ClientCompatibilityVersion: 8, RawBody: []byte(`{"clientCompatibilityVersion":8}`), Data: legacy})
	if !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old fresh writer accepted: %v", err)
	}
	// Even if an unproven source exists through historical test setup, it is
	// never upgraded into an ownership baseline without a migration pin.
	result := seedPreAuthoritySave(t, save, account, legacy)
	if _, err = save.pool.Exec(ctx, `DELETE FROM account_run_authorities WHERE account_id=$1`, account); err != nil {
		t.Fatal(err)
	}
	_, err = save.service.ClaimWriter(ctx, account, save.sessionID, gamesave.ClaimWriterRequest{IdempotencyKey: secondClaimKey, ClientInstanceID: clientInstanceID, ClientCompatibilityVersion: 9, RawBody: []byte(`{"clientCompatibilityVersion":9}`)})
	if !errors.Is(err, gamesave.ErrGemOfferConflict) {
		t.Fatalf("unproven canonical run imported: %v", err)
	}
	after, err := save.Get(ctx, account)
	if err != nil || after.Revision != result.Revision {
		t.Fatalf("conflict discarded source checkpoint: %v", err)
	}
	assertGemOfferJSONEqual(t, after.Data, legacy)
}

func TestPinnedGenerationSevenBudgetProjectsUsageWithoutOldCandidates(t *testing.T) {
	for _, normalized := range []bool{false, true} {
		name := "runtime maximum defense"
		if normalized {
			name = "migration-normalized cold bootstrap"
		}
		t.Run(name, func(t *testing.T) {
			ctx, save, account := openSaveService(t)
			f := &gemOfferFixture{t: t, ctx: ctx, save: save, service: economy.NewService(save.pool), account: account}
			legacy := map[string]any{"economyRunId": gemOfferRunID, "stageNumber": 1, "phase": "preparation", "completedRounds": 5, "gemRerollsUsed": 2, "gemInventory": map[string]int64{"range": 2}, "gemShards": 7, "rewardOptions": []string{}}
			data := gamesave.Data{Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`), Progression: json.RawMessage(`{"growthVersion":1,"progressionVersion":1,"clearedStageNumbers":[3,21]}`), TurretModules: json.RawMessage(`{"items":[]}`), ActiveRun: gemOfferJSON(t, legacy)}
			seeded := seedPreAuthoritySave(t, save, account, data)
			f.revision = seeded.Revision
			if _, err := save.pool.Exec(ctx, `INSERT INTO player_economies(account_id,revision,authority_state,bootstrap_save_revision,bootstrapped_at,gem_reroll_enabled,gem_reset_tickets) VALUES($1,3,'server_authoritative',$2,now(),true,4)`, account, seeded.Revision); err != nil {
				t.Fatal(err)
			}
			var command string
			if err := save.pool.QueryRow(ctx, `INSERT INTO economy_commands(account_id,idempotency_key,command_type,request_hash,resulting_revision,authority_epoch,response_payload) SELECT $1,$2,'gem_reroll',decode(repeat('00',32),'hex'),3,authority_epoch,'{}'::jsonb FROM economy_system_state WHERE singleton RETURNING id::text`, account, f.key()).Scan(&command); err != nil {
				t.Fatal(err)
			}
			if _, err := save.pool.Exec(ctx, `INSERT INTO economy_gem_rerolls(account_id,run_id,reward_wave,total_used,gem_options,command_id) VALUES($1,$2,5,3,ARRAY['range','chain','explosion'],$3)`, account, gemOfferRunID, command); err != nil {
				t.Fatal(err)
			}
			if normalized {
				// Emulate the bounded migration016 reconciliation before its final pin.
				// Independent PostgreSQL migration tests execute the actual rollout SQL.
				if err := save.pool.QueryRow(ctx, `WITH changed AS (UPDATE save_active_runs SET payload=jsonb_set(payload,'{gemRerollsUsed}','3'::jsonb) WHERE account_id=$1 RETURNING account_id) UPDATE save_headers SET revision=revision+1,updated_at=now() FROM changed WHERE save_headers.account_id=changed.account_id RETURNING revision`, account).Scan(&f.revision); err != nil {
					t.Fatal(err)
				}
				if _, err := save.pool.Exec(ctx, `UPDATE account_run_authorities SET legacy_source_revision=$2 WHERE account_id=$1`, account, f.revision); err != nil {
					t.Fatal(err)
				}
			}
			claim, err := save.service.ClaimWriter(ctx, account, save.sessionID, gamesave.ClaimWriterRequest{IdempotencyKey: f.key(), ClientInstanceID: clientInstanceID, ClientCompatibilityVersion: 9, RawBody: []byte(`{"clientCompatibilityVersion":9}`)})
			if err != nil {
				t.Fatal(err)
			}
			save.writerGeneration = claim.WriterGeneration
			var used int
			if err = save.pool.QueryRow(ctx, `SELECT total_used FROM economy_runs WHERE account_id=$1 AND run_id=$2`, account, gemOfferRunID).Scan(&used); err != nil || used != 3 {
				t.Fatalf("durable budget not imported: %d %v", used, err)
			}
			if normalized {
				// Cold startup PUT occurs before the first economy GET; it must work using
				// only the migration-normalized canonical checkpoint.
				canonical, e := save.Get(ctx, account)
				if e != nil {
					t.Fatal(e)
				}
				var run map[string]any
				if json.Unmarshal(canonical.Data.ActiveRun, &run) != nil {
					t.Fatal("invalid canonical")
				}
				if run["gemRerollsUsed"] != float64(3) || len(run["rewardOptions"].([]any)) != 0 {
					t.Fatal("rollout did not normalize only usage")
				}
				saveGemFloorRun(f, run)
			}
			f.economy, err = f.service.Get(ctx, account)
			if err != nil {
				t.Fatal(err)
			}
			if f.economy.GemReroll == nil || f.economy.GemReroll.TotalUsed != 3 || f.economy.GemOffer != nil {
				t.Fatalf("missing usage-only recovery: %+v", f.economy)
			}
			rejectGemFloorRun(f, legacy)
			legacy["gemRerollsUsed"] = f.economy.GemReroll.TotalUsed
			saveGemFloorRun(f, legacy)
			checkpoint, err := save.Get(ctx, account)
			if err != nil {
				t.Fatal(err)
			}
			var saved map[string]any
			if json.Unmarshal(checkpoint.Data.ActiveRun, &saved) != nil {
				t.Fatal("invalid canonical checkpoint")
			}
			if len(saved["rewardOptions"].([]any)) != 0 {
				t.Fatal("historical candidates were restored during usage-only recovery")
			}
			if f.economy.Wallet.GemResetTickets != 4 {
				t.Fatal("usage recovery charged a ticket")
			}
		})
	}
}
