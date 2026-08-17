CREATE TABLE save_headers (
    account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    schema_version INTEGER NOT NULL,
    revision BIGINT NOT NULL DEFAULT 0,
    client_saved_at_millis BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT save_headers_schema_version_check CHECK (schema_version > 0),
    CONSTRAINT save_headers_revision_check CHECK (revision >= 0),
    CONSTRAINT save_headers_client_saved_at_check
        CHECK (client_saved_at_millis >= 0)
);

CREATE TABLE save_preferences (
    account_id UUID PRIMARY KEY REFERENCES save_headers(account_id) ON DELETE CASCADE,
    payload JSONB NOT NULL,
    CONSTRAINT save_preferences_payload_check CHECK (jsonb_typeof(payload) = 'object')
);

CREATE TABLE save_progression (
    account_id UUID PRIMARY KEY REFERENCES save_headers(account_id) ON DELETE CASCADE,
    payload JSONB NOT NULL,
    CONSTRAINT save_progression_payload_check CHECK (jsonb_typeof(payload) = 'object')
);

CREATE TABLE save_turret_modules (
    account_id UUID PRIMARY KEY REFERENCES save_headers(account_id) ON DELETE CASCADE,
    payload JSONB NOT NULL,
    CONSTRAINT save_turret_modules_payload_check CHECK (jsonb_typeof(payload) = 'object')
);

CREATE TABLE save_active_runs (
    account_id UUID PRIMARY KEY REFERENCES save_headers(account_id) ON DELETE CASCADE,
    payload JSONB NOT NULL,
    CONSTRAINT save_active_runs_payload_check CHECK (jsonb_typeof(payload) = 'object')
);

CREATE TABLE save_requests (
    account_id UUID NOT NULL REFERENCES save_headers(account_id) ON DELETE CASCADE,
    idempotency_key UUID NOT NULL,
    request_hash BYTEA NOT NULL,
    expected_revision BIGINT NOT NULL,
    resulting_revision BIGINT NOT NULL,
    result_saved_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, idempotency_key),
    CONSTRAINT save_requests_account_revision_key
        UNIQUE (account_id, resulting_revision),
    CONSTRAINT save_requests_hash_length_check
        CHECK (octet_length(request_hash) = 32),
    CONSTRAINT save_requests_expected_revision_check
        CHECK (expected_revision >= 0),
    CONSTRAINT save_requests_resulting_revision_check
        CHECK (resulting_revision = expected_revision + 1)
);

---- create above / drop below ----

DROP TABLE save_requests;
DROP TABLE save_active_runs;
DROP TABLE save_turret_modules;
DROP TABLE save_progression;
DROP TABLE save_preferences;
DROP TABLE save_headers;
