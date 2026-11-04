// Package runlog stores analysis-only run summaries sent after run settlement.
// Nothing here feeds rewards, leaderboards or the economy; the body is client
// trusted and kept as JSON after a minimal shape check.
package runlog

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5/pgtype"
)

const (
	SchemaVersion = 1
	MaxBodyBytes  = 32 << 10
	Retention     = 180 * 24 * time.Hour
)

var ErrInvalid = errors.New("invalid run log")

type Entry struct {
	RunID       pgtype.UUID
	ClientBuild int32
	StageID     int32
	Payload     []byte
}

// Parse checks only what the table needs; every other field is stored as sent.
func Parse(body []byte) (Entry, error) {
	decoder := json.NewDecoder(bytes.NewReader(body))
	decoder.UseNumber()
	var fields map[string]any
	if err := decoder.Decode(&fields); err != nil || fields == nil {
		return Entry{}, ErrInvalid
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return Entry{}, ErrInvalid
	}
	if version, ok := integer(fields["schemaVersion"], 1, 1000); !ok || version != SchemaVersion {
		return Entry{}, ErrInvalid
	}
	stage, ok := integer(fields["stageId"], 1, 9999)
	if !ok {
		return Entry{}, ErrInvalid
	}
	build, ok := integer(fields["clientBuild"], 0, 1<<31-1)
	if !ok {
		return Entry{}, ErrInvalid
	}
	text, _ := fields["runId"].(string)
	var runID pgtype.UUID
	if len(text) != 36 || runID.Scan(text) != nil {
		return Entry{}, ErrInvalid
	}
	return Entry{RunID: runID, ClientBuild: int32(build), StageID: int32(stage), Payload: body}, nil
}

func integer(value any, minimum, maximum int64) (int64, bool) {
	number, ok := value.(json.Number)
	if !ok {
		return 0, false
	}
	parsed, err := number.Int64()
	return parsed, err == nil && parsed >= minimum && parsed <= maximum
}

type Service struct{ queries *dbgen.Queries }

func NewService(database dbgen.DBTX) *Service {
	return &Service{queries: dbgen.New(database)}
}

// Record ignores duplicates and accounts with a pending deletion request.
func (service *Service) Record(ctx context.Context, accountID string, entry Entry) error {
	var account pgtype.UUID
	if err := account.Scan(accountID); err != nil {
		return fmt.Errorf("parse run log account ID: %w", err)
	}
	_, err := service.queries.InsertRunLog(ctx, dbgen.InsertRunLogParams{
		AccountID:   account,
		RunID:       entry.RunID,
		ClientBuild: entry.ClientBuild,
		StageID:     entry.StageID,
		Payload:     entry.Payload,
	})
	if err != nil {
		return fmt.Errorf("insert run log: %w", err)
	}
	return nil
}

func (service *Service) DeleteExpired(ctx context.Context, now time.Time) (int64, error) {
	deleted, err := service.queries.DeleteRunLogsReceivedBefore(ctx, pgtype.Timestamptz{Time: now.Add(-Retention), Valid: true})
	if err != nil {
		return 0, fmt.Errorf("delete expired run logs: %w", err)
	}
	return deleted, nil
}
