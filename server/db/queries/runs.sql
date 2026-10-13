-- name: GetEconomyRun :one
SELECT * FROM economy_runs WHERE account_id = $1 AND run_id = $2;

-- name: GetEconomyRunForUpdate :one
SELECT * FROM economy_runs WHERE account_id = $1 AND run_id = $2 FOR UPDATE;

-- name: GetActiveEconomyRun :one
SELECT * FROM economy_runs WHERE account_id = $1 AND status = 'active';

-- name: GetActiveEconomyRunForUpdate :one
SELECT * FROM economy_runs WHERE account_id = $1 AND status = 'active' FOR UPDATE;

-- name: CreateEconomyRun :one
INSERT INTO economy_runs(account_id,run_id,stage_number,status,owned_gems,total_used,legacy_imported)
VALUES ($1,$2,$3,'active',$4,$5,$6) RETURNING *;

-- name: SetEconomyRunGemDeck :execrows
UPDATE economy_runs SET gem_deck=$3,updated_at=now()
WHERE account_id=$1 AND run_id=$2 AND status='active' AND gem_deck IS NULL;

-- name: UpdateEconomyRun :execrows
UPDATE economy_runs SET owned_gems=$3,total_used=$4,purchased_offer=$5,purchase_sequence=$6,updated_at=now()
WHERE account_id=$1 AND run_id=$2 AND status='active';

-- name: CloseEconomyRun :execrows
UPDATE economy_runs SET status='closed',closed_at=now(),updated_at=now()
WHERE account_id=$1 AND run_id=$2 AND status='active';

-- name: EnableRunAuthority :exec
UPDATE player_economies SET run_authority_enabled=true WHERE account_id=$1;

-- name: EnsureAccountRunAuthority :exec
INSERT INTO account_run_authorities(account_id) VALUES($1) ON CONFLICT DO NOTHING;

-- name: GetAccountRunAuthority :one
SELECT * FROM account_run_authorities WHERE account_id=$1;

-- name: MarkAccountRunAdopted :exec
UPDATE account_run_authorities SET adopted=true,legacy_source_revision=NULL WHERE account_id=$1;
