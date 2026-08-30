-- name: DeleteExpiredLegacySaveTransfers :execrows
DELETE FROM legacy_save_transfers
WHERE expires_at <= $1;

-- name: CreateLegacySaveTransfer :one
INSERT INTO legacy_save_transfers (
    token_hash,
    payload_hash,
    schema_version,
    client_saved_at_millis,
    preferences,
    progression,
    turret_modules,
    active_run,
    created_at,
    expires_at
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8,
    $9,
    $10
)
RETURNING *;

-- name: GetLegacySaveTransferForUpdate :one
SELECT *
FROM legacy_save_transfers
WHERE token_hash = $1
FOR UPDATE;

-- name: GetLegacySaveTransferReceipt :one
SELECT *
FROM legacy_save_transfer_receipts
WHERE token_hash = $1;

-- name: CreateLegacySaveTransferReceipt :one
INSERT INTO legacy_save_transfer_receipts (
    transfer_id,
    token_hash,
    payload_hash,
    consumed_account_id,
    consumed_at,
    result_revision,
    result_saved_at,
    replaced_existing_save,
    previous_schema_version,
    previous_revision,
    previous_client_saved_at_millis,
    previous_preferences,
    previous_progression,
    previous_turret_modules,
    previous_active_run
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8,
    $9,
    $10,
    $11,
    $12,
    $13,
    $14,
    $15
)
RETURNING *;

-- name: DeleteLegacySaveTransfer :exec
DELETE FROM legacy_save_transfers
WHERE id = $1;
