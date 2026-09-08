package leaderboard

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5/pgtype"
)

type Entry struct {
	Rank            int64     `json:"rank"`
	DisplayName     string    `json:"displayName"`
	StageNumber     int       `json:"stageNumber"`
	CompletedRounds int       `json:"completedRounds"`
	AchievedAt      time.Time `json:"achievedAt"`
	IsMe            bool      `json:"isMe"`
}

type Snapshot struct {
	RulesVersion int       `json:"rulesVersion"`
	AsOf         time.Time `json:"asOf"`
	Entries      []Entry   `json:"entries"`
	MyEntry      *Entry    `json:"myEntry"`
}

type Service struct{ queries *dbgen.Queries }

func NewService(database dbgen.DBTX) *Service {
	return &Service{queries: dbgen.New(database)}
}

func (service *Service) GetProgression(ctx context.Context, accountID string) (Snapshot, error) {
	var id pgtype.UUID
	if err := id.Scan(accountID); err != nil {
		return Snapshot{}, fmt.Errorf("parse leaderboard account ID: %w", err)
	}
	row, err := service.queries.GetProgressionLeaderboard(ctx, id)
	if err != nil {
		return Snapshot{}, fmt.Errorf("get progression leaderboard: %w", err)
	}
	result := Snapshot{RulesVersion: 1, AsOf: row.AsOf.Time.UTC(), Entries: []Entry{}}
	if err := json.Unmarshal(row.Entries, &result.Entries); err != nil {
		return Snapshot{}, fmt.Errorf("decode leaderboard entries: %w", err)
	}
	if err := json.Unmarshal(row.MyEntry, &result.MyEntry); err != nil {
		return Snapshot{}, fmt.Errorf("decode own leaderboard entry: %w", err)
	}
	for i := range result.Entries {
		result.Entries[i].AchievedAt = result.Entries[i].AchievedAt.UTC()
	}
	if result.MyEntry != nil {
		result.MyEntry.AchievedAt = result.MyEntry.AchievedAt.UTC()
	}
	return result, nil
}
