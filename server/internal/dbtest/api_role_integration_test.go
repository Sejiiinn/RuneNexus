//go:build integration

package dbtest_test

import (
	"context"
	"errors"
	"os"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

const insufficientPrivilege = "42501"

// ownerExec injects faults the API role may not cause itself.
func ownerExec(ctx context.Context, statement string) error {
	config, err := pgx.ParseConfig(os.Getenv("RUNE_NEXUS_TEST_OWNER_DATABASE_URL"))
	if err != nil {
		return err
	}
	password, err := os.ReadFile(os.Getenv("RUNE_NEXUS_TEST_OWNER_PASSWORD_FILE"))
	if err != nil {
		return err
	}
	config.Password = strings.TrimSpace(string(password))
	connection, err := pgx.ConnectConfig(ctx, config)
	if err != nil {
		return err
	}
	defer connection.Close(ctx)
	_, err = connection.Exec(ctx, statement)
	return err
}

func TestAPIRoleHoldsOnlyTableData(t *testing.T) {
	ctx, tx, _ := openTestTransaction(t)

	var super, createRole, createDatabase bool
	err := tx.QueryRow(ctx, `
SELECT rolsuper, rolcreaterole, rolcreatedb FROM pg_roles WHERE rolname = current_user`).
		Scan(&super, &createRole, &createDatabase)
	if err != nil {
		t.Fatalf("read role attributes: %v", err)
	}
	if super || createRole || createDatabase {
		t.Fatalf("API role is privileged: super=%v createRole=%v createDatabase=%v", super, createRole, createDatabase)
	}

	for _, statement := range []string{
		`CREATE TABLE api_role_probe (id int)`,
		`DROP TABLE accounts`,
		`ALTER TABLE accounts ADD COLUMN api_role_probe int`,
		`TRUNCATE accounts`,
		`SELECT * FROM schema_version`,
		`UPDATE schema_version SET version = 0`,
		`SELECT pg_read_file('/etc/passwd')`,
		`COPY accounts TO PROGRAM 'cat'`,
		`CREATE ROLE api_role_probe SUPERUSER`,
	} {
		probe, err := tx.Begin(ctx)
		if err != nil {
			t.Fatalf("begin savepoint: %v", err)
		}
		_, err = probe.Exec(ctx, statement)
		var postgresError *pgconn.PgError
		if !errors.As(err, &postgresError) || postgresError.Code != insufficientPrivilege {
			t.Errorf("%s: want permission denied, got %v", statement, err)
		}
		if err := probe.Rollback(ctx); err != nil {
			t.Fatalf("roll back savepoint: %v", err)
		}
	}
}
