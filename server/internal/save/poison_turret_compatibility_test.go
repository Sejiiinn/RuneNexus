package save

import (
	"errors"
	"testing"
)

func TestPoisonTurretRequiresCurrentClient(t *testing.T) {
	for _, tc := range []struct {
		name   string
		run    string
		client int
		reject bool
	}{
		{"poison turret old client", `{"turrets":[{"type":"poison"}]}`, 12, true},
		{"poison stacks old client", `{"enemies":[{"poisonInstances":[{"remaining":1,"damagePerSecond":2}]}]}`, 12, true},
		{"poison turret current client", `{"turrets":[{"type":"poison"}]}`, 13, false},
		{"poison stacks current client", `{"enemies":[{"poisonInstances":[{"remaining":1,"damagePerSecond":2,"stackBonus":0.1,"corrosive":true}]}]}`, 13, false},
		{"other turret old client", `{"turrets":[{"type":"lightning"}],"enemies":[{"poisonInstances":[]}]}`, 12, false},
		{"no run", `null`, 12, false},
	} {
		if err := ValidateContentClient([]byte(`{}`), []byte(tc.run), tc.client); errors.Is(err, ErrClientUpdateRequired) != tc.reject {
			t.Fatalf("%s: reject=%v err=%v", tc.name, tc.reject, err)
		}
	}
	for _, value := range []string{"0.9", "4.01", `"1"`} {
		raw := []byte(`{"enemies":[{"poisonInstances":[{"remaining":1,"damagePerSecond":2,"damageOverTimeIncreaseMultiplier":` + value + `}]}]}`)
		if err := ValidateContentClient([]byte(`{}`), raw, 13); !errors.Is(err, ErrClientUpdateRequired) {
			t.Fatalf("invalid poison stack multiplier %s accepted: %v", value, err)
		}
	}
	if CurrentClientCompatibilityVersion != PoisonTurretClientCompatibilityVersion {
		t.Fatalf("current client generation %d", CurrentClientCompatibilityVersion)
	}
}

func TestPoisonDamageTrainingRequiresCurrentClient(t *testing.T) {
	for _, tc := range []struct {
		progression string
		client      int
		reject      bool
	}{
		{`{"poisonDamageTrainingUpgradeLevel":1}`, 12, true},
		{`{"poisonDamageTrainingUpgradeLevel":0}`, 12, false},
		{`{}`, 12, false},
		{`{"poisonDamageTrainingUpgradeLevel":50}`, 13, false},
		{`{"poisonDamageTrainingUpgradeLevel":51}`, 13, true},
		{`{"poisonDamageTrainingUpgradeLevel":-1}`, 13, true},
		{`{"poisonDamageTrainingUpgradeLevel":1.5}`, 13, true},
	} {
		if err := ValidateGrowthClient([]byte(tc.progression), tc.client); errors.Is(err, ErrClientUpdateRequired) != tc.reject {
			t.Fatalf("%s client=%d reject=%v err=%v", tc.progression, tc.client, tc.reject, err)
		}
	}
	if err := ValidateGrowthUpdate([]byte(`{"poisonDamageTrainingUpgradeLevel":3}`), []byte(`{"poisonDamageTrainingUpgradeLevel":2}`), 13); !errors.Is(err, ErrClientUpdateRequired) {
		t.Fatalf("poison training decrease accepted: %v", err)
	}
	if err := ValidateGrowthUpdate([]byte(`{"poisonDamageTrainingUpgradeLevel":3}`), []byte(`{}`), 13); !errors.Is(err, ErrClientUpdateRequired) {
		t.Fatalf("poison training removal accepted: %v", err)
	}
}
