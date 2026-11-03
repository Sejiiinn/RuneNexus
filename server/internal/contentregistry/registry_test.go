package contentregistry

import "testing"

func TestModuleRangeAppliesPartOverrideOnlyToThatPart(t *testing.T) {
	core, ok := ModuleRange("damageIncrease", "core", "unique")
	if !ok || core != (Range{25, 36}) {
		t.Fatalf("core damage range = %v, %v", core, ok)
	}
	barrel, ok := ModuleRange("damageIncrease", "barrel", "unique")
	if !ok || barrel != (Range{22, 30}) {
		t.Fatalf("barrel damage range = %v, %v", barrel, ok)
	}
	if _, ok := ModuleRange("unknownOption", "core", "unique"); ok {
		t.Fatal("unknown option must not have a range")
	}
}

func TestAccessorsReturnIndependentCopies(t *testing.T) {
	gems := GemTypes()
	gems[0] = "changed"
	if GemTypes()[0] == "changed" || !ValidGem(GemTypes()[0]) {
		t.Fatal("gem registry was mutated through a returned slice")
	}
	pool := ModulePool("machinegun", "core")
	pool[0] = "changed"
	if ModulePool("machinegun", "core")[0] == "changed" {
		t.Fatal("module pool was mutated through a returned slice")
	}
	if ValidTurret("unknown") || ModuleFamily("unknown", "core") != "" || len(ModulePool("unknown", "core")) != 0 {
		t.Fatal("unknown turret must not resolve")
	}
}

func TestCanonicalTurretMapsOnlyRenamedIds(t *testing.T) {
	for legacy, current := range map[string]string{"arrow": "machinegun", "magic": "flame", "machinegun": "machinegun", "cannon": "cannon", "unknown": "unknown"} {
		if got := CanonicalTurret(legacy); got != current {
			t.Fatalf("CanonicalTurret(%q) = %q, want %q", legacy, got, current)
		}
	}
	if ValidTurret("arrow") || ValidTurret("magic") || !ValidTurret("machinegun") || !ValidTurret("flame") {
		t.Fatal("only current turret ids are valid content")
	}
}
