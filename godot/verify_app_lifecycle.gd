extends SceneTree
class RewardMode extends RefCounted:
	var replacement := false
	func targeting() -> bool: return true
	func replacing() -> bool: return replacement
class TargetHud extends Control:
	var rewards = RewardMode.new()
class MenuStages extends RefCounted:
	var resets := 0
	func reset_navigation() -> void: resets += 1
class MenuLobby extends Control:
	var page := "강화"
	var stages = MenuStages.new()
	func refresh() -> void: pass
var failures: Array = []
var directory := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func create_app(scene, owner: String = "guest"):
	var app = load("res://app/app_lifecycle.gd").new()
	app.ui_enabled = false
	app.checkpoint = load("res://session/session_checkpoint.gd").new(directory, owner)
	scene._standalone_session = app
	scene.add_child(app)
	app.set_process(false)
	return app
func run() -> void:
	directory = OS.get_environment("TMPDIR").path_join("rune-lifecycle-" + str(Time.get_ticks_usec()))
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var app = create_app(scene)
	var initial_camera: String = scene.options.camera
	app.toggle_camera()
	check(scene.options.camera != initial_camera, "formal app retains HUD camera toggle")
	app.toggle_camera()
	check(scene.options.camera == initial_camera, "camera toggle restores prior mode")
	check(not auto_accept_quit and not quit_on_go_back, "OS close and Android back use the saving router")
	check(not app.startup_blocked and app.in_lobby and app.run_domain.state.is_empty(), "new startup is empty lobby")
	check(not FileAccess.file_exists(app.checkpoint.store.primary_path), "startup does not write")
	check(app.apply_growth_command({"kind":"unequipCoreCombatSkill"}), "growth without run")
	var saved = app.checkpoint.store.load_save()
	check(saved.activeRun == null and saved.progression.coreCombatSkill == null, "lobby growth saved without run")
	app.free()
	app = create_app(scene)
	check(not app.startup_blocked and app.run_domain.state.is_empty() and app.progression_inputs.coreCombatSkill == null, "progression-only restart restored")
	check(not app.start_stage(1), "locked stage denied")
	check(app.start_stage(0), "start first unlocked stage")
	check(scene.last_frame.get("presentationVersion") == 2, "formal native labels/effects/selection protocol enabled")
	app.set_auto_start_mode("fullAuto")
	check(app.auto_start_mode == "fullAuto" and app.checkpoint.store.load_save().preferences.autoStartMode == "fullAuto", "popup directly selects and saves automatic mode")
	app.set_auto_start_mode("invalid")
	check(app.auto_start_mode == "fullAuto", "invalid automatic mode rejected")
	app.set_auto_start_mode("pauseEachRound")
	app.cycle_auto_start()
	check(app.auto_start_mode == "skipBossRounds" and app.checkpoint.store.load_save().preferences.autoStartMode == "skipBossRounds", "automatic round preference durable")
	app._maybe_auto_start()
	check(app.run_domain.state.phase == "preparation", "auto mode waits for manual first wave")
	var identity: String = app.run_domain.state.economyRunId
	app.set_speed(2)
	check(scene._native_combat.session.speed == 2, "explicit speed selection")
	app.set_speed(3)
	check(scene._native_combat.session.speed == 2, "unsupported speed ignored")
	var modal_running: bool = app.begin_modal_pause()
	check(modal_running and scene._native_combat.session.paused, "modal pauses running session")
	app.end_modal_pause(modal_running)
	check(not scene._native_combat.session.paused, "modal resumes only prior running session")
	modal_running = app.begin_modal_pause()
	app.pause_and_save()
	app.end_modal_pause(modal_running)
	check(scene._native_combat.session.paused, "background invalidates modal resume")
	var target_hud := TargetHud.new()
	app.hud = target_hud
	check(not scene._session_input.blocked(), "reward target can be selected while simulation paused")
	target_hud.rewards.replacement = true
	check(scene._session_input.blocked(), "reward replacement blocks board")
	target_hud.rewards.replacement = false
	app.save_failed = true
	check(scene._session_input.blocked(), "save failure blocks reward target")
	app.save_failed = false
	app.hud = null; target_hud.free()
	app.toggle_pause()
	app.start_wave()
	for i in range(300): scene._native_combat.advance_session(1.0/60.0)
	app._process(11.0)
	saved = app.checkpoint.store.load_save()
	check(saved.activeRun.phase == "wave" and not saved.activeRun.enemies.is_empty(), "periodic wave checkpoint captures elapsed combat")
	var menu_lobby := MenuLobby.new()
	app.lobby = menu_lobby
	check(app.open_stage_menu_destination(), "stage menu transition saved")
	check(menu_lobby.page == "스테이지" and menu_lobby.stages.resets == 1, "stage menu always selects stage tab")
	check(not app.run_domain.is_finished(), "menu transition preserves resumable run")
	app.lobby = null
	menu_lobby.free()
	app.show_lobby()
	check(app.in_lobby and scene._native_combat.session.paused, "lobby pauses active run")
	check(app.run_domain.state.economyRunId == identity and not app.run_domain.is_finished(), "lobby never abandons run")
	scene.free()
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	app = create_app(scene)
	check(not app.startup_blocked and app.in_lobby and scene._native_combat.session.paused, "startup restores paused to lobby")
	check(app.run_domain.state.economyRunId == identity and app.auto_start_mode == "skipBossRounds", "startup preserves identity and preferences")
	check(app.resume_run(), "resume run")
	check(not scene._native_combat.session.paused, "resume advances")
	check(app.pause_and_save() and scene._native_combat.session.paused, "background saves paused")
	check(app.start_stage(0), "replacement saves terminal first")
	check(app.checkpoint.rewards().state.pendingRewards.size() == 1, "abandon retained in outbox once")
	check(app.persist_progression(), "duplicate save")
	check(app.checkpoint.rewards().state.pendingRewards.size() == 1, "no duplicate abandoned reward")
	var before: Dictionary = app.progression_inputs.duplicate(true)
	app.checkpoint.store._valid_slot = false
	check(not app.apply_growth_command({"kind":"equipCoreCombatSkill","id":"guardianBeam"}), "growth failed write rejected")
	check(app.progression_inputs == before and app.run_domain.state.progression == before, "growth failed write rolls back")
	check(not app.pause_and_save(), "failed background save surfaced")
	var save_error: String = app.checkpoint.message
	check(app.save_failed and not app.resume_run() and scene._native_combat.session.paused, "failed save cannot resume combat")
	app._process(0.1)
	check(app.checkpoint.message == save_error, "failed save diagnostic preserved")
	app.checkpoint.store._valid_slot = true
	app._process(11.0)
	check(not app.save_failed and scene._native_combat.session.paused, "periodic recovery saves but remains paused")
	var path: String = app.checkpoint.store.primary_path
	var backup: String = app.checkpoint.store.backup_path
	app.free()
	var damaged := FileAccess.open(path, FileAccess.WRITE)
	damaged.store_string("damaged primary")
	damaged.close()
	scene.free()
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	app = create_app(scene)
	check(not app.startup_blocked and app.checkpoint.store.load_save() != null, "valid backup restores damaged primary")
	app.free()
	DirAccess.remove_absolute(backup)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	app = create_app(scene)
	check(app.startup_blocked and not app.start_stage(0), "corruption blocks startup and replacement")
	app._process(100.0)
	check(FileAccess.get_file_as_string(path) == "corrupt", "corrupt evidence preserved")
	check(not app.retry_load(), "retry does not silently reset")
	app.checkpoint.store.clear()
	check(app.retry_load(), "explicit repaired slot retry")
	app.checkpoint.store.clear()
	app.free()
	var checkpoint = load("res://session/session_checkpoint.gd").new(directory)
	var envelope: Dictionary = load("res://app/save_codec.gd").decode({"version":2,"preferences":{},"progression":{"runes":321},"turretModules":{},"activeRun":null})
	for suffix in [".tmp", ".replace"]:
		var interrupted := FileAccess.open(checkpoint.store.primary_path + suffix, FileAccess.WRITE)
		interrupted.store_string(JSON.stringify(envelope))
		interrupted.close()
		app = create_app(scene)
		check(not app.startup_blocked and app.progression_inputs.runes == 321, "interrupted save recovery " + suffix)
		app.checkpoint.store.clear()
		app.free()
	var corrupt_tmp := FileAccess.open(checkpoint.store.primary_path + ".tmp", FileAccess.WRITE)
	corrupt_tmp.store_string("partial")
	corrupt_tmp.close()
	app = create_app(scene)
	check(app.startup_blocked and FileAccess.get_file_as_string(checkpoint.store.primary_path + ".tmp") == "partial", "corrupt interrupted file preserved")
	app.checkpoint.store.clear()
	app.free()
	var owner := "12345678-1234-1234-1234-123456789abc"
	checkpoint = load("res://session/session_checkpoint.gd").new(directory, owner)
	check(checkpoint.store.save_save(envelope) == OK, "seed account progression only")
	var queue = checkpoint.rewards()
	var authoritative: Dictionary = queue.state.duplicate(true)
	authoritative.lastServerSnapshot = {"authorityState":"server_authoritative","authorityEpoch":"epoch","authorityVersion":1,"catalogVersion":1,"economyRevision":3,"serverTime":"2026-09-21T00:00:00Z","wallet":{"freeDiamonds":42,"paidDiamonds":7,"moduleTickets":5},"turretModules":{"drawCount":0,"ticketPurchaseCount":0,"items":[]},"entitlements":{"researchSlotTwoUnlocked":true},"pendingProgressionEffects":[],"claimedRewardKeys":[]}
	check(queue.save_state(authoritative) == OK, "seed authoritative receipt")
	app = create_app(scene, owner)
	check(not app.startup_blocked and app.run_domain.state.is_empty() and app.progression_inputs.freeDiamonds == 42 and app.progression_inputs.turretModules.tickets == 5, "account no-run restore preserves authoritative balances")
	check(app.apply_growth_command({"kind":"unequipCoreCombatSkill"}), "account lobby growth saved")
	var account_saved: Dictionary = app.checkpoint.store.load_save()
	check(account_saved.activeRun == null and account_saved.progression.freeDiamonds == 42 and account_saved.turretModules.tickets == 5, "account no-run durable progression retains authority")
	app.checkpoint.store.clear()
	app.free()
	app = create_app(scene, owner)
	check(not app.startup_blocked and app.progression_inputs.freeDiamonds == 42, "account missing progression still restores receipt")
	app.checkpoint.store.clear()
	app.checkpoint.rewards().clear()
	scene.queue_free()
	await process_frame
	print("APP_LIFECYCLE failures=", failures)
	quit(0 if failures.is_empty() else 1)
