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

func TestPoisonDamageGemDowngradeGuard(t *testing.T) {
	for _, raw := range []string{
		`{"gemInventory":{"poisonDamage":1}}`,
		`{"turrets":[{"equippedGemSlots":["poisonDamage"]}]}`,
		`{"waves":{"5":{"options":[["range","poisonDamage","armorPiercing"]]}}}`,
	} {
		for _, old := range []int{10, 11, 12} {
			if ValidateGemContentClient([]byte(raw), old) != ErrClientUpdateRequired {
				t.Fatalf("generation %d accepted poison damage: %s", old, raw)
			}
		}
		if err := ValidateGemContentClient([]byte(raw), 13); err != nil {
			t.Fatal(err)
		}
	}
	if err := ValidateGemContentClient([]byte(`{"gemInventory":{"piercing":1}}`), 12); err != nil {
		t.Fatal("generation 12 lost piercing compatibility", err)
	}
}
