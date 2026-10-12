package economy

import (
	"bytes"
	"encoding/json"
	"errors"
	"slices"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
)

const rerollTestRun = "0198b955-3656-7c40-b3cb-87f427b90be6"

func TestGemRerollDeterminismAndImmediateExclusion(t *testing.T) {
	previous := []string{"attackSpeed", "range", "physicalDamage"}
	first, err := rerolledGems(rerollTestRun, 5, 1, gemTypes, previous)
	if err != nil {
		t.Fatal(err)
	}
	repeated, err := rerolledGems(rerollTestRun, 5, 1, gemTypes, previous)
	if err != nil || !slices.Equal(first, repeated) {
		t.Fatalf("not deterministic: %v %v", first, repeated)
	}
	reordered := slices.Clone(gemTypes)
	slices.Reverse(reordered)
	repeated, _ = rerolledGems(rerollTestRun, 5, 1, reordered, previous)
	if !slices.Equal(first, repeated) {
		t.Fatal("catalog iteration order changed result")
	}
	seenEarlier := false
	for wave := 5; wave <= 35; wave += 5 {
		next, err := rerolledGems(rerollTestRun, wave, 2, gemTypes, first)
		if err != nil || len(next) != 3 {
			t.Fatalf("reroll: %v %v", next, err)
		}
		for _, gem := range next {
			if slices.Contains(first, gem) {
				t.Fatal("immediately previous option repeated")
			}
			if slices.Contains(previous, gem) {
				seenEarlier = true
			}
		}
	}
	if !seenEarlier {
		t.Fatal("earlier option set should be eligible again")
	}
	t.Logf("cross-language vector: %v", first)
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
		if _, err := rerolledGems(rerollTestRun, 5, 1, available, previous); !errors.Is(err, ErrInvalidCommand) {
			t.Fatalf("accepted candidates %v", previous)
		}
	}
}

func TestGemRerollRunRequiresRecoveredState(t *testing.T) {
	base := gemRewardRun{RunID: rerollTestRun, Phase: "reward", CompletedRounds: 5, Options: []string{"range", "chain", "explosion"}}
	request := GemRerollRequest{RunID: rerollTestRun, CompletedRounds: 5}
	if used, err := validateGemRerollRun(base, request, nil); err != nil || used != 0 {
		t.Fatalf("free: %d %v", used, err)
	}
	latest := &GemRerollState{RunID: rerollTestRun, RewardWave: 5, TotalUsed: 1, GemOptions: []string{"attackSpeed", "physicalDamage", "lightWeapon"}}
	if _, err := validateGemRerollRun(base, request, latest); !errors.Is(err, ErrGemRerollConflict) {
		t.Fatalf("stale recovered save: %v", err)
	}
	base.Used = 1
	base.Options = latest.GemOptions
	request.ExpectedRerollCount = 1
	if used, err := validateGemRerollRun(base, request, latest); err != nil || used != 1 {
		t.Fatalf("recovered: %d %v", used, err)
	}
	base.CompletedRounds = 10
	request.CompletedRounds = 10
	base.Options = []string{"range", "chain", "explosion"}
	if _, err := validateGemRerollRun(base, request, latest); err != nil {
		t.Fatalf("next wave: %v", err)
	}
	latest.RewardWave = 15
	if _, err := validateGemRerollRun(base, request, latest); !errors.Is(err, ErrGemRerollConflict) {
		t.Fatalf("previous wave restored: %v", err)
	}
	latest.RewardWave = 10
	latest.GemOptions = base.Options
	latest.TotalUsed = 3
	base.Used = 3
	request.ExpectedRerollCount = 3
	if _, err := validateGemRerollRun(base, request, latest); !errors.Is(err, ErrGemRerollLimit) {
		t.Fatalf("limit: %v", err)
	}
	for _, mutate := range []func(*gemRewardRun){func(r *gemRewardRun) { r.Purchased = true }, func(r *gemRewardRun) { r.LegacyPaid = true }, func(r *gemRewardRun) { r.Phase = "wave" }, func(r *gemRewardRun) { r.CompletedRounds = 0 }, func(r *gemRewardRun) { r.CompletedRounds = 40 }, func(r *gemRewardRun) { r.CompletedRounds = 45 }, func(r *gemRewardRun) { r.CompletedRounds = 6 }, func(r *gemRewardRun) { r.RunID = "other" }} {
		changed := base
		mutate(&changed)
		if _, err := validateGemRerollRun(changed, request, nil); !errors.Is(err, ErrInvalidCommand) {
			t.Fatalf("invalid run accepted: %+v %v", changed, err)
		}
	}
}

func TestLegacyReceiptDoesNotAdvertiseUnsupportedRerollVersion(t *testing.T) {
	raw := []byte(`{"economy":{"wallet":{"freeDiamonds":10,"paidDiamonds":0,"moduleTickets":2}}}`)
	result, err := existingCommandResult[CommandResult](dbgen.EconomyCommand{RequestHash: []byte{1}, ResponsePayload: raw}, []byte{1})
	if err != nil {
		t.Fatal(err)
	}
	replay, err := json.Marshal(result)
	if err != nil || bytes.Contains(replay, []byte(`"gemRerollVersion"`)) {
		t.Fatalf("old receipt invented capability: %s %v", replay, err)
	}
}

func TestLinkedGuestRerollNeverRestoresFreeBudget(t *testing.T) {
	run := gemRewardRun{RunID: rerollTestRun, Phase: "reward", CompletedRounds: 5, Used: 1, Options: []string{"range", "chain", "explosion"}}
	request := GemRerollRequest{RunID: rerollTestRun, CompletedRounds: 5, ExpectedRerollCount: 1}
	used, err := validateGemRerollRun(run, request, nil)
	if err != nil || used != 1 {
		t.Fatalf("guest usage lost: %d %v", used, err)
	}
	request.ExpectedRerollCount = 0
	if _, err = validateGemRerollRun(run, request, nil); !errors.Is(err, ErrGemRerollConflict) {
		t.Fatalf("guest reset free budget: %v", err)
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
