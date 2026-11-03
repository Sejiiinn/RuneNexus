//go:build integration

package dbtest_test

import (
	"encoding/json"
	"reflect"
	"testing"
)

// 023 rewrites saved turret ids in place. Enemy types and module grades share
// the old spellings ("magic" rarity), so only turret fields may change.
func TestTurretIdentityRenameRewritesOnlyTurretFields(t *testing.T) {
	ctx, tx, _ := openTestTransaction(t)
	for _, test := range []struct{ raw, want string }{
		{
			`{"turrets":[{"type":"arrow","equippedGemSlots":["attackSpeed"]},{"type":"magic"},{"type":"cannon"}],` +
				`"enemies":[{"type":"normal","rarity":"magic"}],"runTurretModules":[{"turretType":"magic","grade":"magic"}],` +
				`"challengeTurretTypes":["arrow","frost"]}`,
			`{"turrets":[{"type":"machinegun","equippedGemSlots":["attackSpeed"]},{"type":"flame"},{"type":"cannon"}],` +
				`"enemies":[{"type":"normal","rarity":"magic"}],"runTurretModules":[{"turretType":"flame","grade":"magic"}],` +
				`"challengeTurretTypes":["machinegun","frost"]}`,
		},
		{
			`{"items":[{"turretType":"arrow","part":"core","grade":"magic"}],"tickets":3}`,
			`{"items":[{"turretType":"machinegun","part":"core","grade":"magic"}],"tickets":3}`,
		},
		{
			`{"grandfatherUnlocks":["turret:arrow","turret:sniper","research:linkExpansionOne"],"clearedStageNumbers":[1,2]}`,
			`{"grandfatherUnlocks":["turret:machinegun","turret:sniper","research:linkExpansionOne"],"clearedStageNumbers":[1,2]}`,
		},
	} {
		var got string
		if err := tx.QueryRow(ctx, `SELECT rename_turret_ids($1::jsonb, '', '{"arrow":"machinegun","magic":"flame"}')::text`, test.raw).Scan(&got); err != nil {
			t.Fatal(err)
		}
		var actual, expected any
		if json.Unmarshal([]byte(got), &actual) != nil || json.Unmarshal([]byte(test.want), &expected) != nil || !reflect.DeepEqual(actual, expected) {
			t.Fatalf("rename_turret_ids(%s) = %s, want %s", test.raw, got, test.want)
		}
	}
}

// A NULL section (no active run) stays NULL, so transfer rows keep their shape.
func TestTurretIdentityRenameKeepsNullSections(t *testing.T) {
	ctx, tx, _ := openTestTransaction(t)
	var isNull bool
	if err := tx.QueryRow(ctx, `SELECT rename_turret_ids(NULL::jsonb, '', '{"arrow":"machinegun"}') IS NULL`).Scan(&isNull); err != nil {
		t.Fatal(err)
	}
	if !isNull {
		t.Fatal("NULL section must stay NULL")
	}
}
