//go:build integration

package dbtest_test

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"slices"
	"sync"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

const gemOfferRunID = "0198b955-3656-7c40-b3cb-87f427b90bfa"

type gemOfferFixture struct {
	t             *testing.T
	ctx           context.Context
	save          *claimedSaveService
	service       *economy.Service
	account       string
	sequence      int
	revision      int64
	economy       economy.Snapshot
	checkpoints   map[string]json.RawMessage
	compatibility int
}

func openGemOfferFixture(t *testing.T) *gemOfferFixture {
	t.Helper()
	ctx, save, account := openSaveService(t)
	f := &gemOfferFixture{t: t, ctx: ctx, save: save, service: economy.NewService(save.pool), account: account, compatibility: 9}
	initial := map[string]any{"economyRunId": gemOfferRunID, "stageNumber": 1, "phase": "reward", "completedRounds": 5, "gemRerollsUsed": 0, "rewardOptions": []string{}, "isPurchasedGemReward": false, "gemInventory": map[string]int64{"range": 2}, "gemShards": 7}
	seeded := seedPreAuthoritySave(t, save, account, gamesave.Data{Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`), Progression: json.RawMessage(`{"growthVersion":1,"progressionVersion":1,"clearedStageNumbers":[3,21],"freeDiamonds":1000}`), TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`), ActiveRun: gemOfferJSON(t, initial)})
	f.revision = seeded.Revision
	boot, err := f.service.Bootstrap(ctx, account, save.sessionID, economy.BootstrapRequest{
		IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":9}`),
		WriterGeneration: save.writerGeneration, ExpectedSaveRevision: f.revision,
	})
	if err != nil {
		t.Fatalf("bootstrap gem offer fixture: %v", err)
	}
	f.economy = boot.Snapshot
	return f
}

func (f *gemOfferFixture) key() string {
	f.sequence++
	return fmt.Sprintf("0198b955-3656-7c40-b3cc-%012x", f.sequence)
}

func gemOfferJSON(t *testing.T, value any) []byte {
	t.Helper()
	raw, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func (f *gemOfferFixture) saveRun(run any) error {
	f.t.Helper()
	var active json.RawMessage
	if run != nil {
		active = gemOfferJSON(f.t, run)
	}
	id := f.key()
	result, err := f.save.Update(f.ctx, f.account, gamesave.UpdateRequest{
		IdempotencyKey: id, ExpectedRevision: f.revision, ClientCompatibilityVersion: f.compatibility,
		RawBody: gemOfferJSON(f.t, map[string]any{
			"clientCompatibilityVersion": f.compatibility, "expectedRevision": f.revision, "activeRun": active,
		}),
		Data: gamesave.Data{
			Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`),
			Progression:   json.RawMessage(`{"growthVersion":1,"progressionVersion":1,"clearedStageNumbers":[3,21],"freeDiamonds":1000}`),
			TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`), ActiveRun: active,
		},
	})
	if err == nil {
		f.revision = result.Revision
	}
	return err
}

func (f *gemOfferFixture) body(request economy.GemOfferRequest, extra map[string]any) []byte {
	f.t.Helper()
	fields := map[string]any{
		"clientCompatibilityVersion": 9, "runId": request.RunID,
		"completedRounds": request.CompletedRounds, "sourceSaveRevision": request.SourceSaveRevision,
		"expectedEconomyRevision": request.ExpectedRevision, "expectedCatalogVersion": request.ExpectedCatalogVersion,
		"writerGeneration": request.WriterGeneration,
	}
	for key, value := range extra {
		fields[key] = value
	}
	return gemOfferJSON(f.t, fields)
}

func (f *gemOfferFixture) offerRequest(wave int) economy.GemOfferRequest {
	request := economy.GemOfferRequest{
		IdempotencyKey: f.key(), ExpectedRevision: f.economy.EconomyRevision,
		ExpectedCatalogVersion: economy.CatalogVersion, SourceSaveRevision: f.revision,
		WriterGeneration: f.save.writerGeneration, RunID: gemOfferRunID, CompletedRounds: wave,
	}
	request.RawBody = f.body(request, nil)
	return request
}

func (f *gemOfferFixture) rerollRequest(offer *economy.GemOfferState) economy.GemRerollRequest {
	base := f.offerRequest(offer.RewardWave)
	return economy.GemRerollRequest{
		IdempotencyKey: base.IdempotencyKey, ExpectedRevision: base.ExpectedRevision,
		ExpectedCatalogVersion: base.ExpectedCatalogVersion, SourceSaveRevision: base.SourceSaveRevision,
		WriterGeneration: base.WriterGeneration, RunID: base.RunID, CompletedRounds: base.CompletedRounds,
		OfferID: offer.OfferID, ExpectedOfferRevision: offer.Revision, ExpectedRerollCount: offer.TotalUsed,
		RawBody: f.body(base, map[string]any{
			"offerId": offer.OfferID, "expectedOfferRevision": offer.Revision, "expectedRerollCount": offer.TotalUsed,
		}),
	}
}

func (f *gemOfferFixture) chooseRequest(offer *economy.GemOfferState, choice string) economy.GemChooseRequest {
	base := f.offerRequest(offer.RewardWave)
	base.RawBody = f.body(base, map[string]any{
		"offerId": offer.OfferID, "expectedOfferRevision": offer.Revision, "choice": choice,
	})
	return economy.GemChooseRequest{
		GemOfferRequest: base, OfferID: offer.OfferID, ExpectedOfferRevision: offer.Revision, Choice: choice,
	}
}

func (f *gemOfferFixture) accept(result economy.CommandResult) {
	f.t.Helper()
	if result.GemOffer == nil || result.GemOffer.OfferID == "" || len(result.GemOffer.GemOptions) != 3 {
		f.t.Fatalf("missing authoritative offer: %+v", result)
	}
	for i, gem := range result.GemOffer.GemOptions {
		if gem == "" || slices.Contains(result.GemOffer.GemOptions[:i], gem) {
			f.t.Fatalf("invalid offer options: %v", result.GemOffer.GemOptions)
		}
	}
	if result.GemReceipt == nil || result.GemReceipt.Version != 1 || len(result.ActiveRun) != 0 || result.Snapshot.AuthorityEpoch != "" {
		f.t.Fatalf("receipt is not compact: %+v", result)
	}
	f.revision = result.SaveRevision
	var err error
	f.economy, err = f.service.Get(f.ctx, f.account)
	if err != nil {
		f.t.Fatal(err)
	}
	saved, err := f.save.Get(f.ctx, f.account)
	if err != nil {
		f.t.Fatal(err)
	}
	if f.checkpoints == nil {
		f.checkpoints = map[string]json.RawMessage{}
	}
	f.checkpoints[fmt.Sprintf("%s/%d", result.GemOffer.OfferID, result.GemOffer.Revision)] = saved.Data.ActiveRun
	f.assertCanonical(result)
}

func (f *gemOfferFixture) issue(wave int) economy.CommandResult {
	f.t.Helper()
	result, err := f.service.OfferGems(f.ctx, f.account, f.save.sessionID, f.offerRequest(wave))
	if err != nil {
		f.t.Fatalf("issue wave %d offer: %v", wave, err)
	}
	f.accept(result)
	return result
}

func assertGemOfferJSONEqual(t *testing.T, got, want any) {
	t.Helper()
	// PostgreSQL JSONB normalizes whitespace inside the embedded activeRun.
	var decodedGot, decodedWant any
	if err := json.Unmarshal(gemOfferJSON(t, got), &decodedGot); err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(gemOfferJSON(t, want), &decodedWant); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(decodedGot, decodedWant) {
		t.Fatalf("JSON mismatch:\ngot  %s\nwant %s", gemOfferJSON(t, got), gemOfferJSON(t, want))
	}
}

func (f *gemOfferFixture) assertCanonical(result economy.CommandResult) {
	f.t.Helper()
	saved, err := f.save.Get(f.ctx, f.account)
	if err != nil || saved.Revision != result.SaveRevision {
		f.t.Fatalf("canonical save revision: got %d, want %d, error %v", saved.Revision, result.SaveRevision, err)
	}
	var run struct {
		OfferID       string           `json:"gemOfferId"`
		OfferRevision int64            `json:"gemOfferRevision"`
		OfferStatus   string           `json:"gemOfferStatus"`
		Used          int              `json:"gemRerollsUsed"`
		Options       []string         `json:"rewardOptions"`
		Inventory     map[string]int64 `json:"gemInventory"`
		Shards        int64            `json:"gemShards"`
	}
	if err := json.Unmarshal(saved.Data.ActiveRun, &run); err != nil {
		f.t.Fatal(err)
	}
	offer := result.GemOffer
	if run.OfferID != offer.OfferID || run.OfferRevision != offer.Revision || run.OfferStatus != offer.Status || run.Used != offer.TotalUsed {
		f.t.Fatalf("save markers disagree with receipt: run=%+v offer=%+v", run, offer)
	}
	if offer.Status == "pending" && !slices.Equal(run.Options, offer.GemOptions) {
		f.t.Fatalf("pending reward options disagree: %v != %v", run.Options, offer.GemOptions)
	}
	if offer.Status == "chosen" && (len(run.Options) != 0 || !reflect.DeepEqual(run.Inventory, offer.GemInventory) || run.Shards != offer.GemShards) {
		f.t.Fatalf("choice was not atomically saved: run=%+v offer=%+v", run, offer)
	}
}

func (f *gemOfferFixture) assertUnchanged(before economy.CommandResult) {
	f.t.Helper()
	f.assertCanonical(before)
	current, err := f.service.Get(f.ctx, f.account)
	if err != nil || current.EconomyRevision != before.GemReceipt.EconomyRevision || current.Wallet.GemResetTickets != before.GemReceipt.GemResetTickets {
		f.t.Fatalf("failed command mutated economy: %+v, error %v", current, err)
	}
}

func (f *gemOfferFixture) grantTickets(count int64) {
	f.t.Helper()
	now := time.Now().UTC()
	mailID, err := f.service.CreateMail(f.ctx, economy.CreateMailRequest{
		DispatchKey: f.key(), Title: "Gem offer test", Body: "Gem reset tickets", GemResetTickets: count,
		Audience: "targeted", TargetAccountIDs: []string{f.account}, CreatedBy: "integration test",
		StartsAt: now.Add(-time.Minute), ExpiresAt: now.Add(time.Hour),
	})
	if err != nil {
		f.t.Fatal(err)
	}
	f.t.Cleanup(func() { _, _ = f.save.pool.Exec(f.ctx, `DELETE FROM mails WHERE id=$1`, mailID) })
	grant, err := f.service.ClaimMail(f.ctx, f.account, economy.MailClaimRequest{
		IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":9}`), MailID: mailID,
	})
	if err != nil || grant.GrantedGemResetTickets != count {
		f.t.Fatalf("grant tickets: %+v, error %v", grant, err)
	}
	f.economy = grant.Snapshot
}

func TestGemOfferFirstIssuanceRecoveryAndReceiptIdentity(t *testing.T) {
	f := openGemOfferFixture(t)
	request := f.offerRequest(5)
	first, err := f.service.OfferGems(f.ctx, f.account, f.save.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	if first.SaveRevision != request.SourceSaveRevision+1 || first.GemOffer == nil || first.GemOffer.Status != "pending" || first.GemOffer.TotalUsed != 0 {
		t.Fatalf("first issuance: %+v", first)
	}
	f.accept(first)
	exact, err := f.service.OfferGems(f.ctx, f.account, f.save.sessionID, request)
	if err != nil {
		t.Fatalf("exact first-offer receipt: %v", err)
	}
	assertGemOfferJSONEqual(t, exact, first)

	// A lost receipt recovered under a different key must not resample or charge,
	// even when its source/economy revisions still describe the pre-offer save.
	recovery := request
	recovery.IdempotencyKey = f.key()
	recovered, err := economy.NewService(f.save.pool).OfferGems(f.ctx, f.account, f.save.sessionID, recovery)
	if err != nil || !reflect.DeepEqual(recovered.GemOffer, first.GemOffer) || recovered.SaveRevision != first.SaveRevision || recovered.GemReceipt.EconomyRevision != first.GemReceipt.EconomyRevision || recovered.GemReceipt.GemResetTickets != first.GemReceipt.GemResetTickets {
		t.Fatalf("different-key recovery: %+v, error %v", recovered, err)
	}
	f.accept(recovered)
	var offers, receipts int
	if err := f.save.pool.QueryRow(f.ctx, `SELECT
		(SELECT count(*) FROM economy_gem_offers WHERE account_id=$1 AND run_id=$2),
		(SELECT count(*) FROM economy_commands WHERE account_id=$1 AND command_type='gem_offer')`, f.account, gemOfferRunID).Scan(&offers, &receipts); err != nil || offers != 1 || receipts != 1 {
		t.Fatalf("durable first-offer rows: offers=%d receipts=%d error=%v", offers, receipts, err)
	}
	changed := request
	changed.RawBody = append([]byte(" "), request.RawBody...)
	if _, err := f.service.OfferGems(f.ctx, f.account, f.save.sessionID, changed); !errors.Is(err, economy.ErrIdempotencyKeyReused) {
		t.Fatalf("changed first-offer body: %v", err)
	}
	choose := f.chooseRequest(first.GemOffer, "shards")
	choose.IdempotencyKey, choose.RawBody = request.IdempotencyKey, request.RawBody
	if _, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, choose); !errors.Is(err, economy.ErrIdempotencyKeyReused) {
		t.Fatalf("cross-command receipt alias: %v", err)
	}
	f.assertUnchanged(recovered)
}

func TestGemOfferConcurrentFirstIssuanceCreatesOneOffer(t *testing.T) {
	f := openGemOfferFixture(t)
	requests := []economy.GemOfferRequest{f.offerRequest(5), f.offerRequest(5)}
	results := make([]economy.CommandResult, len(requests))
	errs := make([]error, len(requests))
	var wait sync.WaitGroup
	start := make(chan struct{})
	for i := range requests {
		wait.Add(1)
		go func(i int) {
			defer wait.Done()
			<-start
			results[i], errs[i] = f.service.OfferGems(f.ctx, f.account, f.save.sessionID, requests[i])
		}(i)
	}
	close(start)
	wait.Wait()
	for i, err := range errs {
		if err != nil {
			t.Fatalf("concurrent first offer %d: %v", i, err)
		}
		f.accept(results[i])
	}
	if !reflect.DeepEqual(results[0].GemOffer, results[1].GemOffer) || results[0].SaveRevision != results[1].SaveRevision {
		t.Fatalf("concurrent first issuance diverged: %+v / %+v", results[0], results[1])
	}
	if min(results[0].GemReceipt.EconomyRevision, results[1].GemReceipt.EconomyRevision) != requests[0].ExpectedRevision+1 || max(results[0].GemReceipt.EconomyRevision, results[1].GemReceipt.EconomyRevision) != requests[0].ExpectedRevision+1 {
		t.Fatal("concurrent retrieval created an extra command revision")
	}
	if results[0].SaveRevision != requests[0].SourceSaveRevision+1 {
		t.Fatal("concurrent retrieval advanced save twice")
	}
}

func TestGemOfferRerollBudgetAndConcurrentTicketDebit(t *testing.T) {
	f := openGemOfferFixture(t)
	initial := f.issue(5)
	freeRequest := f.rerollRequest(initial.GemOffer)
	free, err := f.service.RerollGems(f.ctx, f.account, f.save.sessionID, freeRequest)
	if err != nil {
		t.Fatal(err)
	}
	f.accept(free)
	if free.GemOffer.TotalUsed != 1 || free.GemOffer.Revision != initial.GemOffer.Revision+1 || free.GemReceipt.GemResetTickets != 0 || free.SaveRevision != initial.SaveRevision+1 {
		t.Fatalf("free reroll: %+v", free)
	}
	assertGemOfferExcludesPrevious(t, free.GemOffer, initial.GemOffer)
	exact, err := f.service.RerollGems(f.ctx, f.account, f.save.sessionID, freeRequest)
	if err != nil {
		t.Fatal(err)
	}
	assertGemOfferJSONEqual(t, exact, free)
	if _, err := f.service.RerollGems(f.ctx, f.account, f.save.sessionID, f.rerollRequest(free.GemOffer)); !errors.Is(err, economy.ErrInsufficientGemResetTickets) {
		t.Fatalf("paid reroll without tickets: %v", err)
	}
	f.assertUnchanged(free)
	f.grantTickets(2)
	paid, err := f.service.RerollGems(f.ctx, f.account, f.save.sessionID, f.rerollRequest(free.GemOffer))
	if err != nil {
		t.Fatal(err)
	}
	f.accept(paid)
	if paid.GemOffer.TotalUsed != 2 || paid.GemReceipt.GemResetTickets != 1 {
		t.Fatalf("paid reroll: %+v", paid)
	}
	assertGemOfferExcludesPrevious(t, paid.GemOffer, free.GemOffer)
	for _, mutate := range []func(*economy.GemOfferState){
		func(state *economy.GemOfferState) { state.Revision-- },
		func(state *economy.GemOfferState) { state.OfferID = gemOfferRunID },
	} {
		stale := *paid.GemOffer
		mutate(&stale)
		if _, err := f.service.RerollGems(f.ctx, f.account, f.save.sessionID, f.rerollRequest(&stale)); !errors.Is(err, economy.ErrGemOfferConflict) {
			t.Fatalf("stale paid reroll: %v", err)
		}
		f.assertUnchanged(paid)
	}
	chosen, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, f.chooseRequest(paid.GemOffer, "shards"))
	if err != nil {
		t.Fatal(err)
	}
	f.accept(chosen)
	var nextRun map[string]any
	if err := json.Unmarshal(f.runFor(chosen), &nextRun); err != nil {
		t.Fatal(err)
	}
	nextRun["phase"], nextRun["completedRounds"], nextRun["rewardOptions"] = "reward", 10, []string{}
	if err := f.saveRun(nextRun); err != nil {
		t.Fatalf("advance to next wave reward: %v", err)
	}
	next := f.issue(10)
	if next.GemOffer.TotalUsed != 2 || next.GemOffer.OfferID == initial.GemOffer.OfferID {
		t.Fatalf("next wave reset run budget or reused offer ID: %+v", next.GemOffer)
	}
	requests := []economy.GemRerollRequest{f.rerollRequest(next.GemOffer), f.rerollRequest(next.GemOffer)}
	results := make([]economy.CommandResult, len(requests))
	errs := make([]error, len(requests))
	var wait sync.WaitGroup
	start := make(chan struct{})
	for i := range requests {
		wait.Add(1)
		go func(i int) {
			defer wait.Done()
			<-start
			results[i], errs[i] = f.service.RerollGems(f.ctx, f.account, f.save.sessionID, requests[i])
		}(i)
	}
	close(start)
	wait.Wait()
	successes := 0
	var last economy.CommandResult
	for i, err := range errs {
		if err == nil {
			successes++
			last = results[i]
		} else if !isGemOfferStateConflict(err) {
			t.Fatalf("unexpected concurrent reroll failure: %v", err)
		}
	}
	if successes != 1 || last.GemOffer == nil || last.GemOffer.TotalUsed != 3 || last.GemReceipt.GemResetTickets != 0 || last.SaveRevision != next.SaveRevision+1 {
		t.Fatalf("concurrent paid rerolls: successes=%d result=%+v errors=%v", successes, last, errs)
	}
	f.accept(last)
	assertGemOfferExcludesPrevious(t, last.GemOffer, next.GemOffer)
	if _, err := f.service.RerollGems(f.ctx, f.account, f.save.sessionID, f.rerollRequest(last.GemOffer)); !errors.Is(err, economy.ErrGemRerollLimit) {
		t.Fatalf("fourth per-run reroll: %v", err)
	}
	f.assertUnchanged(last)
	var debits, spent, commands, offers int64
	if err := f.save.pool.QueryRow(f.ctx, `SELECT
		(SELECT count(*) FROM economy_ledger_entries l JOIN economy_commands c ON c.id=l.command_id WHERE c.account_id=$1 AND l.asset_type='gem_reset_ticket' AND l.delta=-1),
		(SELECT coalesce(-sum(l.delta),0) FROM economy_ledger_entries l JOIN economy_commands c ON c.id=l.command_id WHERE c.account_id=$1 AND l.asset_type='gem_reset_ticket' AND l.delta<0),
		(SELECT count(*) FROM economy_commands WHERE account_id=$1 AND command_type='gem_reroll'),
		(SELECT count(*) FROM economy_gem_offers WHERE account_id=$1 AND run_id=$2)`, f.account, gemOfferRunID).Scan(&debits, &spent, &commands, &offers); err != nil || debits != 2 || spent != 2 || commands != 3 || offers != 2 {
		t.Fatalf("atomic debit ledger: debits=%d spent=%d commands=%d offers=%d error=%v", debits, spent, commands, offers, err)
	}
}

func assertGemOfferExcludesPrevious(t *testing.T, next, previous *economy.GemOfferState) {
	t.Helper()
	for _, gem := range next.GemOptions {
		if slices.Contains(previous.GemOptions, gem) {
			t.Fatalf("reroll repeated immediately previous candidate %q", gem)
		}
	}
}

func isGemOfferStateConflict(err error) bool {
	var revision *economy.ConflictError
	return errors.As(err, &revision) || errors.Is(err, economy.ErrSaveRevisionConflict) || errors.Is(err, economy.ErrGemOfferConflict) || errors.Is(err, economy.ErrGemRerollConflict)
}

func TestGemOfferChooseValidatesAndGrantsExactlyOnce(t *testing.T) {
	for _, kind := range []string{"gem", "shards"} {
		t.Run(kind, func(t *testing.T) {
			f := openGemOfferFixture(t)
			offer := f.issue(5)
			choice := "shards"
			if kind == "gem" {
				choice = offer.GemOffer.GemOptions[0]
			}
			invalidChoices := []string{"not-a-gem", "", "Shards"}
			for _, gem := range []string{"attackSpeed", "range", "physicalDamage", "elementalDamage"} {
				if !slices.Contains(offer.GemOffer.GemOptions, gem) {
					invalidChoices = append(invalidChoices, gem)
					break
				}
			}
			for _, invalid := range invalidChoices {
				if _, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, f.chooseRequest(offer.GemOffer, invalid)); !errors.Is(err, economy.ErrInvalidCommand) {
					t.Fatalf("invalid choice %q: %v", invalid, err)
				}
				f.assertUnchanged(offer)
			}
			stale := *offer.GemOffer
			stale.Revision++
			if _, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, f.chooseRequest(&stale, choice)); !errors.Is(err, economy.ErrGemOfferConflict) {
				t.Fatalf("stale offer revision: %v", err)
			}
			stale = *offer.GemOffer
			stale.OfferID = "0198b955-3656-7c40-b3cb-87f427b90bfb"
			if _, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, f.chooseRequest(&stale, choice)); !errors.Is(err, economy.ErrGemOfferConflict) {
				t.Fatalf("wrong offer identity: %v", err)
			}
			f.assertUnchanged(offer)
			request := f.chooseRequest(offer.GemOffer, choice)
			chosen, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, request)
			if err != nil {
				t.Fatal(err)
			}
			f.accept(chosen)
			if chosen.GemOffer.Status != "chosen" || chosen.GemOffer.Choice != choice || chosen.GemOffer.Revision != offer.GemOffer.Revision+1 || chosen.SaveRevision != offer.SaveRevision+1 {
				t.Fatalf("choice receipt: %+v", chosen)
			}
			inventory := map[string]int64{"range": 2}
			shards := int64(7)
			if kind == "gem" {
				inventory[choice]++
				if chosen.GemOffer.GrantedGem != choice || chosen.GemOffer.GrantedShards != 0 {
					t.Fatalf("gem grant: %+v", chosen.GemOffer)
				}
			} else {
				shards += 10
				if chosen.GemOffer.GrantedGem != "" || chosen.GemOffer.GrantedShards != 10 {
					t.Fatalf("shard alternative: %+v", chosen.GemOffer)
				}
			}
			if !reflect.DeepEqual(chosen.GemOffer.GemInventory, inventory) || chosen.GemOffer.GemShards != shards {
				t.Fatalf("incorrect reward totals: %+v", chosen.GemOffer)
			}
			exact, err := economy.NewService(f.save.pool).ChooseGem(f.ctx, f.account, f.save.sessionID, request)
			if err != nil {
				t.Fatal(err)
			}
			assertGemOfferJSONEqual(t, exact, chosen)
			alternate := "shards"
			if choice == "shards" {
				alternate = offer.GemOffer.GemOptions[0]
			}
			if _, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, f.chooseRequest(chosen.GemOffer, alternate)); !errors.Is(err, economy.ErrGemOfferConflict) {
				t.Fatalf("changed immutable selection: %v", err)
			}
			if _, err := f.service.RerollGems(f.ctx, f.account, f.save.sessionID, f.rerollRequest(chosen.GemOffer)); !errors.Is(err, economy.ErrGemOfferConflict) {
				t.Fatalf("reroll after choosing: %v", err)
			}
			f.assertUnchanged(chosen)
			claim, err := f.save.service.ClaimWriter(f.ctx, f.account, f.save.sessionID, gamesave.ClaimWriterRequest{
				IdempotencyKey: f.key(), ClientInstanceID: secondClientID, ClientCompatibilityVersion: 9,
				RawBody: []byte(`{"clientInstanceId":"` + secondClientID + `","clientCompatibilityVersion":9}`),
			})
			if err != nil || claim.WriterGeneration <= request.WriterGeneration {
				t.Fatalf("replace choice writer: %+v, error %v", claim, err)
			}
			exact, err = f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, request)
			if err != nil {
				t.Fatalf("choice receipt after writer replacement: %v", err)
			}
			assertGemOfferJSONEqual(t, exact, chosen)
			f.assertUnchanged(chosen)
		})
	}
}

func TestGemOfferConcurrentChoicesGrantOneReward(t *testing.T) {
	for _, sameKey := range []bool{false, true} {
		t.Run(fmt.Sprintf("same_key_%t", sameKey), func(t *testing.T) {
			testGemOfferConcurrentChoices(t, sameKey)
		})
	}
}

func testGemOfferConcurrentChoices(t *testing.T, sameKey bool) {
	t.Helper()
	f := openGemOfferFixture(t)
	offer := f.issue(5)
	requests := []economy.GemChooseRequest{
		f.chooseRequest(offer.GemOffer, offer.GemOffer.GemOptions[0]),
		f.chooseRequest(offer.GemOffer, "shards"),
	}
	wantSuccesses := 1
	if sameKey {
		requests[1] = requests[0]
		wantSuccesses = 2
	}
	results := make([]economy.CommandResult, len(requests))
	errs := make([]error, len(requests))
	var wait sync.WaitGroup
	start := make(chan struct{})
	for i := range requests {
		wait.Add(1)
		go func(i int) {
			defer wait.Done()
			<-start
			results[i], errs[i] = f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, requests[i])
		}(i)
	}
	close(start)
	wait.Wait()
	successes := 0
	var chosen economy.CommandResult
	for i, err := range errs {
		if err == nil {
			successes++
			chosen = results[i]
		} else if !isGemOfferStateConflict(err) {
			t.Fatalf("unexpected concurrent choice failure: %v", err)
		}
	}
	if successes != wantSuccesses || chosen.GemOffer == nil || chosen.GemOffer.Status != "chosen" || chosen.SaveRevision != offer.SaveRevision+1 {
		t.Fatalf("concurrent choices: successes=%d result=%+v errors=%v", successes, chosen, errs)
	}
	if sameKey {
		assertGemOfferJSONEqual(t, results[0], results[1])
	}
	f.accept(chosen)
	var receipts int
	if err := f.save.pool.QueryRow(f.ctx, `SELECT count(*) FROM economy_commands WHERE account_id=$1 AND command_type='gem_choose'`, f.account).Scan(&receipts); err != nil || receipts != 1 {
		t.Fatalf("choice receipt count=%d error=%v", receipts, err)
	}
}

func TestGemOfferOrdinarySaveCannotRollBackOrReopenReward(t *testing.T) {
	f := openGemOfferFixture(t)
	initial := f.issue(5)
	rerolled, err := f.service.RerollGems(f.ctx, f.account, f.save.sessionID, f.rerollRequest(initial.GemOffer))
	if err != nil {
		t.Fatal(err)
	}
	f.accept(rerolled)
	for _, test := range []struct {
		name   string
		mutate func(map[string]any)
	}{
		{"remove marker", func(run map[string]any) { delete(run, "gemOfferId") }},
		{"change marker", func(run map[string]any) { run["gemOfferId"] = gemOfferRunID }},
		{"roll back marker revision", func(run map[string]any) { run["gemOfferRevision"] = initial.GemOffer.Revision }},
		{"remove candidates", func(run map[string]any) { run["rewardOptions"] = []string{} }},
		{"change candidates", func(run map[string]any) { run["rewardOptions"] = initial.GemOffer.GemOptions }},
		{"roll back budget", func(run map[string]any) { run["gemRerollsUsed"] = 0 }},
		{"alter pending inventory", func(run map[string]any) { run["gemInventory"] = map[string]int64{"range": 99} }},
		{"alter pending shards", func(run map[string]any) { run["gemShards"] = 99 }},
		{"skip pending reward", func(run map[string]any) { run["phase"] = "preparation" }},
	} {
		t.Run(test.name, func(t *testing.T) {
			var run map[string]any
			if err := json.Unmarshal(f.runFor(rerolled), &run); err != nil {
				t.Fatal(err)
			}
			test.mutate(run)
			if err := f.saveRun(run); !errors.Is(err, gamesave.ErrGemOfferConflict) {
				t.Fatalf("ordinary save changed authoritative offer: %v", err)
			}
			f.assertUnchanged(rerolled)
		})
	}
	chosen, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, f.chooseRequest(rerolled.GemOffer, "shards"))
	if err != nil {
		t.Fatal(err)
	}
	f.accept(chosen)
	var preChoice map[string]any
	if err := json.Unmarshal(f.runFor(rerolled), &preChoice); err != nil {
		t.Fatal(err)
	}
	if err := f.saveRun(preChoice); !errors.Is(err, gamesave.ErrGemOfferConflict) {
		t.Fatalf("pre-choice save restored pending offer: %v", err)
	}
	var reopened map[string]any
	if err := json.Unmarshal(f.runFor(chosen), &reopened); err != nil {
		t.Fatal(err)
	}
	reopened["phase"], reopened["rewardOptions"] = "reward", chosen.GemOffer.GemOptions
	if err := f.saveRun(reopened); !errors.Is(err, gamesave.ErrGemOfferConflict) {
		t.Fatalf("chosen reward reopened through save: %v", err)
	}
	f.assertUnchanged(chosen)
	if err := f.saveRun(nil); !errors.Is(err, gamesave.ErrGemOfferConflict) {
		t.Fatalf("save silently closed active run: %v", err)
	}
	beforeClose := f.runFor(chosen)
	closeRequest := economy.CloseRunRequest{IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":9}`), WriterGeneration: f.save.writerGeneration, SourceSaveRevision: f.revision, ExpectedRevision: f.economy.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion, RunID: gemOfferRunID}
	closed, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, closeRequest)
	if err != nil {
		t.Fatal(err)
	}
	f.revision = closed.SaveRevision
	var old map[string]any
	if err = json.Unmarshal(beforeClose, &old); err != nil {
		t.Fatal(err)
	}
	if err = f.saveRun(old); !errors.Is(err, gamesave.ErrGemOfferConflict) {
		t.Fatalf("closed run resurrected: %v", err)
	}
	var offers, used int
	if err = f.save.pool.QueryRow(f.ctx, `SELECT (SELECT count(*) FROM economy_gem_offers WHERE account_id=$1 AND run_id=$2),(SELECT total_used FROM economy_gem_rerolls WHERE account_id=$1 AND run_id=$2)`, f.account, gemOfferRunID).Scan(&offers, &used); err != nil || offers != 1 || used != 1 {
		t.Fatalf("closed run lost records: %d %d %v", offers, used, err)
	}

}

func TestGemOfferGenerationEightGatePreservesLegacyRerollReceipt(t *testing.T) {
	f := openGemOfferFixture(t)
	// Reproduce a generation-seven free reroll whose response was lost before
	// the client saved it. Its durable budget, receipt and wallet revision exist,
	// but the canonical activeRun still has the earlier local counter.
	legacyRequest := economy.GemRerollRequest{
		IdempotencyKey: f.key(), RunID: gemOfferRunID, CompletedRounds: 5,
		SourceSaveRevision: f.revision, ExpectedRevision: f.economy.EconomyRevision,
		WriterGeneration: f.save.writerGeneration, ExpectedCatalogVersion: economy.CatalogVersion,
		RawBody: []byte(`{"clientCompatibilityVersion":7,"runId":"` + gemOfferRunID + `","completedRounds":5,"expectedRerollCount":0}`),
	}
	legacyRevision := f.economy.EconomyRevision + 1
	legacyRaw := json.RawMessage(fmt.Sprintf(`{"gemReroll":{"runId":%q,"rewardWave":5,"totalUsed":1,"gemOptions":["range","chain","explosion"]},"economy":{"economyRevision":%d,"wallet":{"freeDiamonds":1000,"paidDiamonds":0,"moduleTickets":0,"gemResetTickets":0}}}`, gemOfferRunID, legacyRevision))
	hash := sha256.Sum256(append([]byte("gem_reroll\n"), legacyRequest.RawBody...))
	var legacyCommand string
	if err := f.save.pool.QueryRow(f.ctx, `INSERT INTO economy_commands
		(account_id,idempotency_key,command_type,request_hash,resulting_revision,authority_epoch,response_payload)
		VALUES($1,$2,'gem_reroll',$3,$4,$5,$6) RETURNING id::text`, f.account, legacyRequest.IdempotencyKey, hash[:], legacyRevision, f.economy.AuthorityEpoch, legacyRaw).Scan(&legacyCommand); err != nil {
		t.Fatalf("seed historical receipt: %v", err)
	}
	if _, err := f.save.pool.Exec(f.ctx, `UPDATE player_economies SET revision=$2,gem_reroll_enabled=true WHERE account_id=$1`, f.account, legacyRevision); err != nil {
		t.Fatalf("seed historical wallet revision: %v", err)
	}
	if _, err := f.save.pool.Exec(f.ctx, `INSERT INTO economy_gem_rerolls(account_id,run_id,reward_wave,total_used,gem_options,command_id)
		VALUES($1,$2,5,1,ARRAY['range','chain','explosion'],$3)`, f.account, gemOfferRunID, legacyCommand); err != nil {
		t.Fatalf("seed historical budget: %v", err)
	}
	// This fixture injects historical state after its common adoption helper;
	// mirror the legacy budget that adoption would have read before the upgrade.
	if _, err := f.save.pool.Exec(f.ctx, `UPDATE economy_runs SET total_used=1 WHERE account_id=$1 AND run_id=$2`, f.account, gemOfferRunID); err != nil {
		t.Fatal(err)
	}
	f.economy.EconomyRevision = legacyRevision
	offer := f.issue(5)
	if offer.GemOffer.TotalUsed != 1 {
		t.Fatalf("upgrade restored already-used free reroll: %+v", offer.GemOffer)
	}
	oldRequest := f.offerRequest(5)
	oldRequest.RawBody = f.body(oldRequest, map[string]any{"clientCompatibilityVersion": 7})
	if _, err := f.service.OfferGems(f.ctx, f.account, f.save.sessionID, oldRequest); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("generation seven created offer: %v", err)
	}
	oldChoose := f.chooseRequest(offer.GemOffer, "shards")
	oldChoose.RawBody = f.body(oldChoose.GemOfferRequest, map[string]any{"clientCompatibilityVersion": 7, "choice": "shards", "offerId": offer.GemOffer.OfferID, "expectedOfferRevision": offer.GemOffer.Revision})
	if _, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, oldChoose); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("generation seven chose offer: %v", err)
	}
	oldReroll := f.rerollRequest(offer.GemOffer)
	oldReroll.RawBody = []byte(`{"clientCompatibilityVersion":7,"runId":"` + gemOfferRunID + `","completedRounds":5,"expectedRerollCount":0}`)
	oldReroll.OfferID, oldReroll.ExpectedOfferRevision = "", 0
	if _, err := f.service.RerollGems(f.ctx, f.account, f.save.sessionID, oldReroll); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("generation seven fresh reroll: %v", err)
	}
	legacyRequest.SourceSaveRevision, legacyRequest.ExpectedRevision, legacyRequest.WriterGeneration = 0, 0, f.save.writerGeneration+1
	replay, err := f.service.RerollGems(f.ctx, f.account, f.save.sessionID, legacyRequest)
	if err != nil {
		t.Fatalf("exact legacy receipt blocked by current compatibility/writer/save: %v", err)
	}
	var expected economy.CommandResult
	if err := json.Unmarshal(legacyRaw, &expected); err != nil {
		t.Fatal(err)
	}
	assertGemOfferJSONEqual(t, replay, expected)
	f.assertUnchanged(offer)
}

func (f *gemOfferFixture) runFor(result economy.CommandResult) json.RawMessage {
	f.t.Helper()
	key := fmt.Sprintf("%s/%d", result.GemOffer.OfferID, result.GemOffer.Revision)
	raw, ok := f.checkpoints[key]
	if !ok {
		f.t.Fatalf("missing checkpoint for %s", key)
	}
	return raw
}
