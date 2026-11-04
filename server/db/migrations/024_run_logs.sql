-- Analysis-only run summaries. Never read by rewards, leaderboards or economy.
CREATE TABLE run_logs (
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    run_id UUID NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    client_build INTEGER NOT NULL CHECK (client_build >= 0),
    stage_id INTEGER NOT NULL CHECK (stage_id BETWEEN 1 AND 9999),
    payload JSONB NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
    PRIMARY KEY (account_id, run_id)
);
CREATE INDEX run_logs_received_at ON run_logs (received_at);

-- Any path that records a deletion request also drops the account's run logs.
-- Inserts lock the account row FOR SHARE, so they serialize with this update.
CREATE FUNCTION delete_run_logs_on_deletion_request() RETURNS TRIGGER
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
    DELETE FROM run_logs WHERE account_id = NEW.id;
    RETURN NEW;
END
$$;

CREATE TRIGGER accounts_deletion_request_run_logs
    AFTER UPDATE OF deletion_requested_at ON accounts
    FOR EACH ROW WHEN (NEW.deletion_requested_at IS NOT NULL)
    EXECUTE FUNCTION delete_run_logs_on_deletion_request();

---- create above / drop below ----

DROP TRIGGER accounts_deletion_request_run_logs ON accounts;
DROP FUNCTION delete_run_logs_on_deletion_request();
DROP TABLE run_logs;
