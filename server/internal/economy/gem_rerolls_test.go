package economy

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"errors"
	"io"
	"slices"
	"testing"
	"time"
)

const rerollTestRun = "0198b955-3656-7c40-b3cb-87f427b90be6"

func TestGemSamplingUniquenessImmediateExclusionAndEntropyFailure(t *testing.T) {
	previous := []string{"attackSpeed", "range", "physicalDamage"}
	for i := 0; i < 100; i++ {
		options, err := sampleGems(rand.Reader, gemTypes, previous)
		if err != nil || len(options) != 3 {
			t.Fatalf("sampling %v %v", options, err)
		}
		seen := map[string]bool{}
		for _, gem := range options {
			if seen[gem] || slices.Contains(previous, gem) || !slices.Contains(gemTypes, gem) {
				t.Fatalf("invalid draw %v", options)
			}
			seen[gem] = true
		}
	}
	// The only eligible candidates are exactly the set from two offers earlier.
	options, err := sampleGems(bytes.NewReader(make([]byte, 32)), append(slices.Clone(previous), "chain", "explosion", "criticalChance"), []string{"chain", "explosion", "criticalChance"})
	if err != nil || len(options) != 3 {
		t.Fatalf("earlier candidates: %v %v", options, err)
	}
	for _, gem := range previous {
		if !slices.Contains(options, gem) {
			t.Fatal("older set incorrectly excluded")
		}
	}
	if _, err = sampleGems(bytes.NewReader(nil), gemTypes, nil); !errors.Is(err, io.EOF) {
		t.Fatalf("entropy failure ignored: %v", err)
	}
}

func TestGemRerollUnlocksAndInvalidCandidates(t *testing.T) {
	for _, test := range []struct {
		raw        string
		count      int
		aim, armor bool
	}{
		{`{}`, 12, false, false},
		{`{"progressionVersion":1,"clearedStageNumbers":[3,21]}`, 14, true, true},
		{`{"progressionVersion":1,"clearedStageNumbers":[10]}`, 12, false, false},
		{`{"clearedStageNumbers":[3,10]}`, 14, true, true},
		{`{"progressionVersion":1,"grandfatherUnlocks":["gem:armorPiercing"]}`, 13, false, true},
	} {
		available, err := availableGems([]byte(test.raw))
		if err != nil || len(available) != test.count || slices.Contains(available, "aimSpeed") != test.aim || slices.Contains(available, "armorPiercing") != test.armor {
			t.Fatalf("unlock %s: %v %v", test.raw, available, err)
		}
	}
	for _, previous := range [][]string{{"range"}, {"range", "range", "chain"}, {"unknown", "range", "chain"}, {"aimSpeed", "range", "chain"}} {
		available, _ := availableGems([]byte(`{}`))
		if _, err := sampleGems(rand.Reader, available, previous); !errors.Is(err, ErrInvalidCommand) {
			t.Fatalf("accepted candidates %v", previous)
		}
	}
}

func TestLegacyReceiptDoesNotAdvertiseUnsupportedRerollVersion(t *testing.T) {
	raw := []byte(`{"economy":{"wallet":{"freeDiamonds":10,"paidDiamonds":0,"moduleTickets":2}}}`)
	var result CommandResult
	if err := json.Unmarshal(raw, &result); err != nil {
		t.Fatal(err)
	}
	replay, err := json.Marshal(result)
	if err != nil || (bytes.Contains(replay, []byte(`"gemRerollVersion"`)) || bytes.Contains(replay, []byte(`"gemOfferVersion"`)) || bytes.Contains(replay, []byte(`"serverSavedAt"`))) {
		t.Fatalf("old receipt invented capability: %s %v", replay, err)
	}
}

func TestGemTicketMailValidationAndLegacyDispatchHash(t *testing.T) {
	request := CreateMailRequest{DispatchKey: rerollTestRun, Title: "test", Body: "test", Audience: "all", CreatedBy: "test", StartsAt: time.Unix(1, 0), ExpiresAt: time.Unix(2, 0), GemResetTickets: 2}
	if err := ValidateMail(&request); err != nil {
		t.Fatalf("ticket-only mail rejected: %v", err)
	}
	request.GemResetTickets = -1
	if err := ValidateMail(&request); !errors.Is(err, ErrInvalidMailRequest) {
		t.Fatal("negative tickets accepted")
	}
	request.GemResetTickets = 100001
	if err := ValidateMail(&request); !errors.Is(err, ErrInvalidMailRequest) {
		t.Fatal("oversized tickets accepted")
	}
	request.GemResetTickets = 0
	request.FreeDiamonds = 1
	if err := ValidateMail(&request); err != nil {
		t.Fatal(err)
	}
	encoded, err := json.Marshal(request)
	if err != nil || bytes.Contains(encoded, []byte(`"gemResetTickets"`)) {
		t.Fatalf("legacy dispatch hash would change: %s %v", encoded, err)
	}
}

func TestGemChoiceProjectionPreservesUnrelatedStateAndIsAbsolute(t *testing.T) {
	offer := &GemOfferState{OfferID: "opaque", RunID: rerollTestRun, RewardWave: 5, Revision: 2, Status: "chosen", Choice: "shards", GrantedShards: 10, GemShards: 30, GemInventory: map[string]int64{"range": 1}, GemOptions: []string{"range", "chain", "explosion"}}
	raw := []byte(`{"phase":"reward","gemShards":20,"gemInventory":{"range":1},"rewardOptions":["range","chain","explosion"],"gold":19,"turrets":[],"gemOfferEquipRevision":0}`)
	first, err := projectGemOffer(raw, offer)
	if err != nil {
		t.Fatal(err)
	}
	second, err := projectGemOffer(first, offer)
	if err != nil || !bytes.Equal(first, second) {
		t.Fatalf("projection added twice: %s %v", second, err)
	}
	var value map[string]any
	if err = json.Unmarshal(first, &value); err != nil {
		t.Fatal(err)
	}
	if value["phase"] != "preparation" || value["gold"] != float64(19) || value["gemShards"] != float64(30) || len(value["rewardOptions"].([]any)) != 0 || value["gemOfferStatus"] != "chosen" {
		t.Fatalf("bad projection %s", first)
	}
}

// This benchmark isolates server candidate generation. It deliberately excludes
// PostgreSQL transactions and network round trips, which require separate timing.
func BenchmarkGemOfferSampling(b *testing.B) {
	defaultPool, err := availableGems([]byte(`{}`))
	if err != nil {
		b.Fatal(err)
	}
	for _, scenario := range []struct {
		name                string
		available, previous []string
	}{
		{"initial_12", defaultPool, nil},
		{"reroll_14_exclude_3", gemTypes, []string{"attackSpeed", "range", "physicalDamage"}},
	} {
		b.Run(scenario.name, func(b *testing.B) {
			b.ReportAllocs()
			for b.Loop() {
				if _, err := sampleGems(rand.Reader, scenario.available, scenario.previous); err != nil {
					b.Fatal(err)
				}
			}
		})
	}
}
