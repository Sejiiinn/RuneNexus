package save

import "encoding/json"

// Older codecs drop the hard difficulty of a run and the separate hard round
// record, so saves that hold either must not be resumed or overwritten by them.
const HardDifficultyClientCompatibilityVersion = 15

func validateHardDifficultyClient(progression, activeRun []byte, clientVersion int) error {
	if clientVersion >= HardDifficultyClientCompatibilityVersion {
		return nil
	}
	var run struct {
		Difficulty string `json:"difficulty"`
	}
	if len(activeRun) > 0 && string(activeRun) != "null" && json.Unmarshal(activeRun, &run) == nil && run.Difficulty == "hard" {
		return ErrClientUpdateRequired
	}
	var record struct {
		HardBestRoundsByStage map[string]json.RawMessage `json:"hardBestRoundsByStage"`
	}
	if len(progression) > 0 && json.Unmarshal(progression, &record) == nil && len(record.HardBestRoundsByStage) > 0 {
		return ErrClientUpdateRequired
	}
	return nil
}
