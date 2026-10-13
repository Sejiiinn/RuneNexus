package save

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/Sejiiinn/RuneNexus/server/internal/runstate"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

const RunAuthorityClientCompatibilityVersion = 9

// Ordinary saves cannot create, close or resurrect a server-issued run. The
// sole pre-start exception is a pristine full checkpoint with no client ID.
func validateRunSave(ctx context.Context, q *dbgen.Queries, account pgtype.UUID, current, incoming []byte) error {
	row, err := q.GetActiveEconomyRunForUpdate(ctx, account)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	if noActiveRun(incoming) {
		if err == nil {
			return ErrGemOfferConflict
		}
		return nil
	}
	var run struct {
		ID    string `json:"economyRunId"`
		Stage int32  `json:"stageNumber"`
		Used  int32  `json:"gemRerollsUsed"`
		Phase string `json:"phase"`
	}
	if json.Unmarshal(incoming, &run) != nil {
		return ErrGemOfferConflict
	}
	var previousPhase struct {
		ID    string `json:"economyRunId"`
		Phase string `json:"phase"`
	}
	if json.Unmarshal(current, &previousPhase) == nil && previousPhase.ID == run.ID && terminalPhase(previousPhase.Phase) && previousPhase.Phase != run.Phase {
		return ErrGemOfferConflict
	}
	if errors.Is(err, pgx.ErrNoRows) {
		if run.ID == "" {
			// Explicit close must clear a previous terminal checkpoint first.
			var previous struct {
				ID string `json:"economyRunId"`
			}
			_ = json.Unmarshal(current, &previous)
			if previous.ID != "" || run.Stage > CurrentStageCount || runstate.ValidatePristine(incoming, run.Stage) != nil {
				return ErrGemOfferConflict
			}
			return nil
		}
		id, idErr := runstate.ParseUUID(run.ID)
		if idErr != nil {
			return ErrGemOfferConflict
		}
		row, err = q.GetEconomyRunForUpdate(ctx, dbgen.GetEconomyRunForUpdateParams{AccountID: account, RunID: id})
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrGemOfferConflict
		}
		if err != nil {
			return err
		}
		var previous struct {
			ID    string `json:"economyRunId"`
			Phase string `json:"phase"`
		}
		if json.Unmarshal(current, &previous) != nil || previous.ID != run.ID || row.Status != "closed" || !terminalPhase(previous.Phase) || run.Phase != previous.Phase {
			return ErrGemOfferConflict
		}
	}
	id, idErr := runstate.ParseUUID(run.ID)
	if idErr != nil || id != row.RunID || run.Stage != row.StageNumber {
		return ErrGemOfferConflict
	}
	if len(row.GemDeck) > 0 {
		// Deck runs record their reward history in the checkpoint itself. It is
		// replayed against the issued deck when the run closes, not per upload.
		return nil
	}
	if run.Used != row.TotalUsed {
		return ErrGemOfferConflict
	}
	state, err := runstate.FromRow(row)
	if err != nil {
		return ErrGemOfferConflict
	}
	if runstate.ValidateOwnership(incoming, state.OwnedGems) != nil {
		return ErrGemOfferConflict
	}
	return nil
}

func terminalPhase(phase string) bool { return phase == "success" || phase == "failure" }
func noActiveRun(raw []byte) bool     { return len(raw) == 0 || string(raw) == "null" }
