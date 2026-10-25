//go:build integration

package dbtest_test

import (
	"strings"
	"testing"
)

// Content names belong to the generated server registry; the schema only
// rejects malformed identities, so new gems and turrets need no migration.
func TestSchemaChecksContentIdentityShapeOnly(t *testing.T) {
	ctx, tx, _ := openTestTransaction(t)
	for _, test := range []struct {
		raw  string
		want bool
	}{
		{`{"futureGem":1,"poisonDamage":2}`, true},
		{`{"Future Gem":1}`, false},
		{`{"future,gem":1}`, false},
	} {
		var valid bool
		if err := tx.QueryRow(ctx, `SELECT valid_run_gem_totals($1::jsonb)`, test.raw).Scan(&valid); err != nil {
			t.Fatal(err)
		}
		if valid != test.want {
			t.Fatalf("%s: valid=%v want=%v", test.raw, valid, test.want)
		}
	}
	for _, name := range []string{"player_modules_turret_type_check", "economy_gem_rerolls_gem_options_check"} {
		var definition string
		if err := tx.QueryRow(ctx, `SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname=$1`, name).Scan(&definition); err != nil {
			t.Fatal(err)
		}
		if strings.Contains(definition, "'poison'") || strings.Contains(definition, "'attackSpeed'") {
			t.Fatalf("%s still lists content names: %s", name, definition)
		}
	}
}
