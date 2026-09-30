package economy

import "testing"

func TestLightningChapterTwoAndLegacyPermission(t *testing.T) {
	for _, tc := range []struct {
		name, progression string
		allowed           bool
	}{
		{"legacy chapter two first", `{"clearedStageNumbers":[6]}`, true},
		{"new first is insufficient", `{"progressionVersion":1,"clearedStageNumbers":[6]}`, false},
		{"new second unlocks", `{"progressionVersion":1,"clearedStageNumbers":[7]}`, true},
		{"new chapter one sixth is different", `{"progressionVersion":1,"clearedStageNumbers":[16]}`, false},
		{"legacy level zero preserved", `{"progressionVersion":1,"clearedStageNumbers":[6],"grandfatherUnlocks":["turret:lightning"]}`, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := turretUnlocked("lightning", []byte(tc.progression)); got != tc.allowed {
				t.Fatalf("allowed=%v want %v", got, tc.allowed)
			}
		})
	}
}

func TestSlotPurchaseEligibilityIsNotOwnership(t *testing.T) {
	for _, tc := range []struct {
		name, progression string
		allowed           bool
	}{
		{"legacy chapter two fifth", `{"clearedStageNumbers":[10]}`, true},
		{"new fifth is insufficient", `{"progressionVersion":1,"clearedStageNumbers":[10]}`, false},
		{"new tenth is eligible", `{"progressionVersion":1,"clearedStageNumbers":[25]}`, true},
		{"legacy unpurchased eligible", `{"progressionVersion":1,"clearedStageNumbers":[10],"grandfatherUnlocks":["feature:researchSlotTwo"]}`, true},
		{"preview is not purchase", `{"progressionVersion":1,"grandfatherUnlocks":["feature:researchSlotTwoPreview"]}`, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := researchSlotEligible([]byte(tc.progression)); got != tc.allowed {
				t.Fatalf("eligible=%v want %v", got, tc.allowed)
			}
		})
	}
}
