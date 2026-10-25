extends SceneTree
## Support cores: 3-2 unlock without legacy rights, construction with a bag gem
## (default: the most copies, then the least equipped), adjacent +15% damage in the module damage-increase layer (strongest
## of a family only), demolition refund, deck log consumption and the run save.
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Codec = preload("res://app/save_codec.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const Progress = preload("res://content/stage_progression.gd")
const SupportCore = preload("res://app/support_core_rules.gd")
const Cache = preload("res://ui/hud_configuration_cache.gd")
const CorePanel = preload("res://ui/hud_support_core_panel.gd")
var failures: Array[String] = []
var checks := 0
var catalog
var growth
var service
var map: Dictionary

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	catalog = Catalog.new()
	growth = Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(), "catalogs")
	service = Commands.new(catalog, growth)
	map = catalog.stage_map(0)
	_unlock()
	_default_gem()
	var tiles := _tiles()
	check(not tiles.is_empty(), "stage has a core tile with two build neighbours and a diagonal")
	if not tiles.is_empty():
		var state := _construction(tiles)
		_bonus(state, tiles)
		_demolition(state, tiles)
		_save(state)
	print("SUPPORT_CORE checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _build(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < int(map.columns) and y < int(map.rows) and map.tiles[y * int(map.columns) + x] == "build"

# Core C, turret east E, turret south S, second core at E's east, diagonal D.
func _default_gem() -> void:
	check(CorePanel.default_gem({"gemInventory":{}, "turrets":[]}) == "", "no default without bag gems")
	check(CorePanel.default_gem({"gemInventory":{"range":1, "chain":3, "attackSpeed":2}, "turrets":[]}) == "chain", "default is the gem with the most copies")
	var equipped := [{"equippedGemSlots":["range", null]}, {"equippedGemSlots":["range", "chain"]}]
	check(CorePanel.default_gem({"gemInventory":{"range":2, "chain":2, "crit":0}, "turrets":equipped}) == "chain", "ties go to the gem fewer turrets use")
	check(CorePanel.default_gem({"gemInventory":{"crit":0, "range":0}, "turrets":[]}) == "", "empty stacks are not spent")

func _tiles() -> Dictionary:
	for y in range(int(map.rows)):
		for x in range(int(map.columns)):
			if _build(x, y) and _build(x + 1, y) and _build(x, y + 1) and _build(x + 2, y) and _build(x + 1, y + 1):
				return {"core":Vector2i(x, y), "east":Vector2i(x + 1, y), "south":Vector2i(x, y + 1), "second":Vector2i(x + 2, y), "diagonal":Vector2i(x + 1, y + 1)}
	return {}

func _progression(cleared: Array) -> Dictionary:
	return {"growthVersion":1, "progressionVersion":Progress.VERSION, "clearedStageNumbers":cleared, "coreCombatSkill":null, "turretModules":{"tickets":0, "items":[]}}

func _unlock() -> void:
	check(Progress.requirement("feature", "supportCore") == 12 and Progress.stage_label(12) == "3-2", "unlocks on the 3-2 (ID12) first clear")
	check(Progress.has_unlock(_progression([12]), "feature", "supportCore"), "3-2 clear unlocks")
	check(not Progress.has_unlock(_progression([11, 13]), "feature", "supportCore"), "other clears do not unlock")
	var grandfathered := _progression([])
	grandfathered.grandfatherUnlocks = ["feature:supportCore"]
	check(not Progress.has_unlock(grandfathered, "feature", "supportCore"), "grandfathered right never unlocks new content")
	check(not Progress.has_unlock({"progressionVersion":0, "unlockedStageCount":20, "clearedStageNumbers":[]}, "feature", "supportCore"), "legacy progression never unlocks")
	check(Progress.has_unlock({"progressionVersion":0, "researchSlotTwoUnlocked":true}, "feature", "researchSlotTwo"), "legacy research slot right kept")
	var locked: Dictionary = service.initial_state(_progression([]), 0)
	locked.gemInventory = {"range":1}
	var cell: int = map.tiles.find("build")
	check(service.apply(locked, {"kind":"buildSupportCore", "x":cell % int(map.columns), "y":cell / int(map.columns), "gem":"range"}).error == "locked", "locked before 3-2")
	check(service.derived(locked).supportCoreUnlocked == false and service.derived(service.initial_state(_progression([12]), 0)).supportCoreUnlocked == true, "derived configuration exposes the unlock")

func _construction(t: Dictionary) -> Dictionary:
	var state: Dictionary = service.initial_state(_progression([12]), 0)
	state.gold = 2000
	state.gemInventory = {"range":2, "chain":1}
	for at in [t.east, t.south]:
		state = service.apply(state, {"kind":"build", "type":"arrow", "x":at.x, "y":at.y}).state
	state.turrets[0].equippedGemSlots = ["attackSpeed"]
	state.turrets[0].equippedGems = ["attackSpeed"]
	var core := {"kind":"buildSupportCore", "x":t.core.x, "y":t.core.y, "gem":"range"}
	var equipped := core.duplicate(); equipped.gem = "attackSpeed"
	check(service.apply(state, equipped).error == "inventory", "equipped gems cannot be consumed")
	var poor := state.duplicate(true); poor.gold = 149
	check(service.apply(poor, core).error == "gold", "needs 150 gold")
	var on_turret := core.duplicate(); on_turret.x = t.east.x; on_turret.y = t.east.y
	check(service.apply(state, on_turret).error == "occupied", "not on a turret")
	var path: int = map.tiles.find("path")
	var on_path := core.duplicate(); on_path.x = path % int(map.columns); on_path.y = path / int(map.columns)
	check(service.apply(state, on_path).error == "tile", "only on build tiles")
	var built: Dictionary = service.apply(state, core)
	check(built.ok, "build: " + str(built.error))
	var next: Dictionary = built.state
	check(next.gold == state.gold - 150 and next.gemInventory == {"range":1, "chain":1}, "spends 150 gold and the chosen bag gem")
	check(next.supportCores == [{"x":t.core.x, "y":t.core.y, "family":"damage", "investedGold":150, "consumedGem":"range"}], "core recorded with its family and spent gem")
	check(not next.has("gemDeckLog"), "guest runs keep no deck log")
	check(built.commands.size() == 2 and built.commands.all(func(c): return c.kind == "turret"), "adjacent turrets refreshed")
	var last := core.duplicate(); last.gem = "chain"; last.x = t.second.x; last.y = t.second.y; last.deckLog = true
	var deck_state: Dictionary = next.duplicate(true)
	deck_state.gemDeckLog = [{"kind":"wave", "wave":5, "rerolls":0, "choice":"chain"}]
	var logged: Dictionary = service.apply(deck_state, last)
	check(logged.ok and logged.state.gemDeckLog.back() == {"kind":"consume", "choice":"chain"} and not logged.state.gemInventory.has("chain"), "deck runs log the consumed gem")
	var turret_on_core: Dictionary = service.apply(next, {"kind":"build", "type":"arrow", "x":t.core.x, "y":t.core.y})
	check(turret_on_core.error == "occupied", "turrets cannot be built on a core")
	return logged.state if logged.ok else next

func _bonus(state: Dictionary, t: Dictionary) -> void:
	var base: Dictionary = state.duplicate(true)
	base.supportCores = []
	var configuration: Dictionary = service.derived(state)
	var east: Dictionary = {}
	for turret in state.turrets:
		if Vector2i(turret.x, turret.y) == t.east: east = turret
	var cache = Cache.new()
	var with_core: Dictionary = cache.stat_input(configuration, east, state)
	var without: Dictionary = cache.stat_input(configuration, east, base)
	var rate := float(without.get("moduleEffect", {}).get("damageIncreaseRate", 0.0))
	# Two damage cores touch the east turret; only the strongest one applies.
	check(SupportCore.bonuses_at(state, t.east.x, t.east.y) == {"damage":0.15}, "same family never stacks")
	check(is_equal_approx(float(with_core.moduleEffect.damageIncreaseRate), rate + 0.15), "adjacent turret gains +15% in the module damage layer")
	check(SupportCore.bonuses_at(state, t.diagonal.x, t.diagonal.y).is_empty(), "diagonal tiles are not adjacent")
	var boosted: Dictionary = catalog.turret_stats("arrow", {"tileSize":1.0, "statInput":with_core})
	var plain: Dictionary = catalog.turret_stats("arrow", {"tileSize":1.0, "statInput":without})
	check(is_equal_approx(float(boosted.damage) / float(plain.damage), (1.0 + rate + 0.15) / (1.0 + rate)), "damage scales with the summed increase")
	var runtime_input: Dictionary = {}
	for command in service.runtime_commands(state):
		if int(command.turret.state.x) == t.east.x and int(command.turret.state.y) == t.east.y: runtime_input = command.turret.statInput
	check(not runtime_input.is_empty() and is_equal_approx(float(runtime_input.moduleEffect.damageIncreaseRate), float(with_core.moduleEffect.damageIncreaseRate)), "combat input matches the HUD preview")
	check(SupportCore.connections(state).size() == 3, "connections: core to east and south, second core to east")

func _demolition(state: Dictionary, t: Dictionary) -> void:
	var refund: int = service.support_core_refund(SupportCore.at(state, t.core.x, t.core.y), service.derived(state))
	check(refund == int(150 * float(service.derived(state).turretRefundPercent) / 100.0) and refund == 112, "refund uses the turret rate (75%)")
	var sold: Dictionary = service.apply(state, {"kind":"sellSupportCore", "x":t.core.x, "y":t.core.y})
	check(sold.ok and sold.state.gold == state.gold + refund and sold.state.gemInventory == state.gemInventory, "demolition refunds gold, not the gem")
	check(SupportCore.at(sold.state, t.core.x, t.core.y).is_empty() and SupportCore.bonuses_at(sold.state, t.south.x, t.south.y).is_empty(), "connection ends at once")
	check(service.apply(sold.state, {"kind":"sellSupportCore", "x":t.core.x, "y":t.core.y}).error == "supportCore", "nothing to demolish")

func _save(state: Dictionary) -> void:
	var adapter = Adapter.new(catalog, growth)
	var inputs: Dictionary = {"defenseConfig":service.derived(state).defenseConfig, "coreConfig":growth.core_config(state, 0, 0, catalog)}
	var bootstrap: Dictionary = catalog.bootstrap(0, inputs)
	bootstrap.turrets = []
	for command in service.runtime_commands(state): bootstrap.turrets.append(command.turret)
	var runtime = Runtime.new()
	runtime.process_command({"epoch":1, "sequence":0, "session":{"clock":"godot", "phase":"preparation", "paused":true}, "bootstrap":bootstrap})
	state.runCoreCombatSkill = null
	state.economyRunId = "support-core-run"
	var saved: Dictionary = adapter.capture(state, runtime.snapshot(), 7)
	check(not saved.is_empty(), "capture: " + str(adapter.error))
	if saved.is_empty(): return
	check(Codec.is_normalized_v2(saved) and saved.activeRun.supportCores == state.supportCores and saved.activeRun.gemDeckLog == state.gemDeckLog, "cores and consumed gems survive the codec")
	check(Hash.encode(saved.activeRun.supportCores, "SavedSupportCore").begins_with('[{"x":'), "hash orders core fields")
	var prepared: Dictionary = adapter.prepare(saved)
	check(not prepared.is_empty() and prepared.state.supportCores == state.supportCores, "restore: " + str(adapter.error))
	var bad := saved.duplicate(true)
	bad.activeRun.supportCores[0].x = bad.activeRun.turrets[0].x
	bad.activeRun.supportCores[0].y = bad.activeRun.turrets[0].y
	check(adapter.prepare(bad).is_empty(), "core on a turret tile rejected")
	var path: int = map.tiles.find("path")
	bad = saved.duplicate(true)
	bad.activeRun.supportCores[0].x = path % int(map.columns)
	bad.activeRun.supportCores[0].y = path / int(map.columns)
	check(adapter.prepare(bad).is_empty(), "core on a path tile rejected")
	var unknown := saved.duplicate(true)
	unknown.activeRun.supportCores[0].family = "speed"
	unknown.activeRun.gemDeckLog.append({"kind":"consume", "choice":"shards"})
	var decoded: Variant = Codec.decode(unknown)
	check(decoded.activeRun.supportCores.size() == saved.activeRun.supportCores.size() - 1 and decoded.activeRun.gemDeckLog == saved.activeRun.gemDeckLog, "unknown family and invalid consumption dropped")
	var plain := saved.duplicate(true)
	plain.activeRun.erase("supportCores")
	check(not Codec.decode(plain).activeRun.has("supportCores"), "runs without cores keep their payload shape")
