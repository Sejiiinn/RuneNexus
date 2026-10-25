//go:build integration

package dbtest_test

import (
	"errors"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func TestPiercingSchemaPreservesGemIdentities(t *testing.T) {
	ctx, tx, _ := openTestTransaction(t)
	for _, test := range []struct {
		raw  string
		want bool
	}{
		{`{"piercing":1,"armorPiercing":2}`, true},
		{`{"piercing":-1}`, false},
		{`{"Unknown Gem":1}`, false},
	} {
		var valid bool
		if err := tx.QueryRow(ctx, `SELECT valid_run_gem_totals($1::jsonb)`, test.raw).Scan(&valid); err != nil {
			t.Fatal(err)
		}
		if valid != test.want {
			t.Fatalf("%s: valid=%v want=%v", test.raw, valid, test.want)
		}
	}
	// Function dependencies must also work under pg_dump's empty search_path.
	if _, err := tx.Exec(ctx, `SET LOCAL search_path = ''`); err != nil {
		t.Fatal(err)
	}
	var valid bool
	if err := tx.QueryRow(ctx, `SELECT public.valid_run_gem_offer('{}'::jsonb)`).Scan(&valid); err != nil || valid {
		t.Fatalf("offer validation under empty search_path: %v %v", valid, err)
	}
}

func TestOldWriterCannotClosePiercingDeck(t *testing.T) {
	f, started, _ := openDeckRun(t)
	// Seed one new-content candidate into the otherwise legacy fixture deck.
	if _, err := f.save.pool.Exec(f.ctx, `UPDATE economy_runs SET gem_deck=jsonb_set(gem_deck,'{waves,5,options,0,0}','"piercing"'::jsonb) WHERE account_id=$1 AND run_id=$2`, f.account, started.Run.RunID); err != nil {
		t.Fatal(err)
	}
	request := economy.CloseRunRequest{
		IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":10}`), RunID: started.Run.RunID,
		WriterGeneration: f.save.writerGeneration, SourceSaveRevision: f.revision,
		ExpectedRevision: f.economy.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion,
	}
	if _, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, request); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("older valid writer closed piercing run: %v", err)
	}
	current, err := f.save.Get(f.ctx, f.account)
	if err != nil || current.Revision != f.revision || len(current.Data.ActiveRun) == 0 || string(current.Data.ActiveRun) == "null" {
		t.Fatalf("rejected close changed checkpoint: %+v %v", current, err)
	}
	request.IdempotencyKey, request.RawBody = f.key(), []byte(`{"clientCompatibilityVersion":11}`)
	closed, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	f.revision = closed.SaveRevision
	f.refreshEconomy()
	request.IdempotencyKey, request.RawBody = f.key(), []byte(`{"clientCompatibilityVersion":10}`)
	request.SourceSaveRevision, request.ExpectedRevision = f.revision, f.economy.EconomyRevision
	if _, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, request); err != nil {
		t.Fatalf("read-only already-cleared recovery was blocked: %v", err)
	}
}
