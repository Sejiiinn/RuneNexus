CREATE TABLE reward_claims (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    reward_key TEXT NOT NULL,
    period_key TEXT NOT NULL,
    week_key BIGINT NOT NULL,
    reward_type TEXT NOT NULL,
    quest_type TEXT,
    idempotency_key UUID NOT NULL,
    request_hash BYTEA NOT NULL,
    diamond_amount INTEGER NOT NULL,
    module_ticket_amount INTEGER NOT NULL,
    writer_generation BIGINT NOT NULL,
    source_save_revision BIGINT NOT NULL,
    evidence JSONB NOT NULL,
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, reward_key),
    CONSTRAINT reward_claims_account_idempotency_key
        UNIQUE (account_id, idempotency_key),
    CONSTRAINT reward_claims_period_key_check
        CHECK (period_key ~ '^[0-9]{4}-W[0-9]{2}$'),
    CONSTRAINT reward_claims_week_key_check CHECK (week_key >= 0),
    CONSTRAINT reward_claims_reward_type_check
        CHECK (reward_type IN ('quest', 'all_complete', 'attendance')),
    CONSTRAINT reward_claims_quest_type_check CHECK (
        (reward_type = 'quest' AND quest_type IS NOT NULL)
        OR (reward_type <> 'quest' AND quest_type IS NULL)
    ),
    CONSTRAINT reward_claims_hash_length_check
        CHECK (octet_length(request_hash) = 32),
    CONSTRAINT reward_claims_diamond_amount_check
        CHECK (diamond_amount > 0),
    CONSTRAINT reward_claims_module_ticket_amount_check
        CHECK (module_ticket_amount >= 0),
    CONSTRAINT reward_claims_writer_generation_check
        CHECK (writer_generation > 0),
    CONSTRAINT reward_claims_source_save_revision_check
        CHECK (source_save_revision >= 0),
    CONSTRAINT reward_claims_evidence_check
        CHECK (jsonb_typeof(evidence) = 'object')
);

---- create above / drop below ----

DROP TABLE reward_claims;
