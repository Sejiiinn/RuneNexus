extends SceneTree
const Simulation = preload("combat_simulation.gd")
func _initialize() -> void:
	var fixture := {"map": {"columns": 4, "rows": 3, "tiles": ["spawn", "path", "path", "path", "build", "build", "build", "path", "build", "build", "core", "path"]}, "turrets": [], "enemies": [[100, 2.5, 0.5], [101, 3.5, 0.5], [102, 3.5, 1.5]]}
	for i in range(6):
		fixture.turrets.append([i, 1.5 + i % 2, 1.5, 0.0, 0, 0.0, "cannon", 1])
	fixture["viewport"] = [540, 1200]
	fixture["screenCenter"] = [270, 640]
	fixture["pixelsPerTile"] = 40.0
	fixture["zoom"] = 1.1
	fixture.enemies[0] = [100, 2.5, 0.5, 0.3, 0.7, 0.65, 0.0, "tank"]
	var a := Simulation.new()
	var b := Simulation.new()
	a.configure(fixture, "fire", 1.0)
	b.configure(fixture, "fire", 1.0)
	for i in range(600):
		a.step(1.0 / 60.0)
	for i in range(100):
		b.step(0.1)
	assert(a.counters == b.counters, "fixed step must give same combat counts across render rates")
	assert(is_equal_approx(a.game_time, b.game_time))
	var before := a._frame()
	assert(before.viewport == fixture.viewport and before.screenCenter == fixture.screenCenter and before.pixelsPerTile == 40.0 and before.zoom == 1.1, "camera fields must survive")
	assert(before.enemies[0][5] == 0.65, "original enemy scale must survive")
	a.set_paused(true)
	a.step(10.0)
	var after := a._frame()
	after["seq"] = before.seq
	assert(after == before, "pause must freeze all combat and effect ages")
	a.set_paused(false)
	a.step(1.0)
	assert(a.game_time > b.game_time)
	assert(a.counters.shots > 0 and a.counters.hits > 0 and a.counters.burn_ticks > 0)
	b.configure(fixture, "fire_4x", 4.0)
	b.step(2.5)
	assert(b.counters.steps == 600 and is_equal_approx(b.game_time, 10.0))
	assert(is_equal_approx(b._frame().time, 2.5), "4x combat must not speed up the production visual clock")
	assert(b._frame().enemies[0][4] == 0.7, "original visual phase is constant")
	assert(b.counters.burn_ticks > 0, "burn numbers must be emitted at game-time intervals")
	b.configure(fixture, "normal", 1.0)
	for i in range(120):
		b.step(1.0 / 60.0)
	assert(b.counters.hits > 0)
	b.configure(fixture, "combat_normal", 4.0)
	for i in range(1800):
		b.step(1.0 / 60.0)
	assert(b.counters.deaths > 0 and b.counters.respawns > 0 and b.counters.slows > 0)
	b.configure(fixture, "stress_4x", 4.0)
	assert(b.step(0.0).enemies.size() == 96)
	assert(fixture.turrets[0][6] == "cannon", "configure must not mutate caller fixture")
	var clone_check := Simulation.new()
	var clone_fixture := fixture.duplicate(true)
	clone_fixture.enemies = [fixture.enemies[0]]
	clone_check.configure(clone_fixture, "combat_normal", 1.0)
	for enemy: Array in clone_check.step(0.0).enemies:
		assert(enemy[5] == 0.65, "spawned enemies must inherit source scale")
	var cache_fixture := fixture.duplicate(true)
	cache_fixture.enemies = []
	for index in range(96):
		var source: Array = fixture.enemies[0].duplicate()
		source[0] = 100 + index
		source[1] = 2.5 + (index % 2)
		cache_fixture.enemies.append(source)
	_verify_stationary_cache(cache_fixture)
	print("COMBAT_FIXTURE_PASS: deterministic, pause/resume, 4x, hits/burn/death/slow/respawn, 96 enemies; CPU logic test only")
	quit(0)

func _verify_stationary_cache(fixture: Dictionary) -> void:
	# Frozen pre-optimization source lives outside the Android export tree.
	var reference_path := "docs/analysis/godot_validation_20260915/combat_simulation_before_cache.gd.txt"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--reference="):
			reference_path = argument.trim_prefix("--reference=")
	assert(FileAccess.file_exists(reference_path), "cache regression requires frozen reference source")
	var reference_script := GDScript.new()
	reference_script.source_code = FileAccess.get_file_as_string(reference_path)
	assert(reference_script.reload() == OK)
	for scenario in ["normal", "fire_4x", "stress_4x", "combat_normal"]:
		var original = reference_script.new()
		var optimized := Simulation.new()
		original.configure(fixture, scenario, 4.0)
		optimized.configure(fixture, scenario, 4.0)
		for tick in range(600):
			var expected: Dictionary = original.step(1.0 / 60.0)
			var actual: Dictionary = optimized.step(1.0 / 60.0)
			assert(actual == expected, "cache changed frame at %s tick %d" % [scenario, tick])
			assert(optimized.counters == original.counters, "cache changed combat counters")
		if scenario == "combat_normal":
			assert(optimized._stationary_targets.is_empty(), "moving fixture must not cache targets")
		else:
			assert(optimized._stationary_targets.size() == fixture.turrets.size())
	print("STATIONARY_CACHE_EQUIVALENCE: 2400 frames/counters identical to frozen source; moving scenario unchanged")
