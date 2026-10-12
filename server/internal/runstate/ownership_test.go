package runstate

import (
	"encoding/json"
	"errors"
	"math"
	"testing"
)

func TestExactOwnershipConservesAllocationAndRejectsMintOrLoss(t *testing.T) {
	expected := map[string]int64{"range": 2, "chain": 1}
	for _, raw := range []string{
		`{"gemInventory":{"range":2,"chain":1},"turrets":[]}`,
		`{"gemInventory":{"range":1},"turrets":[{"type":"arrow","slotLimit":3,"equippedGemSlots":["range",null,"chain"],"equippedGems":["range","chain"]}]}`,
		`{"gemInventory":{"chain":1},"turrets":[{"type":"arrow","equippedGemSlots":["range"]},{"type":"cannon","equippedGemSlots":["range"]}]}`,
		`{"gemInventory":{"range":1},"turrets":[{"type":"arrow","slotLimit":2,"equippedGems":["range","chain"]}]}`,
	} {
		if err := ValidateOwnership([]byte(raw), expected); err != nil {
			t.Fatalf("valid allocation rejected %s: %v", raw, err)
		}
	}
	for _, raw := range []string{
		`{"gemInventory":{"range":3,"chain":1}}`,
		`{"gemInventory":{"range":2,"chain":1,"explosion":1}}`,
		`{"gemInventory":{"range":1,"chain":1}}`,
		`{"gemInventory":{"range":1,"chain":2}}`,
		`{"gemInventory":{"range":1,"chain":1},"turrets":[{"type":"arrow","equippedGemSlots":[null],"equippedGems":["range"]}]}`,
		`{"gemInventory":{"chain":1},"turrets":[{"type":"arrow","slotLimit":2,"equippedGemSlots":["range","range"]}]}`,
		`{"isPurchasedGemReward":true,"gemInventory":{"range":3,"chain":1}}`,
	} {
		if !errors.Is(ValidateOwnership([]byte(raw), expected), ErrConflict) {
			t.Fatalf("mint/loss accepted %s", raw)
		}
	}
	if err := ValidateOwnership([]byte(`{"gemInventory":{"range":1}}`), nil); !errors.Is(err, ErrConflict) {
		t.Fatal("zero baseline minted a gem")
	}
}

func TestOwnershipRejectsMalformedRepresentations(t *testing.T) {
	for _, raw := range []string{`null`, `[]`, `{"gemInventory":null}`, `{"gemInventory":{"range":null}}`, `{"gemInventory":{"range":1.5}}`, `{"gemInventory":{"range":"1"}}`, `{"gemInventory":{"range":-1}}`, `{"gemInventory":{"range":9223372036854775808}}`, `{"gemInventory":{"unknown":0}}`, `{"turrets":null}`, `{"turrets":[null]}`, `{"turrets":[{"type":"arrow","slotLimit":null,"equippedGemSlots":[]}]}`, `{"turrets":[{"type":"laser","equippedGemSlots":["range"]}]}`, `{"gemInventory":{"range":9223372036854775807},"turrets":[{"type":"arrow","equippedGemSlots":["range"]}]}`} {
		if _, err := ReadOwnedGems([]byte(raw)); !errors.Is(err, ErrConflict) {
			t.Fatalf("malformed representation accepted %s", raw)
		}
	}
}

func TestPristineCheckpointCannotResetProgress(t *testing.T) {
	base := map[string]any{"economyRunId": "", "stageNumber": 1, "phase": "preparation", "completedRounds": 0, "roundIndex": 0, "gemRerollsUsed": 0, "gemInventory": map[string]int{}, "gemShards": 5, "turrets": []any{}, "rewardOptions": []string{}}
	encode := func(v map[string]any) []byte {
		raw, err := json.Marshal(v)
		if err != nil {
			t.Fatal(err)
		}
		return raw
	}
	if err := ValidatePristine(encode(base), 1); err != nil {
		t.Fatal(err)
	} // Legitimate starting-shard research bonus.
	for field, value := range map[string]any{"economyRunId": "0198b955-3656-7c40-b3cb-87f427b90bfa", "stageNumber": 2, "phase": "wave", "completedRounds": 5, "roundIndex": 1, "gemRerollsUsed": 1, "gemInventory": map[string]int{"range": 1}, "rewardOptions": []string{"range"}, "gemShards": -1, "rewardReturnPhase": "wave", "isPurchasedGemReward": true, "gemOfferId": "prior", "gemOfferStatus": "chosen", "enemies": []any{map[string]any{}}, "spawnQueue": []any{map[string]any{}}} {
		t.Run(field, func(t *testing.T) {
			copy := map[string]any{}
			for k, v := range base {
				copy[k] = v
			}
			copy[field] = value
			if !errors.Is(ValidatePristine(encode(copy), 1), ErrConflict) {
				t.Fatal("progressed checkpoint accepted")
			}
		})
	}
}

func TestGrantRequiresActiveKnownAndRepresentableTotal(t *testing.T) {
	s := State{Status: "active", OwnedGems: map[string]int64{"range": 2}}
	if err := Grant(&s, "range", 1); err != nil || s.OwnedGems["range"] != 3 {
		t.Fatal(s, err)
	}
	for _, gem := range []string{"unknown", ""} {
		if !errors.Is(Grant(&s, gem, 1), ErrConflict) {
			t.Fatal("unknown gem accepted")
		}
	}
	s.OwnedGems["range"] = math.MaxInt64
	if !errors.Is(Grant(&s, "range", 1), ErrConflict) {
		t.Fatal("overflow accepted")
	}
	s.Status = "closed"
	if !errors.Is(Grant(&s, "chain", 1), ErrConflict) {
		t.Fatal("closed run minted gem")
	}
}
