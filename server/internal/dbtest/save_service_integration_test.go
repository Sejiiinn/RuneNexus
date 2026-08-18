//go:build integration

package dbtest_test

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"strings"
	"sync"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	firstSaveKey  = "0198b955-3656-7c40-b3cb-87f427b90be4"
	secondSaveKey = "0198b955-3656-7c40-b3cb-87f427b90be5"
)

func TestSaveServicePersistsSnapshotAndEnforcesRequestContract(t *testing.T) {
	ctx, service, accountID := openSaveService(t)
	firstBody := []byte(`{"expectedRevision":0,"data":{"version":2,"savedAtMillis":1234,"preferences":{"music":true},"progression":{"runes":30},"turretModules":{"tickets":4},"activeRun":{"roundIndex":3}}}`)
	firstRequest := gamesave.UpdateRequest{
		IdempotencyKey:  firstSaveKey,
		ExpectedRevision: 0,
		RawBody:          firstBody,
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			SavedAtMillis: 1234,
			Preferences:   json.RawMessage(`{"music":true}`),
			Progression:   json.RawMessage(`{"runes":30}`),
			TurretModules: json.RawMessage(`{"tickets":4}`),
			ActiveRun:     json.RawMessage(`{"roundIndex":3}`),
		},
	}

	created, err := service.Update(ctx, accountID, firstRequest)
	if err != nil {
		t.Fatalf("create save: %v", err)
	}
	if created.Revision != 1 || created.ServerSavedAt.IsZero() {
		t.Fatalf("created = %#v", created)
	}
	replayed, err := service.Update(ctx, accountID, firstRequest)
	if err != nil {
		t.Fatalf("replay save: %v", err)
	}
	if replayed != created {
		t.Fatalf("replayed = %#v, want %#v", replayed, created)
	}

	changedBody := firstRequest
	changedBody.RawBody = append([]byte(nil), firstBody...)
	changedBody.RawBody[len(changedBody.RawBody)-2] = ' '
	if _, err := service.Update(ctx, accountID, changedBody); !errors.Is(
		err,
		gamesave.ErrIdempotencyKeyReused,
	) {
		t.Fatalf("changed body error = %v", err)
	}

	if _, err := service.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey:  secondSaveKey,
		ExpectedRevision: 0,
		RawBody:          []byte(`{"expectedRevision":0}`),
		Data:             firstRequest.Data,
	}); err == nil {
		t.Fatal("stale revision update succeeded")
	} else {
		var conflict *gamesave.RevisionConflictError
		if !errors.As(err, &conflict) || conflict.CurrentRevision != 1 {
			t.Fatalf("stale revision error = %v", err)
		}
	}

	snapshot, err := service.Get(ctx, accountID)
	if err != nil {
		t.Fatalf("get save: %v", err)
	}
	if snapshot.Revision != 1 || snapshot.Data.SavedAtMillis != 1234 {
		t.Fatalf("snapshot = %#v", snapshot)
	}
	requireSameJSON(t, snapshot.Data.Preferences, firstRequest.Data.Preferences)
	requireSameJSON(t, snapshot.Data.Progression, firstRequest.Data.Progression)
	requireSameJSON(t, snapshot.Data.TurretModules, firstRequest.Data.TurretModules)
	requireSameJSON(t, snapshot.Data.ActiveRun, firstRequest.Data.ActiveRun)

	secondBody := []byte(`{"expectedRevision":1,"data":{"version":2,"savedAtMillis":5678,"preferences":{},"progression":{},"turretModules":{},"activeRun":null}}`)
	updated, err := service.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey:  secondSaveKey,
		ExpectedRevision: 1,
		RawBody:          secondBody,
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			SavedAtMillis: 5678,
			Preferences:   json.RawMessage(`{}`),
			Progression:   json.RawMessage(`{}`),
			TurretModules: json.RawMessage(`{}`),
		},
	})
	if err != nil {
		t.Fatalf("remove active run: %v", err)
	}
	if updated.Revision != 2 {
		t.Fatalf("updated revision = %d", updated.Revision)
	}
	snapshot, err = service.Get(ctx, accountID)
	if err != nil {
		t.Fatalf("get updated save: %v", err)
	}
	if snapshot.Data.ActiveRun != nil {
		t.Fatalf("active run = %s, want nil", snapshot.Data.ActiveRun)
	}
}

func TestSaveServiceConcurrentIdenticalRequestReturnsOneRevision(t *testing.T) {
	ctx, service, accountID := openSaveService(t)
	request := gamesave.UpdateRequest{
		IdempotencyKey:  firstSaveKey,
		ExpectedRevision: 0,
		RawBody:          []byte(`{"expectedRevision":0,"data":{"version":2}}`),
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			Preferences:   json.RawMessage(`{}`),
			Progression:   json.RawMessage(`{}`),
			TurretModules: json.RawMessage(`{}`),
		},
	}

	start := make(chan struct{})
	results := make(chan gamesave.UpdateResult, 2)
	errorsChannel := make(chan error, 2)
	var group sync.WaitGroup
	for range 2 {
		group.Add(1)
		go func() {
			defer group.Done()
			<-start
			result, err := service.Update(ctx, accountID, request)
			results <- result
			errorsChannel <- err
		}()
	}
	close(start)
	group.Wait()
	close(results)
	close(errorsChannel)

	for err := range errorsChannel {
		if err != nil {
			t.Fatalf("concurrent update: %v", err)
		}
	}
	for result := range results {
		if result.Revision != 1 {
			t.Fatalf("result revision = %d", result.Revision)
		}
	}
	snapshot, err := service.Get(ctx, accountID)
	if err != nil {
		t.Fatalf("get save: %v", err)
	}
	if snapshot.Revision != 1 {
		t.Fatalf("snapshot revision = %d", snapshot.Revision)
	}
}

func TestSaveServiceConcurrentDifferentBodiesRejectsIdempotencyKeyReuse(t *testing.T) {
	ctx, service, accountID := openSaveService(t)
	requests := []gamesave.UpdateRequest{
		{
			IdempotencyKey:  firstSaveKey,
			ExpectedRevision: 0,
			RawBody:          []byte(`{"expectedRevision":0,"value":"first"}`),
			Data: gamesave.Data{
				Version:       gamesave.CurrentSchemaVersion,
				Preferences:   json.RawMessage(`{"value":"first"}`),
				Progression:   json.RawMessage(`{}`),
				TurretModules: json.RawMessage(`{}`),
			},
		},
		{
			IdempotencyKey:  firstSaveKey,
			ExpectedRevision: 0,
			RawBody:          []byte(`{"expectedRevision":0,"value":"second"}`),
			Data: gamesave.Data{
				Version:       gamesave.CurrentSchemaVersion,
				Preferences:   json.RawMessage(`{"value":"second"}`),
				Progression:   json.RawMessage(`{}`),
				TurretModules: json.RawMessage(`{}`),
			},
		},
	}

	start := make(chan struct{})
	errorsChannel := make(chan error, len(requests))
	var group sync.WaitGroup
	for _, request := range requests {
		group.Add(1)
		go func() {
			defer group.Done()
			<-start
			_, err := service.Update(ctx, accountID, request)
			errorsChannel <- err
		}()
	}
	close(start)
	group.Wait()
	close(errorsChannel)

	successCount := 0
	reuseCount := 0
	for err := range errorsChannel {
		switch {
		case err == nil:
			successCount++
		case errors.Is(err, gamesave.ErrIdempotencyKeyReused):
			reuseCount++
		default:
			t.Fatalf("concurrent update error = %v", err)
		}
	}
	if successCount != 1 || reuseCount != 1 {
		t.Fatalf("successes = %d, key reuses = %d", successCount, reuseCount)
	}
}

func TestSaveServiceConcurrentRevisionsAllowsOnlyOneWriter(t *testing.T) {
	ctx, service, accountID := openSaveService(t)
	requests := []gamesave.UpdateRequest{
		{
			IdempotencyKey:  firstSaveKey,
			ExpectedRevision: 0,
			RawBody:          []byte(`{"expectedRevision":0,"value":"first"}`),
			Data: gamesave.Data{
				Version:       gamesave.CurrentSchemaVersion,
				Preferences:   json.RawMessage(`{"value":"first"}`),
				Progression:   json.RawMessage(`{}`),
				TurretModules: json.RawMessage(`{}`),
			},
		},
		{
			IdempotencyKey:  secondSaveKey,
			ExpectedRevision: 0,
			RawBody:          []byte(`{"expectedRevision":0,"value":"second"}`),
			Data: gamesave.Data{
				Version:       gamesave.CurrentSchemaVersion,
				Preferences:   json.RawMessage(`{"value":"second"}`),
				Progression:   json.RawMessage(`{}`),
				TurretModules: json.RawMessage(`{}`),
			},
		},
	}

	start := make(chan struct{})
	errorsChannel := make(chan error, len(requests))
	var group sync.WaitGroup
	for _, request := range requests {
		group.Add(1)
		go func() {
			defer group.Done()
			<-start
			_, err := service.Update(ctx, accountID, request)
			errorsChannel <- err
		}()
	}
	close(start)
	group.Wait()
	close(errorsChannel)

	successCount := 0
	conflictCount := 0
	for err := range errorsChannel {
		if err == nil {
			successCount++
			continue
		}
		var conflict *gamesave.RevisionConflictError
		if !errors.As(err, &conflict) || conflict.CurrentRevision != 1 {
			t.Fatalf("concurrent update error = %v", err)
		}
		conflictCount++
	}
	if successCount != 1 || conflictCount != 1 {
		t.Fatalf("successes = %d, conflicts = %d", successCount, conflictCount)
	}
}

func TestSaveServiceRollsBackWholeTransactionOnPayloadFailure(t *testing.T) {
	ctx, service, accountID := openSaveService(t)
	_, err := service.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey:  firstSaveKey,
		ExpectedRevision: 0,
		RawBody:          []byte(`{"expectedRevision":0}`),
		Data: gamesave.Data{
			Version:       gamesave.CurrentSchemaVersion,
			Preferences:   json.RawMessage(`[]`),
			Progression:   json.RawMessage(`{}`),
			TurretModules: json.RawMessage(`{}`),
		},
	})
	if err == nil {
		t.Fatal("invalid payload update succeeded")
	}
	if _, err := service.Get(ctx, accountID); !errors.Is(err, gamesave.ErrNotFound) {
		t.Fatalf("get rolled back save error = %v", err)
	}
}

func openSaveService(t *testing.T) (context.Context, *gamesave.Service, string) {
	t.Helper()
	databaseURL := os.Getenv("RUNE_NEXUS_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("RUNE_NEXUS_TEST_DATABASE_URL is not set")
	}
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		t.Fatalf("parse test database URL: %v", err)
	}
	if passwordFile := os.Getenv("RUNE_NEXUS_TEST_DATABASE_PASSWORD_FILE"); passwordFile != "" {
		password, err := os.ReadFile(passwordFile)
		if err != nil {
			t.Fatalf("read test database password: %v", err)
		}
		config.ConnConfig.Password = strings.TrimSpace(string(password))
	}

	ctx, cancel := context.WithTimeout(context.Background(), testDatabaseTimeout)
	t.Cleanup(cancel)
	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatalf("connect test database: %v", err)
	}
	t.Cleanup(pool.Close)
	account, err := dbgen.New(pool).CreateAccount(ctx)
	if err != nil {
		t.Fatalf("create account: %v", err)
	}
	var accountID string
	if err := pool.QueryRow(
		ctx,
		"SELECT $1::uuid::text",
		account.ID,
	).Scan(&accountID); err != nil {
		t.Fatalf("format account ID: %v", err)
	}
	t.Cleanup(func() {
		cleanupContext, cleanupCancel := context.WithTimeout(
			context.Background(),
			testDatabaseTimeout,
		)
		defer cleanupCancel()
		if _, err := pool.Exec(
			cleanupContext,
			"DELETE FROM accounts WHERE id = $1",
			account.ID,
		); err != nil {
			t.Errorf("delete test account: %v", err)
		}
	})
	return ctx, gamesave.NewService(pool), accountID
}
