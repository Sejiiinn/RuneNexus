CREATE TABLE mails (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    dispatch_key UUID NOT NULL UNIQUE,
    request_hash BYTEA NOT NULL CHECK (octet_length(request_hash) = 32),
    title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
    body TEXT NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
    free_diamonds BIGINT NOT NULL DEFAULT 0 CHECK (free_diamonds BETWEEN 0 AND 1000000),
    module_tickets BIGINT NOT NULL DEFAULT 0 CHECK (module_tickets BETWEEN 0 AND 100000),
    audience TEXT NOT NULL CHECK (audience IN ('all', 'targeted')),
    eligibility_cutoff TIMESTAMPTZ NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_by TEXT NOT NULL CHECK (char_length(created_by) BETWEEN 1 AND 120),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    disabled_at TIMESTAMPTZ,
    disabled_by TEXT,
    CHECK (expires_at > starts_at),
    CHECK (free_diamonds > 0 OR module_tickets > 0)
);
CREATE INDEX mails_active_expiry_idx ON mails (expires_at, starts_at, id) WHERE disabled_at IS NULL;
CREATE TABLE mail_targets (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    mail_id UUID NOT NULL REFERENCES mails(id) ON DELETE CASCADE,
    PRIMARY KEY (account_id, mail_id)
);
CREATE INDEX mail_targets_mail_idx ON mail_targets(mail_id);
CREATE TABLE mail_reads (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    mail_id UUID NOT NULL REFERENCES mails(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, mail_id)
);
CREATE INDEX mail_reads_mail_idx ON mail_reads(mail_id);

CREATE TABLE mail_claim_batches (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    idempotency_key UUID NOT NULL,
    request_hash BYTEA NOT NULL CHECK (octet_length(request_hash) = 32),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, idempotency_key)
);

---- create above / drop below ----

-- 수령 원장과 운영 이력 보존: 우편 마이그레이션은 forward-only.
SELECT 1;
