package economy

import (
	"bytes"
	"encoding/json"
	"math"
	"testing"
	"time"
)

func TestCompactGemReceiptIsBoundedAndLegacyIsRetained(t *testing.T) {
	inventory := map[string]int64{}
	for _, gem := range gemTypes {
		inventory[gem] = math.MaxInt64
	}
	receipt := CommandResult{GemReceipt: &GemCommandReceipt{Version: 1, EconomyRevision: math.MaxInt64, AuthorityEpoch: rerollTestRun, GemResetTickets: math.MaxInt64}, SaveRevision: math.MaxInt64, ServerSavedAt: time.Unix(1, 0).UTC(), GemOffer: &GemOfferState{LegacyImported: true, EconomyRevision: math.MaxInt64, Kind: "purchase", ReturnPhase: "preparation", PurchaseSequence: math.MaxInt64, OfferID: rerollTestRun, RunID: rerollTestRun, RewardWave: 35, Revision: math.MaxInt64, TotalUsed: 3, GemOptions: []string{"attackSpeed", "physicalDamage", "multipleProjectiles"}, Status: "chosen", Choice: "multipleProjectiles", GrantedGem: "multipleProjectiles", GemInventory: inventory, GemShards: math.MaxInt64}}
	raw, err := json.Marshal(receipt)
	if err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{`"economy":`, `"activeRun":`, `"claimedRewardKeys":`, `"turretModules":`, `"pendingProgressionEffects":`} {
		if bytes.Contains(raw, []byte(key)) {
			t.Fatalf("unbounded state %s in receipt: %s", key, raw)
		}
	}
	if len(raw) > 2048 {
		t.Fatalf("bounded maximum receipt unexpectedly large: %d bytes", len(raw))
	}
	t.Logf("maximum populated purchased-gem receipt: %d bytes", len(raw))
	legacy := []byte(`{"gemOffer":{"offerId":"old","revision":2},"activeRun":{"gold":7},"saveRevision":5,"economy":{"authorityEpoch":"old","economyRevision":9,"claimedRewardKeys":["legacy"]}}`)
	var decoded CommandResult
	if err = json.Unmarshal(legacy, &decoded); err != nil {
		t.Fatal(err)
	}
	if decoded.GemReceipt != nil || decoded.Snapshot.EconomyRevision != 9 || len(decoded.ActiveRun) == 0 || len(decoded.Snapshot.ClaimedRewardKeys) != 1 {
		t.Fatalf("legacy recovery data lost: %+v", decoded)
	}
}

func TestPurchasedGemProjectionRestoresBoundCombatPhase(t *testing.T) {
	for _, phase := range []string{"preparation", "wave"} {
		offer := &GemOfferState{Kind: "purchase", ReturnPhase: phase, PurchaseSequence: 1, OfferID: rerollTestRun, RunID: rerollTestRun, RewardWave: 0, Revision: 1, Status: "pending", GemInventory: map[string]int64{}, GemShards: 3, GemOptions: []string{"range", "chain", "explosion"}}
		raw, err := projectGemOffer([]byte(`{"phase":"`+phase+`","gold":71,"gemShards":23,"gemInventory":{},"gemOfferEquipRevision":2}`), offer)
		if err != nil {
			t.Fatal(err)
		}
		var pending map[string]any
		_ = json.Unmarshal(raw, &pending)
		if pending["phase"] != "reward" || pending["rewardReturnPhase"] != phase || pending["isPurchasedGemReward"] != true || pending["gemShards"] != float64(3) {
			t.Fatalf("pending purchase projection %s", raw)
		}
		offer.Status = "chosen"
		offer.Revision++
		offer.Choice = "range"
		offer.GrantedGem = "range"
		offer.GemInventory["range"] = 1
		raw, err = projectGemOffer(raw, offer)
		if err != nil {
			t.Fatal(err)
		}
		var chosen map[string]any
		_ = json.Unmarshal(raw, &chosen)
		if chosen["phase"] != phase || chosen["rewardReturnPhase"] != nil || chosen["isPurchasedGemReward"] != false || chosen["gold"] != float64(71) {
			t.Fatalf("chosen purchase projection %s", raw)
		}
	}
}
