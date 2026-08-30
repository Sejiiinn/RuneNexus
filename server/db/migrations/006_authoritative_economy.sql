ALTER TABLE reward_claims
    DROP CONSTRAINT reward_claims_period_key_check,
    ADD CONSTRAINT reward_claims_period_key_check CHECK (
        period_key ~ '^[0-9]{4}-W[0-9]{2}$'
        OR period_key ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    );

CREATE TABLE economy_system_state (
    singleton BOOLEAN PRIMARY KEY DEFAULT true,
    authority_epoch UUID NOT NULL DEFAULT uuidv7(),
    authority_version INTEGER NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT economy_system_state_singleton_check CHECK (singleton),
    CONSTRAINT economy_system_state_authority_version_check CHECK (authority_version > 0)
);

INSERT INTO economy_system_state (singleton) VALUES (true);

CREATE TABLE player_economies (
    account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    revision BIGINT NOT NULL DEFAULT 0,
    free_diamonds BIGINT NOT NULL DEFAULT 0,
    paid_diamonds BIGINT NOT NULL DEFAULT 0,
    module_tickets BIGINT NOT NULL DEFAULT 0,
    module_draw_count BIGINT NOT NULL DEFAULT 0,
    module_ticket_purchase_count BIGINT NOT NULL DEFAULT 0,
    module_item_sequence BIGINT NOT NULL DEFAULT 0,
    research_slot_two_unlocked BOOLEAN NOT NULL DEFAULT false,
    authority_state TEXT NOT NULL DEFAULT 'legacy_local',
    authority_version INTEGER NOT NULL DEFAULT 1,
    bootstrap_save_revision BIGINT,
    bootstrapped_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT player_economies_revision_check CHECK (revision >= 0),
    CONSTRAINT player_economies_free_diamonds_check CHECK (free_diamonds >= 0),
    CONSTRAINT player_economies_paid_diamonds_check CHECK (paid_diamonds >= 0),
    CONSTRAINT player_economies_module_tickets_check CHECK (module_tickets >= 0),
    CONSTRAINT player_economies_module_draw_count_check CHECK (module_draw_count >= 0),
    CONSTRAINT player_economies_ticket_purchase_count_check CHECK (module_ticket_purchase_count >= 0),
    CONSTRAINT player_economies_module_item_sequence_check CHECK (module_item_sequence >= 0),
    CONSTRAINT player_economies_authority_state_check CHECK (authority_state IN (
        'legacy_local', 'bootstrap_in_progress', 'server_authoritative'
    )),
    CONSTRAINT player_economies_authority_version_check CHECK (authority_version > 0),
    CONSTRAINT player_economies_bootstrap_state_check CHECK (
        (authority_state = 'server_authoritative'
            AND bootstrap_save_revision IS NOT NULL
            AND bootstrap_save_revision > 0
            AND bootstrapped_at IS NOT NULL)
        OR
        (authority_state <> 'server_authoritative'
            AND bootstrap_save_revision IS NULL
            AND bootstrapped_at IS NULL)
    )
);

CREATE TABLE economy_commands (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    idempotency_key UUID NOT NULL,
    command_type TEXT NOT NULL,
    request_hash BYTEA NOT NULL,
    expected_revision BIGINT,
    resulting_revision BIGINT NOT NULL,
    authority_epoch UUID NOT NULL,
    catalog_version INTEGER,
    rng_algorithm_version INTEGER,
    response_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT economy_commands_account_idempotency_key UNIQUE (account_id, idempotency_key),
    CONSTRAINT economy_commands_account_revision_key UNIQUE (account_id, resulting_revision),
    CONSTRAINT economy_commands_type_check CHECK (command_type IN (
        'legacy_bootstrap', 'turret_module_draw', 'turret_module_disassemble',
        'research_complete', 'research_slot_two_unlock', 'progression_effect_ack',
        'reward_claim', 'run_settlement', 'purchase_verify', 'operator_adjustment'
    )),
    CONSTRAINT economy_commands_hash_length_check CHECK (octet_length(request_hash) = 32),
    CONSTRAINT economy_commands_expected_revision_check CHECK (expected_revision IS NULL OR expected_revision >= 0),
    CONSTRAINT economy_commands_resulting_revision_check CHECK (
        resulting_revision > 0
        AND (expected_revision IS NULL OR resulting_revision = expected_revision + 1)
    ),
    CONSTRAINT economy_commands_catalog_version_check CHECK (catalog_version IS NULL OR catalog_version > 0),
    CONSTRAINT economy_commands_rng_version_check CHECK (rng_algorithm_version IS NULL OR rng_algorithm_version > 0),
    CONSTRAINT economy_commands_response_check CHECK (jsonb_typeof(response_payload) = 'object')
);

CREATE TABLE economy_ledger_entries (
    command_id UUID NOT NULL REFERENCES economy_commands(id) ON DELETE CASCADE,
    entry_order SMALLINT NOT NULL,
    asset_type TEXT NOT NULL,
    delta BIGINT NOT NULL,
    balance_after BIGINT NOT NULL,
    reason TEXT NOT NULL,
    PRIMARY KEY (command_id, entry_order),
    CONSTRAINT economy_ledger_entries_order_check CHECK (entry_order >= 0),
    CONSTRAINT economy_ledger_entries_asset_check CHECK (asset_type IN ('free_diamond', 'paid_diamond', 'module_ticket')),
    CONSTRAINT economy_ledger_entries_delta_check CHECK (delta <> 0),
    CONSTRAINT economy_ledger_entries_balance_check CHECK (balance_after >= 0),
    CONSTRAINT economy_ledger_entries_reason_check CHECK (reason <> '')
);

CREATE TABLE player_modules (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    legacy_item_id TEXT,
    turret_type TEXT NOT NULL,
    part TEXT NOT NULL,
    family TEXT NOT NULL,
    grade TEXT NOT NULL,
    options JSONB NOT NULL,
    acquired_order BIGINT NOT NULL,
    acquired_revision BIGINT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_by_command_id UUID NOT NULL REFERENCES economy_commands(id),
    disassembled_by_command_id UUID REFERENCES economy_commands(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    disassembled_at TIMESTAMPTZ,
    CONSTRAINT player_modules_account_order_key UNIQUE (account_id, acquired_order),
    CONSTRAINT player_modules_account_legacy_id_key UNIQUE (account_id, legacy_item_id),
    CONSTRAINT player_modules_turret_type_check CHECK (turret_type IN ('arrow', 'cannon', 'magic', 'frost', 'sniper', 'lightning')),
    CONSTRAINT player_modules_part_check CHECK (part IN ('core', 'barrel', 'frame')),
    CONSTRAINT player_modules_grade_check CHECK (grade IN ('normal', 'magic', 'rare', 'unique')),
    CONSTRAINT player_modules_options_check CHECK (jsonb_typeof(options) = 'array'),
    CONSTRAINT player_modules_acquired_order_check CHECK (acquired_order > 0),
    CONSTRAINT player_modules_acquired_revision_check CHECK (acquired_revision > 0),
    CONSTRAINT player_modules_status_check CHECK (status IN ('active', 'disassembled')),
    CONSTRAINT player_modules_disassembled_state_check CHECK (
        (status = 'active' AND disassembled_by_command_id IS NULL AND disassembled_at IS NULL)
        OR
        (status = 'disassembled' AND disassembled_by_command_id IS NOT NULL AND disassembled_at IS NOT NULL)
    )
);

CREATE INDEX player_modules_active_account_order_idx
    ON player_modules (account_id, acquired_order) WHERE status = 'active';

CREATE TABLE economy_reward_claims (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    reward_key TEXT NOT NULL,
    command_id UUID NOT NULL REFERENCES economy_commands(id) ON DELETE CASCADE,
    writer_generation BIGINT,
    origin_save_revision BIGINT,
    evidence JSONB NOT NULL,
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, reward_key),
    CONSTRAINT economy_reward_claims_writer_generation_check CHECK (writer_generation IS NULL OR writer_generation > 0),
    CONSTRAINT economy_reward_claims_origin_revision_check CHECK (origin_save_revision IS NULL OR origin_save_revision >= 0),
    CONSTRAINT economy_reward_claims_evidence_check CHECK (jsonb_typeof(evidence) = 'object')
);

CREATE TABLE economy_progression_effects (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    command_id UUID NOT NULL REFERENCES economy_commands(id) ON DELETE CASCADE,
    effect_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    applied_save_revision BIGINT,
    applied_by_command_id UUID REFERENCES economy_commands(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    applied_at TIMESTAMPTZ,
    CONSTRAINT economy_progression_effects_account_command_key UNIQUE (account_id, command_id),
    CONSTRAINT economy_progression_effects_type_check CHECK (effect_type = 'complete_research'),
    CONSTRAINT economy_progression_effects_payload_check CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT economy_progression_effects_status_check CHECK (status IN ('pending', 'applied')),
    CONSTRAINT economy_progression_effects_applied_state_check CHECK (
        (status = 'pending' AND applied_save_revision IS NULL AND applied_by_command_id IS NULL AND applied_at IS NULL)
        OR
        (status = 'applied' AND applied_save_revision > 0 AND applied_by_command_id IS NOT NULL AND applied_at IS NOT NULL)
    )
);

CREATE TABLE economy_bootstrap_backups (
    account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    command_id UUID NOT NULL UNIQUE REFERENCES economy_commands(id) ON DELETE CASCADE,
    source_save_revision BIGINT NOT NULL,
    progression JSONB NOT NULL,
    turret_modules JSONB NOT NULL,
    diagnostics JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT economy_bootstrap_backups_revision_check CHECK (source_save_revision > 0),
    CONSTRAINT economy_bootstrap_backups_progression_check CHECK (jsonb_typeof(progression) = 'object'),
    CONSTRAINT economy_bootstrap_backups_modules_check CHECK (jsonb_typeof(turret_modules) = 'object'),
    CONSTRAINT economy_bootstrap_backups_diagnostics_check CHECK (jsonb_typeof(diagnostics) = 'object')
);

---- create above / drop below ----

DROP TABLE economy_bootstrap_backups;
DROP TABLE economy_progression_effects;
DROP TABLE economy_reward_claims;
DROP INDEX player_modules_active_account_order_idx;
DROP TABLE player_modules;
DROP TABLE economy_ledger_entries;
DROP TABLE economy_commands;
DROP TABLE player_economies;
DROP TABLE economy_system_state;

-- 006 이전 서버가 해석할 수 없는 일간 수령 기록 제거.
DELETE FROM reward_claims
WHERE period_key ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';

ALTER TABLE reward_claims
    DROP CONSTRAINT reward_claims_period_key_check,
    ADD CONSTRAINT reward_claims_period_key_check
        CHECK (period_key ~ '^[0-9]{4}-W[0-9]{2}$');
