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

-- name: DeleteLegacySaveTransfer :exec
DELETE FROM legacy_save_transfers
WHERE id = $1;
