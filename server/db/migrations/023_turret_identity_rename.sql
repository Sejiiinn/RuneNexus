-- Turret ids now match their display names: arrow → machinegun (기관총),
-- magic → flame (화염). Stored saves, module rows, bootstrap backups and legacy transfers are
-- rewritten in place; revisions are unchanged because the content is the same.
-- Client compatibility 17 reads both spellings, so its own unsynced local
-- saves keep working. Older clients would drop the new ids on read, so every
-- existing account's writer floor is raised to 17 and the deployment also
-- sets MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION=17 for new accounts.
-- Kept after the migration so the schema test can exercise the rewrite.
CREATE FUNCTION rename_turret_ids(value JSONB, parent TEXT, renames JSONB) RETURNS JSONB
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    result JSONB;
    field TEXT;
    item JSONB;
BEGIN
    CASE jsonb_typeof(value)
    WHEN 'object' THEN
        result := '{}'::JSONB;
        FOR field, item IN SELECT * FROM jsonb_each(value) LOOP
            -- A turret's own type, or a module's turret; enemies also have "type".
            IF (field = 'turretType' OR (field = 'type' AND parent = 'turrets'))
                    AND jsonb_typeof(item) = 'string' AND renames ? (item #>> '{}') THEN
                item := renames -> (item #>> '{}');
            ELSE
                item := rename_turret_ids(item, field, renames);
            END IF;
            result := result || jsonb_build_object(field, item);
        END LOOP;
        RETURN result;
    WHEN 'array' THEN
        SELECT COALESCE(jsonb_agg(CASE
                WHEN parent = 'challengeTurretTypes' AND jsonb_typeof(element) = 'string'
                    AND renames ? (element #>> '{}') THEN renames -> (element #>> '{}')
                WHEN parent = 'grandfatherUnlocks' AND jsonb_typeof(element) = 'string'
                    AND starts_with(element #>> '{}', 'turret:') AND renames ? substr(element #>> '{}', 8)
                    THEN to_jsonb('turret:' || (renames ->> substr(element #>> '{}', 8)))
                ELSE rename_turret_ids(element, parent, renames) END ORDER BY position), '[]'::JSONB)
            INTO result FROM jsonb_array_elements(value) WITH ORDINALITY AS entry(element, position);
        RETURN result;
    ELSE
        RETURN value;
    END CASE;
END
$$;

CREATE FUNCTION apply_turret_id_renames(renames JSONB) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE save_progression SET payload = rename_turret_ids(payload, '', renames)
        WHERE payload <> rename_turret_ids(payload, '', renames);
    UPDATE save_turret_modules SET payload = rename_turret_ids(payload, '', renames)
        WHERE payload <> rename_turret_ids(payload, '', renames);
    UPDATE save_active_runs SET payload = rename_turret_ids(payload, '', renames)
        WHERE payload <> rename_turret_ids(payload, '', renames);
    UPDATE economy_bootstrap_backups
        SET progression = rename_turret_ids(progression, '', renames),
            turret_modules = rename_turret_ids(turret_modules, '', renames)
        WHERE progression <> rename_turret_ids(progression, '', renames)
            OR turret_modules <> rename_turret_ids(turret_modules, '', renames);
    -- Unconsumed transfer tokens and replaced-save receipts still feed bootstrap.
    UPDATE legacy_save_transfers
        SET progression = rename_turret_ids(progression, '', renames),
            turret_modules = rename_turret_ids(turret_modules, '', renames),
            active_run = rename_turret_ids(active_run, '', renames)
        WHERE progression <> rename_turret_ids(progression, '', renames)
            OR turret_modules <> rename_turret_ids(turret_modules, '', renames)
            OR active_run IS DISTINCT FROM rename_turret_ids(active_run, '', renames);
    UPDATE legacy_save_transfer_receipts
        SET previous_progression = rename_turret_ids(previous_progression, '', renames),
            previous_turret_modules = rename_turret_ids(previous_turret_modules, '', renames),
            previous_active_run = rename_turret_ids(previous_active_run, '', renames)
        WHERE previous_progression IS DISTINCT FROM rename_turret_ids(previous_progression, '', renames)
            OR previous_turret_modules IS DISTINCT FROM rename_turret_ids(previous_turret_modules, '', renames)
            OR previous_active_run IS DISTINCT FROM rename_turret_ids(previous_active_run, '', renames);
    UPDATE player_modules SET turret_type = renames ->> turret_type WHERE renames ? turret_type;
END
$$;

SELECT apply_turret_id_renames('{"arrow": "machinegun", "magic": "flame"}');

UPDATE save_writer_states SET client_generation_floor = 17 WHERE client_generation_floor < 17;

DROP FUNCTION apply_turret_id_renames(JSONB);

---- create above / drop below ----
-- Restores the old ids for a rollback to a compatibility-16 server. Writer
-- floors stay raised: lowering them could let a client drop newer content.
CREATE FUNCTION apply_turret_id_renames(renames JSONB) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE save_progression SET payload = rename_turret_ids(payload, '', renames)
        WHERE payload <> rename_turret_ids(payload, '', renames);
    UPDATE save_turret_modules SET payload = rename_turret_ids(payload, '', renames)
        WHERE payload <> rename_turret_ids(payload, '', renames);
    UPDATE save_active_runs SET payload = rename_turret_ids(payload, '', renames)
        WHERE payload <> rename_turret_ids(payload, '', renames);
    UPDATE economy_bootstrap_backups
        SET progression = rename_turret_ids(progression, '', renames),
            turret_modules = rename_turret_ids(turret_modules, '', renames)
        WHERE progression <> rename_turret_ids(progression, '', renames)
            OR turret_modules <> rename_turret_ids(turret_modules, '', renames);
    -- Unconsumed transfer tokens and replaced-save receipts still feed bootstrap.
    UPDATE legacy_save_transfers
        SET progression = rename_turret_ids(progression, '', renames),
            turret_modules = rename_turret_ids(turret_modules, '', renames),
            active_run = rename_turret_ids(active_run, '', renames)
        WHERE progression <> rename_turret_ids(progression, '', renames)
            OR turret_modules <> rename_turret_ids(turret_modules, '', renames)
            OR active_run IS DISTINCT FROM rename_turret_ids(active_run, '', renames);
    UPDATE legacy_save_transfer_receipts
        SET previous_progression = rename_turret_ids(previous_progression, '', renames),
            previous_turret_modules = rename_turret_ids(previous_turret_modules, '', renames),
            previous_active_run = rename_turret_ids(previous_active_run, '', renames)
        WHERE previous_progression IS DISTINCT FROM rename_turret_ids(previous_progression, '', renames)
            OR previous_turret_modules IS DISTINCT FROM rename_turret_ids(previous_turret_modules, '', renames)
            OR previous_active_run IS DISTINCT FROM rename_turret_ids(previous_active_run, '', renames);
    UPDATE player_modules SET turret_type = renames ->> turret_type WHERE renames ? turret_type;
END
$$;

SELECT apply_turret_id_renames('{"machinegun": "arrow", "flame": "magic"}');

DROP FUNCTION apply_turret_id_renames(JSONB);
DROP FUNCTION rename_turret_ids(JSONB, TEXT, JSONB);
