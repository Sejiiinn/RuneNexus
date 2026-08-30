-- name: GetEconomySystemState :one
SELECT * FROM economy_system_state WHERE singleton = true;

-- name: RotateEconomyAuthorityEpoch :one
UPDATE economy_system_state
SET authority_epoch = uuidv7(), updated_at = now()
WHERE singleton = true
RETURNING *;

-- name: EnsurePlayerEconomy :exec
INSERT INTO player_economies (account_id)
VALUES ($1)
ON CONFLICT (account_id) DO NOTHING;

-- name: GetPlayerEconomy :one
SELECT * FROM player_economies WHERE account_id = $1;

-- name: GetPlayerEconomyForUpdate :one
SELECT * FROM player_economies WHERE account_id = $1 FOR UPDATE;

-- name: CompleteEconomyBootstrap :one
UPDATE player_economies
SET revision = $2,
    free_diamonds = $3,
    paid_diamonds = 0,
    module_tickets = $4,
    module_draw_count = $5,
    module_ticket_purchase_count = $6,
    module_item_sequence = $7,
    research_slot_two_unlocked = $8,
    authority_state = 'server_authoritative',
    authority_version = $9,
    bootstrap_save_revision = $10,
    bootstrapped_at = now(),
    updated_at = now()
WHERE account_id = $1 AND authority_state = 'legacy_local'
RETURNING *;

-- name: UpdatePlayerEconomy :one
UPDATE player_economies
SET revision = $2,
    free_diamonds = $3,
    paid_diamonds = $4,
    module_tickets = $5,
    module_draw_count = $6,
    module_ticket_purchase_count = $7,
    module_item_sequence = $8,
    research_slot_two_unlocked = $9,
    updated_at = now()
WHERE account_id = $1
  AND revision = $10
  AND authority_state = 'server_authoritative'
RETURNING *;

-- name: GetEconomyCommand :one
SELECT * FROM economy_commands
WHERE account_id = $1 AND idempotency_key = $2;

-- name: CreateEconomyCommand :one
INSERT INTO economy_commands (
    account_id, idempotency_key, command_type, request_hash,
    expected_revision, resulting_revision, authority_epoch,
    catalog_version, rng_algorithm_version, response_payload
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING *;

-- name: UpdateEconomyCommandResponse :one
UPDATE economy_commands
SET response_payload = $2
WHERE id = $1
RETURNING *;

-- name: CreateEconomyLedgerEntry :exec
INSERT INTO economy_ledger_entries (
    command_id, entry_order, asset_type, delta, balance_after, reason
) VALUES ($1, $2, $3, $4, $5, $6);

-- name: CreatePlayerModule :one
INSERT INTO player_modules (
    account_id, legacy_item_id, turret_type, part, family, grade,
    options, acquired_order, acquired_revision, created_by_command_id
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING *;

-- name: ListActivePlayerModules :many
SELECT * FROM player_modules
WHERE account_id = $1 AND status = 'active'
ORDER BY acquired_order;

-- name: GetActivePlayerModuleForUpdate :one
SELECT * FROM player_modules
WHERE account_id = $1 AND id = $2 AND status = 'active'
FOR UPDATE;

-- name: DisassemblePlayerModule :one
UPDATE player_modules
SET status = 'disassembled',
    disassembled_by_command_id = $3,
    disassembled_at = now()
WHERE account_id = $1 AND id = $2 AND status = 'active'
RETURNING *;

-- name: CreateEconomyRewardClaim :exec
INSERT INTO economy_reward_claims (
    account_id, reward_key, command_id, writer_generation,
    origin_save_revision, evidence
) VALUES ($1, $2, $3, $4, $5, $6);

-- name: GetEconomyRewardClaim :one
SELECT economy_reward_claims.*, economy_commands.response_payload
FROM economy_reward_claims
JOIN economy_commands ON economy_commands.id = economy_reward_claims.command_id
WHERE economy_reward_claims.account_id = $1
  AND economy_reward_claims.reward_key = $2;

-- name: ListEconomyRewardClaimKeys :many
SELECT reward_key FROM economy_reward_claims
WHERE account_id = $1
ORDER BY claimed_at;

-- name: CreateEconomyProgressionEffect :one
INSERT INTO economy_progression_effects (
    account_id, command_id, effect_type, payload
) VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: ListPendingEconomyProgressionEffects :many
SELECT * FROM economy_progression_effects
WHERE account_id = $1 AND status = 'pending'
ORDER BY created_at, id;

-- name: GetEconomyProgressionEffectForUpdate :one
SELECT * FROM economy_progression_effects
WHERE account_id = $1 AND id = $2
FOR UPDATE;

-- name: ApplyEconomyProgressionEffect :one
UPDATE economy_progression_effects
SET status = 'applied',
    applied_save_revision = $3,
    applied_by_command_id = $4,
    applied_at = now()
WHERE account_id = $1 AND id = $2 AND status = 'pending'
RETURNING *;

-- name: CreateEconomyBootstrapBackup :exec
INSERT INTO economy_bootstrap_backups (
    account_id, command_id, source_save_revision,
    progression, turret_modules, diagnostics
) VALUES ($1, $2, $3, $4, $5, $6);
