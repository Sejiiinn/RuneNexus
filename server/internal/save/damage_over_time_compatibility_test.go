package save

import (
	"errors"
	"fmt"
	"testing"
)

func TestDamageOverTimeMetadataCompatibility(t *testing.T) {
	for _, key := range []string{"damageOverTimeIncreaseMultiplier", "poisonDamageOverTimeIncreaseMultiplier"} {
		t.Run(key, func(t *testing.T) {
			for _, tc := range []struct {
				value  string
				client int
				reject bool
			}{
				{"1", 11, true}, {"1.5", 11, true}, {"1", 12, false}, {"1.5", 12, false}, {"4", 12, false},
				{"0", 12, true}, {"-1", 12, true}, {"0.9", 12, true}, {"4.01", 12, true},
				{"1e999", 12, true}, {`"1"`, 12, true}, {"true", 12, true}, {"null", 12, true},
			} {
				record := fmt.Sprintf(`{"%s":%s}`, key, tc.value)
				if key == "damageOverTimeIncreaseMultiplier" {
					record = `{"burnInstances":[` + record + `]}`
				}
				raw := []byte(`{"enemies":[` + record + `]}`)
				if err := ValidateContentClient([]byte(`{}`), raw, tc.client); errors.Is(err, ErrClientUpdateRequired) != tc.reject {
					t.Fatalf("value=%s client=%d reject=%v err=%v", tc.value, tc.client, tc.reject, err)
				}
			}
		})
	}
	if err := ValidateContentClient([]byte(`{}`), []byte(`{"enemies":[7,{"poisonDamageOverTimeIncreaseMultiplier":null}]}`), 12); !errors.Is(err, ErrClientUpdateRequired) {
		t.Fatalf("malformed unrelated enemy must not bypass metadata validation: %v", err)
	}
	if err := ValidateContentClient([]byte(`{}`), []byte(`{"enemies":[{"burnInstances":[{"remaining":1,"damagePerSecond":3}]}]}`), 11); err != nil {
		t.Fatal(err)
	}
}
