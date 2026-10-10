extends SceneTree
## Exercise the real menu/Continue path with an isolated save and native clock.
const App = preload("res://app/app_lifecycle.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")

class Host extends Node3D:
	var _native_combat = Runtime.new()
	var _native_combat_base_frame := {}
	var prepared := true
	var realized := true
	var cancel_at := ""
	var app
	var loading_paused := true
	func _apply_frame(_frame: Dictionary) -> void: pass
	func prepare_stage_resources(_catalog, _stage: int, _growth: Dictionary, _state: Dictionary) -> bool:
		loading_paused = loading_paused and _native_combat.session.paused
		if cancel_at == "prepare": app.cancel_stage_entry()
		await Engine.get_main_loop().process_frame
		loading_paused = loading_paused and _native_combat.session.paused
		return prepared
	func realize_battle_presentation() -> bool:
		loading_paused = loading_paused and _native_combat.session.paused
		if cancel_at == "realize": app.cancel_stage_entry()
		if cancel_at == "save":
			app.checkpoint.store._valid_slot = false
			app.persist_progression()
		if cancel_at == "background": app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		await Engine.get_main_loop().process_frame
		loading_paused = loading_paused and _native_combat.session.paused
		return realized

var checks := 0
var failures: Array[String] = []
var directory := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func _initialize() -> void: run.call_deferred()

func create_app():
	var app = App.new()
	var host := Host.new()
	app.scene = host
	host.app = app
	app.startup_blocked = false
	app.in_lobby = false
	app.checkpoint = Checkpoint.new(directory.path_join(str(checks)))
	check(app.catalog.load_catalog(), "content loaded")
	app.enter_stage(0)
	check(not app.run_domain.state.is_empty(), "run initialized")
	return app

func dispose(app) -> void:
	app.checkpoint.store.clear()
	app.scene.free()
	app.free()

func run() -> void:
	directory = OS.get_environment("TMPDIR").path_join("rune-menu-return-" + str(Time.get_ticks_usec()))
	for mode in ["pauseEachRound", "skipBossRounds"]:
		var app = create_app()
		app.auto_start_mode = mode
		if mode == "skipBossRounds":
			app.next_round = 9
			app.run_domain.state.roundIndex = 9
			app.run_domain.state.completedRounds = 9
			check(app.catalog.wave_has_boss(0, 9), "next wave is a boss")
		var identity: String = app.run_domain.state.economyRunId
		app.show_lobby()
		check(app.in_lobby and app.scene._native_combat.session.paused, "menu pauses preparation")
		var saved := FileAccess.get_file_as_string(app.checkpoint.store.primary_path)
		check(await app.resume_run(), "Continue opens preparation")
		check(app.scene.loading_paused, "loading stays paused")
		check(not app.in_lobby and not app.scene._native_combat.session.paused, "preparation returns without game pause")
		check(app.run_domain.state.economyRunId == identity and FileAccess.get_file_as_string(app.checkpoint.store.primary_path) == saved, "Continue preserves run and checkpoint")
		var clock: float = app.scene._native_combat.clock
		app.scene._native_combat.advance_session(0.1)
		check(app.scene._native_combat.clock > clock and app.run_domain.state.phase == "preparation" and not app.scene._native_combat.wave.active, "clock advances while wave waits for input")
		app.start_wave()
		check(app.run_domain.state.phase == "wave" and app.scene._native_combat.wave.active, "manual start begins waiting wave")
		dispose(app)
	var active = create_app()
	active.start_wave()
	active.scene._native_combat.advance_session(0.1)
	active.show_lobby()
	check(await active.resume_run(), "Continue opens active wave")
	var elapsed: float = active.scene._native_combat.clock
	active.scene._native_combat.advance_session(0.1)
	check(active.scene._native_combat.session.paused and active.scene._native_combat.clock == elapsed, "active wave remains paused until explicit resume")
	active.toggle_pause()
	active.scene._native_combat.advance_session(0.1)
	check(active.scene._native_combat.clock > elapsed, "explicit resume advances active wave")
	dispose(active)
	for fault in ["prepare_failure", "realize_failure", "prepare_cancel", "realize_cancel", "save_failure", "realize_save_failure"]:
		var app = create_app()
		app.show_lobby()
		match fault:
			"prepare_failure": app.scene.prepared = false
			"realize_failure": app.scene.realized = false
			"prepare_cancel": app.scene.cancel_at = "prepare"
			"realize_cancel": app.scene.cancel_at = "realize"
			"realize_save_failure": app.scene.cancel_at = "save"
			"save_failure":
				app.save_failed = true
				app.checkpoint.store._valid_slot = false
		check(not await app.resume_run(), fault + " rejects Continue")
		check(app.in_lobby and app.scene._native_combat.session.paused and not app._stage_entry_pending, fault + " keeps menu and paused simulation")
		app.checkpoint.store._valid_slot = true
		dispose(app)
	var background = create_app()
	background.show_lobby()
	background.scene.cancel_at = "background"
	check(await background.resume_run(), "background during Continue finishes presentation")
	check(background.scene._native_combat.session.paused, "background during loading keeps simulation paused")
	dispose(background)
	print("MENU_RETURN checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
