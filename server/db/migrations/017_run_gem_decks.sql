-- Generation-ten runs pre-commit every wave candidate chain and purchase choice
-- at start. Commands consume the same server rows, so clients present them
-- immediately and confirm in the background. Older runs keep NULL decks.
ALTER TABLE economy_runs ADD COLUMN gem_deck JSONB CHECK (
    gem_deck IS NULL OR (jsonb_typeof(gem_deck) = 'object'
        AND gem_deck->>'version' = '1'
        AND gem_deck->>'runId' = run_id::TEXT
        AND jsonb_typeof(gem_deck->'waves') = 'object'
        AND jsonb_typeof(gem_deck->'purchases') = 'array')
);

---- create above / drop below ----
-- Issued decks determine already presented choices and must not be lost.
SELECT 1;
