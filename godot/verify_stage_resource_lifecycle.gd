extends SceneTree
## Prepared project integration: real formal-app presentation and native saves.
## Two headless child processes prove fresh and saved startup without a warm
## ResourceLoader cache. Every child uses isolated user data and checkpoint paths.
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Json = preload("res://app/save_json.gd")
var failures: Array[String] = []
var checks := 0
var battle_paths: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 3 and args[0] == "--stage-resource-child":
		await child(args[1], args[2])
		return
	var base := OS.get_environment("TMPDIR")
	if base.is_empty(): base = OS.get_environment("TEMP")
	if base.is_empty(): base = OS.get_cache_dir()
	var directory := base.path_join("rune-stage-resources-" + str(Time.get_ticks_usec()))
	check(directory.is_absolute_path(), "test save root must be absolute")
	if not directory.is_absolute_path(): finish("parent"); return
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "create isolated integration directory")
	var previous_data := OS.get_environment("XDG_DATA_HOME")
	var previous_appdata := OS.get_environment("APPDATA")
	for mode in ["fresh", "stored"]:
		OS.set_environment("XDG_DATA_HOME", directory.path_join(mode + "-userdata"))
		OS.set_environment("APPDATA", directory.path_join(mode + "-userdata"))
		var output: Array = []
		var result := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://verify_stage_resource_lifecycle.gd", "--", "--stage-resource-child", mode, directory], output, true)
		var combined := ""
		for part: String in output: combined += part
		var clean: bool = result == 0 and not combined.contains("SCRIPT ERROR:") and not combined.contains("\nERROR:")
		check(clean, mode + " child completes without engine or assertion errors")
		check(combined.contains("STAGE_RESOURCE_CHILD " + mode) and combined.contains("failures=[]"), mode + " child reports completion")
		if not clean: print(combined)
		else:
			for line in combined.split("\n"):
				if line.begins_with("STAGE_RESOURCE_CHILD "): print(line)
	OS.set_environment("XDG_DATA_HOME", previous_data)
	OS.set_environment("APPDATA", previous_appdata)
	finish("parent")

func finish(mode: String) -> void:
	print(("STAGE_RESOURCE_LIFECYCLE" if mode == "parent" else "STAGE_RESOURCE_CHILD " + mode), " checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func gather_battle_paths(path: String) -> void:
	for filename in DirAccess.get_files_at(path):
		if filename.get_extension().to_lower() in ["glb", "png", "jpg", "jpeg", "webp", "hdr", "exr", "res"]:
			battle_paths.append(path.path_join(filename))
	for folder in DirAccess.get_directories_at(path): gather_battle_paths(path.path_join(folder))

func assert_cold(scene, app, label: String) -> void:
	var cached: Array[String] = []
	for path: String in battle_paths:
		if ResourceLoader.has_cached(path): cached.append(path)
	check(cached.is_empty(), label + " has no cached battle models/textures: " + str(cached))
	var snapshot: Dictionary = scene.resource_snapshot()
	check(snapshot.resources.count == 0 and snapshot.resources.loads == 0 and snapshot.manifest.is_empty(), label + " has zero stage-owned resources")
	check(snapshot.environment.library_count == 0 and not snapshot.environment.sky_loaded, label + " has no source libraries or sky")
	check(scene._current_map.is_empty() and scene.turrets.is_empty() and scene.enemies.is_empty(), label + " has no realized map or units")
	check(app.in_lobby and scene._battle_deferred and root.disable_3d and not scene.world.visible, label + " defers rendering in lobby")

func wait_preparation(scene, label: String) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while scene.battle_preparation_pending() and Time.get_ticks_msec() < deadline: await process_frame
	check(not scene.battle_preparation_pending() and scene.effects_prepared, label + " completes selective effect preparation")
	# Retired nodes release their transitive references after the frame boundary.
	for frame in 3: await process_frame

func assert_scope(scene, stage_id: int, baselines: Dictionary) -> void:
	var snapshot: Dictionary = scene.resource_snapshot()
	var paths: Array = snapshot.resources.paths
	var selected: Array = snapshot.manifest.paths.duplicate()
	selected.sort()
	check(paths == selected, "stage %d owns exactly its selected resource paths" % stage_id)
	check(snapshot.manifest.stage_id == stage_id and snapshot.environment.library_count > 0, "stage %d realizes its environment only" % stage_id)
	var off_stage: Array[String] = []
	for path: String in battle_paths:
		if path.ends_with(".glb") and ResourceLoader.has_cached(path) and path not in paths: off_stage.append(path)
	check(off_stage.is_empty(), "stage %d has no cached unrelated model resources: %s" % [stage_id, off_stage])
	var scoped := {"paths":paths, "libraries":snapshot.environment.libraries}
	if baselines.has(stage_id): check(scoped == baselines[stage_id], "stage %d repeated visits have fixed resource and library scope" % stage_id)
	else: baselines[stage_id] = scoped

func child(mode: String, directory: String) -> void:
	for folder in ["enemies", "turrets", "environment", "effects", "projectiles", "backgrounds", "shared_textures"]:
		gather_battle_paths("res://assets/" + folder)
	battle_paths.append_array(["res://assets/ui/turret_levels.png", "res://assets/ui/death_silhouettes.png"])
	check(battle_paths.size() > 20, "prepared battle asset catalog is available")
	var scene = load("res://main.tscn").instantiate()
	scene._app_mode = true
	root.add_child(scene)
	var app = scene._standalone_session
	# setup() only queued service initialization. Free it synchronously before
	# that callback so even a production-configured prepared project stays offline.
	var services = app.services
	app.services = null
	if services != null: services.free()
	app.set_process(false)
	scene.set_process(false)
	app.checkpoint = Checkpoint.new(directory.path_join("checkpoint"))
	app.checkpoint.allow_progression_only = true
	check(app.retry_load(), mode + " isolated checkpoint load")
	await process_frame
	assert_cold(scene, app, mode + " cold lobby")
	if mode == "stored":
		await stored_roundtrip(scene, app, directory)
	else:
		await stage_cycles(scene, app, directory)
	scene.queue_free()
	await process_frame
	finish(mode)

func stage_cycles(scene, app, directory: String) -> void:
	check(app.run_domain.state.is_empty() and not FileAccess.file_exists(app.checkpoint.store.primary_path), "fresh startup does not create a checkpoint")
	app.progression_inputs.unlockedStageIds = app.StageProgression.ORDER.duplicate()
	var baselines := {}
	for stage_id in [1, 6, 11, 1, 6, 11, 1]:
		var index: int = app.catalog.stage_index(stage_id)
		var entered: bool = await app.start_stage(index)
		check(entered, "start selected stage %d" % stage_id)
		if not entered: return
		await wait_preparation(scene, "stage %d" % stage_id)
		assert_scope(scene, stage_id, baselines)
		if baselines.size() == 1 and stage_id == 1: await failed_transition(scene, app)
		var before: Dictionary = scene.resource_snapshot()
		var identity: String = app.run_domain.state.economyRunId
		app.show_lobby()
		await process_frame
		check(root.disable_3d and not scene.world.visible and scene.world.process_mode == Node.PROCESS_MODE_DISABLED, "lobby suspends stage %d rendering and processing" % stage_id)
		check(scene.resource_snapshot().resources.paths == before.resources.paths, "lobby retains stage %d resources" % stage_id)
		check(await app.resume_run(), "Continue stage %d" % stage_id)
		await wait_preparation(scene, "Continue stage %d" % stage_id)
		check(scene.resource_snapshot().resources.loads == before.resources.loads and scene.resource_snapshot().environment.asset_load_counts == before.environment.asset_load_counts,
			"same-stage Continue loads no assets or source libraries")
		check(not root.disable_3d and app.run_domain.state.economyRunId == identity and not scene._native_combat.session.paused,
			"Continue reveals the same preparation run without pausing simulation")
		check(await app.retry_stage(), "restart selected stage %d" % stage_id)
		await wait_preparation(scene, "restart stage %d" % stage_id)
		check(scene.resource_snapshot().resources.loads == before.resources.loads and scene.resource_snapshot().environment.asset_load_counts == before.environment.asset_load_counts,
			"same-stage restart loads no assets or source libraries")
		assert_scope(scene, stage_id, baselines)
		app.show_lobby()
	check(await app.resume_run(), "open final stage to seed saved coldboot")
	await wait_preparation(scene, "save seed")
	var map: Dictionary = app.stage_map(app.stage)
	var cell: int = map.tiles.find("build")
	check(app.apply_run_command({"kind":"build", "type":"arrow", "x":cell % int(map.columns), "y":int(cell / int(map.columns))}), "seed a saved turret")
	app.start_wave()
	for frame in 300:
		scene._native_combat.advance_session(1.0 / 60.0)
		if not scene._native_combat.enemies.is_empty(): break
	check(app.pause_and_save(), "persist live-wave coldboot fixture")
	var expected: Dictionary = app.checkpoint.store.load_save()
	check(not expected.activeRun.turrets.is_empty() and not expected.activeRun.enemies.is_empty() and not expected.activeRun.spawnQueue.is_empty(), "saved fixture includes turret, live enemy and queued spawns")
	var file := FileAccess.open(directory.path_join("expected.json"), FileAccess.WRITE)
	check(file != null, "create roundtrip evidence")
	if file != null: file.store_string(JSON.stringify(expected)); file.close()

func failed_transition(scene, app) -> void:
	var before: Dictionary = scene.resource_snapshot()
	var identity: String = app.run_domain.state.economyRunId
	var terrain_id: int = scene._terrain_library.get_instance_id()
	var map: Dictionary = scene._current_map.duplicate(true)
	var queue = app.checkpoint.rewards()
	queue._valid_slot = false
	check(not await app.start_stage(app.catalog.stage_index(6)), "failed durable abandonment blocks preflighted chapter switch")
	queue._valid_slot = true
	await process_frame
	var after: Dictionary = scene.resource_snapshot()
	check(app.run_domain.state.economyRunId == identity and scene._native_combat.session.paused, "failed chapter switch preserves paused outgoing run")
	check(after.resources.paths == before.resources.paths and after.manifest == before.manifest, "failed chapter switch restores outgoing resource ownership")
	check(scene._terrain_library.get_instance_id() == terrain_id and scene._current_map == map
		and after.environment.asset_load_counts == before.environment.asset_load_counts, "failed chapter switch preserves existing terrain and source instances")
	check(app.persist_progression() and not app.save_failed, "failed chapter switch can retry saving original run")

func stored_roundtrip(scene, app, directory: String) -> void:
	var expected: Variant = Json.parse(FileAccess.get_file_as_string(directory.path_join("expected.json")))
	check(expected is Dictionary and expected.get("activeRun") is Dictionary, "saved coldboot fixture exists")
	if not expected is Dictionary or not expected.get("activeRun") is Dictionary: return
	check(scene._native_combat.active and scene._native_combat.session.paused and app.lobby._has_run(), "stored cold lobby exposes Continue with paused native metadata")
	check(app.run_domain.state.economyRunId == expected.activeRun.economyRunId, "stored cold lobby retains run identity")
	check(app.persist_progression(), "cold lobby autosave succeeds before realization")
	var saved: Dictionary = app.checkpoint.store.load_save()
	check(same_value(saved.activeRun, expected.activeRun), "cold lobby autosave preserves full activeRun checkpoint")
	assert_cold(scene, app, "stored lobby after autosave")
	check(await app.resume_run(), "stored cold Continue")
	await wait_preparation(scene, "stored cold Continue")
	check(not scene._current_map.is_empty() and not scene.turrets.is_empty() and not scene.enemies.is_empty(), "stored Continue realizes map, turrets and enemies")
	check(scene._native_combat.session.paused and app.pause_and_save(), "stored Continue stays paused and savable")
	saved = app.checkpoint.store.load_save()
	check(same_value(saved.activeRun, expected.activeRun), "stored Continue preserves native activeRun roundtrip")
	var loads: int = scene.resource_snapshot().resources.loads
	app.show_lobby()
	check(await app.resume_run(), "second stored Continue")
	await wait_preparation(scene, "second stored Continue")
	check(scene.resource_snapshot().resources.loads == loads, "second stored Continue reuses resource owners")

func same_value(left: Variant, right: Variant) -> bool:
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not same_value(left[key], right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for index in left.size():
			if not same_value(left[index], right[index]): return false
		return true
	if left is float or right is float: return is_equal_approx(float(left), float(right))
	return left == right
