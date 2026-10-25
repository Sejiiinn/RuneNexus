//go:build integration

package dbtest_test

import (
	"testing"
)

func TestGemRerollSchemaConstraints(t *testing.T) {
	ctx, tx, q := openTestTransaction(t)
	account, err := q.CreateAccount(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if err = q.EnsurePlayerEconomy(ctx, account.ID); err != nil {
		t.Fatal(err)
	}
	wallet, err := q.GetPlayerEconomy(ctx, account.ID)
	if err != nil || wallet.GemResetTickets != 0 || wallet.GemRerollEnabled {
		t.Fatalf("ticket defaults: %+v %v", wallet, err)
	}
	var command string
	if err = tx.QueryRow(ctx, `INSERT INTO economy_commands(account_id,idempotency_key,command_type,request_hash,resulting_revision,authority_epoch,response_payload) VALUES($1,uuidv7(),'gem_reroll',decode(repeat('00',32),'hex'),1,uuidv7(),'{}') RETURNING id::text`, account.ID).Scan(&command); err != nil {
		t.Fatal(err)
	}
	runID := "0198b955-3656-7c40-b3cb-87f427b90bee"
	for _, test := range []struct {
		wave, used int
		options    []string
	}{
		{0, 1, []string{"range", "chain", "explosion"}},
		{40, 1, []string{"range", "chain", "explosion"}},
		{5, 4, []string{"range", "chain", "explosion"}},
		{5, 1, []string{"range", "range", "chain"}},
		{5, 1, []string{"range", "chain"}},
		{5, 1, []string{"range", "chain", "Invalid Gem"}},
	} {
		if _, err = tx.Exec(ctx, "SAVEPOINT invalid_reroll"); err != nil {
			t.Fatal(err)
		}
		_, err = tx.Exec(ctx, `INSERT INTO economy_gem_rerolls(account_id,run_id,reward_wave,total_used,gem_options,command_id) VALUES($1,$2,$3,$4,$5,$6)`, account.ID, runID, test.wave, test.used, test.options, command)
		if err == nil {
			t.Fatalf("invalid reroll inserted: %+v", test)
		}
		if _, err = tx.Exec(ctx, "ROLLBACK TO SAVEPOINT invalid_reroll"); err != nil {
			t.Fatal(err)
		}
	}
	if _, err = tx.Exec(ctx, `INSERT INTO economy_gem_rerolls(account_id,run_id,reward_wave,total_used,gem_options,command_id) VALUES($1,$2,5,1,ARRAY['range','chain','explosion'],$3)`, account.ID, runID, command); err != nil {
		t.Fatal(err)
	}
	if _, err = tx.Exec(ctx, "SAVEPOINT negative_tickets"); err != nil {
		t.Fatal(err)
	}
	if _, err = tx.Exec(ctx, `UPDATE player_economies SET gem_reset_tickets=-1 WHERE account_id=$1`, account.ID); err == nil {
		t.Fatal("negative wallet accepted")
	}
	if _, err = tx.Exec(ctx, "ROLLBACK TO SAVEPOINT negative_tickets"); err != nil {
		t.Fatal(err)
	}
}
