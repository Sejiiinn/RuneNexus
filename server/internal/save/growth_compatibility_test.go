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

func TestExpandedProgressionProtectsMigratedRights(t *testing.T) {
	const migrated = `{"growthVersion":1,"progressionVersion":1,"unlockedStageIds":[1,6,16],"grandfatherUnlocks":["turret:lightning","feature:researchSlotTwo"]}`
	for _, tc := range []struct {
		name, current, incoming string
		client                  int
		reject                  bool
	}{
		{"legacy still supported", `{"growthVersion":1}`, `{"growthVersion":1}`, 3, false},
		{"first expansion", `{"growthVersion":1}`, migrated, 4, false},
		{"generation three cannot migrate", `{}`, migrated, 3, true},
		{"old writer cannot erase rights", migrated, `{"growthVersion":1}`, 3, true},
		{"current stale outbox rejected", migrated, `{"growthVersion":1}`, 4, true},
		{"stage access cannot regress", migrated, `{"growthVersion":1,"progressionVersion":1,"unlockedStageIds":[1,16],"grandfatherUnlocks":["turret:lightning","feature:researchSlotTwo"]}`, 4, true},
		{"unbought permission cannot regress", migrated, `{"growthVersion":1,"progressionVersion":1,"unlockedStageIds":[1,6,16],"grandfatherUnlocks":["turret:lightning"]}`, 4, true},
		{"idempotent migrated save", migrated, migrated, 4, false},
		{"future expansion unsupported", migrated, `{"growthVersion":1,"progressionVersion":2}`, 4, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidateGrowthUpdate([]byte(tc.current), []byte(tc.incoming), tc.client)
			if errors.Is(err, ErrClientUpdateRequired) != tc.reject {
				t.Fatalf("error=%v reject=%v", err, tc.reject)
			}
		})
	}
}
