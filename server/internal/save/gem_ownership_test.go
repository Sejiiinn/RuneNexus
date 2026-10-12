package save

import (
	"errors"
	"testing"
)

func TestCumulativeGemGrantFloorConservesPerTypeOwnership(t *testing.T) {
	// Two different reward waves granted range; a third granted chain.
	floor := map[string]int64{"range": 2, "chain": 1}
	for _, test := range []struct{ name, raw string }{
		{"all loose", `{"gemInventory":{"range":2,"chain":1},"turrets":[]}`},
		{"split loose and slots", `{"gemInventory":{"range":1},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":["range",null,"chain"],"equippedGems":["range","chain"]}]}`},
		{"multiple turrets", `{"gemInventory":{},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":["range","chain"]},{"type":"arrow","slotLimit":5,"equippedGemSlots":[null,"range"]}]}`},
		{"replacement returns same type", `{"gemInventory":{"range":1,"chain":1},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":["range","explosion"]}]}`},
		{"sale returns both gems", `{"gemInventory":{"range":2,"chain":1,"explosion":1},"turrets":[]}`},
		{"extra purchased and legacy ownership", `{"gemInventory":{"range":12,"chain":3,"aimSpeed":5},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":[null,"armorPiercing"]}]}`},
		{"purchased reward retains grants", `{"phase":"reward","isPurchasedGemReward":true,"gemInventory":{"range":2,"chain":1}}`},
		{"pending newer wave retains grants", `{"phase":"reward","gemOfferStatus":"pending","completedRounds":20,"gemInventory":{"range":1},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":["chain","range"]}]}`},
	} {
		t.Run(test.name, func(t *testing.T) {
			if err := validateGemOwnershipFloor([]byte(test.raw), floor); err != nil {
				t.Fatalf("legitimate ownership rejected: %v", err)
			}
		})
	}
	for _, test := range []struct{ name, raw string }{
		{"duplicate wave grant removed", `{"gemInventory":{"range":1,"chain":1}}`},
		{"replace range with different type", `{"gemInventory":{"range":1,"chain":1,"explosion":1}}`},
		{"mirror must not double count", `{"gemInventory":{"chain":1},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":["range"],"equippedGems":["range"]}]}`},
		{"mirror alone grants nothing", `{"gemInventory":{"chain":1},"turrets":[{"equippedGems":["range","range"]}]}`},
		{"purchased branch cannot erase grant", `{"isPurchasedGemReward":true,"gemInventory":{"range":2}}`},
		{"pending later offer cannot erase earlier grant", `{"gemOfferStatus":"pending","completedRounds":20,"gemInventory":{"range":2}}`},
	} {
		t.Run(test.name, func(t *testing.T) {
			if err := validateGemOwnershipFloor([]byte(test.raw), floor); !errors.Is(err, ErrGemOfferConflict) {
				t.Fatalf("grant loss accepted: %v", err)
			}
		})
	}
}

func TestGemOwnershipFloorRejectsMalformedAndOverflowQuantities(t *testing.T) {
	floor := map[string]int64{"range": 1}
	for _, raw := range []string{
		`null`, `[]`, `{"gemInventory":null}`, `{"gemInventory":[]}`,
		`{"gemInventory":{"range":-1}}`, `{"gemInventory":{"range":1.5}}`,
		`{"gemInventory":{"range":null}}`, `{"gemInventory":{"range":"1"}}`,
		`{"gemInventory":{"range":true}}`, `{"gemInventory":{"range":9223372036854775808}}`,
		`{"gemInventory":{"range":1,"unknown":0}}`,
		`{"gemInventory":{"range":9223372036854775807},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":["range"]}]}`,
		`{"gemInventory":{"range":1},"turrets":null}`,
		`{"gemInventory":{"range":1},"turrets":{}}`,
		`{"gemInventory":{"range":1},"turrets":[null]}`,
		`{"gemInventory":{"range":1},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":null}]}`,
		`{"gemInventory":{"range":1},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":{}}]}`,
		`{"gemInventory":{"range":1},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":["unknown"]}]}`,
		`{"gemInventory":{"range":1},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":[2]}]}`,
		`{"gemInventory":{"range":1},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":[""]}]}`,
	} {
		t.Run(raw, func(t *testing.T) {
			if err := validateGemOwnershipFloor([]byte(raw), floor); !errors.Is(err, ErrGemOfferConflict) {
				t.Fatalf("malformed ownership accepted: %v", err)
			}
		})
	}
	if err := validateGemOwnershipFloor([]byte(`{"gemInventory":{"range":9223372036854775807}}`), floor); err != nil {
		t.Fatalf("representable quantity rejected: %v", err)
	}
}

func TestGemOwnershipFloorDoesNotInventLegacyAwards(t *testing.T) {
	// No chosen server gem grants means no floor, including shard alternatives,
	// a new run UUID, another account, and legacy pre-v8 equipment-only saves.
	for _, raw := range []string{`{}`, `{"gemInventory":{},"turrets":[{"equippedGems":["range"]}]}`} {
		if err := validateGemOwnershipFloor([]byte(raw), nil); err != nil {
			t.Fatalf("legacy ownership expanded into a new authority contract: %v", err)
		}
	}
	// A future/unknown or corrupt ledger type must not silently bypass protection.
	for _, grants := range []map[string]int64{{"unknown": 1}, {"range": -1}, {"range": 0}} {
		if err := validateGemOwnershipFloor([]byte(`{"gemInventory":{"range":1}}`), grants); !errors.Is(err, ErrGemOfferConflict) {
			t.Fatalf("invalid floor accepted: %v", err)
		}
	}
}

func TestGemOwnershipFloorValidatesOnlyCountedSlotShape(t *testing.T) {
	floor := map[string]int64{"range": 1}
	for _, raw := range []string{
		`{"gemInventory":{},"turrets":[{"type":"arrow","equippedGemSlots":["range"]}]}`,
		`{"gemInventory":{"range":1},"turrets":[{"type":"arrow","slotLimit":5,"equippedGemSlots":[]}]}`,
		`{"gemInventory":{"range":1},"turrets":[{"type":"cannon","slotLimit":3,"equippedGemSlots":[null,null]}]}`,
		// Gem compatibility is deliberately outside this shape-only boundary; the
		// normal client's migration returns incompatible equipment to inventory.
		`{"gemInventory":{"range":1},"turrets":[{"type":"magic","slotLimit":2,"equippedGemSlots":["lightWeapon"]}]}`,
	} {
		if err := validateGemOwnershipFloor([]byte(raw), floor); err != nil {
			t.Fatalf("valid slot shape rejected: %s %v", raw, err)
		}
	}
	for _, raw := range []string{
		`{"turrets":[{"equippedGemSlots":["range"]}]}`,
		`{"turrets":[{"type":"unknown","equippedGemSlots":["range"]}]}`,
		`{"turrets":[{"type":null,"equippedGemSlots":["range"]}]}`,
		`{"turrets":[{"type":"arrow","equippedGemSlots":["range","chain"]}]}`,
		`{"turrets":[{"type":"arrow","slotLimit":1,"equippedGemSlots":["range",null]}]}`,
		`{"turrets":[{"type":"arrow","slotLimit":2,"equippedGemSlots":["range","range"]}]}`,
		`{"turrets":[{"type":"arrow","slotLimit":0,"equippedGemSlots":["range"]}]}`,
		`{"turrets":[{"type":"arrow","slotLimit":6,"equippedGemSlots":["range"]}]}`,
		`{"turrets":[{"type":"arrow","slotLimit":-1,"equippedGemSlots":["range"]}]}`,
		`{"turrets":[{"type":"arrow","slotLimit":1.5,"equippedGemSlots":["range"]}]}`,
		`{"turrets":[{"type":"arrow","slotLimit":"1","equippedGemSlots":["range"]}]}`,
		`{"turrets":[{"type":"arrow","slotLimit":null,"equippedGemSlots":["range"]}]}`,
		`{"turrets":[{"type":"arrow","slotLimit":9223372036854775808,"equippedGemSlots":["range"]}]}`,
	} {
		if err := validateGemOwnershipFloor([]byte(raw), floor); !errors.Is(err, ErrGemOfferConflict) {
			t.Fatalf("malformed counted slots accepted: %s %v", raw, err)
		}
	}
	for _, kind := range []string{"arrow", "cannon", "magic", "frost", "sniper", "lightning"} {
		raw := []byte(`{"turrets":[{"type":"` + kind + `","equippedGemSlots":["range"]}]}`)
		if err := validateGemOwnershipFloor(raw, floor); err != nil {
			t.Fatalf("known turret type rejected %s: %v", kind, err)
		}
	}
}
