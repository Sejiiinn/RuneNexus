//go:build integration

package dbtest_test

import (
	"errors"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func TestPoisonDamageSchemaPreservesGemIdentities(t *testing.T) {
	ctx, tx, _ := openTestTransaction(t)
	for _, test := range []struct {
		raw  string
		want bool
	}{
		{`{"poisonDamage":1,"piercing":2,"armorPiercing":3}`, true},
		{`{"poisonDamage":-1}`, false},
		{`{"":1}`, false},
	} {
		var valid bool
		if err := tx.QueryRow(ctx, `SELECT valid_run_gem_totals($1::jsonb)`, test.raw).Scan(&valid); err != nil {
			t.Fatal(err)
		}
		if valid != test.want {
			t.Fatalf("%s: valid=%v want=%v", test.raw, valid, test.want)
		}
	}
}

func TestOldWriterCannotClosePoisonDamageDeck(t *testing.T) {
	f, started, _ := openDeckRun(t)
	if _, err := f.save.pool.Exec(f.ctx, `UPDATE economy_runs SET gem_deck=jsonb_set(gem_deck,'{waves,5,options,0,0}','"poisonDamage"'::jsonb) WHERE account_id=$1 AND run_id=$2`, f.account, started.Run.RunID); err != nil {
		t.Fatal(err)
	}
	request := economy.CloseRunRequest{
		IdempotencyKey: f.key(), RawBody: []byte(`{"clientCompatibilityVersion":12}`), RunID: started.Run.RunID,
		WriterGeneration: f.save.writerGeneration, SourceSaveRevision: f.revision,
		ExpectedRevision: f.economy.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion,
	}
	if _, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, request); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("generation 12 writer closed poison damage run: %v", err)
	}
	request.IdempotencyKey, request.RawBody = f.key(), []byte(`{"clientCompatibilityVersion":13}`)
	if _, err := f.service.CloseRun(f.ctx, f.account, f.save.sessionID, request); err != nil {
		t.Fatal(err)
	}
}
