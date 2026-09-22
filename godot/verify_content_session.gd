extends SceneTree
## Actual-content entry and UI wiring. Runtime parity is checked separately.
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var app = load("res://session/standalone.gd").new()
	app.progression_inputs = {"clearedStageNumbers":range(1,16)} # Isolated unlocked content fixture.
	scene._standalone_session = app
	scene.add_child(app)
	app.set_process(false)
	check(app.content_enabled and app.catalog.stage_count() == 15, "default entry loads actual stages")
	if app.catalog.stage_count() != 15:
		push_error(app.catalog.error)
		quit(1)
		return
	var save_directory := OS.get_environment("TMPDIR").path_join("rune-content-save-" + str(OS.get_process_id()))
	check(save_directory.is_absolute_path(), "isolated save directory")
	app.checkpoint = load("res://session/session_checkpoint.gd").new(save_directory)
	for stage in [0, 5, 10]:
		app.enter_stage(stage)
		app.run_domain.state.gold = 100000 # Test budget; every build still pays the actual cost.
		var source: Dictionary = app.stage_source(stage)
		check(scene._current_map == source.map, "content map %d" % (stage+1))
		check(scene._native_combat.path.size() == source.path.size(), "content path %d" % (stage+1))
		var build_indices: Array = []
		for i in range(source.map.tiles.size()):
			if source.map.tiles[i] == "build": build_indices.append(i)
		for i in range(mini(6, build_indices.size())):
			var index: int = build_indices[i]
			app.board_tap(Vector2i(index % int(source.map.columns), floori(float(index)/int(source.map.columns))))
			app.build_selected()
			app.cycle_turret()
		check(scene._native_combat.turrets.size() == mini(6, build_indices.size()), "six actual turret configurations")
		app.start_wave()
		var runtime = scene._native_combat
		check(runtime.wave.id == int(source.waves[0].round), "actual first wave id")
		check(runtime.wave.queue.size() == source.waves[0].spawnQueue.size(), "actual wave schedule count")
		var pending_round: int = app.next_round
		app.start_wave()
		app.cycle_wave()
		check(app.next_round == pending_round, "active wave cannot restart or skip")
		for i in range(360): runtime.advance_session(1.0/60.0)
		check(runtime.clock > 5.9, "native content clock")
		check(runtime.turrets.values().any(func(t): return t.shotSequence > 0), "actual turret attacks")
		var before: float = runtime.clock
		app.toggle_pause()
		runtime.advance_session(0.5)
		check(runtime.clock == before, "content pause")
		app.toggle_pause()
		app.toggle_speed()
		runtime.advance_session(0.25)
		check(is_equal_approx(runtime.clock, before+1.0), "content 4x")
		check(app.checkpoint.save_session(app) == OK, "content checkpoint save")
		var saved_gold: int = app.run_domain.state.gold
		check(app.checkpoint.load_session(app) == OK, "content checkpoint load")
		runtime = scene._native_combat
		check(app.stage == stage and app.run_domain.state.gold == saved_gold and runtime.session.paused, "content restore preserves stage/economy and pauses")
		app.command()
		var settled_gold: int = app.run_domain.state.gold
		app.command()
		check(app.run_domain.state.gold == settled_gold and runtime.events.is_empty(), "events applied once before ACK")
		scene._apply_frame(scene._native_combat_base_frame)
		app._process(0)
		await capture("content-stage-%d" % (stage+1))
	# Select actual boss waves through the same development selector.
	for stage in [4, 9, 14]:
		app.enter_stage(stage)
		var source: Dictionary = app.stage_source(stage)
		for i in range(source.waves.size()-1): app.cycle_wave()
		app.start_wave()
		var runtime = scene._native_combat
		check(runtime.wave.id == int(source.waves[-1].round), "boss wave selector")
		var boss_delay := -1.0
		for pending in runtime.wave.queue:
			if "boss" in str(pending.enemyType).to_lower():
				boss_delay = float(pending.delay)
		check(boss_delay >= 0, "actual chapter boss in schedule")
		# Advance the real schedule until the boss is born (no injected enemies).
		for i in range(ceili((boss_delay+1.0)*60.0)):
			if runtime.defense.failed: break
			runtime.advance_session(1.0/60.0)
		check(runtime.enemies.values().any(func(e): return "boss" in str(e.type).to_lower()), "actual chapter boss spawned")
		scene._apply_frame(scene._native_combat_base_frame)
		app._process(0)
		await capture("content-boss-stage-%d" % (stage+1))
	app.exit_stage()
	app.checkpoint.store.clear()
	DirAccess.remove_absolute(save_directory.path_join("saves/guest"))
	DirAccess.remove_absolute(save_directory.path_join("saves"))
	DirAccess.remove_absolute(save_directory)
	check(not scene._native_combat.active, "content exit")
	scene.queue_free()
	for i in range(3): await process_frame
	print("CONTENT_SESSION failures=", failures)
	quit(0 if failures.is_empty() else 1)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../captures")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
