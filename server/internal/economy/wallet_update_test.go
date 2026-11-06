package economy

import (
	"fmt"
	"reflect"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5/pgtype"
)

// Guards new wallet columns: a field added to UpdatePlayerEconomyParams fails
// here until NextWalletUpdate copies it from the loaded wallet.
func TestNextWalletUpdateCopiesEveryColumn(t *testing.T) {
	wallet := distinctWalletRow(t)
	update := NextWalletUpdate(wallet)

	updateValue := reflect.ValueOf(update)
	for index := range updateValue.NumField() {
		name := updateValue.Type().Field(index).Name
		want := expectedWalletUpdateField(t, wallet, name)
		if reflect.ValueOf(want).IsZero() {
			t.Fatalf("%s expects a zero value, so a missing copy would pass", name)
		}
		if got := updateValue.Field(index).Interface(); !reflect.DeepEqual(got, want) {
			t.Errorf("%s = %v, want %v", name, got, want)
		}
	}
}

// Booleans cannot hold distinct values, so each one is raised alone to prove it
// is copied from its own column and not hardcoded or read from another flag.
func TestNextWalletUpdateCopiesEachFlagFromItsOwnColumn(t *testing.T) {
	walletType := reflect.TypeFor[dbgen.PlayerEconomy]()
	for index := range walletType.NumField() {
		if walletType.Field(index).Type.Kind() != reflect.Bool {
			continue
		}
		wallet := distinctWalletRow(t)
		walletValue := reflect.ValueOf(&wallet).Elem()
		for flag := range walletType.NumField() {
			if walletType.Field(flag).Type.Kind() == reflect.Bool {
				walletValue.Field(flag).SetBool(flag == index)
			}
		}

		updateValue := reflect.ValueOf(NextWalletUpdate(wallet))
		for field := range updateValue.NumField() {
			name := updateValue.Type().Field(field).Name
			want := expectedWalletUpdateField(t, wallet, name)
			if got := updateValue.Field(field).Interface(); !reflect.DeepEqual(got, want) {
				t.Errorf("with only %s set, %s = %v, want %v", walletType.Field(index).Name, name, got, want)
			}
		}
	}
}

func expectedWalletUpdateField(t *testing.T, wallet dbgen.PlayerEconomy, name string) any {
	t.Helper()
	switch name {
	case "Revision":
		return wallet.Revision + 1
	case "Revision_2":
		return wallet.Revision
	}
	source := reflect.ValueOf(wallet).FieldByName(name)
	if !source.IsValid() {
		t.Fatalf("UpdatePlayerEconomyParams.%s has no matching wallet column", name)
	}
	return source.Interface()
}

// Every field gets its own non-zero value, so a missing or crossed copy differs.
func distinctWalletRow(t *testing.T) dbgen.PlayerEconomy {
	t.Helper()
	var wallet dbgen.PlayerEconomy
	walletValue := reflect.ValueOf(&wallet).Elem()
	for index := range walletValue.NumField() {
		seed := int64(index + 1)
		switch field := walletValue.Field(index).Addr().Interface().(type) {
		case *int64:
			*field = 1000 + seed
		case *int32:
			*field = int32(2000 + seed)
		case *string:
			*field = fmt.Sprintf("value-%d", seed)
		case *bool:
			*field = true
		case *pgtype.UUID:
			*field = pgtype.UUID{Bytes: [16]byte{15: byte(seed)}, Valid: true}
		case *pgtype.Int8:
			*field = pgtype.Int8{Int64: 3000 + seed, Valid: true}
		case *pgtype.Timestamptz:
			*field = pgtype.Timestamptz{Time: time.Unix(seed, 0).UTC(), Valid: true}
		default:
			t.Fatalf("add a distinct value for PlayerEconomy.%s", walletValue.Type().Field(index).Name)
		}
	}
	return wallet
}
