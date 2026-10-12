package legacytransfer

import (
	"errors"
	"testing"
)

func TestLateTransferredRunsCannotCreateLegacyGemAuthority(t *testing.T) {
	for _, raw := range []string{`{"economyRunId":"0198b955-3656-7c40-b3cb-87f427b90bea","stageNumber":1,"phase":"preparation","gemInventory":{}}`, `{"stageNumber":1,"phase":"preparation","gemInventory":{"range":1}}`, `{"stageNumber":1,"phase":"reward","completedRounds":5,"gemInventory":{}}`, `{"stageNumber":1,"phase":"preparation","gemRerollsUsed":1,"gemInventory":{}}`} {
		if err := validateTransferredRun([]byte(raw)); !errors.Is(err, ErrTargetNotReplaceable) {
			t.Fatalf("accepted transferred run %s: %v", raw, err)
		}
	}
	for _, raw := range [][]byte{nil, []byte(`null`), []byte(`{"economyRunId":null,"stageNumber":1,"phase":"preparation","completedRounds":0,"roundIndex":0,"gemShards":3,"gemInventory":{},"turrets":[]}`)} {
		if err := validateTransferredRun(raw); err != nil {
			t.Fatalf("rejected empty/pristine checkpoint %s: %v", raw, err)
		}
	}
}
