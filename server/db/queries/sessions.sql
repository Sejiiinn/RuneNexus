-- name: CreateSession :one
INSERT INTO sessions (
    account_id,
    access_token_hash,
    access_expires_at,
    refresh_expires_at
) VALUES (
    $1,
    $2,
    $3,
    $4
)
RETURNING *;

-- name: CreateRefreshToken :one
INSERT INTO refresh_tokens (
    session_id,
    token_hash,
    parent_token_id
) VALUES (
    $1,
    $2,
    $3
)
RETURNING *;

-- name: GetActiveSessionByAccessTokenHash :one
SELECT
    session.id,
    session.account_id,
    session.access_expires_at,
    session.refresh_expires_at,
    session.created_at,
    session.last_used_at
FROM sessions AS session
JOIN accounts AS account ON account.id = session.account_id
WHERE session.access_token_hash = $1
  AND session.revoked_at IS NULL
  AND session.access_expires_at > now()
  AND account.status = 'active';

-- name: GetRefreshTokenForUpdate :one
SELECT
    token.id,
    token.session_id,
    token.parent_token_id,
    token.created_at,
    token.consumed_at,
    token.revoked_at,
    session.account_id,
    session.access_expires_at,
    session.refresh_expires_at,
    session.revoked_at AS session_revoked_at,
    account.status AS account_status
FROM refresh_tokens AS token
JOIN sessions AS session ON session.id = token.session_id
JOIN accounts AS account ON account.id = session.account_id
WHERE token.token_hash = $1
FOR UPDATE OF token, session;

-- name: ConsumeRefreshToken :one
UPDATE refresh_tokens
SET consumed_at = now()
WHERE id = $1
  AND consumed_at IS NULL
  AND revoked_at IS NULL
RETURNING *;

-- name: RotateSessionAccessToken :one
UPDATE sessions
SET access_token_hash = $2,
    access_expires_at = $3,
    last_used_at = now()
WHERE id = $1
  AND revoked_at IS NULL
RETURNING *;

-- name: TouchSession :exec
UPDATE sessions
SET last_used_at = now()
WHERE id = $1
  AND revoked_at IS NULL;

-- name: RevokeRefreshTokensForSession :execrows
UPDATE refresh_tokens
SET revoked_at = COALESCE(revoked_at, now())
WHERE session_id = $1
  AND revoked_at IS NULL;

-- name: RevokeSession :execrows
UPDATE sessions
SET revoked_at = COALESCE(revoked_at, now())
WHERE id = $1
  AND revoked_at IS NULL;

-- name: RevokeSessionsForAccount :execrows
UPDATE sessions
SET revoked_at = COALESCE(revoked_at, now())
WHERE account_id = $1
  AND revoked_at IS NULL;
