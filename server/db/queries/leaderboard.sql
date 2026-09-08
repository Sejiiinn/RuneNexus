-- name: UpsertProgressionLeaderboardRecord :exec
INSERT INTO leaderboard_records (
    board_key, rules_version, account_id, stage_number, completed_rounds, source_command_id, source_save_revision
) VALUES ('progression', 1, $1, $2, $3, $4, $5)
ON CONFLICT (board_key, rules_version, account_id) DO UPDATE
SET stage_number = EXCLUDED.stage_number,
    completed_rounds = EXCLUDED.completed_rounds,
    source_command_id = EXCLUDED.source_command_id,
    source_save_revision = EXCLUDED.source_save_revision,
    achieved_at = clock_timestamp()
WHERE (EXCLUDED.stage_number, EXCLUDED.completed_rounds) >
      (leaderboard_records.stage_number, leaderboard_records.completed_rounds);

-- name: GetProgressionLeaderboard :one
WITH ranked AS MATERIALIZED (
    SELECT records.account_id,
           records.stage_number, records.completed_rounds, records.achieved_at,
           rank() OVER (ORDER BY records.stage_number DESC, records.completed_rounds DESC, records.achieved_at ASC) AS rank,
           accounts.nickname || '#' || accounts.nickname_tag AS display_name
    FROM leaderboard_records AS records
    JOIN accounts ON accounts.id = records.account_id
    WHERE records.board_key = 'progression' AND records.rules_version = 1
      AND accounts.status = 'active'
      AND accounts.nickname IS NOT NULL AND accounts.nickname_tag IS NOT NULL
), rendered AS MATERIALIZED (
    SELECT account_id, rank, stage_number, completed_rounds, achieved_at,
           jsonb_build_object('rank', rank, 'displayName', display_name,
               'stageNumber', stage_number, 'completedRounds', completed_rounds,
               'achievedAt', achieved_at, 'isMe', account_id = $1::uuid) AS entry
    FROM ranked
), top_entries AS (
    SELECT * FROM rendered
    ORDER BY stage_number DESC, completed_rounds DESC, achieved_at ASC, account_id
    LIMIT 100
)
SELECT statement_timestamp()::timestamptz AS as_of,
       COALESCE((SELECT jsonb_agg(entry ORDER BY stage_number DESC, completed_rounds DESC, achieved_at ASC, account_id) FROM top_entries), '[]'::jsonb)::jsonb AS entries,
       COALESCE((SELECT entry FROM rendered WHERE account_id = $1::uuid), 'null'::jsonb)::jsonb AS my_entry;
