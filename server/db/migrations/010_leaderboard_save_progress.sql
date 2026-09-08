ALTER TABLE leaderboard_records
    ALTER COLUMN source_command_id DROP NOT NULL,
    ADD COLUMN source_save_revision BIGINT,
    ADD CONSTRAINT leaderboard_records_source_check CHECK (
        (source_command_id IS NOT NULL AND source_save_revision IS NULL)
        OR (source_command_id IS NULL AND source_save_revision IS NOT NULL AND source_save_revision > 0)
    );

---- create above / drop below ----

-- 저장 출처 기록이 있으면 롤백을 거부하여 기록 손실 방지.
ALTER TABLE leaderboard_records ALTER COLUMN source_command_id SET NOT NULL;
ALTER TABLE leaderboard_records
    DROP CONSTRAINT leaderboard_records_source_check,
    DROP COLUMN source_save_revision;
