CREATE TABLE leaderboard_records (
    board_key TEXT NOT NULL,
    rules_version INTEGER NOT NULL CHECK (rules_version > 0),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    stage_number INTEGER NOT NULL CHECK (stage_number BETWEEN 1 AND 15),
    completed_rounds INTEGER NOT NULL CHECK (completed_rounds BETWEEN 1 AND 40),
    source_command_id UUID NOT NULL REFERENCES economy_commands(id),
    achieved_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (board_key, rules_version, account_id)
);

CREATE INDEX leaderboard_records_ranking_idx ON leaderboard_records
    (board_key, rules_version, stage_number DESC, completed_rounds DESC, achieved_at ASC, account_id);

---- create above / drop below ----

DROP TABLE leaderboard_records;
