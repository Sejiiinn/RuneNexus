extends SceneTree
## Presentation lifetime regression: hidden input, real clock and native restoration.
## Timeline poses read a manual clock, so frame pacing and machine load cannot
## move a sample; only the pause section runs on the production real clock.
const Fixture = preload("res://tests/verify_battle_hud.gd")
var failures: Array[String] = []
var checks := 0
var clock_usec := 1000000
func manual_clock() -> int: return clock_usec
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func real_delay(seconds: float) -> void:
	await create_timer(seconds,true,false,true).timeout
func frames(count := 4) -> void:
	for index in count: await process_frame
func advance(seconds: float) -> void:
	clock_usec += int(seconds*1000000.0)
	await frames(2)
func run() -> void:
	root.size = Vector2i(440,900)
	root.content_scale_size = root.size
	var app := Fixture.App.new()
	check(app.catalog.load_catalog() and app.run_domain.initialize(app.catalog,{},0,100),"fixture initialized")
	root.add_child(app)
	var hud = load("res://ui/battle_hud.gd").new()
	hud.app = app
	app.hud = hud
	root.add_child(hud)
	await frames()
	var state: Dictionary = app.run_domain.state
	state.economyRunId = "entrance-success"
	state.phase = "success"
	state.progression.lastRunCorePointReward = 2
	state.progression.lastRunTurretModuleTicketReward = 1
	var entrance = hud.rewards.result_entrance
	var real_clock: Callable = entrance.clock
	entrance.clock = manual_clock
	hud.refresh()
	check(entrance.active and hud.overlay_body.find_child("ResultRestart",true,false).disabled,"initial concealed actions cannot receive input")
	await frames()
	var start: int = entrance.started_usec
	check(start > 0 and entrance._halves.size() == 2,"native frame split and timeline started after layout")
	await advance(0.18)
	var crystal: Control = hud.overlay_body.find_child("ResultCrystal",true,false)
	var sprung_scale: Vector2 = crystal.scale
	var sprung_rotation: float = crystal.rotation
	check(sprung_scale != Vector2.ONE and not is_zero_approx(sprung_rotation),"crystal has meaningful spring transform")
	# Fire the HUD's own poll this frame: it runs before the entrance's _process
	# and its refit sorts afterwards, so this frame's final pose is checked here.
	hud.elapsed = 0.25
	await process_frame
	check(crystal.scale == sprung_scale and crystal.rotation == sprung_rotation,"polled result refit keeps the sprung pose in its frame")
	state.gold += 1
	hud.refresh()
	await frames()
	check(entrance.started_usec == start and entrance.elapsed() >= 0.18,"content rebuild keeps elapsed timeline")
	root.size = Vector2i(600,680)
	root.content_scale_size = root.size
	hud.refresh()
	await frames()
	check(entrance.started_usec == start,"resize does not restart entrance")
	# Only waiting real time can pass this; any load delay just finishes it sooner.
	entrance.clock = real_clock
	entrance.started_usec = real_clock.call()-200000
	start = entrance.started_usec
	check(entrance.active,"real-clock section starts mid-timeline")
	Engine.time_scale = 0.05
	paused = true
	await real_delay(1.15)
	check(not entrance.active,"timeline completes through battle time scale and scene pause")
	paused = false
	Engine.time_scale = 1
	crystal = hud.overlay_body.find_child("ResultCrystal",true,false)
	check(crystal.scale == Vector2.ONE and is_zero_approx(crystal.rotation) and crystal.modulate.a == 1,"native crystal transform restored")
	check(hud.overlay.get_theme_stylebox("panel") is StyleBoxTexture and entrance._halves.is_empty(),"native frame restored and temporary halves removed")
	check(not hud.overlay_body.find_child("ResultRestart",true,false).disabled,"visible native actions enabled")
	hud.refresh()
	check(not entrance.active and entrance.started_usec == start,"normal result refresh stays settled")
	state.phase = "preparation"
	hud.refresh()
	state.phase = "success"
	hud.refresh()
	check(not entrance.active,"same finished run does not replay after phase interruption")
	entrance.clock = manual_clock
	state.economyRunId = "entrance-failure"
	state.phase = "failure"
	hud.refresh()
	await frames()
	check(entrance.active and not entrance.success,"another finished run starts failure entrance")
	await advance(0.16)
	crystal = hud.overlay_body.find_child("ResultCrystal",true,false)
	check(crystal.scale.x > 1 and crystal.rotation < 0,"failure crystal falls and rotates")
	hud.hide()
	await frames(2)
	check(not entrance.active and crystal.scale == Vector2.ONE,"hidden HUD cancels and resets in-progress presentation")
	hud.show()
	hud.refresh()
	check(not entrance.active,"same run after close remains settled")
	state.economyRunId = "entrance-free"
	hud.refresh()
	await frames()
	hud.free()
	check(not is_instance_valid(entrance),"helper lifetime follows HUD free")
	app.free()
	await frames(2)
	print("RESULT_ENTRANCE checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
