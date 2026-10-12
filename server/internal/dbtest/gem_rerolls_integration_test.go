//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"reflect"
	"sync"
	"testing"
	"time"
)

func TestGemRerollAuthorityRecoveryAndBudget(t *testing.T) {
	ctx, f, account := openSaveService(t)
	svc := economy.NewService(f.pool)
	n := 0
	key := func() string { n++; return fmt.Sprintf("0198b955-3656-7c40-b3cb-%012x", n) }
	runID := "0198b955-3656-7c40-b3cb-87f427b90bee"
	initial := []string{"attackSpeed", "range", "physicalDamage"}
	run := map[string]any{"economyRunId": runID, "stageNumber": 1, "phase": "reward", "completedRounds": 5, "gemRerollsUsed": 0, "rewardOptions": initial, "isPurchasedGemReward": false}
	p := json.RawMessage(`{"growthVersion":1,"progressionVersion":1,"clearedStageNumbers":[3,21],"freeDiamonds":1000}`)
	revision := int64(0)
	save := func(client int, active any) error {
		raw, _ := json.Marshal(active)
		id := key()
		_, err := f.Update(ctx, account, gamesave.UpdateRequest{IdempotencyKey: id, ExpectedRevision: revision, ClientCompatibilityVersion: client, RawBody: []byte(fmt.Sprintf(`{"clientCompatibilityVersion":%d,"save":%d}`, client, n)), Data: gamesave.Data{Version: 2, Preferences: json.RawMessage(`{}`), Progression: p, TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`), ActiveRun: raw}})
		if err == nil {
			revision++
		}
		return err
	}
	if err := save(7, run); err != nil {
		t.Fatal(err)
	}
	bootRequest := economy.BootstrapRequest{IdempotencyKey: key(), RawBody: []byte(`{"clientCompatibilityVersion":6}`), WriterGeneration: f.writerGeneration, ExpectedSaveRevision: 1}
	boot, err := svc.Bootstrap(ctx, account, f.sessionID, bootRequest)
	if err != nil || boot.Snapshot.Wallet.GemResetTickets != 0 || boot.Snapshot.GemReroll != nil {
		t.Fatalf("boot %+v %v", boot, err)
	}
	request := func(econ int64, used, wave int) economy.GemRerollRequest {
		id := key()
		return economy.GemRerollRequest{IdempotencyKey: id, RawBody: []byte(fmt.Sprintf(`{"clientCompatibilityVersion":7,"runId":%q,"completedRounds":%d,"expectedRerollCount":%d,"sourceSaveRevision":%d,"expectedEconomyRevision":%d}`, runID, wave, used, revision, econ)), RunID: runID, CompletedRounds: wave, ExpectedRerollCount: used, SourceSaveRevision: revision, ExpectedRevision: econ, ExpectedCatalogVersion: economy.CatalogVersion, WriterGeneration: f.writerGeneration}
	}
	firstRequest := request(boot.Snapshot.EconomyRevision, 0, 5)
	first, err := svc.RerollGems(ctx, account, f.sessionID, firstRequest)
	if err != nil || first.GemReroll == nil || first.GemReroll.TotalUsed != 1 || first.Snapshot.Wallet.GemResetTickets != 0 || !reflect.DeepEqual(first.GemReroll, first.Snapshot.GemReroll) {
		t.Fatalf("first %+v %v", first, err)
	}
	for _, gem := range first.GemReroll.GemOptions {
		for _, old := range initial {
			if gem == old {
				t.Fatal("previous candidate repeated")
			}
		}
	}
	replay, err := svc.RerollGems(ctx, account, f.sessionID, firstRequest)
	if err != nil || !reflect.DeepEqual(first, replay) {
		t.Fatalf("exact replay %+v %v", replay, err)
	}
	changed := firstRequest
	changed.RawBody = []byte(`{"clientCompatibilityVersion":7,"changed":true}`)
	if _, err = svc.RerollGems(ctx, account, f.sessionID, changed); !errors.Is(err, economy.ErrIdempotencyKeyReused) {
		t.Fatalf("changed body %v", err)
	}
	if _, err = svc.RerollGems(ctx, account, f.sessionID, request(first.Snapshot.EconomyRevision, 1, 5)); !errors.Is(err, economy.ErrGemRerollConflict) {
		t.Fatalf("unpersisted result %v", err)
	}
	recovered, err := economy.NewService(f.pool).Get(ctx, account)
	if err != nil || !reflect.DeepEqual(recovered.GemReroll, first.GemReroll) {
		t.Fatalf("recovery %+v %v", recovered.GemReroll, err)
	}
	run["gemRerollsUsed"] = 1
	run["rewardOptions"] = first.GemReroll.GemOptions
	if err = save(7, run); err != nil {
		t.Fatal(err)
	}
	if _, err = svc.RerollGems(ctx, account, f.sessionID, request(first.Snapshot.EconomyRevision, 1, 5)); !errors.Is(err, economy.ErrInsufficientGemResetTickets) {
		t.Fatalf("no tickets %v", err)
	}
	noSpend, _ := svc.Get(ctx, account)
	if noSpend.EconomyRevision != first.Snapshot.EconomyRevision || noSpend.Wallet.FreeDiamonds != 1000 {
		t.Fatal("failure changed wallet/revision")
	}
	now := time.Now().UTC()
	mailID, err := svc.CreateMail(ctx, economy.CreateMailRequest{DispatchKey: key(), Title: "test", Body: "test", GemResetTickets: 2, Audience: "targeted", TargetAccountIDs: []string{account}, StartsAt: now.Add(-time.Minute), ExpiresAt: now.Add(time.Hour), CreatedBy: "integration test"})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _, _ = f.pool.Exec(ctx, `DELETE FROM mails WHERE id=$1`, mailID) })
	if _, err = svc.ClaimMail(ctx, account, economy.MailClaimRequest{IdempotencyKey: key(), RawBody: []byte(`{"clientCompatibilityVersion":6}`), MailID: mailID}); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old grant %v", err)
	}
	grant, err := svc.ClaimMail(ctx, account, economy.MailClaimRequest{IdempotencyKey: key(), RawBody: []byte(`{"clientCompatibilityVersion":7}`), MailID: mailID})
	if err != nil || grant.GrantedGemResetTickets != 2 || grant.Snapshot.Wallet.GemResetTickets != 2 {
		t.Fatalf("grant %+v %v", grant, err)
	}
	run["completedRounds"] = 10
	run["rewardOptions"] = initial
	if err = save(7, run); err != nil {
		t.Fatal(err)
	}
	second, err := svc.RerollGems(ctx, account, f.sessionID, request(grant.Snapshot.EconomyRevision, 1, 10))
	if err != nil || second.GemReroll.TotalUsed != 2 || second.Snapshot.Wallet.GemResetTickets != 1 {
		t.Fatalf("second %+v %v", second, err)
	}
	run["gemRerollsUsed"] = 2
	run["rewardOptions"] = second.GemReroll.GemOptions
	if err = save(7, run); err != nil {
		t.Fatal(err)
	}
	requests := []economy.GemRerollRequest{request(second.Snapshot.EconomyRevision, 2, 10), request(second.Snapshot.EconomyRevision, 2, 10)}
	results := make([]economy.CommandResult, 2)
	errs := make([]error, 2)
	var wait sync.WaitGroup
	for i := range requests {
		wait.Add(1)
		go func(i int) {
			defer wait.Done()
			results[i], errs[i] = svc.RerollGems(ctx, account, f.sessionID, requests[i])
		}(i)
	}
	wait.Wait()
	success := 0
	var third economy.CommandResult
	for i, err := range errs {
		if err == nil {
			success++
			third = results[i]
		} else {
			var conflict *economy.ConflictError
			if !errors.As(err, &conflict) {
				t.Fatalf("race %v", err)
			}
		}
	}
	if success != 1 || third.GemReroll.TotalUsed != 3 || third.Snapshot.Wallet.GemResetTickets != 0 {
		t.Fatalf("race %+v %v", third, errs)
	}
	run["gemRerollsUsed"] = 3
	run["rewardOptions"] = third.GemReroll.GemOptions
	if err = save(7, run); err != nil {
		t.Fatal(err)
	}
	if _, err = svc.RerollGems(ctx, account, f.sessionID, request(third.Snapshot.EconomyRevision, 3, 10)); !errors.Is(err, economy.ErrGemRerollLimit) {
		t.Fatalf("limit %v", err)
	}
	run["completedRounds"] = 5
	run["gemRerollsUsed"] = 0
	if err = save(7, run); err != nil {
		t.Fatal(err)
	}
	restored, _ := svc.Get(ctx, account)
	if restored.GemReroll.TotalUsed != 3 || restored.GemReroll.RewardWave != 10 {
		t.Fatal("save rollback erased budget")
	}
	if _, err = svc.RerollGems(ctx, account, f.sessionID, request(third.Snapshot.EconomyRevision, 0, 5)); !errors.Is(err, economy.ErrGemRerollConflict) {
		t.Fatalf("old wave %v", err)
	}
	if err = save(7, nil); err != nil {
		t.Fatal(err)
	}
	cleared, _ := svc.Get(ctx, account)
	if cleared.GemReroll != nil {
		t.Fatal("snapshot leaked unrelated run")
	}
	if err = save(7, run); err != nil {
		t.Fatal(err)
	}
	restored, _ = svc.Get(ctx, account)
	if restored.GemReroll == nil || restored.GemReroll.TotalUsed != 3 {
		t.Fatal("active run removal erased budget")
	}
	if err = save(6, nil); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old save %v", err)
	}
	replayBoot, err := svc.Bootstrap(ctx, account, f.sessionID, bootRequest)
	if err != nil || replayBoot.Snapshot.EconomyRevision != boot.Snapshot.EconomyRevision {
		t.Fatalf("old exact receipt %v", err)
	}
	if _, err = f.service.ClaimWriter(ctx, account, f.sessionID, gamesave.ClaimWriterRequest{IdempotencyKey: key(), ClientInstanceID: secondClientID, ClientCompatibilityVersion: 6, RawBody: []byte(`{"clientCompatibilityVersion":6}`)}); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old writer %v", err)
	}
	var entries int
	if err = f.pool.QueryRow(ctx, `SELECT count(*) FROM economy_ledger_entries l JOIN economy_commands c ON c.id=l.command_id WHERE c.account_id=$1 AND l.asset_type='gem_reset_ticket' AND l.delta=-1`, account).Scan(&entries); err != nil || entries != 2 {
		t.Fatalf("ledger %d %v", entries, err)
	}
}

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
		{5, 1, []string{"range", "chain", "invalid"}},
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
