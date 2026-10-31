extends SceneTree
## Hard start, retry and next stage through the formal app lifecycle; the rule
## cases live in verify_stage_difficulty.gd.
class LifecycleFixture extends "res://app/app_lifecycle.gd":
	func _detached_debug_lifecycle() -> bool: return true
var failures: Array = []

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	await _app_cases()
	print("STAGE_DIFFICULTY_APP failures=%s" % [failures])
	quit(0 if failures.is_empty() else 1)

func _app_cases() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var app = LifecycleFixture.new()
	app.ui_enabled = false
	app.checkpoint = load("res://session/session_checkpoint.gd").new(OS.get_environment("TMPDIR").path_join("rune-difficulty-" + str(Time.get_ticks_usec())), "guest")
	scene.session_controller = app
	scene.add_child(app)
	app.set_process(false)
	check(not await app.start_stage(0, "hard"), "hard denied before the normal clear")
	check(await app.start_stage(0) and not app.run_domain.state.has("difficulty"), "normal run has no difficulty field")
	app.run_domain.state.progression.clearedStageNumbers.append(1)
	check(await app.start_stage(0, "hard") and app.run_domain.state.get("difficulty") == "hard", "hard run after the clear")
	var hard_id: String = app.run_domain.state.economyRunId
	check(preload("res://content/stage_difficulty.gd").promotion_seed(app.run_domain.state) == hard_id, "hard waves promote by the run ID")
	check(app.persist_progression() and app.checkpoint.store.load_save().activeRun.get("difficulty") == "hard", "hard run is saved")
	check(await app.retry_stage() and app.run_domain.state.get("difficulty") == "hard" and app.run_domain.state.economyRunId != hard_id, "retry keeps hard")
	await app.enter_next()
	check(app.stage == 1 and not app.run_domain.state.has("difficulty"), "next stage starts normal")
	scene.free()
