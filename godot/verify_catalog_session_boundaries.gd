extends SceneTree
## Stage entry uses compact catalog queries with the real headless combat authority.
const SessionController = preload("res://session/session_controller.gd")

class CountingCatalog extends "res://content/content_catalog.gd":
	var full_stage_calls := 0
	var full_wave_calls := 0
	func stage(index: int) -> Dictionary:
		full_stage_calls += 1
		return super.stage(index)
	func wave_definition(stage_index: int, round_index: int) -> Dictionary:
		full_wave_calls += 1
		return super.wave_definition(stage_index, round_index)

class SceneStub extends Node3D:
	var _native_combat = preload("res://combat/native_combat_runtime.gd").new()
	var _native_combat_base_frame: Dictionary = {}
	var frames: Array = []
	func _apply_frame(frame: Dictionary) -> void:
		frames.append(frame.duplicate(true))

class FixtureController extends "res://session/session_controller.gd":
	var fixtures: Array = []
	func is_content_session() -> bool: return false
	func stage_count() -> int: return fixtures.size()
	func stage_source(index: int) -> Dictionary: return fixtures[index]

var checks := 0
var failures := []

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _native_path(raw: Array) -> Array:
	var result := []
	for point in raw: result.append({"x": float(point.x), "y": float(point.y)})
	return result

func _initialize() -> void:
	_content_entry()
	_fixture_entry()
	if failures.is_empty():
		print("PASS catalog session boundaries: ", checks, " checks; stage entry map/path/defense/run/session, compact queries and fixture compatibility")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _content_entry() -> void:
	var catalog := CountingCatalog.new()
	_check(catalog.load_catalog(), "compact catalog loads")
	if not catalog.is_loaded(): return
	for index in [0, 16, 24]:
		var controller := SessionController.new()
		var scene := SceneStub.new()
		controller.scene = scene
		controller.catalog = catalog
		controller.next_round = 9
		controller.next_enemy_id = 900000
		controller.selected = Vector2i(2, 3)
		controller.battle_inputs = {"tileSize": 1.75, "origin": [2.5, -3.0]}
		controller.checkpoint.message = "previous stage"
		var previous_epoch: int = controller.epoch
		controller.enter_stage(index)
		var runtime = scene._native_combat
		var map: Dictionary = catalog.stage_map(index)
		_check(controller.checkpoint.message.is_empty() and runtime.active, "content entry activates real backend %d" % index)
		_check(controller.stage == index and controller.epoch == previous_epoch + 1 and runtime.epoch == controller.epoch, "entry stage/epoch match %d" % index)
		_check(controller.next_round == 0 and controller.next_enemy_id == 100000 and controller.selected == Vector2i(-1, -1), "entry resets controller counters %d" % index)
		_check(scene.frames.size() == 2 and scene.frames[0] == {"reset": true, "sceneEpoch": controller.epoch}, "entry reset frame precedes map %d" % index)
		var frame: Dictionary = scene.frames[1]
		_check(frame.map == map and frame.map.theme == frame.map.tileTheme and frame.mapRevision == index, "presentation retains stage map/theme/revision %d" % index)
		_check(frame.seq == 0 and frame.sceneEpoch == controller.epoch and frame.time == 0.0 and frame.turrets.is_empty() and frame.enemies.is_empty() and frame.projectiles.is_empty() and frame.impacts.is_empty(), "entry frame starts empty %d" % index)
		_check(frame.presentation == {"effects": {}, "labels": {}} and scene._native_combat_base_frame == frame, "entry frame base/presentation contract %d" % index)
		var expected_path := []
		for point in map.path:
			expected_path.append({"x": 2.5 + (float(point[0]) + 0.5) * 1.75, "y": -3.0 + (float(point[1]) + 0.5) * 1.75})
		_check(runtime.path == expected_path and runtime.tile_size == 1.75 and runtime.board_scale == 1.75 / 48.0 and runtime.origin == Vector2(2.5, -3.0), "combat applies supplied world layout %d" % index)
		var run: Dictionary = controller.run_domain.state
		_check(run.stage == index and run.phase == "preparation" and run.roundIndex == 0 and run.turrets.is_empty() and not str(run.economyRunId).is_empty(), "new run initializes stage/preparation/id %d" % index)
		_check(controller.run_domain.epoch == controller.epoch and controller.run_domain.event_ack == 0 and controller.run_domain.service.catalog == catalog, "run owner shares stage epoch/catalog %d" % index)
		var inputs := controller.battle_inputs.duplicate(true)
		inputs.defenseConfig = controller.run_domain.growth.derive(run.progression).defenseConfig
		inputs.coreConfig = controller.run_domain.growth.core_config(run, index, 0, catalog)
		var initial: Dictionary = catalog.bootstrap(index, inputs)
		_check(runtime.path == _native_path(initial.path) and runtime.defense.config == initial.defense.config and runtime.defense.hp == float(initial.defense.config.maxHp), "catalog bootstrap defense/path reaches native authority %d" % index)
		_check(runtime.core.config == initial.coreConfig and runtime.teleport_pairs == initial.get("teleportPairs", []), "core and optional teleport bootstrap reaches native authority %d" % index)
		_check(runtime.session == {"clock": "godot", "phase": "preparation", "paused": false, "speed": 1.0} and runtime.sequence == 0 and not runtime.wave_configured, "native session starts before wave materialization %d" % index)
		_check(catalog.full_stage_calls == 0 and catalog.full_wave_calls == 0, "content entry avoids expanding all waves %d" % index)
		controller.free()
		scene.free()

func _fixture_entry() -> void:
	var controller := FixtureController.new()
	var scene := SceneStub.new()
	controller.scene = scene
	controller.fixtures = [
		{"map": {"columns": 2, "rows": 1, "theme": "fixtureFirst", "tiles": ["spawn", "core"]}, "path": [{"x": 0.5, "y": 0.5}, {"x": 1.5, "y": 0.5}], "waves": [{}]},
		{"map": {"columns": 3, "rows": 1, "theme": "fixtureSecond", "tiles": ["spawn", "path", "core"]}, "path": [{"x": 0.5, "y": 0.5}, {"x": 1.5, "y": 0.5}, {"x": 2.5, "y": 0.5}], "waves": [{}, {}]}]
	_check(not controller.catalog.is_loaded(), "fixture branch does not need shipped catalog")
	_check(controller.wave_count(0) == 1 and controller.wave_count(1) == 2, "fixture wave count uses requested index")
	var map := controller.stage_map(1)
	map.tiles[0] = "caller"
	_check(controller.stage_map(1).theme == "fixtureSecond" and controller.fixtures[1].map.tiles[0] == "spawn", "fixture stage_map uses requested index and owns map")
	controller.enter_stage(1, {"defense": {"config": {"maxHp": 175.0}}}, {"paused": true, "speed": 4.0})
	var runtime = scene._native_combat
	_check(runtime.active and runtime.epoch == controller.epoch and controller.stage == 1, "legacy fixture stage enters real backend")
	_check(scene.frames.size() == 2 and scene.frames[1].map == controller.fixtures[1].map and scene._native_combat_base_frame == scene.frames[1], "fixture entry preserves source map frame")
	_check(runtime.path == _native_path(controller.fixtures[1].path) and runtime.tile_size == 1.0 and runtime.board_scale == 1.0 / 48.0, "fixture path/default units preserved")
	_check(runtime.defense.hp == 175.0 and runtime.session == {"clock": "godot", "phase": "preparation", "paused": true, "speed": 4.0}, "fixture bootstrap/session overrides preserved")
	_check(controller.run_domain.state.is_empty() and not runtime.wave_configured, "fixture entry remains independent from content run/waves")
	var frames_before: int = scene.frames.size()
	var epoch_before: int = controller.epoch
	controller.enter_stage(-1)
	controller.enter_stage(controller.stage_count())
	_check(scene.frames.size() == frames_before and controller.epoch == epoch_before and controller.stage == 1, "invalid fixture entry leaves current stage intact")
	controller.free()
	scene.free()
