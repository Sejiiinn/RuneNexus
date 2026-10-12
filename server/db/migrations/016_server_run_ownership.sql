-- Run identity and gem ownership outlive replaceable client checkpoints.
ALTER TABLE player_economies ADD COLUMN run_authority_enabled BOOLEAN NOT NULL DEFAULT false;

-- Older canonical checkpoints may predate client run IDs. Assign ownership
-- metadata once at migration without changing any combat, gem or reroll data.
-- The revision bump forces stale uploads to reload this server-issued ID.
WITH assigned AS (
    UPDATE save_active_runs SET payload=jsonb_set(payload,'{economyRunId}',to_jsonb(gen_random_uuid()::TEXT))
    WHERE jsonb_typeof(payload)='object' AND (
        NOT payload ? 'economyRunId' OR payload->'economyRunId'='null'::JSONB OR payload->>'economyRunId'='')
    RETURNING account_id
)
UPDATE save_headers SET revision=revision+1,updated_at=now()
FROM assigned WHERE save_headers.account_id=assigned.account_id;

-- Generation seven could commit its durable reroll budget before the client
-- uploaded the new usage counter. Reconcile that bounded counter before pinning
-- so the first generation-nine bootstrap PUT can preserve the canonical save
-- without waiting for a later economy refresh. Do not replay old candidates.
WITH reconciled AS (
    UPDATE save_active_runs AS active
    SET payload=jsonb_set(active.payload,'{gemRerollsUsed}',to_jsonb(budget.total_used))
    FROM economy_gem_rerolls AS budget
    WHERE active.account_id=budget.account_id
      AND lower(active.payload->>'economyRunId')=budget.run_id::TEXT
      AND budget.total_used > CASE
        WHEN NOT active.payload ? 'gemRerollsUsed' OR active.payload->'gemRerollsUsed'='null'::JSONB THEN 0
        WHEN jsonb_typeof(active.payload->'gemRerollsUsed')='number'
          AND active.payload->>'gemRerollsUsed' ~ '^[0-3]$'
          THEN (active.payload->>'gemRerollsUsed')::INTEGER
        ELSE NULL
      END
    RETURNING active.account_id
)
UPDATE save_headers SET revision=revision+1,updated_at=now()
FROM reconciled WHERE save_headers.account_id=reconciled.account_id;

-- Freeze migration provenance without copying a combat checkpoint. Fresh writes
-- must adopt this exact revision before changing it. Later guest/client uploads
-- never become eligible merely by having reached the canonical save endpoint.
CREATE TABLE account_run_authorities (
    account_id UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    adopted BOOLEAN NOT NULL DEFAULT false,
    legacy_source_revision BIGINT CHECK (legacy_source_revision >= 0),
    CHECK (NOT adopted OR legacy_source_revision IS NULL)
);
INSERT INTO account_run_authorities(account_id,legacy_source_revision)
SELECT active.account_id,header.revision FROM save_active_runs AS active
JOIN save_headers AS header ON header.account_id=active.account_id
WHERE jsonb_typeof(active.payload)='object' AND jsonb_typeof(active.payload->'economyRunId')='string'
    AND active.payload->>'economyRunId' <> '';

CREATE FUNCTION valid_run_gem_totals(value JSONB) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
    SELECT CASE WHEN jsonb_typeof(value) = 'object' THEN NOT EXISTS (
        SELECT 1 FROM jsonb_each(value) AS item
        WHERE item.key NOT IN ('attackSpeed','range','physicalDamage','elementalDamage',
            'lightWeapon','heavyWeapon','damageOverTime','explosion','chain','criticalChance',
            'aimSpeed','damageAmplifier','armorPiercing','multipleProjectiles')
            OR jsonb_typeof(item.value) <> 'number'
            OR item.value::TEXT !~ '^(0|[1-9][0-9]*)$'
            OR length(item.value::TEXT) > 19
            OR (length(item.value::TEXT) = 19 AND item.value::TEXT > '9223372036854775807')
    ) ELSE false END
$$;

CREATE FUNCTION valid_run_integer(value JSONB, maximum NUMERIC) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
    SELECT CASE WHEN jsonb_typeof(value) = 'number' AND value::TEXT ~ '^(0|[1-9][0-9]*)$'
        THEN value::TEXT::NUMERIC <= maximum ELSE false END
$$;

CREATE FUNCTION valid_run_gem_offer(value JSONB) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
    SELECT CASE WHEN jsonb_typeof(value) = 'object'
        AND jsonb_typeof(value->'gemOptions') = 'array' THEN COALESCE(
        jsonb_typeof(value->'offerId') = 'string'
        AND value->>'offerId' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        AND jsonb_typeof(value->'runId') = 'string'
        AND value->>'runId' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        AND valid_run_integer(value->'rewardWave',40)
        AND valid_run_integer(value->'revision',9223372036854775807) AND value->>'revision' <> '0'
        AND valid_run_integer(value->'totalUsed',3)
        AND valid_run_integer(value->'gemShards',9223372036854775807)
        AND valid_run_integer(value->'grantedShards',10)
        AND valid_run_gem_totals(value->'gemInventory')
        AND jsonb_typeof(value->'status') = 'string' AND value->>'status' IN ('pending','chosen')
        AND jsonb_typeof(value->'choice') = 'string'
        AND jsonb_typeof(value->'grantedGem') = 'string'
        AND jsonb_array_length(value->'gemOptions') = 3
        AND (SELECT count(DISTINCT gem) = 3 FROM jsonb_array_elements_text(value->'gemOptions') AS gem)
        AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(value->'gemOptions') AS gem WHERE
            jsonb_typeof(gem) <> 'string' OR gem #>> '{}' NOT IN
            ('attackSpeed','range','physicalDamage','elementalDamage','lightWeapon','heavyWeapon',
             'damageOverTime','explosion','chain','criticalChance','aimSpeed','damageAmplifier','armorPiercing','multipleProjectiles'))
        AND (NOT value ? 'kind' OR (jsonb_typeof(value->'kind')='string' AND value->>'kind' IN ('wave','purchase')))
        AND (NOT value ? 'economyRevision' OR valid_run_integer(value->'economyRevision',9223372036854775807))
        AND (NOT value ? 'legacyImported' OR jsonb_typeof(value->'legacyImported')='boolean')
        AND ((value->>'status'='pending' AND value->>'choice'='' AND value->>'grantedGem'='' AND value->>'grantedShards'='0')
            OR (value->>'status'='chosen' AND ((value->>'choice'='shards' AND value->>'grantedGem'='' AND value->>'grantedShards'='10')
            OR (value->'gemOptions' ? (value->>'choice') AND value->>'grantedGem'=value->>'choice' AND value->>'grantedShards'='0'))))
        , false) ELSE false END
$$;

CREATE TABLE economy_runs (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    run_id UUID NOT NULL,
    stage_number INTEGER NOT NULL CHECK (stage_number > 0),
    status TEXT NOT NULL CHECK (status IN ('active','closed')),
    owned_gems JSONB NOT NULL DEFAULT '{}' CHECK (valid_run_gem_totals(owned_gems)),
    total_used INTEGER NOT NULL DEFAULT 0 CHECK (total_used BETWEEN 0 AND 3),
    purchased_offer JSONB,
    purchase_sequence BIGINT NOT NULL DEFAULT 0 CHECK (purchase_sequence >= 0),
    legacy_imported BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id,run_id),
    CHECK ((purchase_sequence = 0) = (purchased_offer IS NULL)),
    CHECK ((status = 'active' AND closed_at IS NULL) OR (status = 'closed' AND closed_at IS NOT NULL)),
    CHECK (purchased_offer IS NULL OR COALESCE(valid_run_gem_offer(purchased_offer)
        AND purchased_offer->>'kind' = 'purchase' AND purchased_offer->>'runId' = run_id::TEXT
        AND valid_run_integer(purchased_offer->'purchaseSequence',9223372036854775807)
        AND purchased_offer->>'purchaseSequence' = purchase_sequence::TEXT AND purchase_sequence > 0
        AND jsonb_typeof(purchased_offer->'returnPhase')='string'
        AND purchased_offer->>'returnPhase' IN ('preparation','wave')
        AND purchased_offer->>'choice' <> 'shards',false))
);
CREATE UNIQUE INDEX economy_runs_one_active ON economy_runs(account_id) WHERE status = 'active';

ALTER TABLE economy_gem_offers ADD CONSTRAINT economy_gem_offers_payload_coherent CHECK (
    COALESCE(valid_run_gem_offer(payload) AND payload->>'offerId'=offer_id::TEXT
        AND payload->>'runId'=run_id::TEXT AND payload->>'rewardWave'=reward_wave::TEXT
        AND payload->>'revision'=revision::TEXT AND (NOT payload ? 'kind' OR payload->>'kind'='wave'),false)
);

ALTER TABLE economy_commands DROP CONSTRAINT economy_commands_type_check;
ALTER TABLE economy_commands ADD CONSTRAINT economy_commands_type_check CHECK (command_type IN (
    'legacy_bootstrap', 'turret_module_draw', 'turret_module_disassemble',
    'research_complete', 'research_slot_two_unlock', 'progression_effect_ack',
    'reward_claim', 'run_settlement', 'purchase_verify', 'operator_adjustment',
    'gem_reroll', 'gem_offer', 'gem_choose', 'gem_purchase', 'run_start', 'run_close'
));

---- create above / drop below ----
-- Permanent tombstones and exact ownership cannot safely be rolled back.
SELECT 1;
