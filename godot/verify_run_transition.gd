extends SceneTree
## Real app/session/combat/save paths; rendering is replaced by a minimal host.
const App = preload("res://app/app_lifecycle.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
class Host extends Node3D:
	var _native_combat = preload("res://combat/native_combat_runtime.gd").new()
	var _native_combat_base_frame: Dictionary = {}
	func _apply_frame(frame: Dictionary) -> void:
		if frame.get("reset", false): _native_combat.active = false
var failures: Array = []
var checks := 0
var directory := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func create_app(slot: String):
	# Not added to the tree: retain every lifecycle method without booting UI/services.
	var app = App.new()
	app.scene = Host.new()
	app.checkpoint = Checkpoint.new(directory.path_join(slot))
	app.checkpoint.allow_progression_only = true
	app.run_domain.now_millis = func(): return 1700000000000
	check(app.catalog.load_catalog() and app.run_domain.growth.load_catalog(), slot + " catalog")
	check(app.retry_load(), slot + " startup")
	return app

func free_app(app) -> void:
	app.scene.free()
	app.free()

func same_schedule(left: Dictionary, right: Dictionary) -> bool:
	for key in ["id", "active", "completed"]:
		if left[key] != right[key]: return false
	if left.spawnQueue.size() != right.spawnQueue.size(): return false
	for i in range(left.spawnQueue.size()):
		if left.spawnQueue[i].enemyType != right.spawnQueue[i].enemyType: return false
		# v2 JSON delays roundtrip decimal values, not identical float bits.
		if not is_equal_approx(float(left.spawnQueue[i].delay), float(right.spawnQueue[i].delay)): return false
	return true

func start_pending_wave(app, label: String) -> void:
	check(app.start_stage(0), label + " start")
	# One completed round gives abandonment a nonzero progression reward. The
	# second round still uses the production catalog/bootstrap/spawn schedule.
	app.next_round = 1
	app.run_domain.state.roundIndex = 1
	app.run_domain.state.completedRounds = 1
	app.run_domain.state.pendingEconomyDiamonds = 5
	app.start_wave()
	check(app.run_domain.state.phase == "wave" and app.scene._native_combat.wave.active,
		label + " active wave")
	check(not app.scene._native_combat.wave.snapshot().spawnQueue.is_empty(), label + " pending spawn")

func successful_abandon() -> void:
	var app = create_app("success")
	start_pending_wave(app, "abandon")
	var identity: String = app.run_domain.state.economyRunId
	var quest_before: int = int(app.run_domain.state.progression.get("dailyQuestProgress", {}).get("clearWaves", 0))
	check(app.abandon_run(), "pending-wave abandon returns to stage menu")
	var runtime = app.scene._native_combat
	check(app.in_lobby and not app.save_failed and app.run_domain.state.phase == "failure",
		"abandon leaves a savable terminal session")
	check(not runtime.wave.active and runtime.wave.queue.is_empty() and not runtime.running,
		"durable abandon cancels live pending spawns")
	check(runtime.session.phase == "failure" and runtime.session.paused, "live terminal phase paused")
	check(runtime.events.is_empty() and int(app.run_domain.state.progression.get("dailyQuestProgress", {}).get("clearWaves", 0)) == quest_before,
		"cancellation does not invent wave completion")
	var saved: Dictionary = app.checkpoint.store.load_save()
	check(saved.activeRun.phase == "failure" and saved.activeRun.spawnQueue.is_empty(), "terminal v2 has no pending spawns")
	var rewarded: Dictionary = app.run_domain.state.progression.duplicate(true)
	check(int(rewarded.lastRunRuneReward) > 0, "abandon applies completed-round rewards")
	var queue = app.checkpoint.rewards()
	check(queue.state.pendingRewards.size() == 1 and queue.state.pendingRewards[0].runId == identity and queue.state.pendingRewards[0].pendingDiamonds == 5,
		"durable abandoned reward retained")
	for repeat in range(3):
		check(app.prepare_run_transition() and app.persist_progression(), "repeat terminal save " + str(repeat))
	check(app.run_domain.state.progression == rewarded and queue.state.pendingRewards.size() == 1,
		"repeat terminal save does not duplicate rewards")
	check(app.start_stage(0), "new stage starts without app restart")
	check(app.run_domain.state.economyRunId != identity and app.run_domain.state.phase == "preparation" and not app.in_lobby and not app.save_failed,
		"new run playable after abandon")
	check(queue.state.pendingRewards.size() == 1, "replacement retains single abandoned reward")
	free_app(app)

func failed_abandon(outbox_failure: bool) -> void:
	var label := "outbox" if outbox_failure else "checkpoint"
	var app = create_app(label)
	start_pending_wave(app, label)
	var queue = app.checkpoint.rewards()
	var before: Dictionary = app.run_domain.state.duplicate(true)
	var schedule: Dictionary = app.scene._native_combat.wave.snapshot()
	var epoch: int = app.epoch
	var failing_store = queue if outbox_failure else app.checkpoint.store
	failing_store._valid_slot = false
	check(not app.abandon_run(), label + " failure blocks abandon")
	check(app.save_failed and not app.in_lobby and app.epoch == epoch and app.run_domain.state == before,
		label + " failure preserves live run and progression")
	check(app.scene._native_combat.wave.snapshot() == schedule and app.scene._native_combat.session.paused,
		label + " failure preserves pending spawn schedule and pauses")
	check(queue.state.pendingRewards.is_empty(), label + " failure does not enqueue reward")
	check(not app.start_stage(0) and app.epoch == epoch and app.scene._native_combat.wave.snapshot() == schedule,
		label + " failure blocks replacement without clearing queue")
	failing_store._valid_slot = true
	check(app.abandon_run() and not app.save_failed, label + " recovered abandon succeeds")
	check(app.scene._native_combat.wave.queue.is_empty() and queue.state.pendingRewards.size() == 1,
		label + " recovery cancels and rewards exactly once")
	check(app.start_stage(0), label + " recovery permits reentry")
	check(queue.state.pendingRewards.size() == 1, label + " recovery retains one reward")
	free_app(app)

func save_and_resume() -> void:
	var app = create_app("resume")
	start_pending_wave(app, "resume")
	var identity: String = app.run_domain.state.economyRunId
	var schedule: Dictionary = app.scene._native_combat.wave.snapshot()
	check(app.open_stage_menu_destination(), "save and leave succeeds")
	check(not app.run_domain.is_finished() and app.scene._native_combat.wave.snapshot() == schedule,
		"save and leave preserves active spawn schedule")
	check(app.checkpoint.rewards().state.pendingRewards.is_empty(), "resumable leave awards nothing")
	check(app.resume_run() and not app.in_lobby and app.scene._native_combat.session.paused,
		"same-process continue opens existing battle paused")
	check(app.run_domain.state.economyRunId == identity and app.scene._native_combat.wave.snapshot() == schedule,
		"same-process continue retains run and pending spawns")
	check(app.open_stage_menu_destination(), "saved wave returns to menu before restart")
	free_app(app)
	app = create_app("resume")
	check(app.run_domain.state.economyRunId == identity and app.run_domain.state.phase == "wave" and app.in_lobby,
		"saved wave restored with same run identity")
	var restored: Dictionary = app.scene._native_combat.wave.snapshot()
	check(same_schedule(restored, schedule), "saved wave restores all pending spawns")
	check(app.resume_run() and not app.in_lobby and app.scene._native_combat.session.paused,
		"continue opens existing battle paused")
	check(app.checkpoint.rewards().state.pendingRewards.is_empty(), "continue does not finish or enqueue")
	free_app(app)

func run() -> void:
	directory = OS.get_environment("TMPDIR").path_join("rune-run-transition-" + str(OS.get_process_id()))
	check(directory.is_absolute_path(), "isolated save root")
	successful_abandon()
	failed_abandon(false)
	failed_abandon(true)
	save_and_resume()
	print("RUN_TRANSITION failures=", failures, " checks=", checks)
	quit(0 if failures.is_empty() else 1)
