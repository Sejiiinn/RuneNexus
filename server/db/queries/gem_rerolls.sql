-- name: SetGemResetTickets :exec
UPDATE player_economies
SET gem_reset_tickets = $2, gem_reroll_enabled = true
WHERE account_id = $1;

-- name: GetGemReroll :one
SELECT * FROM economy_gem_rerolls WHERE account_id = $1 AND run_id = $2;

-- name: UpsertGemReroll :exec
INSERT INTO economy_gem_rerolls(account_id, run_id, reward_wave, total_used, gem_options, command_id)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (account_id, run_id) DO UPDATE
SET reward_wave = EXCLUDED.reward_wave, total_used = EXCLUDED.total_used,
    gem_options = EXCLUDED.gem_options, command_id = EXCLUDED.command_id, updated_at = now();
