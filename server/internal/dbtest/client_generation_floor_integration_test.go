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
