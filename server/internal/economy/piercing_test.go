package economy

import (
	"slices"
	"testing"
)

func TestPiercingPoolClientCompatibility(t *testing.T) {
	legacy, err := availableGemsForClient([]byte(`{}`), 10)
	if err != nil || len(legacy) != 12 || slices.Contains(legacy, "piercing") {
		t.Fatalf("legacy pool changed: %v %v", legacy, err)
	}
	current, err := availableGemsForClient([]byte(`{}`), 11)
	if err != nil || len(current) != len(legacy)+1 || !slices.Equal(current[:len(legacy)], legacy) || current[len(current)-1] != "piercing" {
		t.Fatalf("new pool must append piercing without reordering legacy entries: %v %v", current, err)
	}
	if !validDeckOptions([]string{"piercing", "armorPiercing", "range"}) {
		t.Fatal("distinct piercing identities rejected from deck")
	}
}
