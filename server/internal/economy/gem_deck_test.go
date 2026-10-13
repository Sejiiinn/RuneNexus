package economy

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"slices"
	"strconv"
	"testing"
)

const deckTestRun = "0198b955-3656-7c40-b3cb-87f427b90be7"

func testDeck(t *testing.T) *GemDeck {
	t.Helper()
	deck, err := generateGemDeck(rand.Reader, deckTestRun, gemTypes)
	if err != nil || deck == nil {
		t.Fatalf("generate deck: %v %v", deck, err)
	}
	return deck
}

func TestGemDeckChainsExcludeTheImmediatePreviousCandidates(t *testing.T) {
	deck := testDeck(t)
	if len(deck.Waves) != 7 || len(deck.Purchases) != gemDeckPurchaseCount {
		t.Fatalf("deck shape: %d waves %d purchases", len(deck.Waves), len(deck.Purchases))
	}
	ids := map[string]bool{}
	for wave := gemDeckFirstWave; wave <= gemDeckLastWave; wave += 5 {
		entry := deck.Waves[strconv.Itoa(wave)]
		if len(entry.Options) != gemDeckRerollDepth+1 || ids[entry.OfferID] {
			t.Fatalf("wave %d: %+v", wave, entry)
		}
		ids[entry.OfferID] = true
		for k, options := range entry.Options {
			if !validDeckOptions(options) {
				t.Fatalf("invalid options %v", options)
			}
			if k > 0 {
				for _, gem := range options {
					if slices.Contains(entry.Options[k-1], gem) {
						t.Fatalf("reroll %d repeats %s", k, gem)
					}
				}
			}
		}
	}
	for _, entry := range deck.Purchases {
		if ids[entry.OfferID] || !validDeckOptions(entry.Options) {
			t.Fatalf("purchase %+v", entry)
		}
		ids[entry.OfferID] = true
	}
	raw, _ := json.Marshal(deck)
	parsed, err := parseGemDeck(raw)
	if err != nil {
		t.Fatal(err)
	}
	id, options, ok := parsed.waveOffer(10, 2)
	if !ok || id != deck.Waves["10"].OfferID || !slices.Equal(options, deck.Waves["10"].Options[2]) {
		t.Fatal("wave lookup")
	}
	if _, _, ok = parsed.waveOffer(10, 4); ok {
		t.Fatal("reroll beyond the run budget")
	}
	if _, _, ok = parsed.waveOffer(40, 0); ok {
		t.Fatal("final wave has no offer")
	}
	if _, _, ok = parsed.purchase(0); ok {
		t.Fatal("purchase sequences start at one")
	}
}

func TestGemDeckFallsBackWhenTooFewGemsAreUnlocked(t *testing.T) {
	deck, err := generateGemDeck(rand.Reader, deckTestRun, gemTypes[:2])
	if err != nil || deck != nil {
		t.Fatalf("offerless deck: %v %v", deck, err)
	}
	// Five gems allow first offers but no disjoint reroll.
	deck, err = generateGemDeck(rand.Reader, deckTestRun, gemTypes[:5])
	if err != nil || deck == nil || len(deck.Waves["5"].Options) != 1 {
		t.Fatalf("short chain: %+v %v", deck, err)
	}
	if _, err = generateGemDeck(bytes.NewReader(make([]byte, 8)), deckTestRun, gemTypes); err == nil {
		t.Fatal("entropy failure ignored")
	}
}

func TestParseGemDeckRejectsMalformedRows(t *testing.T) {
	for _, raw := range []string{
		`{"version":2,"runId":"` + deckTestRun + `","waves":{},"purchases":[]}`,
		`{"version":1,"runId":"x","waves":{},"purchases":[]}`,
		`{"version":1,"runId":"` + deckTestRun + `","waves":{"7":{"offerId":"` + deckTestRun + `","options":[["range","chain","explosion"]]}},"purchases":[]}`,
		`{"version":1,"runId":"` + deckTestRun + `","waves":{"5":{"offerId":"` + deckTestRun + `","options":[["range","range","explosion"]]}},"purchases":[]}`,
		`{"version":1,"runId":"` + deckTestRun + `","waves":{},"purchases":[{"offerId":"` + deckTestRun + `","options":["range","chain"]}]}`,
	} {
		if _, err := parseGemDeck([]byte(raw)); err == nil {
			t.Fatalf("accepted %s", raw)
		}
	}
	if deck, err := parseGemDeck(nil); deck != nil || err != nil {
		t.Fatal("legacy runs have no deck")
	}
}

func TestReplayGemDeckLogFollowsTheDeck(t *testing.T) {
	deck := testDeck(t)
	five, ten := deck.Waves["5"].Options, deck.Waves["10"].Options
	purchase := deck.Purchases[0].Options
	// Wave 5 rerolled once then took shards; purchase 1 was equipped; wave 10
	// is pending after one more reroll.
	base := func() map[string]any {
		return map[string]any{
			"phase": "reward", "gemRerollsUsed": 2, "rewardOptions": ten[1],
			"gemInventory": map[string]any{},
			"turrets":      []any{map[string]any{"type": "arrow", "slotLimit": 2, "equippedGemSlots": []any{purchase[1], nil}}},
			"gemDeckLog": []any{
				map[string]any{"kind": "wave", "wave": 5, "rerolls": 1, "choice": "shards"},
				map[string]any{"kind": "purchase", "sequence": 1, "choice": purchase[1]},
				map[string]any{"kind": "wave", "wave": 10, "rerolls": 1, "choice": ""},
			},
		}
	}
	replay := func(run map[string]any) (int64, bool) {
		raw, _ := json.Marshal(run)
		return replayGemDeckLog(deck, raw)
	}
	if rerolls, ok := replay(base()); rerolls != 2 || !ok {
		t.Fatalf("consistent replay: %d %v", rerolls, ok)
	}
	chosen := base()
	chosen["gemDeckLog"].([]any)[0].(map[string]any)["choice"] = five[1][0]
	chosen["gemInventory"] = map[string]any{five[1][0]: 1}
	if _, ok := replay(chosen); !ok {
		t.Fatal("recorded wave gem rejected")
	}
	outside := ""
	for _, gem := range gemTypes {
		if !slices.Contains(five[1], gem) && gem != purchase[1] {
			outside = gem
			break
		}
	}
	for name, tamper := range map[string]func(map[string]any){
		"choice outside candidates": func(run map[string]any) {
			run["gemDeckLog"].([]any)[0].(map[string]any)["choice"] = outside
			run["gemInventory"] = map[string]any{outside: 1}
		},
		"unrecorded gem":       func(run map[string]any) { run["gemInventory"] = map[string]any{outside: 1} },
		"skipped reroll":       func(run map[string]any) { run["rewardOptions"] = ten[0] },
		"reroll count":         func(run map[string]any) { run["gemRerollsUsed"] = 1 },
		"purchase sequence":    func(run map[string]any) { run["gemDeckLog"].([]any)[1].(map[string]any)["sequence"] = 2 },
		"repeated wave":        func(run map[string]any) { run["gemDeckLog"].([]any)[2].(map[string]any)["wave"] = 5 },
		"pending before last":  func(run map[string]any) { run["gemDeckLog"].([]any)[0].(map[string]any)["choice"] = "" },
		"purchase shard grant": func(run map[string]any) { run["gemDeckLog"].([]any)[1].(map[string]any)["choice"] = "shards" },
	} {
		run := base()
		tamper(run)
		if _, ok := replay(run); ok {
			t.Fatalf("%s accepted", name)
		}
	}
	if gemRerollCost(0) != 0 || gemRerollCost(1) != 0 || gemRerollCost(3) != 2 {
		t.Fatal("first reroll of a run is free")
	}
}
