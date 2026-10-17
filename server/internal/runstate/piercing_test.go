package runstate

import (
	"fmt"
	"testing"
)

func TestPiercingOwnershipUsesAttackCapabilities(t *testing.T) {
	for _, turret := range []string{"arrow", "cannon", "magic", "frost", "sniper", "lightning"} {
		raw := []byte(fmt.Sprintf(`{"gemInventory":{"armorPiercing":1},"turrets":[{"type":%q,"equippedGemSlots":["piercing"]}]}`, turret))
		owned, err := ReadOwnedGems(raw)
		want := turret == "arrow" || turret == "cannon" || turret == "magic"
		if (err == nil) != want {
			t.Fatalf("%s capability allocation: %v", turret, err)
		}
		if want && (owned["piercing"] != 1 || owned["armorPiercing"] != 1) {
			t.Fatalf("distinct ownership lost: %v", owned)
		}
	}
	if _, err := ReadOwnedGems([]byte(`{"gemInventory":{"piercing":2},"turrets":[]}`)); err != nil {
		t.Fatal(err)
	}
}
