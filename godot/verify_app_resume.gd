extends SceneTree
## Full prepared project; real lifecycle and isolated checkpoint, no network.
const Services = preload("res://services/app_services.gd")
class Update extends "res://services/update_service.gd":
	var checks := 0
	var accepted := true
	func _check() -> Dictionary:
		checks += 1
		await get_tree().process_frame
		blocked = server_required or not accepted
		return {"ok":true}
class BootProbe extends RefCounted:
	var updates
	func blocks_app_ui() -> bool: return updates.blocked
class ScreenProbe extends Control:
	var page := "강화"
	var modal := Control.new()
	func refresh() -> void: pass
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value: failures.append(label); push_error(label)
func settle() -> void:
	for frame in 4: await process_frame
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene); scene.set_process(false)
	var app = load("res://app/app_lifecycle.gd").new()
	app.ui_enabled = false
	var folder := OS.get_environment("TMPDIR").path_join("rune-resume-" + str(Time.get_ticks_usec()))
	app.checkpoint = load("res://session/session_checkpoint.gd").new(folder)
	scene._standalone_session = app; scene.add_child(app); app.set_process(false)
	check(await app.start_stage(0), "Start isolated run")
	app.start_wave()
	for frame in 120: scene._native_combat.advance_session(1.0 / 60.0)
	app.selected = Vector2i(2, 1)
	scene.options.camera = "drone"
	var identity: String = app.run_domain.state.economyRunId
	var epoch: int = app.epoch
	var elapsed: float = scene._native_combat.elapsed
	var service := Services.new(); app.add_child(service); service.set_process(false)
	service.app = app; service._startup_pending = false; app.services = service
	var update := Update.new(); service.add_child(update)
	update.setup(RefCounted.new(), "https://fixture.invalid/update.json"); update.blocked = false
	service.updates = update; update.changed.connect(service._update_changed)
	var boot := BootProbe.new(); boot.updates = update; service.boot_host = boot
	var screen := ScreenProbe.new(); root.add_child(screen); screen.add_child(screen.modal); app.lobby = screen
	var modal: Control = screen.modal
	app._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	check(scene._native_combat.session.paused, "Background pauses active battle")
	check(app.checkpoint.store.load_save().activeRun != null, "Background checkpoints isolated run")
	app._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	await settle()
	check(update.checks == 0 and not update.blocked, "Ordinary resume does not reopen completed startup update check")
	check(not app.in_lobby and app.epoch == epoch and app.run_domain.state.economyRunId == identity, "Ordinary resume retains battle route, epoch and run")
	check(scene._native_combat.session.paused and scene._native_combat.elapsed == elapsed, "Resume does not advance paused combat")
	check(app.selected == Vector2i(2,1) and scene.options.camera == "drone" and screen.modal == modal, "Selection, camera and existing modal survive")
	app.in_lobby = true
	app._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	app._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	await settle()
	check(app.in_lobby and screen.page == "강화" and screen.modal == modal and update.checks == 0, "Lobby subpage and modal remain on ordinary resume")
	# Existing mandatory/installation gates still refresh when returning from
	# settings or the installer, but their overlay does not change app routing.
	app.in_lobby = false; update.accepted = false
	update.server_required = true; update.blocked = true; update.changed.emit()
	check(not app.in_lobby and boot.blocks_app_ui(), "Required update overlays the current route")
	app._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED); await settle()
	check(update.checks == 1 and update.blocked and update.required(), "Existing required update remains checked and enforced")
	update.server_required = false
	update.installed = {"versionCode":1}
	update.release = {"versionCode":2,"minimumSupportedVersionCode":1}
	update.downloaded = true; update.install_message = "설치 계속"; update.phase = "install"
	app._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED); await settle()
	check(update.checks == 2 and update.blocked and update.phase == "install" and update.downloaded, "Installer return retains verified download and continuation")
	update.skip()
	check(not app.in_lobby and not boot.blocks_app_ui(), "Optional update continuation restores the existing battle")
	app._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED); await settle()
	check(update.checks == 2 and not update.blocked, "Skipped update is not reopened by ordinary resume")
	update.busy = true; update.blocked = true; update.phase = "download"
	app._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED); await settle()
	check(update.checks == 2 and update.busy, "Resume does not restart an active update download")
	update.busy = false; update.blocked = false
	app.lobby = null; screen.free()
	app.services = null; service.app = null; service.boot_host = null
	app.checkpoint.store.clear()
	scene.free()
	print("APP_RESUME failures=", failures)
	quit(0 if failures.is_empty() else 1)
