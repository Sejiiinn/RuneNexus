//go:build integration

package dbtest_test

import (
	"context"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/Sejiiinn/RuneNexus/server/internal/runlog"
	"github.com/jackc/pgx/v5/pgtype"
)

func runLogEntry(t *testing.T, runID string) runlog.Entry {
	t.Helper()
	entry, err := runlog.Parse([]byte(`{"schemaVersion":1,"runId":"` + runID + `","clientBuild":6062,"stageId":23,"turrets":[]}`))
	if err != nil {
		t.Fatal(err)
	}
	return entry
}

func countRunLogs(t *testing.T, ctx context.Context, tx dbgen.DBTX, account pgtype.UUID) int {
	t.Helper()
	var count int
	if err := tx.QueryRow(ctx, `SELECT count(*) FROM run_logs WHERE account_id = $1`, account).Scan(&count); err != nil {
		t.Fatal(err)
	}
	return count
}

func TestRunLogsStoreOnceExpireAndFollowDeletionRequest(t *testing.T) {
	ctx, tx, queries := openTestTransaction(t)
	account, err := queries.CreateAccount(ctx)
	if err != nil {
		t.Fatal(err)
	}
	id := account.ID.String()
	service := runlog.NewService(tx)
	first := runLogEntry(t, "0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a71")
	for range 2 {
		if err := service.Record(ctx, id, first); err != nil {
			t.Fatal(err)
		}
	}
	var payload []byte
	if err := tx.QueryRow(ctx, `SELECT payload::text FROM run_logs WHERE account_id = $1`, account.ID).Scan(&payload); err != nil {
		t.Fatal(err)
	}
	if countRunLogs(t, ctx, tx, account.ID) != 1 || len(payload) == 0 {
		t.Fatalf("duplicate run stored twice or empty payload")
	}

	if err := service.Record(ctx, id, runLogEntry(t, "0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a72")); err != nil {
		t.Fatal(err)
	}
	if _, err := tx.Exec(ctx, `UPDATE run_logs SET received_at = now() - interval '181 days' WHERE run_id = $1`, first.RunID); err != nil {
		t.Fatal(err)
	}
	deleted, err := service.DeleteExpired(ctx, time.Now())
	if err != nil || deleted < 1 || countRunLogs(t, ctx, tx, account.ID) != 1 {
		t.Fatalf("expire deleted %d err %v", deleted, err)
	}

	if _, err := queries.UpdateAccountStatus(ctx, dbgen.UpdateAccountStatusParams{
		ID: account.ID, Status: "deletion_pending",
		DeletionRequestedAt: pgtype.Timestamptz{Time: time.Now(), Valid: true},
	}); err != nil {
		t.Fatal(err)
	}
	if countRunLogs(t, ctx, tx, account.ID) != 0 {
		t.Fatal("deletion request kept run logs")
	}
	if err := service.Record(ctx, id, runLogEntry(t, "0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a73")); err != nil {
		t.Fatal(err)
	}
	if countRunLogs(t, ctx, tx, account.ID) != 0 {
		t.Fatal("stored a run log for an account pending deletion")
	}
}

// An upload racing a deletion request waits on the account row and stores nothing.
func TestRunLogUploadSerializesWithDeletionRequest(t *testing.T) {
	ctx, pool := openTestPool(t)
	queries := dbgen.New(pool)
	account, err := queries.CreateAccount(ctx)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _, _ = pool.Exec(ctx, `DELETE FROM accounts WHERE id = $1`, account.ID) })

	deletion, err := pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := dbgen.New(deletion).UpdateAccountStatus(ctx, dbgen.UpdateAccountStatusParams{
		ID: account.ID, Status: "deletion_pending",
		DeletionRequestedAt: pgtype.Timestamptz{Time: time.Now(), Valid: true},
	}); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() {
		done <- runlog.NewService(pool).Record(ctx, account.ID.String(), runLogEntry(t, "0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a74"))
	}()
	select {
	case err := <-done:
		t.Fatalf("upload finished before the deletion request committed: %v", err)
	case <-time.After(300 * time.Millisecond):
	}
	if err := deletion.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	var count int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM run_logs WHERE account_id = $1`, account.ID).Scan(&count); err != nil || count != 0 {
		t.Fatalf("count %d err %v", count, err)
	}
}
