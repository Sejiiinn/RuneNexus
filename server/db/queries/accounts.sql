-- name: CreateAccount :one
INSERT INTO accounts DEFAULT VALUES
RETURNING *;

-- name: GetAccount :one
SELECT *
FROM accounts
WHERE id = $1;

-- name: GetAccountByIdentity :one
SELECT a.*
FROM accounts AS a
JOIN auth_identities AS identity ON identity.account_id = a.id
WHERE identity.provider = $1
  AND identity.subject = $2;

-- name: LockAuthIdentity :exec
SELECT pg_advisory_xact_lock(
    hashtextextended(
        sqlc.arg(provider)::text || ':' || sqlc.arg(subject)::text,
        0
    )
);

-- name: CreateAuthIdentity :one
INSERT INTO auth_identities (
    account_id,
    provider,
    subject
) VALUES (
    $1,
    $2,
    $3
)
RETURNING *;

-- name: GetAuthIdentityForUpdate :one
SELECT *
FROM auth_identities
WHERE provider = $1
  AND subject = $2
FOR UPDATE;

-- name: TouchAuthIdentity :one
UPDATE auth_identities
SET last_verified_at = now()
WHERE id = $1
RETURNING *;

-- name: UpdateAccountStatus :one
UPDATE accounts
SET status = $2,
    deletion_requested_at = $3,
    updated_at = now()
WHERE id = $1
RETURNING *;

-- name: GetAccountForUpdate :one
SELECT * FROM accounts WHERE id = $1 FOR UPDATE;

-- name: LockAccountNickname :exec
SELECT pg_advisory_xact_lock(hashtextextended(sqlc.arg(nickname)::text, 731));

-- name: ListAccountNicknameTags :many
SELECT nickname_tag::text FROM accounts WHERE nickname = $1;

-- name: SetAccountNickname :one
UPDATE accounts SET nickname = $2, nickname_tag = $3, updated_at = now()
WHERE id = $1 AND nickname IS NULL
RETURNING *;
