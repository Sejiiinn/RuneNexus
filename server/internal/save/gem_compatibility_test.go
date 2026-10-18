package save

import "testing"

func TestPiercingContentDowngradeGuard(t *testing.T) {
	for _, raw := range []string{
		`{"gemInventory":{"piercing":1}}`,
		`{"turrets":[{"equippedGemSlots":["piercing"]}]}`,
		`{"rewardOptions":["range","piercing","armorPiercing"]}`,
		`{"waves":{"5":{"options":[["range","piercing","armorPiercing"]]}}}`,
	} {
		if ValidateGemContentClient([]byte(raw), 10) != ErrClientUpdateRequired {
			t.Fatalf("old client accepted new content: %s", raw)
		}
		if err := ValidateGemContentClient([]byte(raw), 11); err != nil {
			t.Fatal(err)
		}
	}
	if err := ValidateGemContentClient([]byte(`{"gemInventory":{"armorPiercing":1}}`), 10); err != nil {
		t.Fatal("legacy armor gem became incompatible", err)
	}
}
