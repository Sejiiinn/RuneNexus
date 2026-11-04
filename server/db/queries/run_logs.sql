-- name: InsertRunLog :execrows
WITH account AS (
    SELECT id FROM accounts
    WHERE id = sqlc.arg(account_id) AND deletion_requested_at IS NULL
    FOR SHARE
)
INSERT INTO run_logs (account_id, run_id, client_build, stage_id, payload)
SELECT account.id, sqlc.arg(run_id), sqlc.arg(client_build), sqlc.arg(stage_id), sqlc.arg(payload)
FROM account
ON CONFLICT (account_id, run_id) DO NOTHING;

-- name: DeleteRunLogsReceivedBefore :execrows
DELETE FROM run_logs WHERE received_at < sqlc.arg(before);
