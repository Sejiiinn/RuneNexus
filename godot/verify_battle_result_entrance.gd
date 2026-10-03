extends SceneTree
## Presentation lifetime regression: hidden input, real clock and native restoration.
const Fixture = preload("res://verify_battle_hud.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func real_delay(seconds: float) -> void:
	await create_timer(seconds,true,false,true).timeout
func frames(count := 4) -> void:
	for index in count: await process_frame
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
	hud.refresh()
	var entrance = hud.rewards.result_entrance
	check(entrance.active and hud.overlay_body.find_child("ResultRestart",true,false).disabled,"initial concealed actions cannot receive input")
	await frames()
	var start: int = entrance.started_usec
	check(start > 0 and entrance._halves.size() == 2,"native frame split and timeline started after layout")
	await real_delay(0.18)
	var crystal: Control = hud.overlay_body.find_child("ResultCrystal",true,false)
	check(crystal.scale != Vector2.ONE and not is_zero_approx(crystal.rotation),"crystal has meaningful spring transform")
	state.gold += 1
	hud.refresh()
	await frames()
	check(entrance.started_usec == start and entrance.elapsed() > 0.18,"content rebuild keeps real elapsed timeline")
	root.size = Vector2i(320,680)
	root.content_scale_size = root.size
	hud.refresh()
	await frames()
	check(entrance.started_usec == start,"resize does not restart entrance")
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
	state.economyRunId = "entrance-failure"
	state.phase = "failure"
	hud.refresh()
	await frames()
	check(entrance.active and not entrance.success,"another finished run starts failure entrance")
	await real_delay(0.16)
	crystal = hud.overlay_body.find_child("ResultCrystal",true,false)
	check(crystal.scale.x > 1 and crystal.rotation < 0,"failure crystal falls and rotates")
	hud.hide()
	await real_delay(0.04)
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
