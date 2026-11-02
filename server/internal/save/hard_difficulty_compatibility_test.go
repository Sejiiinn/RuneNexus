package save

import (
	"errors"
	"testing"
)

func TestHardDifficultyRequiresCurrentClient(t *testing.T) {
	for _, tc := range []struct {
		name        string
		progression string
		run         string
		client      int
		reject      bool
	}{
		{"hard run old client", `{}`, `{"difficulty":"hard"}`, 14, true},
		{"hard record old client", `{"hardBestRoundsByStage":{"3":12}}`, `null`, 14, true},
		{"hard clear old client", `{"hardClearedStageNumbers":[3]}`, `null`, 14, true},
		{"hard run current client", `{"hardBestRoundsByStage":{"3":12}}`, `{"difficulty":"hard"}`, 15, false},
		{"normal old client", `{"bestRoundsByStage":{"3":40}}`, `{"stageNumber":3}`, 14, false},
		{"empty hard record old client", `{"hardBestRoundsByStage":{}}`, `null`, 14, false},
	} {
		if err := ValidateContentClient([]byte(tc.progression), []byte(tc.run), tc.client); errors.Is(err, ErrClientUpdateRequired) != tc.reject {
			t.Fatalf("%s: reject=%v err=%v", tc.name, tc.reject, err)
		}
	}
	if CurrentClientCompatibilityVersion < HardDifficultyClientCompatibilityVersion {
		t.Fatalf("current client generation %d", CurrentClientCompatibilityVersion)
	}
}
