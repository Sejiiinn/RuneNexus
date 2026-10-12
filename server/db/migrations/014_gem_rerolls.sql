-- A single locked player_economies row serializes all wallet mutations.
ALTER TABLE player_economies
    ADD COLUMN gem_reset_tickets BIGINT NOT NULL DEFAULT 0 CHECK (gem_reset_tickets >= 0),
    ADD COLUMN gem_reroll_enabled BOOLEAN NOT NULL DEFAULT false;

-- This durable budget is deliberately independent of the replaceable activeRun save.
CREATE TABLE economy_gem_rerolls (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    run_id UUID NOT NULL,
    reward_wave INTEGER NOT NULL CHECK (reward_wave > 0 AND reward_wave < 40 AND reward_wave % 5 = 0),
    total_used INTEGER NOT NULL CHECK (total_used BETWEEN 1 AND 3),
    gem_options TEXT[] NOT NULL CHECK (
        cardinality(gem_options) = 3 AND array_ndims(gem_options) = 1
        AND array_lower(gem_options, 1) = 1 AND array_position(gem_options, NULL) IS NULL
        AND gem_options <@ ARRAY['attackSpeed','range','physicalDamage','elementalDamage',
            'lightWeapon','heavyWeapon','damageOverTime','explosion','chain','criticalChance',
            'aimSpeed','damageAmplifier','armorPiercing','multipleProjectiles']::TEXT[]
    ),
    command_id UUID NOT NULL REFERENCES economy_commands(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, run_id),
    CHECK (gem_options[1] <> gem_options[2] AND gem_options[1] <> gem_options[3] AND gem_options[2] <> gem_options[3])
);
ALTER TABLE economy_commands DROP CONSTRAINT economy_commands_type_check;
ALTER TABLE economy_commands ADD CONSTRAINT economy_commands_type_check CHECK (command_type IN (
    'legacy_bootstrap', 'turret_module_draw', 'turret_module_disassemble',
    'research_complete', 'research_slot_two_unlock', 'progression_effect_ack',
    'reward_claim', 'run_settlement', 'purchase_verify', 'operator_adjustment', 'gem_reroll'
));
ALTER TABLE economy_ledger_entries DROP CONSTRAINT economy_ledger_entries_asset_check;
ALTER TABLE economy_ledger_entries ADD CONSTRAINT economy_ledger_entries_asset_check
    CHECK (asset_type IN ('free_diamond', 'paid_diamond', 'module_ticket', 'gem_reset_ticket'));
ALTER TABLE mails ADD COLUMN gem_reset_tickets BIGINT NOT NULL DEFAULT 0 CHECK (gem_reset_tickets BETWEEN 0 AND 100000);
ALTER TABLE mails DROP CONSTRAINT mails_check1;
ALTER TABLE mails ADD CONSTRAINT mails_rewards_check CHECK (free_diamonds > 0 OR module_tickets > 0 OR gem_reset_tickets > 0);

---- create above / drop below ----

-- Currency, budgets and exact receipts cannot safely be rolled back.
SELECT 1;
