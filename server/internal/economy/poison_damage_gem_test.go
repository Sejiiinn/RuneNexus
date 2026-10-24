package economy

import (
	"slices"
	"testing"
)

func TestPoisonDamageGemPoolUnlockAndClientCompatibility(t *testing.T) {
	for _, test := range []struct {
		raw     string
		client  int
		offered bool
	}{
		{`{"progressionVersion":1,"clearedStageNumbers":[23]}`, 13, true},
		{`{"progressionVersion":1,"clearedStageNumbers":[23]}`, 12, false},
		{`{"progressionVersion":1,"clearedStageNumbers":[22]}`, 13, false},
		// New content never accepts grandfathered rights or legacy-era clears.
		{`{"progressionVersion":1,"grandfatherUnlocks":["gem:poisonDamage"]}`, 13, false},
		{`{"clearedStageNumbers":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]}`, 13, false},
	} {
		available, err := availableGemsForClient([]byte(test.raw), test.client)
		if err != nil || slices.Contains(available, "poisonDamage") != test.offered {
			t.Fatalf("%s client %d: %v %v", test.raw, test.client, available, err)
		}
	}
	unlocked, err := availableGemsForClient([]byte(`{"progressionVersion":1,"clearedStageNumbers":[23]}`), 13)
	legacy, _ := availableGemsForClient([]byte(`{"progressionVersion":1,"clearedStageNumbers":[23]}`), 12)
	if err != nil || len(unlocked) != len(legacy)+1 || !slices.Equal(unlocked[:len(legacy)], legacy) || unlocked[len(unlocked)-1] != "poisonDamage" {
		t.Fatalf("poison damage must append without reordering the pool: %v %v", unlocked, err)
	}
	// Existing gated gems keep their grandfathered rights.
	armor, _ := availableGemsForClient([]byte(`{"progressionVersion":1,"grandfatherUnlocks":["gem:armorPiercing"]}`), 13)
	if !slices.Contains(armor, "armorPiercing") {
		t.Fatalf("grandfathered armor piercing lost: %v", armor)
	}
	if !validDeckOptions([]string{"poisonDamage", "piercing", "range"}) {
		t.Fatal("poison damage rejected from deck")
	}
}
