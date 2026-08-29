CREATE TABLE legacy_save_transfers (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    token_hash BYTEA NOT NULL UNIQUE,
    payload_hash BYTEA NOT NULL,
    schema_version INTEGER NOT NULL,
    client_saved_at_millis BIGINT NOT NULL,
    preferences JSONB NOT NULL,
    progression JSONB NOT NULL,
    turret_modules JSONB NOT NULL,
    active_run JSONB,
    created_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT legacy_save_transfers_token_hash_length_check
        CHECK (octet_length(token_hash) = 32),
    CONSTRAINT legacy_save_transfers_payload_hash_length_check
        CHECK (octet_length(payload_hash) = 32),
    CONSTRAINT legacy_save_transfers_schema_version_check
        CHECK (schema_version > 0),
    CONSTRAINT legacy_save_transfers_client_saved_at_check
        CHECK (client_saved_at_millis >= 0),
    CONSTRAINT legacy_save_transfers_preferences_check
        CHECK (jsonb_typeof(preferences) = 'object'),
    CONSTRAINT legacy_save_transfers_progression_check
        CHECK (jsonb_typeof(progression) = 'object'),
    CONSTRAINT legacy_save_transfers_turret_modules_check
        CHECK (jsonb_typeof(turret_modules) = 'object'),
    CONSTRAINT legacy_save_transfers_active_run_check
        CHECK (active_run IS NULL OR jsonb_typeof(active_run) = 'object'),
    CONSTRAINT legacy_save_transfers_expiry_check
        CHECK (expires_at > created_at)
);

CREATE INDEX legacy_save_transfers_expires_at_idx
    ON legacy_save_transfers (expires_at);

CREATE TABLE legacy_save_transfer_receipts (
    transfer_id UUID PRIMARY KEY,
    token_hash BYTEA NOT NULL UNIQUE,
    payload_hash BYTEA NOT NULL,
    consumed_account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,
    consumed_at TIMESTAMPTZ NOT NULL,
    result_revision BIGINT NOT NULL,
    result_saved_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT legacy_save_transfer_receipts_token_hash_length_check
        CHECK (octet_length(token_hash) = 32),
    CONSTRAINT legacy_save_transfer_receipts_payload_hash_length_check
        CHECK (octet_length(payload_hash) = 32),
    CONSTRAINT legacy_save_transfer_receipts_revision_check
        CHECK (result_revision > 0)
);

CREATE INDEX legacy_save_transfer_receipts_account_id_idx
    ON legacy_save_transfer_receipts (consumed_account_id);

---- create above / drop below ----

DROP TABLE legacy_save_transfer_receipts;
DROP TABLE legacy_save_transfers;
