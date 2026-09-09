package economy

import (
	"encoding/json"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
)

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

func TestValidateFrostSlowStrengthGradeBoundaries(t *testing.T) {
	for _, test := range []struct {
		grade string
		min   int
		max   int
	}{
		{"normal", 1, 2},
		{"magic", 3, 4},
		{"rare", 5, 6},
		{"unique", 6, 8},
	} {
		t.Run(test.grade, func(t *testing.T) {
			for value := test.min - 1; value <= test.max+1; value++ {
				module := generatedModule{
					TurretType: "frost", Part: "core", Family: "frostCore", Grade: test.grade,
					Options: []moduleOption{{Type: "slowStrengthBonus", Value: value}},
				}
				err := validateModule(module)
				valid := value >= test.min && value <= test.max
				if (err == nil) != valid {
					t.Errorf("slow strength %d: expected valid=%t, got %v", value, valid, err)
				}
			}
		})
	}
}

func TestDecodeLegacyEconomyPreservesRebalancedFrostModules(t *testing.T) {
	for _, test := range []struct {
		grade                  string
		oldMin, oldMax, newMax int
	}{
		{"normal", 2, 4, 2},
		{"magic", 5, 7, 4},
		{"rare", 8, 10, 6},
		{"unique", 11, 14, 8},
	} {
		t.Run(test.grade, func(t *testing.T) {
			for value := test.oldMin; value <= test.oldMax; value++ {
				inventory := legacyModuleInventory{ItemSequence: 1, Items: []legacyModule{{
					ID: "frost-owned", TurretType: "frost", Part: "core", Family: "frostCore", Grade: test.grade,
					Options: []moduleOption{
						{Type: "slowStrengthBonus", Value: value},
						{Type: "slowDurationIncrease", Value: optionRanges["slowDurationIncrease"][test.grade].max},
					},
					AcquiredOrder: 1, Equipped: true,
				}}}
				payload, err := json.Marshal(inventory)
				if err != nil {
					t.Fatal(err)
				}
				_, accepted, rejected, cleared, err := decodeLegacyEconomy([]byte(`{}`), payload)
				if err != nil || len(accepted) != 1 || len(rejected) != 0 || len(cleared) != 0 {
					t.Fatalf("value %d: unexpected migration: %v %v %v %v", value, accepted, rejected, cleared, err)
				}
				module := accepted[0]
				if module.ID != "frost-owned" || !module.Equipped || module.AcquiredOrder != 1 ||
					module.Options[0].Value != test.newMax || module.Options[1] != inventory.Items[0].Options[1] {
					t.Fatalf("module identity, loadout or options changed incorrectly: %#v", module)
				}
			}
		})
	}
}

func TestDecodeLegacyEconomyStillRejectsInvalidFrostModules(t *testing.T) {
	for _, test := range []struct {
		name    string
		options []moduleOption
	}{
		{"strength_above_old_max", []moduleOption{{Type: "slowStrengthBonus", Value: 15}}},
		{"strength_outside_both_ranges", []moduleOption{{Type: "slowStrengthBonus", Value: 10}}},
		{"strength_below_min", []moduleOption{{Type: "slowStrengthBonus", Value: 0}}},
		{"invalid_other_option", []moduleOption{{Type: "slowStrengthBonus", Value: 14}, {Type: "slowDurationIncrease", Value: 100}}},
		{"duplicate_option", []moduleOption{{Type: "slowStrengthBonus", Value: 14}, {Type: "slowStrengthBonus", Value: 12}}},
	} {
		t.Run(test.name, func(t *testing.T) {
			inventory := legacyModuleInventory{ItemSequence: 1, Items: []legacyModule{{
				ID: "invalid", TurretType: "frost", Part: "core", Family: "frostCore", Grade: "unique",
				Options: test.options, AcquiredOrder: 1, Equipped: true,
			}}}
			payload, err := json.Marshal(inventory)
			if err != nil {
				t.Fatal(err)
			}
			_, accepted, rejected, cleared, err := decodeLegacyEconomy([]byte(`{}`), payload)
			if err != nil || len(accepted) != 0 || len(rejected) != 1 || rejected[0].Reason != "catalog_mismatch" || len(cleared) != 1 {
				t.Fatalf("invalid module was not rejected: %v %v %v %v", accepted, rejected, cleared, err)
			}
		})
	}
}

func TestValidateExpectedEconomyRejectsPreviousCatalog(t *testing.T) {
	economy := dbgen.PlayerEconomy{Revision: 7}
	if err := validateExpectedEconomy(economy, 7, 1); err != ErrCatalogChanged {
		t.Fatalf("previous catalog must require refresh, got %v", err)
	}
	if err := validateExpectedEconomy(economy, 7, CatalogVersion); err != nil {
		t.Fatalf("current catalog must remain valid, got %v", err)
	}
}
