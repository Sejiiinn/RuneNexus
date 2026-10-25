-- The newest client compatibility generation that has claimed this account's
-- save writer. Older generations may drop what it wrote, so every write path
-- rejects them. New content raises the generation instead of adding a
-- per-feature compatibility gate.
ALTER TABLE save_writer_states
    ADD COLUMN client_generation_floor INTEGER NOT NULL DEFAULT 0,
    ADD CONSTRAINT save_writer_states_client_generation_floor_check CHECK (client_generation_floor >= 0);

---- create above / drop below ----
-- Dropping the floor only removes the protection; the frozen per-feature gates remain.
ALTER TABLE save_writer_states DROP COLUMN client_generation_floor;
