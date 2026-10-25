package save

import "encoding/json"

// Older codecs drop support cores and the deck log entries for the gems they
// consumed, so a run that holds either must not be resumed or overwritten by
// them.
const SupportCoreClientCompatibilityVersion = 14

func validateSupportCoreClient(activeRun []byte, clientVersion int) error {
	if clientVersion >= SupportCoreClientCompatibilityVersion || len(activeRun) == 0 || string(activeRun) == "null" {
		return nil
	}
	var run struct {
		SupportCores []json.RawMessage `json:"supportCores"`
		GemDeckLog   []struct {
			Kind string `json:"kind"`
		} `json:"gemDeckLog"`
	}
	if json.Unmarshal(activeRun, &run) != nil {
		return nil
	}
	if len(run.SupportCores) > 0 {
		return ErrClientUpdateRequired
	}
	for _, entry := range run.GemDeckLog {
		if entry.Kind == "consume" {
			return ErrClientUpdateRequired
		}
	}
	return nil
}
