package economy

import "testing"

func TestSpendDiamondsUsesFreeBalanceFirst(t *testing.T) {
	free, paid, freeSpent, paidSpent, err := spendDiamonds(30, 20, 40)
	if err != nil {
		t.Fatalf("spend diamonds: %v", err)
	}
	if free != 0 || paid != 10 || freeSpent != 30 || paidSpent != 10 {
		t.Fatalf("unexpected balances: free=%d paid=%d freeSpent=%d paidSpent=%d", free, paid, freeSpent, paidSpent)
	}
}

func TestSpendDiamondsRejectsInsufficientBalanceWithoutMutation(t *testing.T) {
	free, paid, freeSpent, paidSpent, err := spendDiamonds(5, 4, 10)
	if err != ErrInsufficientDiamonds {
		t.Fatalf("expected insufficient diamonds, got %v", err)
	}
	if free != 5 || paid != 4 || freeSpent != 0 || paidSpent != 0 {
		t.Fatalf("balances mutated on rejection: %d %d %d %d", free, paid, freeSpent, paidSpent)
	}
}

func TestDecodeLegacyEconomyConvertsPaidDiamondsAndRejectsInvalidModules(t *testing.T) {
	progression := []byte(`{"freeDiamonds":10,"paidDiamonds":5,"researchSlotTwoUnlocked":true,"clearedStageNumbers":[11]}`)
	modules := []byte(`{"tickets":2,"drawCount":1,"ticketPurchaseCount":0,"itemSequence":2,"items":[{"id":"valid","turretType":"arrow","part":"core","family":"rapidCore","grade":"normal","options":[{"type":"damageIncrease","value":5}],"acquiredOrder":1,"equipped":false},{"id":"broken","turretType":"unknown","part":"core","family":"assault","grade":"normal","options":[{"type":"damageIncrease","value":5}],"acquiredOrder":2,"equipped":true}]}`)

	legacy, accepted, rejected, cleared, err := decodeLegacyEconomy(progression, modules)
	if err != nil {
		t.Fatalf("decode legacy economy: %v", err)
	}
	if legacy.FreeDiamonds != 15 || !legacy.ResearchSlotTwoUnlocked ||
		!intContains(legacy.ClearedStageNumbers, 11) || len(accepted) != 1 ||
		len(rejected) != 1 || len(cleared) != 1 || cleared[0] != "broken" {
		t.Fatalf("unexpected bootstrap result: %#v %#v %#v %#v", legacy, accepted, rejected, cleared)
	}
}
