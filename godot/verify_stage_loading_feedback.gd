extends SceneTree
## Run in an imported, prepared project. All checkpoints are isolated; networking
## is disabled. Optional RUNE_STAGE_FEEDBACK_CAPTURE_DIR captures real viewports.
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Services = preload("res://services/app_services.gd")
const Resources = preload("res://presentation/stage_resources.gd")

class OfflineBoot extends "res://app/boot.gd":
	func _ready() -> void:
		add_to_group("rune_app_boot")
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		screen = Startup.new()
		layer.add_child(screen)
		updates = Updates.new()
		updates.blocked = false
		add_child(updates)
		_effects_pending = false
		set_process(false)

class ObservedMain extends "res://main.gd":
	var feedback_entries := 0
	var feedback_completions := 0
	var missing_resource_once := false
	var fail_effects_once := false
	var fail_frame_once := false
	func stage_feedback_frame() -> void:
		feedback_entries += 1
		if missing_resource_once:
			missing_resource_once = false
			_pending_stage_manifest.paths.append("res://assets/does-not-exist-loading-regression.glb")
		await super.stage_feedback_frame()
		feedback_completions += 1
	func _apply_frame(frame: Dictionary) -> void:
		if fail_frame_once and _realizing_battle:
			fail_frame_once = false
			_fail("Injected cached realization failure")
			return
		super._apply_frame(frame)
	func prepare_effects() -> bool:
		if fail_effects_once:
			fail_effects_once = false
			return false
		return await super.prepare_effects()

class FailingLoader extends ResourceFormatLoader:
	var allow_load := false
	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["stageprobe"])
	func _handles_type(kind: StringName) -> bool:
		return kind == &"Resource"
	func _get_resource_type(_path: String) -> String:
		return "Resource"
	func _exists(path: String) -> bool:
		return path.ends_with(".stageprobe")
	func _load(_path: String, _original: String, _sub_threads: bool, _cache_mode: int) -> Variant:
		return Resource.new() if allow_load else ERR_FILE_CORRUPT

class FeedbackOwner extends Node:
	func stage_preparation_current(generation: int) -> bool:
		return generation == 1
	func stage_feedback_frame() -> void:
		await get_tree().process_frame

var failures: Array[String] = []
var checks := 0
var scene
var app
var boot
var result := false
var done := true
var attempt := ""
var records: Array[Dictionary] = []
var draw_serial := 0
var capture_folder := ""
var captures: Dictionary = {}
var cancel_mode := ""
var cancel_load_floor := 0
var cancel_identity := ""
var cancelled_at := {}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func start_entry(index: int) -> void:
	done = false
	result = await app.start_stage(index)
	done = true

func retry_entry() -> void:
	done = false
	await boot._action()
	result = not app.in_lobby
	done = true

func wait_entry() -> void:
	var deadline := Time.get_ticks_msec() + 120000
	while not done and Time.get_ticks_msec() < deadline:
		await process_frame
	check(done, attempt + " returns from stage entry")
	if not done:
		quit(1)
	for frame in 2: await process_frame
	print("STAGE_FEEDBACK_PHASE ", attempt, " result=", result, " loads=", Resources.snapshot().loads, " draws=", draw_serial)

func observation() -> Dictionary:
	return {"attempt":attempt, "frame":Engine.get_process_frames(), "draw":draw_serial,
		"loads":int(Resources.snapshot().loads), "pending":app._stage_entry_pending,
		"overlay":boot.screen.visible, "prepared":scene.effects_prepared,
		"flow_x":boot.screen._flow.position.x if is_instance_valid(boot.screen._flow) else -999.0,
		"stage":app.stage, "time_usec":Time.get_ticks_usec()}

func observe_frame() -> void:
	if not is_instance_valid(app) or not is_instance_valid(boot): return
	if app._stage_entry_pending:
		records.append(observation())
		var precommit := cancel_mode == "precommit" and int(Resources.snapshot().loads) > cancel_load_floor
		var postcommit: bool = cancel_mode == "postcommit" and not app.run_domain.state.is_empty() \
			and str(app.run_domain.state.economyRunId) != cancel_identity
		if precommit or postcommit:
			cancelled_at = observation()
			cancel_mode = ""
			app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)

func observe_draw() -> void:
	draw_serial += 1
	if not is_instance_valid(app) or not is_instance_valid(boot) or not app._stage_entry_pending: return
	var sample := observation()
	sample.rendered = true
	records.append(sample)
	if capture_folder.is_empty() or attempt != "successful retry" or not boot.screen.visible: return
	if not captures.has("loading-first"):
		capture_now("loading-first")
		captures["first_flow"] = sample.flow_x
	elif not captures.has("loading-moving") and absf(float(sample.flow_x) - float(captures.first_flow)) > 12.0:
		capture_now("loading-moving")

func capture_now(label: String) -> void:
	if capture_folder.is_empty() or DisplayServer.get_name() == "headless": return
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(), label + " viewport image available")
	if image == null or image.is_empty(): return
	check(image.save_png(capture_folder.path_join(label + ".png")) == OK, label + " viewport image saved")
	captures[label] = observation()

func capture(label: String) -> void:
	if capture_folder.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	capture_now(label)

func verify_failed_threaded_request() -> void:
	# Run separately with --threaded-failure-only: the intentional corrupt loader
	# emits engine errors between these markers; assertions still fail normally.
	var loader := FailingLoader.new()
	var owner := FeedbackOwner.new()
	root.add_child(owner)
	ResourceLoader.add_resource_format_loader(loader, true)
	var path := "res://failed-threaded-recovery.stageprobe"
	print("EXPECTED_THREADED_LOAD_FAILURE_BEGIN")
	check(not await Resources.prepare_threaded([path], owner, 1), "terminal FAILED request is rejected")
	print("EXPECTED_THREADED_LOAD_FAILURE_END")
	loader.allow_load = true
	check(await Resources.prepare_threaded([path], owner, 1), "same path retries successfully after terminal FAILED token is collected")
	check(Resources.snapshot().paths == [path], "retried path has one retained owner")
	Resources.clear()
	ResourceLoader.remove_resource_format_loader(loader)
	owner.free()
	print("STAGE_LOADING_FEEDBACK_FAILED_TOKEN checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	if "--threaded-failure-only" in OS.get_cmdline_user_args():
		await verify_failed_threaded_request()
		return
	root.size = Vector2i(440, 900)
	root.content_scale_size = Vector2i(440, 760)
	capture_folder = OS.get_environment("RUNE_STAGE_FEEDBACK_CAPTURE_DIR")
	if not capture_folder.is_empty():
		check(capture_folder.is_absolute_path(), "capture destination is absolute")
		check(DirAccess.make_dir_recursive_absolute(capture_folder) == OK, "capture destination is writable")
	var directory := OS.get_environment("TMPDIR")
	if directory.is_empty(): directory = OS.get_cache_dir()
	directory = directory.path_join("rune-stage-feedback-" + str(Time.get_ticks_usec()))
	check(directory.is_absolute_path() and DirAccess.make_dir_recursive_absolute(directory) == OK, "isolated checkpoint directory")
	scene = ObservedMain.new()
	scene._app_mode = true
	root.add_child(scene)
	app = scene._standalone_session
	# Stop deferred live-service initialization before the first frame.
	var original_services = app.services
	app.services = null
	if original_services != null: original_services.free()
	app.set_process(false)
	scene.set_process(false)
	app.checkpoint = Checkpoint.new(directory)
	app.checkpoint.allow_progression_only = true
	check(app.retry_load(), "fresh isolated startup")
	boot = OfflineBoot.new()
	root.add_child(boot)
	boot.game = scene
	var services = Services.new()
	services.app = app
	services.boot_host = boot
	services.updates = boot.updates
	services._startup_pending = false
	app.add_child(services)
	services.set_process(false)
	app.services = services
	boot.attach_services(services)
	app._refresh_ui()
	process_frame.connect(observe_frame)
	RenderingServer.frame_post_draw.connect(observe_draw)
	for frame in 3: await process_frame
	check(not boot.screen.visible and app.in_lobby and scene.resource_snapshot().resources.count == 0, "cold lobby hides overlay and owns no battle resources")
	await capture("cold-lobby")
	app.progression_inputs.unlockedStageIds = app.StageProgression.ORDER.duplicate()

	attempt = "Back before durable transition"
	cancel_load_floor = int(Resources.snapshot().loads)
	cancel_mode = "precommit"
	var first_draw := draw_serial
	start_entry(0)
	check(not done and boot.screen.visible and app._stage_entry_pending, "cold request exposes existing boot overlay immediately")
	check(int(Resources.snapshot().loads) == cancel_load_floor and scene.feedback_completions == 0, "no asset load precedes initial feedback boundary")
	var generation: int = scene._stage_preparation_generation
	check(not await app.start_stage(0) and not await app.resume_run(), "duplicate Start and Continue are rejected during pending entry")
	check(generation == scene._stage_preparation_generation, "duplicate input cannot replace resource owner generation")
	await wait_entry()
	check(not result and not cancelled_at.is_empty(), "Back interrupts actual resource preflight")
	check(app.in_lobby and not boot.screen.visible and not app._stage_entry_pending, "Back drains request and returns to lobby without a stale overlay")
	check(app.run_domain.state.is_empty() and not FileAccess.file_exists(app.checkpoint.store.primary_path), "precommit Back creates no run or checkpoint")
	check(Resources.snapshot().count == 0 and scene._pending_stage_manifest.is_empty(), "precommit Back releases partial resource ownership")
	if DisplayServer.get_name() != "headless":
		check(int(cancelled_at.get("draw", 0)) > first_draw, "actual loading canvas was drawn before any retained root resource")
	await capture("cancelled-lobby")

	attempt = "preflight failure"
	scene.missing_resource_once = true
	start_entry(0)
	await wait_entry()
	check(not result and boot.screen.visible and boot._stage_retry.is_valid(), "resource preflight failure exposes scoped Retry")
	check(app.run_domain.state.is_empty() and not FileAccess.file_exists(app.checkpoint.store.primary_path), "failed preflight preserves fresh checkpoint state")
	await capture("stage-error")
	var main_identity: int = scene.get_instance_id()
	var checkpoint_identity: int = app.checkpoint.get_instance_id()
	attempt = "successful retry"
	var retry_begin: int = records.size()
	retry_entry()
	await wait_entry()
	check(result and not app.in_lobby and scene.effects_prepared and not scene.battle_preparation_pending(), "Retry returns only after scene and effects complete")
	check(scene.get_instance_id() == main_identity and boot.game == scene and app.checkpoint.get_instance_id() == checkpoint_identity, "Retry retains main instance and checkpoint owner")
	check(not boot.screen.visible and boot._stage_retry.is_null() and boot._failure.is_empty(), "successful Retry removes loading and error state")
	var observed_loads := {}
	var observed_flow := {}
	var no_early_hide := true
	for sample: Dictionary in records.slice(retry_begin):
		if sample.pending:
			no_early_hide = no_early_hide and sample.overlay
			observed_loads[sample.loads] = true
			observed_flow[sample.flow_x] = true
	check(no_early_hide and observed_loads.size() > 2, "loading feedback remains visible across multiple resource completions")
	check(observed_flow.size() > 2, "indeterminate flow advances while preparation remains pending")
	if DisplayServer.get_name() != "headless" and not capture_folder.is_empty():
		check(captures.has("loading-first") and captures.has("loading-moving"), "two actual viewport captures show changing loading feedback")
	await capture("battle-ready")

	attempt = "cached Continue"
	app.show_lobby()
	var run_identity: String = app.run_domain.state.economyRunId
	var saved_before := FileAccess.get_file_as_string(app.checkpoint.store.primary_path)
	var loads_before: int = Resources.snapshot().loads
	var feedback_before: int = scene.feedback_entries
	check(await app.resume_run(), "same-stage Continue succeeds")
	check(scene.feedback_entries == feedback_before and int(Resources.snapshot().loads) == loads_before, "cached Continue introduces no feedback wait or resource reload")
	check(app.run_domain.state.economyRunId == run_identity and scene._native_combat.session.paused, "Continue keeps the same paused run")
	check(FileAccess.get_file_as_string(app.checkpoint.store.primary_path) == saved_before, "Continue leaves checkpoint bytes unchanged")

	attempt = "cached realization failure"
	app.show_lobby()
	scene.fail_frame_once = true
	check(not await app.resume_run(), "cached realization failure returns false")
	check(boot._stage_retry.is_valid() and scene.get_instance_id() == main_identity, "cached failure stays scoped instead of destroying main")
	retry_entry()
	await wait_entry()
	check(result and app.run_domain.state.economyRunId == run_identity and scene.get_instance_id() == main_identity, "cached failure Retry recovers same run and main")

	attempt = "Back saves outgoing run"
	# Direct entry can start with unsaved application preferences. Back must use
	# the same safe checkpoint boundary as ordinary return-to-lobby.
	app.auto_start_mode = "fullAuto"
	app.checkpoint.preferences.autoStartMode = "fullAuto"
	cancel_load_floor = int(Resources.snapshot().loads)
	cancel_mode = "precommit"
	cancelled_at = {}
	start_entry(app.catalog.stage_index(6))
	await wait_entry()
	check(not result and not cancelled_at.is_empty() and app.run_domain.state.economyRunId == run_identity, "active-run precommit Back preserves outgoing run")
	check(app.checkpoint.store.load_save().preferences.autoStartMode == "fullAuto" and not app.save_failed, "Back persists outgoing unsaved state before returning to lobby")
	check(await app.resume_run() and app.run_domain.state.economyRunId == run_identity, "Continue after active-run Back restores same run")

	attempt = "Back after durable transition"
	app.show_lobby()
	cancel_identity = run_identity
	cancel_mode = "postcommit"
	cancelled_at = {}
	start_entry(app.catalog.stage_index(6))
	await wait_entry()
	check(not result and not cancelled_at.is_empty() and app.in_lobby and not boot.screen.visible, "Back during scene commit returns to lobby")
	check(app.run_domain.state.economyRunId != run_identity and app.checkpoint.store.load_save().activeRun.economyRunId == app.run_domain.state.economyRunId, "postcommit Back preserves the newly committed run")
	check(scene._pending_stage_manifest.is_empty() and scene._stage_manifest.stage_id == 6, "postcommit Back completes destination ownership before cancellation")
	var selected: Array = scene._stage_manifest.paths.duplicate()
	selected.sort()
	check(Resources.snapshot().paths == selected, "postcommit cancellation has exactly destination resource ownership")
	run_identity = app.run_domain.state.economyRunId
	check(await app.resume_run() and app.run_domain.state.economyRunId == run_identity, "Continue after postcommit Back realizes same saved run")

	attempt = "effect failure and scoped resume"
	app.show_lobby()
	scene.fail_effects_once = true
	start_entry(app.catalog.stage_index(11))
	await wait_entry()
	check(not result and boot.screen.visible and boot._stage_retry.is_valid() and app.in_lobby, "effect failure retains scoped retry behind the boot error screen")
	run_identity = app.run_domain.state.economyRunId
	saved_before = FileAccess.get_file_as_string(app.checkpoint.store.primary_path)
	retry_entry()
	await wait_entry()
	check(result and scene.effects_prepared and app.run_domain.state.economyRunId == run_identity, "postcommit Retry resumes saved run rather than replacing it")
	check(FileAccess.get_file_as_string(app.checkpoint.store.primary_path) == saved_before and scene.get_instance_id() == main_identity, "effect Retry preserves checkpoint bytes and main instance")
	check(not boot.screen.visible and not app._stage_entry_pending and not scene._effects_preparing, "all loading locks and overlay are cleared")

	if not capture_folder.is_empty():
		var evidence := FileAccess.open(capture_folder.path_join("feedback-evidence.json"), FileAccess.WRITE)
		if evidence != null:
			evidence.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(), "display":DisplayServer.get_name(), "captures":captures, "frames":records, "checks":checks, "failures":failures}, "\t"))
			evidence.close()
	process_frame.disconnect(observe_frame)
	RenderingServer.frame_post_draw.disconnect(observe_draw)
	boot.game = null
	scene.free()
	boot.free()
	print("STAGE_LOADING_FEEDBACK checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
