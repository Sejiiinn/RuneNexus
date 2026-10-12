package save

import "github.com/Sejiiinn/RuneNexus/server/internal/runstate"

// Kept only for pre-adoption generation-eight compatibility. Generation nine
// always validates equality with the run aggregate in validateRunSave. Both
// versions use the same isolated allocation parser, avoiding codec drift.
func validateGemOwnershipFloor(raw []byte, grants map[string]int64) error {
	if len(grants) == 0 {
		return nil
	}
	for gem, count := range grants {
		if !runstate.ValidGem(gem) || count <= 0 {
			return ErrGemOfferConflict
		}
	}
	owned, err := runstate.ReadOwnedGems(raw)
	if err != nil {
		return ErrGemOfferConflict
	}
	for gem, count := range grants {
		if owned[gem] < count {
			return ErrGemOfferConflict
		}
	}
	return nil
}
