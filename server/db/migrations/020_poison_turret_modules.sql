-- Allow poison turret modules while preserving every existing module row.
ALTER TABLE player_modules DROP CONSTRAINT player_modules_turret_type_check;
ALTER TABLE player_modules ADD CONSTRAINT player_modules_turret_type_check
    CHECK (turret_type IN ('arrow', 'cannon', 'magic', 'frost', 'sniper', 'lightning', 'poison'));

---- create above / drop below ----
-- New module ownership cannot safely be discarded on rollback.
SELECT 1;
