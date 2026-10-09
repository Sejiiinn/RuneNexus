extends SceneTree
## Full-asset integration: fixed steps -> real reward ACK -> rendered actor route.
## Run after prepare_godot_project.py/import, alongside skinned/boss checks.
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Units = preload("res://presentation/battlefield_units.gd")
const Catalog = preload("res://content/content_catalog.gd")
const KINDS := ["normal", "fast", "tank", "boss", "shieldBoss", "forgeBoss"]
var checks := 0
var failures: Array[String] = []
var catalog = Catalog.new()

class TestScene extends Node3D:
	var _native_combat = Runtime.new()
	var _native_combat_base_frame: Dictionary = {}
	func _apply_frame(frame: Dictionary) -> void:
		if frame.get("reset", false): _native_combat = Runtime.new()

class TestApp extends "res://app/app_lifecycle.gd":
	func persist_progression() -> bool: return true
	func refresh_selection() -> void: pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func show_frame(units, runtime) -> void:
	var frame: Dictionary = runtime.decorate_frame({})
	units.configure(runtime.effect_time, Vector2i(8, 10), {"volume":false})
	# This is main._sync_enemies' production order: observe before old actors die.
	units.sync_guardian_events(runtime)
	units._sync_enemies(frame.enemies)

func run() -> void:
	check(catalog.load_catalog(), "content loads")
	for speed in [1.0, 2.0, 4.0]:
		for delta in [1.0/120.0, 1.0/60.0, 1.0/30.0, 0.2, 2.0]:
			verify_delivery(speed, delta)
	print("DEATH_PRESENTATION_DELIVERY checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func verify_delivery(speed: float, delta: float) -> void:
	var label := "%sx/%ssec " % [speed, delta]
	var scene := TestScene.new()
	var app := TestApp.new()
	app.scene = scene
	app.ui_enabled = false
	app.startup_blocked = false
	app.in_lobby = false
	app.auto_start_mode = "fullAuto"
	app.catalog = catalog
	app.spawn_rng.seed = 71423
	app.run_domain.now_millis = func(): return 1720000000000
	app.enter_stage(0, {}, {"speed":speed})
	app.start_wave()
	var runtime = scene._native_combat
	runtime.wave.queue.clear()
	runtime.wave.next_index = 0
	for i in KINDS.size():
		runtime._spawn({"id":900+i,"type":KINDS[i],"hp":1.0,"maxHp":1.0,
			"speed":0.0,"burnRemaining":1.0,"burnDamagePerSecond":60.0,
			"diamondReward":1,"presentationScale":0.55,"laneOffsetRatio":0.15,
			"path":[[48.0+48*i,96.0],[48.0+48*i,400.0]]})
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	var units := Units.new(world, camera)
	units.failure.connect(func(message: String): check(false, message))
	show_frame(units, runtime)
	check(units.enemies.size() == KINDS.size(), label + "all live models instantiated")
	var iterations := 0
	while runtime.simulation_tick == 0 and iterations < 3:
		runtime.advance_session(delta)
		iterations += 1
	check(not runtime.events.any(func(event): return event.get("kind") == "kill") and not runtime.enemies.has("900"), label + "actual per-step reward ACK retired killed enemies before render")
	check(app.run_domain.state.pendingEconomyDiamonds == KINDS.size() and app.run_domain.state.completedRounds == 1,
		label + "every kill and final-wave reward settled once")
	show_frame(units, runtime)
	var motion = units._guardian_preview
	check(motion.deaths.size() == KINDS.size(), label + "all authored death types survive ACK and later catch-up steps")
	check(runtime.take_death_presentations().is_empty(), label + "render drains pending delivery")
	var identities := {}
	for id in motion.deaths:
		identities[id] = motion.deaths[id].root.get_instance_id()
		check(is_equal_approx(motion.deaths[id].born, runtime.effect_time), label + "late delivery starts full authored lifetime")
	show_frame(units, runtime)
	for id in identities:
		check(motion.deaths[id].root.get_instance_id() == identities[id], label + "duplicate render cannot recreate death")
	var born: float = runtime.effect_time
	motion.update_deaths(born + 0.35)
	for id in identities:
		check(motion.deaths.has(id) and motion.deaths[id].player.current_animation_position > 0.0, label + "death animation really advances")
	motion.observe_native(runtime, born - 0.01, Vector2i(8, 10))
	check(motion.deaths.is_empty(), label + "presentation rewind does not replay acknowledged journal")
	# Pending delivery must never cross a stage/bootstrap epoch boundary.
	runtime._spawn({"id":999,"type":"normal","hp":1.0,"maxHp":1.0,"burnRemaining":1.0,"burnDamagePerSecond":60.0})
	runtime.advance_session(1.0/60.0)
	check(not runtime._presentation_deaths.is_empty(), label + "reset fixture has an undelivered acknowledged death")
	runtime.process_command({"epoch":runtime.epoch+1,"sequence":0,"bootstrap":{},"session":{"clock":"godot","phase":"preparation"}})
	check(runtime.take_death_presentations().is_empty(), label + "new epoch clears undelivered deaths")
	units.clear()
	world.free()
	scene.free()
	app.free()
