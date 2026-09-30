-- Keep stored stage IDs and achievement timestamps; only the ordering changes.
CREATE FUNCTION stage_progression_ordinal(stage_id INTEGER) RETURNS INTEGER
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE AS $$
    SELECT CASE
        WHEN stage_id BETWEEN 1 AND 5 THEN stage_id
        WHEN stage_id BETWEEN 6 AND 10 THEN stage_id + 5
        WHEN stage_id BETWEEN 11 AND 15 THEN stage_id + 10
        WHEN stage_id BETWEEN 16 AND 20 THEN stage_id - 10
        WHEN stage_id BETWEEN 21 AND 25 THEN stage_id - 5
        ELSE 0 END;
$$;

ALTER TABLE leaderboard_records DROP CONSTRAINT leaderboard_records_stage_number_check;
ALTER TABLE leaderboard_records ADD CONSTRAINT leaderboard_records_stage_number_check
    CHECK (stage_number BETWEEN 1 AND 25);

DROP INDEX leaderboard_records_ranking_idx;
CREATE INDEX leaderboard_records_ranking_idx ON leaderboard_records
    (board_key, rules_version, stage_progression_ordinal(stage_number) DESC,
     completed_rounds DESC, achieved_at ASC, account_id);

---- create above / drop below ----

-- A downgrade with new-stage records fails rather than deleting user records.
ALTER TABLE leaderboard_records DROP CONSTRAINT leaderboard_records_stage_number_check;
ALTER TABLE leaderboard_records ADD CONSTRAINT leaderboard_records_stage_number_check
    CHECK (stage_number BETWEEN 1 AND 15);
DROP INDEX leaderboard_records_ranking_idx;
CREATE INDEX leaderboard_records_ranking_idx ON leaderboard_records
    (board_key, rules_version, stage_number DESC, completed_rounds DESC, achieved_at ASC, account_id);
DROP FUNCTION stage_progression_ordinal(INTEGER);
