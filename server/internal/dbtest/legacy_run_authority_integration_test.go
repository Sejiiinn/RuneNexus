//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"github.com/Sejiiinn/RuneNexus/server/internal/legacytransfer"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/Sejiiinn/RuneNexus/server/internal/session"
	"testing"
	"time"
)

func TestLegacyTransferCannotReplacePinnedOrAdoptedRun(t *testing.T) {
	ctx, f, account := openSaveService(t)
	run := json.RawMessage(`{"economyRunId":"0198b955-3656-7c40-b3cb-87f427b90bfa","stageNumber":1,"phase":"preparation","completedRounds":0,"gemRerollsUsed":0,"gemInventory":{"range":1},"gemShards":0,"turrets":[]}`)
	seedPreAuthoritySave(t, f, account, gamesave.Data{Version: 2, Preferences: json.RawMessage(`{}`), Progression: json.RawMessage(`{"runes":0,"freeDiamonds":0,"paidDiamonds":0}`), TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`), ActiveRun: run})
	svc := legacytransfer.NewService(f.pool, time.Minute)
	transfer, err := svc.Create(ctx, legacytransfer.CreateRequest{RawBody: []byte(`{"version":2}`), Data: gamesave.Data{Version: 2, Preferences: json.RawMessage(`{}`), Progression: json.RawMessage(`{"runes":9,"freeDiamonds":0,"paidDiamonds":0}`), TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`)}})
	if err != nil {
		t.Fatal(err)
	}
	hash, _ := session.HashToken(transfer.Token)
	t.Cleanup(func() { _, _ = f.pool.Exec(ctx, `DELETE FROM legacy_save_transfers WHERE token_hash=$1`, hash) })
	for _, adopt := range []bool{false, true} {
		if adopt {
			_, err = f.service.ClaimWriter(ctx, account, f.sessionID, gamesave.ClaimWriterRequest{IdempotencyKey: secondClaimKey, ClientInstanceID: secondClientID, ClientCompatibilityVersion: 9, RawBody: []byte(`{"clientCompatibilityVersion":9}`)})
			if err != nil {
				t.Fatal(err)
			}
		}
		before, err := f.Get(ctx, account)
		if err != nil {
			t.Fatal(err)
		}
		if _, err = svc.Consume(ctx, account, f.sessionID, transfer.Token); !errors.Is(err, legacytransfer.ErrTargetNotReplaceable) {
			t.Fatalf("guarded transfer admitted adopted=%t: %v", adopt, err)
		}
		after, err := f.Get(ctx, account)
		if err != nil || after.Revision != before.Revision {
			t.Fatalf("rejected transfer changed revision: %v", err)
		}
		assertGemOfferJSONEqual(t, after.Data, before.Data)
	}
}
