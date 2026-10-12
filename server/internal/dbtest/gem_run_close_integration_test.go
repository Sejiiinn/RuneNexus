//go:build integration

package dbtest_test

import (
	"bytes"
	"encoding/json"
	"errors"
	"sync"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func (f *gemOfferFixture) closeRequest() economy.CloseRunRequest {
	base := f.offerRequest(5)
	return economy.CloseRunRequest{IdempotencyKey: base.IdempotencyKey, RawBody: base.RawBody,
		WriterGeneration: base.WriterGeneration, SourceSaveRevision: base.SourceSaveRevision,
		ExpectedRevision: base.ExpectedRevision, ExpectedCatalogVersion: base.ExpectedCatalogVersion, RunID: base.RunID}
}

// Requires a real pgx listener; compilation alone does not verify the race.
func TestConcurrentRunCloseAndGemChoiceRetainsClosedTombstone(t *testing.T) {
	for _, purchased := range []bool{false, true} {
		name := "wave"
		if purchased {
			name = "purchase"
		}
		t.Run(name, func(t *testing.T) {
			var f *gemOfferFixture
			var issued economy.CommandResult
			if purchased {
				f = openPurchasedGemFixture(t)
				var err error
				issued, err = f.service.PurchaseGems(f.ctx, f.account, f.save.sessionID, f.offerRequest(5))
				if err != nil {
					t.Fatal(err)
				}
				f.accept(issued)
			} else {
				f = openGemOfferFixture(t)
				issued = f.issue(5)
			}
			checkpoint := json.RawMessage(bytes.Clone(f.runFor(issued)))
			choose := f.chooseRequest(issued.GemOffer, issued.GemOffer.GemOptions[0])
			closeRequest := f.closeRequest()
			var chosen, closed economy.CommandResult
			var chooseErr, closeErr error
			start := make(chan struct{})
			var wg sync.WaitGroup
			wg.Add(2)
			go func() {
				defer wg.Done()
				<-start
				chosen, chooseErr = f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, choose)
			}()
			go func() {
				defer wg.Done()
				<-start
				closed, closeErr = f.service.CloseRun(f.ctx, f.account, f.save.sessionID, closeRequest)
			}()
			close(start)
			wg.Wait()
			if (chooseErr == nil) == (closeErr == nil) {
				t.Fatalf("exactly one stale-source contender must commit: choose=%v close=%v", chooseErr, closeErr)
			}
			if chooseErr == nil {
				if !errors.Is(closeErr, economy.ErrSaveRevisionConflict) {
					t.Fatalf("close loser: %v", closeErr)
				}
				f.accept(chosen)
				closeRequest = f.closeRequest()
				closed, closeErr = f.service.CloseRun(f.ctx, f.account, f.save.sessionID, closeRequest)
				if closeErr != nil {
					t.Fatal(closeErr)
				}
			} else if !errors.Is(chooseErr, economy.ErrSaveRevisionConflict) && !errors.Is(chooseErr, economy.ErrGemOfferConflict) {
				t.Fatalf("choice loser: %v", chooseErr)
			}
			if closed.Run == nil || closed.Run.Status != "closed" {
				t.Fatalf("close outcome: %+v", closed)
			}
			replayed, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, closeRequest)
			if err != nil {
				t.Fatal(err)
			}
			assertGemOfferJSONEqual(t, replayed, closed)
			if chooseErr == nil {
				replayed, err = f.service.ChooseGem(f.ctx, f.account, f.save.sessionID, choose)
				if err != nil {
					t.Fatal(err)
				}
				assertGemOfferJSONEqual(t, replayed, chosen)
			}
			f.economy, err = f.service.Get(f.ctx, f.account)
			if err != nil || f.economy.Run != nil || f.economy.GemOffer != nil || f.economy.GemReroll != nil {
				t.Fatalf("closed history leaked into current recovery: %+v %v", f.economy, err)
			}
			f.revision = closed.SaveRevision
			noop, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, f.closeRequest())
			if err != nil || noop.SaveRevision != closed.SaveRevision || noop.GemReceipt.EconomyRevision != closed.GemReceipt.EconomyRevision {
				t.Fatalf("fresh-key recovery mutated closed run: %+v %v", noop, err)
			}
			if err = f.saveRun(checkpoint); !errors.Is(err, gamesave.ErrGemOfferConflict) {
				t.Fatalf("old pending checkpoint resurrected tombstone: %v", err)
			}
			saved, err := f.save.Get(f.ctx, f.account)
			if err != nil || (len(saved.Data.ActiveRun) != 0 && string(saved.Data.ActiveRun) != "null") || saved.Revision != closed.SaveRevision {
				t.Fatalf("current checkpoint reopened: %+v %v", saved, err)
			}
			var closeCount int
			if err = f.save.pool.QueryRow(f.ctx, `SELECT count(*) FROM economy_commands WHERE account_id=$1 AND command_type='run_close'`, f.account).Scan(&closeCount); err != nil || closeCount != 1 {
				t.Fatalf("no-op/failed close created receipts: %d %v", closeCount, err)
			}
		})
	}
}
