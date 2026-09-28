extends SceneTree
const Fixture = preload("res://verify_battle_hud.gd")
const Adapter = preload("res://ui/app_selection.gd")
const Renderer = preload("res://ui/battlefield_selection.gd")
class CountingCatalog extends "res://content/content_catalog.gd":
	var stat_calls := 0
	func turret_stats(type: String = "arrow", inputs: Dictionary = {}) -> Dictionary:
		stat_calls += 1
		return super.turret_stats(type,inputs)
class RewardPreview extends RefCounted:
	var pending_gem := "attackSpeed"
	func targeting() -> bool: return true
class Hud extends Control:
	var rewards = RewardPreview.new()
func _initialize() -> void:
	var app = Fixture.App.new()
	app.catalog = CountingCatalog.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.initialize(app.catalog,{},0,100))
	app.scene._native_combat_base_frame = {"presentation":{}}
	app.run_domain.state.gold = 10000
	var adapter := Adapter.new()
	var renderer := Renderer.new()
	var map: Dictionary = app.stage_source(0).map
	var positions: Array[Vector2i] = []
	for i in range(map.tiles.size()):
		if map.tiles[i] == "build": positions.append(Vector2i(i % int(map.columns),i / int(map.columns)))
	for point in positions.slice(0,2):
		app.selected = point
		app.build_selected()
	app.selected = Vector2i(-1,-1)
	app.catalog.stat_calls = 0
	adapter.apply(app)
	assert(app.catalog.stat_calls == 2,"Initial selection calculates each turret once")
	var frame: Dictionary = app.scene._native_combat_base_frame
	renderer.apply_frame(frame.presentation.selection)
	assert(not renderer._show_all_ranges)
	var first_revision: int = frame.presentation.selection.revision
	adapter.apply(app)
	assert(frame.presentation.selection.revision == first_revision)
	assert(app.catalog.stat_calls == 2,"Unchanged selection reuses turret stats")
	assert(frame.presentation.selection.state.preserveLegacyOrnaments)
	assert(frame.presentation.selection.state.aimKey == "id")
	assert(frame.presentation.selection.state.turrets.filter(func(t): return t.selected).is_empty())
	app.selected = positions[0]
	adapter.apply(app)
	assert(frame.buildPreview == null)
	assert(frame.presentation.selection.state.turrets.filter(func(t): return t.selected).size() == 1)
	var selected: Dictionary = frame.presentation.selection.state.turrets[0]
	var runtime_stats: Dictionary = app.catalog.turret_stats("arrow",{"tileSize":1.0})
	assert(is_equal_approx(selected.range,runtime_stats.range))
	adapter.level_preview = true
	app.catalog.stat_calls = 0
	adapter.apply(app)
	assert(app.catalog.stat_calls == 1,"Only next-level preview needs stats")
	adapter.apply(app)
	assert(app.catalog.stat_calls == 1,"Repeated preview preserves current and future stats")
	assert(frame.presentation.selection.state.turrets[0].previewRange > selected.range)
	app.selected = positions[2]
	adapter.apply(app)
	renderer.apply_frame(frame.presentation.selection)
	assert(renderer._show_all_ranges)
	assert(frame.buildPreview[4] > 0)
	app.build_selected()
	adapter.apply(app)
	renderer.apply_frame(frame.presentation.selection)
	assert(not renderer._show_all_ranges)
	assert(frame.buildPreview == null)
	assert(frame.presentation.selection.state.turrets.filter(func(t): return t.selected).size() == 1)
	for kind in ["spawn","core","path","blocked"]:
		var index: int = map.tiles.find(kind)
		app.selected = Vector2i(index % int(map.columns),index / int(map.columns))
		adapter.apply(app)
		assert(frame.buildPreview == null)
		assert(frame.presentation.selection.state.tiles.size() == (1 if kind in ["spawn","core"] else 0))
	app.selected = Vector2i(-1,-1)
	adapter.apply(app)
	assert(frame.presentation.selection.state.tiles.is_empty())
	assert(frame.presentation.selection.state.turrets.filter(func(t): return t.selected).is_empty())
	app.turret_type = "frost"
	app.selected = positions[3]
	app.build_selected()
	app.run_domain.state.gemInventory = {"range":1,"explosion":1}
	assert(app.selected_run_command("equipGem",{"type":"range","slot":0}))
	assert(app.selected_run_command("link"))
	assert(app.selected_run_command("equipGem",{"type":"explosion","slot":1}))
	var before := JSON.stringify(app.run_domain.state)
	adapter.apply(app)
	assert(before == JSON.stringify(app.run_domain.state))
	var entries: Array = frame.presentation.selection.state.turrets.filter(func(t): return t.selected)
	assert(entries.size() == 1)
	var commands: Array = app.run_domain.service.runtime_commands(app.run_domain.state)
	var native: Dictionary = commands[-1].turret.statInput
	var stats: Dictionary = preload("res://combat/turret_stat_calculation.gd").stats_at(native,int(native.level))
	assert(is_equal_approx(entries[0].range,stats.range*stats.effectAreaMultiplier))
	assert(entries[0].orbitGemColors == [Color("69D7FF"),Color("FF8A2A")])
	assert(not entries[0].has("gemColors"), "3D satellite gems must not also draw legacy arcs")
	assert(app.selected_run_command("removeGem",{"slot":0}))
	adapter.apply(app)
	entries = frame.presentation.selection.state.turrets.filter(func(t): return t.selected)
	assert(entries[0].orbitGemColors == [Color("FF8A2A")], "Empty slots must not spawn satellites")
	frame.presentation.selection = {"rewardTargeting":true,"rewardTargets":[{"position":[1.5,1.5]}]}
	adapter.apply(app)
	assert(frame.presentation.selection.get("state",frame.presentation.selection).rewardTargets.size() == 1)
	assert(frame.buildPreview == null)
	app.hud = Hud.new()
	adapter.apply(app)
	assert(frame.presentation.selection.state.rewardTargeting)
	assert(frame.presentation.selection.state.tiles.is_empty() and frame.buildPreview == null)
	assert(frame.presentation.selection.get("state",frame.presentation.selection).rewardTargets.size() > 0)
	assert(frame.presentation.selection.state.visualScale == 1.0)
	app.hud.free()
	app.hud = null
	# Content-tool hot edits explicitly invalidate; normal progression uses sync.
	app.run_domain.state.progression.physicalDamageTrainingUpgradeLevel = 1
	adapter.apply(app)
	var turret: Dictionary = app.run_domain.state.turrets[0]
	var configuration: Dictionary = adapter.configuration_cache.derived(app.run_domain.state,app.run_domain.service)
	var previous: Dictionary = adapter._stats(app,configuration,turret)
	app.run_domain.growth.data.constants.familyDamageTrainingBonusPerUpgradeLevel += 0.25
	adapter.configuration_cache.invalidate()
	adapter.apply(app)
	configuration = app.run_domain.service.derived(app.run_domain.state)
	var fresh: Dictionary = app.catalog.turret_stats(turret.type,{"tileSize":1.0,"statInput":adapter.configuration_cache.stat_input(configuration,turret)})
	assert(adapter._stats(app,configuration,turret) == fresh)
	assert(float(fresh.damage) > float(previous.damage),"Explicit invalidation refreshes hot-edited growth catalog")
	print("PASS app selection: idle, selected-only, build-all+preview, upgrade range, built selection, cancel, portal/core/invalid tiles; catalog tile units")
	renderer.free()
	app.free()
	quit()
