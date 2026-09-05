ALTER TABLE sessions ALTER COLUMN refresh_expires_at DROP NOT NULL;

-- 소비 이력은 유지하고 응답 복구용 암호문만 짧게 보존.
CREATE TABLE refresh_receipts (
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    request_key VARCHAR(64) NOT NULL,
    parent_token_id UUID NOT NULL REFERENCES refresh_tokens(id),
    child_token_id UUID NOT NULL REFERENCES refresh_tokens(id),
    ciphertext BYTEA,
    expires_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (session_id, request_key),
    UNIQUE (parent_token_id)
);
CREATE INDEX refresh_receipts_expiry_idx ON refresh_receipts(expires_at)
    WHERE ciphertext IS NOT NULL;

---- create above / drop below ----

DROP TABLE refresh_receipts;
-- 영속 세션이 남아 있으면 다운그레이드 거부. 자동 만료/삭제 금지.
ALTER TABLE sessions ALTER COLUMN refresh_expires_at SET NOT NULL;
