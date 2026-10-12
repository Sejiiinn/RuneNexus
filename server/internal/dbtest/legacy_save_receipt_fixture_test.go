//go:build integration

package dbtest_test

import (
	"crypto/sha256"
	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/jackc/pgx/v5/pgtype"
	"testing"
)

// Historical exact receipts remain readable even though their clients cannot
// issue fresh writes. Seeding is deliberately isolated to integration fixtures.
func seedLegacySaveReceipt(t *testing.T, fixture *claimedSaveService, request gamesave.UpdateRequest, result gamesave.UpdateResult) {
	t.Helper()
	var key pgtype.UUID
	if err := key.Scan(request.IdempotencyKey); err != nil {
		t.Fatal(err)
	}
	hash := sha256.Sum256(request.RawBody)
	if _, err := dbgen.New(fixture.pool).CreateSaveRequest(t.Context(), dbgen.CreateSaveRequestParams{AccountID: fixture.accountUUID, IdempotencyKey: key, RequestHash: hash[:], WriterGeneration: fixture.writerGeneration, ExpectedRevision: request.ExpectedRevision, ResultingRevision: result.Revision, ResultSavedAt: pgtype.Timestamptz{Time: result.ServerSavedAt, Valid: true}}); err != nil {
		t.Fatal(err)
	}
}
