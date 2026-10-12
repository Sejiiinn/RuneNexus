-- Wave rewards are durable commands. Client saves still own combat progression
-- and purchased 20-shard choices; they cannot create/reopen these wave offers.
ALTER TABLE player_economies ADD COLUMN gem_offer_enabled BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE economy_gem_rerolls DROP CONSTRAINT economy_gem_rerolls_total_used_check;
ALTER TABLE economy_gem_rerolls ADD CONSTRAINT economy_gem_rerolls_total_used_check CHECK (total_used BETWEEN 0 AND 3);
CREATE TABLE economy_gem_offers (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    run_id UUID NOT NULL,
    reward_wave INTEGER NOT NULL CHECK (reward_wave > 0 AND reward_wave < 40 AND reward_wave % 5 = 0),
    offer_id UUID NOT NULL UNIQUE,
    revision BIGINT NOT NULL CHECK (revision > 0),
    payload JSONB NOT NULL CHECK (jsonb_typeof(payload) = 'object'
        AND payload->>'status' IN ('pending', 'chosen')
        AND payload ? 'choice' AND payload ? 'gemOptions'),
    command_id UUID NOT NULL REFERENCES economy_commands(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, run_id, reward_wave)
);
ALTER TABLE economy_commands DROP CONSTRAINT economy_commands_type_check;
ALTER TABLE economy_commands ADD CONSTRAINT economy_commands_type_check CHECK (command_type IN (
    'legacy_bootstrap', 'turret_module_draw', 'turret_module_disassemble',
    'research_complete', 'research_slot_two_unlock', 'progression_effect_ack',
    'reward_claim', 'run_settlement', 'purchase_verify', 'operator_adjustment',
    'gem_reroll', 'gem_offer', 'gem_choose'
));

---- create above / drop below ----
-- Offers, immutable selections, budgets and exact receipts must not be lost.
SELECT 1;
