package economy

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"maps"
	"slices"
	"strconv"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/Sejiiinn/RuneNexus/server/internal/runstate"
	"github.com/jackc/pgx/v5/pgtype"
)

const (
	GemDeckVersion = 1
	// Generation ten presents deck candidates locally and confirms them through
	// /v1/economy/gems/deck/* without synchronizing the save first.
	GemDeckClientCompatibilityVersion = 10
	// Wave offers exist for completed rounds 5..35. Each chain holds the first
	// candidates plus one entry per reroll; the run budget caps rerolls at three.
	gemDeckFirstWave     = 5
	gemDeckLastWave      = 35
	gemDeckRerollDepth   = 3
	gemDeckPurchaseCount = 24
)

// GemDeckWave is the full pre-committed chain of one wave offer. Options[k] is
// presented after k rerolls of that offer (offer revision k+1).
type GemDeckWave struct {
	OfferID string     `json:"offerId"`
	Options [][]string `json:"options"`
}

type GemDeckEntry struct {
	OfferID string   `json:"offerId"`
	Options []string `json:"options"`
}

// GemDeck is issued once per run start. Commands consume exactly these rows, so
// a client may present them before its confirmation reaches the server.
type GemDeck struct {
	Version   int                    `json:"version"`
	RunID     string                 `json:"runId"`
	Waves     map[string]GemDeckWave `json:"waves"`
	Purchases []GemDeckEntry         `json:"purchases"`
}

func generateGemDeck(random io.Reader, runID string, available []string) (*GemDeck, error) {
	deck := &GemDeck{Version: GemDeckVersion, RunID: runID, Waves: map[string]GemDeckWave{}, Purchases: []GemDeckEntry{}}
	for wave := gemDeckFirstWave; wave <= gemDeckLastWave; wave += 5 {
		first, err := sampleGems(random, available, nil)
		if errors.Is(err, ErrInvalidCommand) {
			// Too few unlocked gems for any offer; such runs keep the legacy path.
			return nil, nil
		}
		if err != nil {
			return nil, err
		}
		chain := [][]string{first}
		for len(chain) <= gemDeckRerollDepth {
			next, err := sampleGems(random, available, chain[len(chain)-1])
			if errors.Is(err, ErrInvalidCommand) {
				break
			}
			if err != nil {
				return nil, err
			}
			chain = append(chain, next)
		}
		id, err := gemUUIDFrom(random)
		if err != nil {
			return nil, err
		}
		deck.Waves[strconv.Itoa(wave)] = GemDeckWave{OfferID: formatUUID(id), Options: chain}
	}
	for range gemDeckPurchaseCount {
		options, err := sampleGems(random, available, nil)
		if err != nil {
			return nil, err
		}
		id, err := gemUUIDFrom(random)
		if err != nil {
			return nil, err
		}
		deck.Purchases = append(deck.Purchases, GemDeckEntry{OfferID: formatUUID(id), Options: options})
	}
	return deck, nil
}

func parseGemDeck(raw []byte) (*GemDeck, error) {
	if len(raw) == 0 || string(raw) == "null" {
		return nil, nil
	}
	var deck GemDeck
	if json.Unmarshal(raw, &deck) != nil || deck.Version != GemDeckVersion || deck.Waves == nil || deck.Purchases == nil {
		return nil, ErrGemOfferConflict
	}
	if _, err := parseUUID(deck.RunID); err != nil {
		return nil, ErrGemOfferConflict
	}
	for key, wave := range deck.Waves {
		number, err := strconv.Atoi(key)
		if err != nil || strconv.Itoa(number) != key || number < gemDeckFirstWave || number > gemDeckLastWave || number%5 != 0 {
			return nil, ErrGemOfferConflict
		}
		if _, err = parseUUID(wave.OfferID); err != nil || len(wave.Options) == 0 || len(wave.Options) > gemDeckRerollDepth+1 {
			return nil, ErrGemOfferConflict
		}
		for _, options := range wave.Options {
			if !validDeckOptions(options) {
				return nil, ErrGemOfferConflict
			}
		}
	}
	for _, entry := range deck.Purchases {
		if _, err := parseUUID(entry.OfferID); err != nil || !validDeckOptions(entry.Options) {
			return nil, ErrGemOfferConflict
		}
	}
	return &deck, nil
}

func validDeckOptions(options []string) bool {
	if len(options) != 3 {
		return false
	}
	for i, gem := range options {
		if !contains(gemTypes, gem) || slices.Contains(options[:i], gem) {
			return false
		}
	}
	return true
}

// waveOffer returns the offer ID and candidates shown after `rerolls` rerolls.
func (deck *GemDeck) waveOffer(wave int, rerolls int64) (string, []string, bool) {
	if deck == nil || rerolls < 0 {
		return "", nil, false
	}
	entry, ok := deck.Waves[strconv.Itoa(wave)]
	if !ok || rerolls >= int64(len(entry.Options)) {
		return "", nil, false
	}
	return entry.OfferID, slices.Clone(entry.Options[rerolls]), true
}

func (deck *GemDeck) purchase(sequence int64) (string, []string, bool) {
	if deck == nil || sequence < 1 || sequence > int64(len(deck.Purchases)) {
		return "", nil, false
	}
	entry := deck.Purchases[sequence-1]
	return entry.OfferID, slices.Clone(entry.Options), true
}

func gemUUIDFrom(random io.Reader) (pgtype.UUID, error) {
	id := pgtype.UUID{Valid: true}
	if _, err := io.ReadFull(random, id.Bytes[:]); err != nil {
		return pgtype.UUID{}, err
	}
	id.Bytes[6] = (id.Bytes[6] & 0x0f) | 0x40
	id.Bytes[8] = (id.Bytes[8] & 0x3f) | 0x80
	return id, nil
}

type gemDeckLogEntry struct {
	Kind     string `json:"kind"`
	Wave     int    `json:"wave"`
	Sequence int64  `json:"sequence"`
	Rerolls  int64  `json:"rerolls"`
	Choice   string `json:"choice"`
}

type gemDeckRun struct {
	Phase   string            `json:"phase"`
	Used    int64             `json:"gemRerollsUsed"`
	Options []string          `json:"rewardOptions"`
	Log     []gemDeckLogEntry `json:"gemDeckLog"`
}

// replayGemDeckLog reconstructs a deck run from its checkpoint log: every
// presented candidate set, choice and owned gem must follow from the deck,
// less the gems support cores consumed. It
// reports the recorded reroll count and whether the checkpoint is consistent.
// Inconsistency is evidence for later review; this function takes no action.
func replayGemDeckLog(deck *GemDeck, activeRun []byte) (int64, bool) {
	var run gemDeckRun
	if deck == nil || json.Unmarshal(activeRun, &run) != nil {
		return 0, false
	}
	consistent := true
	rerolls, lastWave, nextPurchase := int64(0), 0, int64(1)
	granted := map[string]int64{}
	var pending []string
	for index, entry := range run.Log {
		if entry.Kind == "consume" {
			// A support core spent one gem the run already owned (generation 14).
			if entry.Wave != 0 || entry.Sequence != 0 || entry.Rerolls != 0 || granted[entry.Choice] <= 0 {
				consistent = false
			} else if granted[entry.Choice]--; granted[entry.Choice] == 0 {
				delete(granted, entry.Choice)
			}
			continue
		}
		var options []string
		var ok bool
		switch entry.Kind {
		case "wave":
			if entry.Wave <= lastWave {
				consistent = false
			}
			lastWave = entry.Wave
			_, options, ok = deck.waveOffer(entry.Wave, entry.Rerolls)
			rerolls += max(entry.Rerolls, 0)
		case "purchase":
			if entry.Sequence != nextPurchase || entry.Rerolls != 0 {
				consistent = false
			}
			nextPurchase = entry.Sequence + 1
			_, options, ok = deck.purchase(entry.Sequence)
		}
		if !ok {
			consistent = false
			continue
		}
		switch {
		case entry.Choice == "":
			if index != len(run.Log)-1 {
				consistent = false
			}
			pending = options
		case entry.Choice == "shards" && entry.Kind == "wave":
		case slices.Contains(options, entry.Choice):
			granted[entry.Choice]++
		default:
			consistent = false
		}
	}
	if rerolls > gemDeckRerollDepth || rerolls != run.Used {
		consistent = false
	}
	if run.Phase == "reward" && (pending == nil || !slices.Equal(pending, run.Options)) {
		consistent = false
	}
	if owned, err := runstate.ReadOwnedGems(activeRun); err != nil || !maps.Equal(owned, granted) {
		consistent = false
	}
	return rerolls, consistent
}

// The first reroll of a run is free; every later one spends a reset ticket.
func gemRerollCost(used int64) int64 {
	return max(used-1, 0)
}

// chargeDeckRerolls debits, once while closing a deck run, the reset tickets
// for the rerolls its final checkpoint recorded. The balance never goes below
// zero; a shortfall is left to the same later review as replay inconsistency.
func chargeDeckRerolls(ctx context.Context, q *dbgen.Queries, account pgtype.UUID, deckRaw, activeRun []byte, tickets int64, commandID pgtype.UUID, order *int16) error {
	deck, err := parseGemDeck(deckRaw)
	if err != nil || deck == nil {
		return err
	}
	rerolls, _ := replayGemDeckLog(deck, activeRun)
	var run gemDeckRun
	_ = json.Unmarshal(activeRun, &run)
	debit := min(gemRerollCost(min(max(rerolls, run.Used), gemDeckRerollDepth)), tickets)
	if debit <= 0 {
		return nil
	}
	if err = q.SetGemResetTickets(ctx, dbgen.SetGemResetTicketsParams{AccountID: account, GemResetTickets: tickets - debit}); err != nil {
		return err
	}
	return createLedger(ctx, q, commandID, order, "gem_reset_ticket", -debit, tickets-debit, "gem_reroll")
}
