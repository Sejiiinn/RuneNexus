CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deletion_requested_at TIMESTAMPTZ,
    CONSTRAINT accounts_status_check
        CHECK (status IN ('active', 'suspended', 'deletion_pending'))
);

CREATE TABLE auth_identities (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    provider VARCHAR(32) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_verified_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT auth_identities_provider_subject_key UNIQUE (provider, subject),
    CONSTRAINT auth_identities_account_provider_key UNIQUE (account_id, provider),
    CONSTRAINT auth_identities_provider_check
        CHECK (provider IN ('play_games', 'google', 'apple')),
    CONSTRAINT auth_identities_subject_check CHECK (subject <> '')
);

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    access_token_hash BYTEA NOT NULL UNIQUE,
    access_expires_at TIMESTAMPTZ NOT NULL,
    refresh_expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    CONSTRAINT sessions_access_token_hash_length_check
        CHECK (octet_length(access_token_hash) = 32),
    CONSTRAINT sessions_access_expiry_check CHECK (access_expires_at > created_at),
    CONSTRAINT sessions_refresh_expiry_check
        CHECK (refresh_expires_at > access_expires_at)
);

CREATE INDEX sessions_account_id_idx ON sessions (account_id);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    token_hash BYTEA NOT NULL UNIQUE,
    parent_token_id UUID REFERENCES refresh_tokens(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    consumed_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    CONSTRAINT refresh_tokens_hash_length_check
        CHECK (octet_length(token_hash) = 32),
    CONSTRAINT refresh_tokens_parent_check
        CHECK (parent_token_id IS NULL OR parent_token_id <> id)
);

CREATE INDEX refresh_tokens_session_id_idx ON refresh_tokens (session_id);

CREATE UNIQUE INDEX refresh_tokens_active_session_key
    ON refresh_tokens (session_id)
    WHERE consumed_at IS NULL AND revoked_at IS NULL;

CREATE UNIQUE INDEX refresh_tokens_parent_token_key
    ON refresh_tokens (parent_token_id)
    WHERE parent_token_id IS NOT NULL;

---- create above / drop below ----

DROP TABLE refresh_tokens;
DROP TABLE sessions;
DROP TABLE auth_identities;
DROP TABLE accounts;
