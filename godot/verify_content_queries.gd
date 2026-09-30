extends SceneTree
class QueryCatalog extends "res://content/content_catalog.gd":
	var stage_copies := 0
	func stage(index: int) -> Dictionary:
		stage_copies += 1
		return super.stage(index)
class SceneStub extends Node3D:
	var _native_combat := {"session":{"paused":false}}
class AutoApp extends "res://app/app_lifecycle.gd":
	var starts := 0
	func start_wave() -> void: starts += 1

func _initialize() -> void:
	var app := AutoApp.new()
	var scene := SceneStub.new()
	app.scene = scene
	app.catalog = QueryCatalog.new()
	assert(app.catalog.load_catalog())
	app.in_lobby = false
	app.run_domain.state = {"phase":"preparation"}
	app.auto_start_mode = "fullAuto"
	app.next_round = 0
	app._maybe_auto_start()
	assert(app.starts == 0, "First wave remains manual")
	app.next_round = 1
	app._maybe_auto_start()
	assert(app.starts == 1, "Full auto starts the next ordinary wave")
	app.auto_start_mode = "skipBossRounds"
	app.next_round = 9
	assert(app.catalog.wave_has_boss(0, 9))
	app._maybe_auto_start()
	assert(app.starts == 1, "Boss rounds wait for input")
	app.next_round = 8
	app._maybe_auto_start()
	assert(app.starts == 2, "Skip-boss mode starts ordinary waves")
	scene._native_combat.session.paused = true
	app._maybe_auto_start()
	assert(app.starts == 2, "Pause suppresses automatic starts")
	scene._native_combat.session.paused = false
	app.in_lobby = true
	app._maybe_auto_start()
	assert(app.starts == 2, "Lobby suppresses automatic starts")
	app.in_lobby = false
	app.run_domain.state.phase = "wave"
	app._maybe_auto_start()
	assert(app.starts == 2, "Active wave suppresses automatic starts")
	app.run_domain.state.phase = "preparation"
	app.next_round = app.catalog.wave_count(0)
	app._maybe_auto_start()
	assert(app.starts == 2, "Final wave boundary is unchanged")
	assert(app.catalog.stage_copies == 0, "Automatic-start queries never copy compiled stage data")
	app.free()
	scene.free()
	print("PASS content queries: automatic mode, boss, pause, lobby, phase and boundary; zero full-stage copies")
	quit(0)
