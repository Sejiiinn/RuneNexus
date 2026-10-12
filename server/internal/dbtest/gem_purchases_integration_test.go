//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"reflect"
	"sync"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func openPurchasedGemFixture(t *testing.T) *gemOfferFixture {
	t.Helper()
	f := openGemOfferFixture(t)
	issued := f.issue(5)
	chosen, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, f.chooseRequest(issued.GemOffer, "shards"))
	if err != nil {
		t.Fatal(err)
	}
	f.accept(chosen)
	var run map[string]any
	_ = json.Unmarshal(f.runFor(chosen), &run)
	// Shard earning remains explicitly trusted combat input. The server owns the
	// purchase spend/random result and all subsequent gem quantity changes.
	run["gemShards"] = 80
	run["phase"] = "wave"
	if err = f.saveRun(run); err != nil {
		t.Fatal(err)
	}
	return f
}

func TestPurchasedGemDebitSemanticRecoveryAndExactChoice(t *testing.T) {
	f := openPurchasedGemFixture(t)
	request := f.offerRequest(5)
	purchased, err := f.service.PurchaseGems(f.ctx, f.account, f.save.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	f.accept(purchased)
	if purchased.GemOffer.Kind != "purchase" || purchased.GemOffer.ReturnPhase != "wave" || purchased.GemOffer.PurchaseSequence != 1 || purchased.GemOffer.GemShards != 60 {
		t.Fatalf("purchase %+v", purchased)
	}
	again := request
	again.IdempotencyKey = f.key()
	recovered, err := f.service.PurchaseGems(f.ctx, f.account, f.save.sessionID, again)
	if err != nil {
		t.Fatal(err)
	}
	assertGemOfferJSONEqual(t, recovered, purchased)
	var count int
	if err = f.save.pool.QueryRow(f.ctx, `SELECT count(*) FROM economy_commands WHERE account_id=$1 AND command_type='gem_purchase'`, f.account).Scan(&count); err != nil || count != 1 {
		t.Fatalf("semantic read added receipt: %d %v", count, err)
	}
	if _, err = f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, f.chooseRequest(purchased.GemOffer, "shards")); !errors.Is(err, economy.ErrInvalidCommand) {
		t.Fatalf("purchase granted shard fallback: %v", err)
	}
	if _, err = f.service.RerollGems(f.ctx, f.account, f.save.sessionID, f.rerollRequest(purchased.GemOffer)); err == nil {
		t.Fatal("purchase rerolled")
	}
	f.assertUnchanged(purchased)
	// Pending purchase preserves exact ownership while allowing allocation changes.
	var run map[string]any
	_ = json.Unmarshal(f.runFor(purchased), &run)
	run["gemInventory"] = map[string]int64{"range": 1}
	run["turrets"] = []any{map[string]any{"id": 1, "type": "arrow", "slotLimit": 1, "equippedGemSlots": []any{"range"}}}
	if err = f.saveRun(run); err != nil {
		t.Fatal(err)
	}
	choice := f.chooseRequest(purchased.GemOffer, purchased.GemOffer.GemOptions[0])
	chosen, err := f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, choice)
	if err != nil {
		t.Fatal(err)
	}
	f.accept(chosen)
	expected := map[string]int64{"range": 1}
	expected[choice.Choice]++
	if !reflect.DeepEqual(chosen.GemOffer.GemInventory, expected) || chosen.GemOffer.GemShards != 60 {
		t.Fatalf("choice reset allocation or duplicated debit: %+v", chosen.GemOffer)
	}
	replay, err := f.service.PurchaseGems(f.ctx, f.account, f.save.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	assertGemOfferJSONEqual(t, replay, purchased)
	f.assertUnchanged(chosen)
	replay, err = f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, choice)
	if err != nil {
		t.Fatal(err)
	}
	assertGemOfferJSONEqual(t, replay, chosen)
	next, err := f.service.PurchaseGems(f.ctx, f.account, f.save.sessionID, f.offerRequest(5))
	if err != nil {
		t.Fatal(err)
	}
	f.accept(next)
	if next.GemOffer.PurchaseSequence != 2 || next.GemOffer.GemShards != 40 || next.GemOffer.EconomyRevision <= chosen.GemOffer.EconomyRevision {
		t.Fatalf("purchase sequencing %+v", next.GemOffer)
	}
	var stale map[string]any
	_ = json.Unmarshal(f.runFor(chosen), &stale)
	if err = f.saveRun(stale); !errors.Is(err, gamesave.ErrGemOfferConflict) {
		t.Fatalf("old same-wave purchased checkpoint accepted: %v", err)
	}
	f.assertUnchanged(next)
}

func TestConcurrentPurchasedGemRequestsDebitOnce(t *testing.T) {
	f := openPurchasedGemFixture(t)
	requests := []economy.GemOfferRequest{f.offerRequest(5), f.offerRequest(5)}
	results := make([]economy.CommandResult, 2)
	errs := make([]error, 2)
	var wg sync.WaitGroup
	start := make(chan struct{})
	for i := range requests {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-start
			results[i], errs[i] = f.service.PurchaseGems(f.ctx, f.account, f.save.sessionID, requests[i])
		}(i)
	}
	close(start)
	wg.Wait()
	for i, err := range errs {
		if err != nil {
			t.Fatalf("request %d: %v", i, err)
		}
		f.accept(results[i])
	}
	assertGemOfferJSONEqual(t, results[0], results[1])
	if results[0].GemOffer.GemShards != 60 {
		t.Fatal("concurrent purchase charged more than once")
	}
}
