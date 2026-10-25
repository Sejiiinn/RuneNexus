//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	stageprogression "github.com/Sejiiinn/RuneNexus/server/internal/progression"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func TestPoisonModuleDrawRequiresCurrentClient(t *testing.T) {
	ctx, fixture, accountID := openSaveService(t)
	var definition string
	if err := fixture.pool.QueryRow(ctx, `SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='player_modules_turret_type_check'`).Scan(&definition); err != nil || !strings.Contains(definition, "turret_type ~") {
		t.Fatalf("player_modules turret types: %q %v", definition, err)
	}
	progression, err := json.Marshal(map[string]any{
		"progressionVersion": stageprogression.Version, "clearedStageNumbers": []int{1, 23},
	})
	if err != nil {
		t.Fatal(err)
	}
	seedPreAuthoritySave(t, fixture, accountID, gamesave.Data{
		Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`), Progression: progression,
		TurretModules: json.RawMessage(`{"tickets":2,"drawCount":0,"ticketPurchaseCount":0,"itemSequence":0,"items":[]}`),
	})
	service := economy.NewService(fixture.pool)
	bootstrap, err := service.Bootstrap(ctx, accountID, fixture.sessionID, economy.BootstrapRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90c01", RawBody: []byte(`{"expectedSaveRevision":1,"writerGeneration":1,"clientCompatibilityVersion":13}`),
		WriterGeneration: fixture.writerGeneration, ExpectedSaveRevision: 1,
	})
	if err != nil {
		t.Fatalf("bootstrap: %v", err)
	}
	request := economy.DrawRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90c02", RawBody: []byte(`{"clientCompatibilityVersion":12,"count":1,"turretType":"poison"}`),
		ExpectedRevision: bootstrap.Snapshot.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion,
		SourceSaveRevision: 1, WriterGeneration: fixture.writerGeneration, Count: 1, TurretType: "poison",
	}
	if _, err := service.DrawModules(ctx, accountID, fixture.sessionID, request); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("generation 12 drew a poison module: %v", err)
	}
	request.IdempotencyKey, request.RawBody = "0198b955-3656-7c40-b3cb-87f427b90c03", []byte(`{"clientCompatibilityVersion":13,"count":1,"turretType":"poison"}`)
	draw, err := service.DrawModules(ctx, accountID, fixture.sessionID, request)
	if err != nil || len(draw.DrawnModules) != 1 {
		t.Fatalf("poison draw: %#v %v", draw, err)
	}
	module := draw.DrawnModules[0]
	families := map[string]string{"core": "venomCore", "barrel": "mortarBarrel", "frame": "sealedFrame"}
	if module.TurretType != "poison" || families[module.Part] != module.Family {
		t.Fatalf("drawn poison module: %#v", module)
	}
}
