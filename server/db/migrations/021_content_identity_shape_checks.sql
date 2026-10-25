-- Content identities (gem and turret names) are validated by the server from the
-- generated content registry. The schema keeps only their shape, so new content
-- needs no migration. Every existing row already satisfies the looser checks.
CREATE OR REPLACE FUNCTION valid_run_gem_totals(value JSONB) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = public AS $$
    SELECT CASE WHEN jsonb_typeof(value) = 'object' THEN NOT EXISTS (
        SELECT 1 FROM jsonb_each(value) AS item
        WHERE item.key !~ '^[a-z][A-Za-z0-9]{0,63}$'
            OR jsonb_typeof(item.value) <> 'number'
            OR item.value::TEXT !~ '^(0|[1-9][0-9]*)$'
            OR length(item.value::TEXT) > 19
            OR (length(item.value::TEXT) = 19 AND item.value::TEXT > '9223372036854775807')
    ) ELSE false END
$$;

CREATE OR REPLACE FUNCTION valid_run_gem_offer(value JSONB) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = public AS $$
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
            jsonb_typeof(gem) <> 'string' OR gem #>> '{}' !~ '^[a-z][A-Za-z0-9]{0,63}$')
        AND (NOT value ? 'kind' OR (jsonb_typeof(value->'kind')='string' AND value->>'kind' IN ('wave','purchase')))
        AND (NOT value ? 'economyRevision' OR valid_run_integer(value->'economyRevision',9223372036854775807))
        AND (NOT value ? 'legacyImported' OR jsonb_typeof(value->'legacyImported')='boolean')
        AND ((value->>'status'='pending' AND value->>'choice'='' AND value->>'grantedGem'='' AND value->>'grantedShards'='0')
            OR (value->>'status'='chosen' AND ((value->>'choice'='shards' AND value->>'grantedGem'='' AND value->>'grantedShards'='10')
            OR (value->'gemOptions' ? (value->>'choice') AND value->>'grantedGem'=value->>'choice' AND value->>'grantedShards'='0'))))
        , false) ELSE false END
$$;

ALTER TABLE economy_gem_rerolls DROP CONSTRAINT economy_gem_rerolls_gem_options_check;
ALTER TABLE economy_gem_rerolls ADD CONSTRAINT economy_gem_rerolls_gem_options_check CHECK (
    cardinality(gem_options) = 3 AND array_ndims(gem_options) = 1
        AND array_lower(gem_options, 1) = 1 AND array_position(gem_options, NULL) IS NULL
        -- Identities cannot contain commas, so the joined form checks each element.
        AND array_to_string(gem_options, ',') ~ '^[a-z][A-Za-z0-9]{0,63}(,[a-z][A-Za-z0-9]{0,63}){2}$'
);

ALTER TABLE player_modules DROP CONSTRAINT player_modules_turret_type_check;
ALTER TABLE player_modules ADD CONSTRAINT player_modules_turret_type_check
    CHECK (turret_type ~ '^[a-z][A-Za-z0-9]{0,63}$');

---- create above / drop below ----
-- Restores the 019/020 name lists. This fails, and rolls back, once any row
-- holds content added after 020; such rows are never deleted to force it.
CREATE OR REPLACE FUNCTION valid_run_gem_totals(value JSONB) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = public AS $$
    SELECT CASE WHEN jsonb_typeof(value) = 'object' THEN NOT EXISTS (
        SELECT 1 FROM jsonb_each(value) AS item
        WHERE item.key NOT IN ('attackSpeed','range','physicalDamage','elementalDamage',
            'lightWeapon','heavyWeapon','damageOverTime','explosion','chain','criticalChance',
            'aimSpeed','damageAmplifier','armorPiercing','multipleProjectiles','piercing','poisonDamage')
            OR jsonb_typeof(item.value) <> 'number'
            OR item.value::TEXT !~ '^(0|[1-9][0-9]*)$'
            OR length(item.value::TEXT) > 19
            OR (length(item.value::TEXT) = 19 AND item.value::TEXT > '9223372036854775807')
    ) ELSE false END
$$;

CREATE OR REPLACE FUNCTION valid_run_gem_offer(value JSONB) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = public AS $$
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
             'damageOverTime','explosion','chain','criticalChance','aimSpeed','damageAmplifier','armorPiercing','multipleProjectiles','piercing','poisonDamage'))
        AND (NOT value ? 'kind' OR (jsonb_typeof(value->'kind')='string' AND value->>'kind' IN ('wave','purchase')))
        AND (NOT value ? 'economyRevision' OR valid_run_integer(value->'economyRevision',9223372036854775807))
        AND (NOT value ? 'legacyImported' OR jsonb_typeof(value->'legacyImported')='boolean')
        AND ((value->>'status'='pending' AND value->>'choice'='' AND value->>'grantedGem'='' AND value->>'grantedShards'='0')
            OR (value->>'status'='chosen' AND ((value->>'choice'='shards' AND value->>'grantedGem'='' AND value->>'grantedShards'='10')
            OR (value->'gemOptions' ? (value->>'choice') AND value->>'grantedGem'=value->>'choice' AND value->>'grantedShards'='0'))))
        , false) ELSE false END
$$;

ALTER TABLE economy_gem_rerolls DROP CONSTRAINT economy_gem_rerolls_gem_options_check;
ALTER TABLE economy_gem_rerolls ADD CONSTRAINT economy_gem_rerolls_gem_options_check CHECK (
    cardinality(gem_options) = 3 AND array_ndims(gem_options) = 1
        AND array_lower(gem_options, 1) = 1 AND array_position(gem_options, NULL) IS NULL
        AND gem_options <@ ARRAY['attackSpeed','range','physicalDamage','elementalDamage',
            'lightWeapon','heavyWeapon','damageOverTime','explosion','chain','criticalChance',
            'aimSpeed','damageAmplifier','armorPiercing','multipleProjectiles','piercing','poisonDamage']::TEXT[]
);

ALTER TABLE player_modules DROP CONSTRAINT player_modules_turret_type_check;
ALTER TABLE player_modules ADD CONSTRAINT player_modules_turret_type_check
    CHECK (turret_type IN ('arrow', 'cannon', 'magic', 'frost', 'sniper', 'lightning', 'poison'));
