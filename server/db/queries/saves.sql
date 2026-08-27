-- name: EnsureSaveHeader :exec
INSERT INTO save_headers (
    account_id,
    schema_version,
    revision,
    client_saved_at_millis
) VALUES (
    $1,
    1,
    0,
    0
)
ON CONFLICT (account_id) DO NOTHING;

-- name: EnsureSaveWriterState :exec
INSERT INTO save_writer_states (account_id)
VALUES ($1)
ON CONFLICT (account_id) DO NOTHING;

-- name: GetSaveWriterStateForUpdate :one
SELECT *
FROM save_writer_states
WHERE account_id = $1
FOR UPDATE;

-- name: GetSaveWriterClaim :one
SELECT *
FROM save_writer_claims
WHERE account_id = $1
  AND idempotency_key = $2;

-- name: AdvanceSaveWriter :one
UPDATE save_writer_states
SET generation = generation + 1,
    session_id = $2,
    client_instance_id = $3,
    claimed_at = now(),
    updated_at = now()
WHERE account_id = $1
RETURNING *;

-- name: CreateSaveWriterClaim :one
INSERT INTO save_writer_claims (
    account_id,
    idempotency_key,
    session_id,
    client_instance_id,
    request_hash,
    resulting_generation,
    result_claimed_at
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7
)
RETURNING *;

-- name: GetSaveHeaderForUpdate :one
SELECT *
FROM save_headers
WHERE account_id = $1
FOR UPDATE;

-- name: GetSaveRequest :one
SELECT *
FROM save_requests
WHERE account_id = $1
  AND idempotency_key = $2;

-- name: UpsertSavePreferences :exec
INSERT INTO save_preferences (account_id, payload)
VALUES ($1, $2)
ON CONFLICT (account_id) DO UPDATE
SET payload = EXCLUDED.payload;

-- name: UpsertSaveProgression :exec
INSERT INTO save_progression (account_id, payload)
VALUES ($1, $2)
ON CONFLICT (account_id) DO UPDATE
SET payload = EXCLUDED.payload;

-- name: UpsertSaveTurretModules :exec
INSERT INTO save_turret_modules (account_id, payload)
VALUES ($1, $2)
ON CONFLICT (account_id) DO UPDATE
SET payload = EXCLUDED.payload;

-- name: UpsertSaveActiveRun :exec
INSERT INTO save_active_runs (account_id, payload)
VALUES ($1, $2)
ON CONFLICT (account_id) DO UPDATE
SET payload = EXCLUDED.payload;

-- name: DeleteSaveActiveRun :exec
DELETE FROM save_active_runs
WHERE account_id = $1;

-- name: AdvanceSaveHeader :one
UPDATE save_headers
SET schema_version = $2,
    client_saved_at_millis = $3,
    revision = revision + 1,
    updated_at = now()
WHERE account_id = $1
  AND revision = $4
RETURNING revision, updated_at;

-- name: CreateSaveRequest :one
INSERT INTO save_requests (
    account_id,
    idempotency_key,
    request_hash,
    writer_generation,
    expected_revision,
    resulting_revision,
    result_saved_at
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7
)
RETURNING *;

-- name: GetSaveSnapshot :one
SELECT
    header.account_id,
    header.schema_version,
    header.revision,
    header.client_saved_at_millis,
    header.created_at,
    header.updated_at,
    preferences.payload AS preferences,
    progression.payload AS progression,
    turret_modules.payload AS turret_modules,
    active_run.payload AS active_run
FROM save_headers AS header
JOIN save_preferences AS preferences
    ON preferences.account_id = header.account_id
JOIN save_progression AS progression
    ON progression.account_id = header.account_id
JOIN save_turret_modules AS turret_modules
    ON turret_modules.account_id = header.account_id
LEFT JOIN save_active_runs AS active_run
    ON active_run.account_id = header.account_id
WHERE header.account_id = $1;
