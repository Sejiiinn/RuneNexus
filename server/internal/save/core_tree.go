package save

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"math"

	"github.com/Sejiiinn/RuneNexus/server/internal/coretree"
)

const CoreTreeClientCompatibilityVersion = 10

var ErrCoreTreeConflict = errors.New("core tree allocation or frozen run state is invalid")

type legacyCoreAllocation struct {
	Revision       int            `json:"revision"`
	Ranks          map[string]int `json:"ranks"`
	RefundedPoints int            `json:"refundedPoints"`
}

type coreProgression struct {
	Revision int                   `json:"corePassiveTreeRevision"`
	Ranks    map[string]int         `json:"corePassiveNodeRanks"`
	Points   int                   `json:"totalCorePoints"`
	NexusHPUpgrade int `json:"nexusHpUpgradeLevel"`
	Legacy   *legacyCoreAllocation `json:"corePassiveLegacyAllocation"`
}

type coreRun struct {
	ID       string         `json:"economyRunId"`
	Stage    int            `json:"stageNumber"`
	Phase    string         `json:"phase"`
	Revision *int           `json:"runCorePassiveTreeRevision"`
	Ranks    map[string]int  `json:"runCorePassiveNodeRanks"`
	Fields   map[string]json.RawMessage `json:"-"`
}

func decodeCoreProgression(raw []byte) (coreProgression, error) {
	p := coreProgression{Revision: 4}
	if len(raw) == 0 {
		return p, nil
	}
	if err := json.Unmarshal(raw, &p); err != nil {
		return p, ErrCoreTreeConflict
	}
	var fields map[string]json.RawMessage
	if json.Unmarshal(raw, &fields) != nil || fields == nil { return p, ErrCoreTreeConflict }
	for _, key := range []string{"corePassiveTreeRevision", "corePassiveNodeRanks", "totalCorePoints"} {
		if value, present := fields[key]; present && bytes.Equal(bytes.TrimSpace(value), []byte("null")) { return p, ErrCoreTreeConflict }
	}
	if rawRanks, present := fields["corePassiveNodeRanks"]; present {
		if err := validateCoreRankWire(rawRanks); err != nil { return p, err }
	}
	if p.Revision == coretree.CurrentRevision && p.Ranks == nil { return p, ErrCoreTreeConflict }
	if p.Revision < 0 || p.Revision > coretree.CurrentRevision || p.Points < 0 {
		return p, ErrCoreTreeConflict
	}
	if p.Legacy != nil {
		var archive map[string]json.RawMessage
		if json.Unmarshal(fields["corePassiveLegacyAllocation"], &archive) != nil || validateCoreRankWire(archive["ranks"]) != nil { return p, ErrCoreTreeConflict }
		spent, err := coretree.SpentPoints(p.Legacy.Revision, p.Legacy.Ranks)
		if p.Legacy.Revision < 0 || p.Legacy.Revision > 4 || p.Legacy.Ranks == nil || err != nil || spent != p.Legacy.RefundedPoints {
			return p, ErrCoreTreeConflict
		}
		if p.Revision >= coretree.CurrentRevision && coretree.ValidateAllocation(p.Legacy.Revision, p.Legacy.Ranks, p.Points) != nil { return p, ErrCoreTreeConflict }
	}
	return p, nil
}

func decodeCoreRun(raw []byte) (*coreRun, error) {
	if len(bytes.TrimSpace(raw)) == 0 || bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return nil, nil
	}
	var run coreRun
	if json.Unmarshal(raw, &run) != nil || json.Unmarshal(raw, &run.Fields) != nil || run.Fields == nil {
		return nil, ErrCoreTreeConflict
	}
	if rawRanks, present := run.Fields["runCorePassiveNodeRanks"]; present {
		if err := validateCoreRankWire(rawRanks); err != nil { return nil, err }
	}
	if rawRevision, present := run.Fields["runCorePassiveTreeRevision"]; present && bytes.Equal(bytes.TrimSpace(rawRevision), []byte("null")) { return nil, ErrCoreTreeConflict }
	return &run, nil
}

func validateCoreRankWire(raw json.RawMessage) error {
	var ranks map[string]json.RawMessage
	if json.Unmarshal(raw, &ranks) != nil || ranks == nil { return ErrCoreTreeConflict }
	for _, rawRank := range ranks {
		var rank int
		if bytes.Equal(bytes.TrimSpace(rawRank), []byte("null")) || json.Unmarshal(rawRank, &rank) != nil { return ErrCoreTreeConflict }
	}
	return nil
}

func (run *coreRun) allocation(p coreProgression) (int, map[string]int) {
	revision, ranks := p.Revision, p.Ranks
	if run.Revision != nil {
		revision = *run.Revision
	}
	if run.Ranks != nil {
		ranks = run.Ranks
	}
	return revision, ranks
}

func coreRunTerminal(run *coreRun) bool {
	return run == nil || terminalPhase(run.Phase) || run.Phase == "coreDestruction"
}

// ValidateCoreTreeClient is content-based: revision-four runs remain resumable
// by generation nine, but an old codec cannot acquire/write a migrated account.
// It never changes bytes, so historical exact-body receipts remain recoverable.
func ValidateCoreTreeClient(progression, activeRun []byte, client int) error {
	if client >= CoreTreeClientCompatibilityVersion {
		return nil
	}
	var p struct {
		Revision int `json:"corePassiveTreeRevision"`
		Ranks map[string]json.RawMessage `json:"corePassiveNodeRanks"`
	}
	if json.Unmarshal(progression, &p) == nil {
		if p.Revision >= coretree.CurrentRevision || hasExpandedCoreRanks(p.Ranks) {
			return ErrClientUpdateRequired
		}
	}
	var run map[string]json.RawMessage
	if json.Unmarshal(activeRun, &run) == nil {
		var revision int
		_ = json.Unmarshal(run["runCorePassiveTreeRevision"], &revision)
		var ranks map[string]json.RawMessage
		_ = json.Unmarshal(run["runCorePassiveNodeRanks"], &ranks)
		if revision >= coretree.CurrentRevision || hasExpandedCoreRanks(ranks) {
			return ErrClientUpdateRequired
		}
		for _, key := range []string{"nexusAdditionalHp", "nexusAdditionalHpGranted", "indomitableUsedThisStage", "nexusInvulnerableRemaining"} {
			if _, ok := run[key]; ok { return ErrClientUpdateRequired }
		}
		for _, collection := range []string{"turrets", "enemies"} {
			var rows []map[string]json.RawMessage
			_ = json.Unmarshal(run[collection], &rows)
			for _, row := range rows {
				for _, key := range []string{"stockpileCharges", "firstControlApplied", "stunRemaining", "freezeRemaining"} {
					if _, ok := row[key]; ok { return ErrClientUpdateRequired }
				}
			}
		}
	}
	return nil
}

func hasExpandedCoreRanks(ranks map[string]json.RawMessage) bool {
	for id := range ranks {
		if _, ok := coretree.Catalogs[coretree.CurrentRevision].Nodes[id]; ok { return true }
	}
	return false
}

// ValidateCoreTreeUpdate runs under the save lock, after exact receipt lookup.
// Missing legacy fields are interpreted for validation only, never rewritten.
func ValidateCoreTreeUpdate(currentProgression, currentRun, incomingProgression, incomingRun []byte, client int) error {
	if err := ValidateCoreTreeClient(currentProgression, currentRun, client); err != nil { return err }
	if err := ValidateCoreTreeClient(incomingProgression, incomingRun, client); err != nil { return err }
	before, err := decodeCoreProgression(currentProgression)
	if err != nil { return err }
	after, err := decodeCoreProgression(incomingProgression)
	if err != nil { return err }
	if len(currentProgression) > 0 && after.Revision < before.Revision { return ErrClientUpdateRequired }
	if err := coretree.ValidateAllocation(after.Revision, after.Ranks, after.Points); err != nil { return fmt.Errorf("%w: %v", ErrCoreTreeConflict, err) }
	oldRun, err := decodeCoreRun(currentRun)
	if err != nil { return err }
	newRun, err := decodeCoreRun(incomingRun)
	if err != nil { return err }
	migrating := before.Revision < coretree.CurrentRevision && after.Revision == coretree.CurrentRevision && len(currentProgression) > 0
	if migrating {
		// Finishing a legacy run may migrate the account while retaining that
		// terminal run's old frozen allocation. A suspended run cannot migrate.
		if !coreRunTerminal(oldRun) && !coreRunTerminal(newRun) { return ErrCoreTreeConflict }
		if oldRun != nil && !coreRunTerminal(oldRun) && newRun == nil { return ErrCoreTreeConflict }
		if after.Legacy == nil || after.Legacy.Revision != before.Revision || after.Points < before.Points { return ErrCoreTreeConflict }
		// Outbox coalescing can include legitimate stage/quest point earnings,
		// an unsynced legacy allocation, and the first new allocation. Points
		// retain their existing client-reported authority; migration does not
		// add refundedPoints to that total or introduce a new earnings policy.
		if err := coretree.ValidateAllocation(after.Legacy.Revision, after.Legacy.Ranks, after.Points); err != nil { return ErrCoreTreeConflict }
	} else if before.Revision >= coretree.CurrentRevision && !equalLegacyCoreAllocation(before.Legacy, after.Legacy) {
		return ErrCoreTreeConflict
	}
	if newRun == nil { return nil }
	revision, ranks := newRun.allocation(after)
	if revision >= coretree.CurrentRevision && (newRun.Revision == nil || newRun.Ranks == nil) { return ErrCoreTreeConflict }
	if err := validateCoreRunFields(newRun.Fields, revision, ranks, after.NexusHPUpgrade); err != nil { return err }
	if err := coretree.ValidateAllocation(revision, ranks, after.Points); err != nil { return fmt.Errorf("%w: %v", ErrCoreTreeConflict, err) }
	if oldRun != nil && oldRun.ID == newRun.ID && oldRun.Stage == newRun.Stage {
		oldRevision, oldRanks := oldRun.allocation(before)
		if oldRevision != revision || (oldRun.Ranks != nil && !equalCoreRanks(oldRanks, ranks)) { return ErrCoreTreeConflict }
		// Pre-snapshot legacy saves may acquire their first frozen copy. Once
		// recorded it is immutable, including in terminal history.
		if oldRevision >= coretree.CurrentRevision && !equalCoreRanks(oldRanks, ranks) { return ErrCoreTreeConflict }
		return validateCoreRunMonotonicFields(oldRun.Fields, newRun.Fields)
	}
	if after.Revision >= coretree.CurrentRevision {
		if newRun.Revision == nil || newRun.Ranks == nil || revision != after.Revision || !equalCoreRanks(ranks, after.Ranks) { return ErrCoreTreeConflict }
	}
	return nil
}

// ValidateCoreTreeRunStart protects the exact allocation frozen by a new run.
func ValidateCoreTreeRunStart(progression, activeRun []byte, client int) error {
	if err := ValidateCoreTreeClient(progression, activeRun, client); err != nil { return err }
	p, err := decodeCoreProgression(progression)
	if err != nil { return err }
	run, err := decodeCoreRun(activeRun)
	if err != nil || run == nil { return ErrCoreTreeConflict }
	revision, ranks := run.allocation(p)
	if err := coretree.ValidateAllocation(p.Revision, p.Ranks, p.Points); err != nil { return ErrCoreTreeConflict }
	if revision != p.Revision || !equalCoreRanks(ranks, p.Ranks) { return ErrCoreTreeConflict }
	if p.Revision >= coretree.CurrentRevision && (run.Revision == nil || run.Ranks == nil) { return ErrCoreTreeConflict }
	return validateCoreRunFields(run.Fields, revision, ranks, p.NexusHPUpgrade)
}

// Codecs omit zero ranks. Their presence cannot turn an unchanged frozen
// allocation into a mutation, and validation still rejects unknown node IDs.
func equalCoreRanks(a, b map[string]int) bool {
	for id, rank := range a { if b[id] != rank { return false } }
	for id, rank := range b { if a[id] != rank { return false } }
	return true
}

func equalLegacyCoreAllocation(a, b *legacyCoreAllocation) bool {
	if a == nil || b == nil { return a == b }
	return a.Revision == b.Revision && a.RefundedPoints == b.RefundedPoints && equalCoreRanks(a.Ranks, b.Ranks)
}

func validateCoreRunFields(fields map[string]json.RawMessage, revision int, ranks map[string]int, nexusHPUpgrade int) error {
	var invulnerable, additionalHP float64
	var used, granted bool
	_ = json.Unmarshal(fields["nexusInvulnerableRemaining"], &invulnerable)
	_ = json.Unmarshal(fields["nexusAdditionalHp"], &additionalHP)
	_ = json.Unmarshal(fields["indomitableUsedThisStage"], &used)
	_ = json.Unmarshal(fields["nexusAdditionalHpGranted"], &granted)
	if used && (revision != coretree.CurrentRevision || ranks["K8"] <= 0) { return ErrCoreTreeConflict }
	if invulnerable > 0 && (revision != coretree.CurrentRevision || ranks["K8"] <= 0 || !used) { return ErrCoreTreeConflict }
	if additionalHP > 0 && (revision != coretree.CurrentRevision || ranks["C12"] <= 0 || !granted) { return ErrCoreTreeConflict }
	// The generated C12 rank rates use unmodified stage HP. Core max-HP
	// multipliers do not amplify this nonrecoverable pool. Match the client's
	// serialization tolerance without duplicating catalog balance constants.
	baseHP := coretree.BaseNexusHP + float64(max(0, min(coretree.MaxNexusHPUpgradeLevel, nexusHPUpgrade)))
	rate := coretree.AdditionalHPRate(ranks["C12"])
	if additionalHP > baseHP * rate + 0.000001 { return ErrCoreTreeConflict }
	for _, key := range []string{"nexusAdditionalHp", "nexusInvulnerableRemaining"} {
		if raw, present := fields[key]; present {
			var value float64
			if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) || json.Unmarshal(raw, &value) != nil || math.IsNaN(value) || math.IsInf(value, 0) || value < 0 || (key == "nexusInvulnerableRemaining" && value > 3) { return ErrCoreTreeConflict }
		}
	}
	for _, key := range []string{"nexusAdditionalHpGranted", "indomitableUsedThisStage"} {
		if err := validateOptionalBool(fields, key); err != nil { return err }
	}
	for _, collection := range []string{"turrets", "enemies"} {
		var rows []map[string]json.RawMessage
		if raw, present := fields[collection]; present && json.Unmarshal(raw, &rows) != nil { return ErrCoreTreeConflict }
		for _, row := range rows {
			if collection == "turrets" {
				if raw, present := row["level"]; present && revision >= coretree.CurrentRevision {
					var level int
					maximum := 10
					if ranks["K5"] > 0 { maximum++ }
					if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) || json.Unmarshal(raw, &level) != nil || level < 1 || level > maximum { return ErrCoreTreeConflict }
				}
				if raw, present := row["stockpileCharges"]; present {
					var value int
					if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) || json.Unmarshal(raw, &value) != nil || value < 0 || value > 2 || (value > 0 && (revision != coretree.CurrentRevision || ranks["K2"] <= 0)) { return ErrCoreTreeConflict }
				}
			} else {
				if err := validateOptionalBool(row, "firstControlApplied"); err != nil { return err }
				for _, key := range []string{"stunRemaining", "freezeRemaining"} {
					if raw, present := row[key]; present {
						var value float64
						if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) || json.Unmarshal(raw, &value) != nil || math.IsNaN(value) || math.IsInf(value, 0) || value < 0 { return ErrCoreTreeConflict }
					}
				}
			}
		}
	}
	return nil
}

func validateOptionalBool(fields map[string]json.RawMessage, key string) error {
	if raw, present := fields[key]; present {
		var value bool
		if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) || json.Unmarshal(raw, &value) != nil { return ErrCoreTreeConflict }
	}
	return nil
}

func validateCoreRunMonotonicFields(before, after map[string]json.RawMessage) error {
	// Stage-only grants/second-chance use must survive suspension and resumes.
	for _, key := range []string{"nexusAdditionalHpGranted", "indomitableUsedThisStage"} {
		var oldValue, newValue bool
		_ = json.Unmarshal(before[key], &oldValue)
		_ = json.Unmarshal(after[key], &newValue)
		if oldValue && !newValue { return ErrCoreTreeConflict }
		if oldValue {
			pool := "nexusAdditionalHp"
			if key == "indomitableUsedThisStage" { pool = "nexusInvulnerableRemaining" }
			var previous, next float64
			if raw, present := before[pool]; present && json.Unmarshal(raw, &previous) == nil {
				if raw, present := after[pool]; !present || json.Unmarshal(raw, &next) != nil || next > previous { return ErrCoreTreeConflict }
			}
		}
	}
	return nil
}
