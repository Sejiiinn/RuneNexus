-- name: GetRewardClaimByIdempotencyKey :one
SELECT *
FROM reward_claims
WHERE account_id = $1
  AND idempotency_key = $2;

-- name: GetRewardClaimByRewardKey :one
SELECT *
FROM reward_claims
WHERE account_id = $1
  AND reward_key = $2;

-- name: CreateRewardClaim :one
INSERT INTO reward_claims (
    account_id,
    reward_key,
    period_key,
    week_key,
    reward_type,
    quest_type,
    idempotency_key,
    request_hash,
    diamond_amount,
    module_ticket_amount,
    writer_generation,
    source_save_revision,
    evidence
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
    $13
)
RETURNING *;
