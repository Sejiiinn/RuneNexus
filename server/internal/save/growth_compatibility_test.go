package save

import (
	"errors"
	"testing"
)

func TestGrowthCompatibilityRollingUpgrade(t *testing.T) {
	for _, tc := range []struct {
		name, current, incoming string
		client                  int
		reject                  bool
	}{
		{"legacy generation two", `{}`, `{}`, 2, false},
		{"first migration", `{}`, `{"growthVersion":1}`, 3, false},
		{"old client cannot migrate", `{}`, `{"growthVersion":1}`, 2, true},
		{"old client after migration", `{"growthVersion":1}`, `{"growthVersion":1}`, 2, true},
		{"current stale outbox", `{"growthVersion":1}`, `{}`, 3, true},
		{"migrated current", `{"growthVersion":1}`, `{"growthVersion":1}`, 3, false},
		{"future growth unsupported", `{"growthVersion":1}`, `{"growthVersion":2}`, 3, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidateGrowthUpdate([]byte(tc.current), []byte(tc.incoming), tc.client)
			if errors.Is(err, ErrClientUpdateRequired) != tc.reject {
				t.Fatalf("error=%v, reject=%v", err, tc.reject)
			}
		})
	}
}
