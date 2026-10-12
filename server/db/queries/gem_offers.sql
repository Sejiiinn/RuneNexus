-- name: GetGemOffer :one
SELECT * FROM economy_gem_offers WHERE account_id = $1 AND run_id = $2 AND reward_wave = $3;

-- name: GetLatestGemOffer :one
SELECT * FROM economy_gem_offers WHERE account_id = $1 AND run_id = $2 ORDER BY reward_wave DESC LIMIT 1;

-- name: CreateGemOffer :exec
INSERT INTO economy_gem_offers(account_id, run_id, reward_wave, offer_id, revision, payload, command_id)
VALUES ($1, $2, $3, $4, $5, $6, $7);

-- name: UpdateGemOffer :execrows
UPDATE economy_gem_offers SET revision = $4, payload = $5, command_id = $6, updated_at = now()
WHERE account_id = $1 AND run_id = $2 AND reward_wave = $3 AND payload->>'status' = 'pending';

-- name: EnableGemOffers :exec
UPDATE player_economies SET gem_offer_enabled = true WHERE account_id = $1;

-- name: ListRunGemGrants :many
-- Every chosen wave contributes exactly one gem, or zero for the shard alternative.
-- Retain grants from every earlier wave, even when the latest offer is pending.
SELECT (payload->>'grantedGem')::TEXT AS gem, count(*)::BIGINT AS quantity
FROM economy_gem_offers
WHERE account_id = $1 AND run_id = $2
  AND payload->>'status' = 'chosen' AND payload->>'grantedGem' <> ''
GROUP BY (payload->>'grantedGem')::TEXT;
