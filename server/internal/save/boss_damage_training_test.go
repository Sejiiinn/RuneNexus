package save

import (
	"errors"
	"fmt"
	"testing"
)

func TestBossDamageTrainingSelectiveCompatibility(t *testing.T) {
	for _, tc := range []struct {
		name, raw string
		client    int
		reject    bool
	}{
		{"unbought old client", `{}`, 10, false},
		{"explicit zero old client", `{"bossDamageTrainingUpgradeLevel":0}`, 10, false},
		{"bought old client", `{"bossDamageTrainingUpgradeLevel":1}`, 10, true},
		{"bought current client", `{"bossDamageTrainingUpgradeLevel":1}`, 11, false},
		{"maximum", `{"bossDamageTrainingUpgradeLevel":40}`, 11, false},
		{"negative", `{"bossDamageTrainingUpgradeLevel":-1}`, 11, true},
		{"over maximum", `{"bossDamageTrainingUpgradeLevel":41}`, 11, true},
		{"fraction", `{"bossDamageTrainingUpgradeLevel":1.5}`, 11, true},
		{"float token", `{"bossDamageTrainingUpgradeLevel":1.0}`, 11, true},
		{"string", `{"bossDamageTrainingUpgradeLevel":"1"}`, 11, true},
		{"bool", `{"bossDamageTrainingUpgradeLevel":true}`, 11, true},
		{"null", `{"bossDamageTrainingUpgradeLevel":null}`, 11, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidateContentClient([]byte(tc.raw), nil, tc.client)
			if errors.Is(err, ErrClientUpdateRequired) != tc.reject {
				t.Fatalf("err=%v, reject=%v", err, tc.reject)
			}
		})
	}
}

func TestBossDamageTrainingCannotRegressThroughStaleOutbox(t *testing.T) {
	for _, tc := range []struct {
		name, before, after string
		reject              bool
	}{
		{"old absent payload", `{}`, `{}`, false},
		{"first purchase", `{}`, `{"bossDamageTrainingUpgradeLevel":1}`, false},
		{"same purchased level", `{"bossDamageTrainingUpgradeLevel":1}`, `{"bossDamageTrainingUpgradeLevel":1}`, false},
		{"purchase to maximum", `{"bossDamageTrainingUpgradeLevel":39}`, `{"bossDamageTrainingUpgradeLevel":40}`, false},
		{"missing purchased field", `{"bossDamageTrainingUpgradeLevel":1}`, `{}`, true},
		{"zero purchased field", `{"bossDamageTrainingUpgradeLevel":1}`, `{"bossDamageTrainingUpgradeLevel":0}`, true},
		{"lower purchased level", `{"bossDamageTrainingUpgradeLevel":40}`, `{"bossDamageTrainingUpgradeLevel":39}`, true},
		{"zero may remain absent", `{"bossDamageTrainingUpgradeLevel":0}`, `{}`, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidateGrowthUpdate([]byte(tc.before), []byte(tc.after), BossDamageTrainingClientCompatibilityVersion)
			if errors.Is(err, ErrClientUpdateRequired) != tc.reject {
				t.Fatalf("err=%v, reject=%v", err, tc.reject)
			}
		})
	}
}

func TestDamageTrainingSelectiveCompatibilityAndStrictLevels(t *testing.T) {
	for _, key := range damageTrainingFields {
		t.Run(key, func(t *testing.T) {
			for _, tc := range []struct {
				value  string
				client int
				reject bool
			}{
				{"0", 11, false}, {"1", 11, true}, {"1", 12, false}, {"60", 12, false}, {"80", 12, false},
				{"-1", 12, true}, {"81", 12, true}, {"1.0", 12, true}, {"1.5", 12, true},
				{`"1"`, 12, true}, {"true", 12, true}, {"null", 12, true},
			} {
				raw := []byte(fmt.Sprintf(`{"%s":%s}`, key, tc.value))
				if err := ValidateContentClient(raw, nil, tc.client); errors.Is(err, ErrClientUpdateRequired) != tc.reject {
					t.Fatalf("value=%s client=%d reject=%v err=%v", tc.value, tc.client, tc.reject, err)
				}
			}
			if err := ValidateContentClient([]byte(`{}`), nil, 11); err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestDamageTrainingCannotRegressThroughStaleOutbox(t *testing.T) {
	for _, key := range damageTrainingFields {
		t.Run(key, func(t *testing.T) {
			for _, tc := range []struct {
				before, after string
				reject        bool
			}{
				{"", "", false}, {"", "1", false}, {"1", "1", false}, {"59", "60", false}, {"79", "80", false},
				{"1", "", true}, {"1", "0", true}, {"80", "79", true}, {"0", "", false},
			} {
				encode := func(value string) []byte {
					if value == "" {
						return []byte(`{}`)
					}
					return []byte(fmt.Sprintf(`{"%s":%s}`, key, value))
				}
				if err := ValidateGrowthUpdate(encode(tc.before), encode(tc.after), 12); errors.Is(err, ErrClientUpdateRequired) != tc.reject {
					t.Fatalf("before=%s after=%s reject=%v err=%v", tc.before, tc.after, tc.reject, err)
				}
			}
		})
	}
}
