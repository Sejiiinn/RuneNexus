ALTER TABLE legacy_save_transfer_receipts
    ADD COLUMN replaced_existing_save BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN previous_schema_version INTEGER,
    ADD COLUMN previous_revision BIGINT,
    ADD COLUMN previous_client_saved_at_millis BIGINT,
    ADD COLUMN previous_preferences JSONB,
    ADD COLUMN previous_progression JSONB,
    ADD COLUMN previous_turret_modules JSONB,
    ADD COLUMN previous_active_run JSONB,
    ADD CONSTRAINT legacy_save_transfer_receipts_previous_save_check CHECK (
        (
            NOT replaced_existing_save
            AND previous_schema_version IS NULL
            AND previous_revision IS NULL
            AND previous_client_saved_at_millis IS NULL
            AND previous_preferences IS NULL
            AND previous_progression IS NULL
            AND previous_turret_modules IS NULL
            AND previous_active_run IS NULL
        )
        OR (
            replaced_existing_save
            AND previous_schema_version > 0
            AND previous_revision > 0
            AND previous_client_saved_at_millis >= 0
            AND jsonb_typeof(previous_preferences) = 'object'
            AND jsonb_typeof(previous_progression) = 'object'
            AND jsonb_typeof(previous_turret_modules) = 'object'
            AND (
                previous_active_run IS NULL
                OR jsonb_typeof(previous_active_run) = 'object'
            )
        )
    );

---- create above / drop below ----

ALTER TABLE legacy_save_transfer_receipts
    DROP CONSTRAINT legacy_save_transfer_receipts_previous_save_check,
    DROP COLUMN previous_active_run,
    DROP COLUMN previous_turret_modules,
    DROP COLUMN previous_progression,
    DROP COLUMN previous_preferences,
    DROP COLUMN previous_client_saved_at_millis,
    DROP COLUMN previous_revision,
    DROP COLUMN previous_schema_version,
    DROP COLUMN replaced_existing_save;
