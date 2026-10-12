//go:build integration

package dbtest_test

import (
	"bytes"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

// seedPreAuthoritySave models a canonical authenticated checkpoint that existed
// BEFORE migration016. It never uses an obsolete fresh public write as a test
// setup shortcut; current services correctly reject those writes after rollout.
func seedPreAuthoritySave(t *testing.T, f *claimedSaveService, account string, data gamesave.Data) gamesave.UpdateResult {
	t.Helper()
	ctx := t.Context()
	tx, err := f.pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback(ctx)
	q := dbgen.New(tx)
	if err = q.EnsureSaveHeader(ctx, f.accountUUID); err != nil {
		t.Fatal(err)
	}
	header, err := q.GetSaveHeaderForUpdate(ctx, f.accountUUID)
	if err != nil {
		t.Fatal(err)
	}
	if err = q.UpsertSavePreferences(ctx, dbgen.UpsertSavePreferencesParams{AccountID: f.accountUUID, Payload: data.Preferences}); err != nil {
		t.Fatal(err)
	}
	if err = q.UpsertSaveProgression(ctx, dbgen.UpsertSaveProgressionParams{AccountID: f.accountUUID, Payload: data.Progression}); err != nil {
		t.Fatal(err)
	}
	if err = q.UpsertSaveTurretModules(ctx, dbgen.UpsertSaveTurretModulesParams{AccountID: f.accountUUID, Payload: data.TurretModules}); err != nil {
		t.Fatal(err)
	}
	if data.ActiveRun == nil {
		err = q.DeleteSaveActiveRun(ctx, f.accountUUID)
	} else {
		err = q.UpsertSaveActiveRun(ctx, dbgen.UpsertSaveActiveRunParams{AccountID: f.accountUUID, Payload: data.ActiveRun})
	}
	if err != nil {
		t.Fatal(err)
	}
	result, err := q.AdvanceSaveHeader(ctx, dbgen.AdvanceSaveHeaderParams{AccountID: f.accountUUID, SchemaVersion: data.Version, ClientSavedAtMillis: data.SavedAtMillis, Revision: header.Revision})
	if err != nil {
		t.Fatal(err)
	}
	// Migration016 assigns identity to historical no-ID runs before pinning;
	// the extra header revision makes that canonical metadata change observable.
	normalized, err := tx.Exec(ctx, `UPDATE save_active_runs SET payload=jsonb_set(payload,'{economyRunId}',to_jsonb(gen_random_uuid()::text),true) WHERE account_id=$1 AND jsonb_typeof(payload)='object' AND COALESCE(payload->>'economyRunId','')=''`, account)
	if err != nil {
		t.Fatal(err)
	}
	if normalized.RowsAffected() > 0 {
		result, err = q.AdvanceSaveHeader(ctx, dbgen.AdvanceSaveHeaderParams{AccountID: f.accountUUID, SchemaVersion: data.Version, ClientSavedAtMillis: data.SavedAtMillis, Revision: result.Revision})
		if err != nil {
			t.Fatal(err)
		}
	}
	var pinned any
	if len(bytes.TrimSpace(data.ActiveRun)) > 0 && !bytes.Equal(bytes.TrimSpace(data.ActiveRun), []byte("null")) {
		pinned = result.Revision
	}
	if _, err = tx.Exec(ctx, `INSERT INTO account_run_authorities(account_id,adopted,legacy_source_revision) VALUES($1,false,$2) ON CONFLICT(account_id) DO UPDATE SET adopted=false,legacy_source_revision=EXCLUDED.legacy_source_revision`, account, pinned); err != nil {
		t.Fatal(err)
	}
	if err = tx.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	return gamesave.UpdateResult{Revision: result.Revision, ServerSavedAt: result.UpdatedAt.Time.UTC()}
}
