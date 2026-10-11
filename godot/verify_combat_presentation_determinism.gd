extends SceneTree
## Fixed-seed combat → presentation digests for refactors that must not change
## results. Each case hashes the combat state, the decorated presentation frame
## and the 3D node local transforms separately.
##   -- --session                      run twice in fresh scenes; digests must match
##   -- --session --write <abs path>   also store the digests (before a refactor)
##   -- --session --compare <abs path> compare against stored digests (after it)
## The decorated frame format may change by design; compare reports each
## component so combat/node equality can still be judged.
const FrameRows = preload("res://presentation/frame_rows.gd")
const STAGES := [0, 4, 9, 14, 16, 26] # each chapter plus chapter one/three teleport maps
const STEPS_PER_ROUND := 2400 # 40 s of game time
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func _wait(frames: int) -> void:
	for i in frames: await process_frame

func _argument(name: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func run() -> void:
	var first: Dictionary = await _digests()
	var second: Dictionary = await _digests()
	if first.is_empty() or second.is_empty():
		failures.append("scenario did not run")
	elif first != second:
		for key in first:
			if first[key] != second.get(key): failures.append("nondeterministic " + key)
	var write_path := _argument("--write")
	if not write_path.is_empty():
		var file := FileAccess.open(write_path, FileAccess.WRITE)
		if file == null: failures.append("cannot write " + write_path)
		else: file.store_string(JSON.stringify(first, "\t", true) + "\n")
	var compare_path := _argument("--compare")
	if not compare_path.is_empty():
		var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(compare_path))
		if not stored is Dictionary: failures.append("cannot read " + compare_path)
		else:
			for key in stored:
				if stored[key] != first.get(key): failures.append("changed " + key)
			for key in first:
				if not stored.has(key): failures.append("new " + key)
	for key in first: print("DIGEST ", key, " ", first[key])
	print("PRESENTATION_DETERMINISM cases=", first.size(), " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _digests() -> Dictionary:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await _wait(3)
	var app = scene.session_controller
	if app == null:
		push_error("run with -- --session")
		scene.free()
		return {}
	app.checkpoint = load("res://session/session_checkpoint.gd").new(OS.get_environment("TMPDIR").path_join("rune-determinism-" + str(OS.get_process_id())))
	var result := {}
	for stage in STAGES:
		app.spawn_rng.seed = 9001 + stage
		app.enter_stage(stage)
		await _wait(2)
		scene.set_process(false)
		app.set_process(false)
		app.run_domain.state.gold = 10000000
		var source: Dictionary = app.stage_source(stage)
		var columns := int(source.map.columns)
		var types: Array = app.catalog.turret_types()
		var k := 0
		for i in range(source.map.tiles.size()):
			if source.map.tiles[i] != "build": continue
			app.turret_type = types[k % types.size()]; k += 1
			app.board_tap(Vector2i(i % columns, floori(float(i) / columns)))
			app.build_selected()
		app.board_tap(Vector2i(-1, -1))
		var runtime = scene.combat_runtime
		var priorities := ["first", "last", "strongest", "weakest", "nearest"]
		var n := 0
		for t in runtime.turrets.values():
			t.targetPriority = priorities[n % priorities.size()]
			n += 1
		# The boss round, sampled mid-combat: many enemies, projectiles and effects alive.
		var count: int = app.catalog.wave_count(stage)
		for round_index in [count - 1]:
			app.next_round = round_index
			app.start_wave()
			runtime.defense.max_hp = 1.0e12
			runtime.defense.hp = 1.0e12
			for s in range(STEPS_PER_ROUND):
				runtime.advance_session(runtime.FIXED_STEP)
				if not runtime.wave.active and runtime.session.get("phase") != "wave": break
			app.command()
			var state := {"clock": runtime.clock, "event_id": runtime.event_id, "enemies": runtime.enemies,
				"turrets": runtime.turrets, "projectiles": runtime.projectiles, "delayed": runtime.delayed,
				"visual_effects": runtime.visual_effects, "gold": app.run_domain.state.get("gold"),
				"phase": runtime.session.get("phase")}
			var decorated: Dictionary = runtime.decorate_frame(scene.combat_base_frame, true, true)
			# Local transforms only: placement feedback offsets globals with wall-clock time.
			var poses := []
			for frame in 3:
				scene.apply_frame(scene.combat_base_frame)
				for id in scene._units.turrets:
					var entry: Dictionary = scene._units.turrets[id]
					var line := [id, entry.root.transform, entry.head.transform]
					if entry.has("barrel"): line.append(entry.barrel.transform)
					poses.append(var_to_str(line))
				for id in scene._units.enemies:
					poses.append(var_to_str([id, scene._units.enemies[id].root.transform]))
			var key := "stage%02d/round%02d" % [stage + 1, round_index + 1]
			result[key + "/combat"] = JSON.stringify(state, "", true, true).sha256_text().substr(0, 16)
			# Rows are hashed in their serialized form so digests compare across row representations.
			result[key + "/frame"] = JSON.stringify(FrameRows.serialized(decorated), "", true, true).sha256_text().substr(0, 16)
			result[key + "/nodes"] = "%s:%d" % ["|".join(poses).sha256_text().substr(0, 16), poses.size()]
		scene.set_process(true)
		app.set_process(true)
	scene.queue_free()
	await _wait(3)
	return result
