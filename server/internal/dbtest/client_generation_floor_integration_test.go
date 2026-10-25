//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"fmt"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func TestClientGenerationFloorRejectsOlderClientsAfterNewerClaim(t *testing.T) {
	ctx, f, account := openSaveService(t)
	current := gamesave.CurrentClientCompatibilityVersion
	older := current - 1
	body := func(version int) []byte { return []byte(fmt.Sprintf(`{"clientCompatibilityVersion":%d}`, version)) }
	data := gamesave.Data{Version: 2, Preferences: json.RawMessage(`{}`),
		TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`), Progression: json.RawMessage(`{"runes":0}`)}
	// Control: before any newer claim the same older save is accepted.
	if _, err := f.Update(ctx, account, gamesave.UpdateRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90c60", ClientCompatibilityVersion: older, RawBody: body(older), Data: data,
	}); err != nil {
		t.Fatalf("older save below floor: %v", err)
	}
	claim, err := f.service.ClaimWriter(ctx, account, f.sessionID, gamesave.ClaimWriterRequest{
		IdempotencyKey: secondClaimKey, ClientInstanceID: secondClientID,
		ClientCompatibilityVersion: current, RawBody: body(current),
	})
	if err != nil {
		t.Fatalf("current claim: %v", err)
	}
	f.writerGeneration = claim.WriterGeneration
	var floor int32
	if err := f.pool.QueryRow(ctx, `SELECT client_generation_floor FROM save_writer_states WHERE account_id=$1`, f.accountUUID).Scan(&floor); err != nil || int(floor) != current {
		t.Fatalf("floor after current claim = %d, %v", floor, err)
	}

	// The current writer downgraded in place keeps its token but not its codec.
	if _, err := f.Update(ctx, account, gamesave.UpdateRequest{
		ExpectedRevision: 1, IdempotencyKey: firstSaveKey, ClientCompatibilityVersion: older, RawBody: body(older), Data: data,
	}); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("older save over floor: %v", err)
	}
	if _, err := f.service.ClaimWriter(ctx, account, f.sessionID, gamesave.ClaimWriterRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90c61", ClientInstanceID: clientInstanceID,
		ClientCompatibilityVersion: older, RawBody: body(older),
	}); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("older claim over floor: %v", err)
	}
	saved, err := f.Update(ctx, account, gamesave.UpdateRequest{
		ExpectedRevision: 1, IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90c62", ClientCompatibilityVersion: current, RawBody: body(current), Data: data,
	})
	if err != nil {
		t.Fatalf("current save: %v", err)
	}
	if _, err := economy.NewService(f.pool).Bootstrap(ctx, account, f.sessionID, economy.BootstrapRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90c63",
		RawBody: []byte(fmt.Sprintf(`{"expectedSaveRevision":%d,"writerGeneration":%d,"clientCompatibilityVersion":%d}`,
			saved.Revision, f.writerGeneration, older)),
		WriterGeneration: f.writerGeneration, ExpectedSaveRevision: saved.Revision,
	}); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("older economy command over floor: %v", err)
	}
}

// A retry that passed the unlocked receipt lookup before its first attempt
// committed must still recover that receipt after a newer client raised the
// floor while it waited for the writer lock.
func TestClientGenerationFloorKeepsLockedClaimReplay(t *testing.T) {
	ctx, f, account := openSaveService(t)
	older := gamesave.CurrentClientCompatibilityVersion - 1
	retryKey := "0198b955-3656-7c40-b3cb-87f427b90c64"
	raw := []byte(fmt.Sprintf(`{"clientCompatibilityVersion":%d}`, older))
	hold, err := f.pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer hold.Rollback(ctx)
	var holder int32
	if err := hold.QueryRow(ctx, `SELECT pg_backend_pid()`).Scan(&holder); err != nil {
		t.Fatal(err)
	}
	if _, err := hold.Exec(ctx, `SELECT 1 FROM save_writer_states WHERE account_id=$1 FOR UPDATE`, f.accountUUID); err != nil {
		t.Fatal(err)
	}
	type outcome struct {
		result gamesave.ClaimWriterResult
		err    error
	}
	done := make(chan outcome, 1)
	go func() {
		result, err := f.service.ClaimWriter(ctx, account, f.sessionID, gamesave.ClaimWriterRequest{
			IdempotencyKey: retryKey, ClientInstanceID: secondClientID, ClientCompatibilityVersion: older, RawBody: raw,
		})
		done <- outcome{result, err}
	}()
	for waiting := false; !waiting; {
		if err := f.pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE $1::int = ANY(pg_blocking_pids(pid)))`, holder).Scan(&waiting); err != nil {
			t.Fatal(err)
		}
	}
	// The first attempt commits its receipt, then a newer client raises the floor.
	if _, err := hold.Exec(ctx, `INSERT INTO save_writer_claims(account_id,idempotency_key,session_id,client_instance_id,request_hash,resulting_generation,result_claimed_at)
		VALUES($1,$2::uuid,$3::uuid,$4::uuid,sha256($5::bytea),7,now())`, f.accountUUID, retryKey, f.sessionID, secondClientID, raw); err != nil {
		t.Fatal(err)
	}
	if _, err := hold.Exec(ctx, `UPDATE save_writer_states SET client_generation_floor=$2 WHERE account_id=$1`, f.accountUUID, older+1); err != nil {
		t.Fatal(err)
	}
	if err := hold.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	got := <-done
	if got.err != nil || got.result.WriterGeneration != 7 {
		t.Fatalf("locked retry after floor raise: %+v %v", got.result, got.err)
	}
}
