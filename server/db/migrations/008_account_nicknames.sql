ALTER TABLE accounts
    ADD COLUMN nickname TEXT COLLATE "C",
    ADD COLUMN nickname_tag TEXT COLLATE "C",
    ADD CONSTRAINT accounts_nickname_pair_check CHECK (
        (nickname IS NULL AND nickname_tag IS NULL) OR
        (nickname IS NOT NULL AND nickname_tag IS NOT NULL
         AND nickname ~ '^[가-힣A-Za-z0-9_]+$'
         AND char_length(nickname) >= 2
         AND char_length(nickname) + char_length(regexp_replace(nickname, '[^가-힣]', '', 'g')) <= 16
         AND nickname_tag ~ '^[0-9]{4}$')
    ),
    ADD CONSTRAINT accounts_nickname_tag_key UNIQUE (nickname, nickname_tag);

---- create above / drop below ----

ALTER TABLE accounts
    DROP CONSTRAINT accounts_nickname_tag_key,
    DROP CONSTRAINT accounts_nickname_pair_check,
    DROP COLUMN nickname_tag,
    DROP COLUMN nickname;
