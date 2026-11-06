extends SceneTree
## Start level research: unlock, price, free level on build, refund and save contract.
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Codec = preload("res://app/save_codec.gd")
const Progression = preload("res://content/stage_progression.gd")

var failures: Array = []
var checks := 0
func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok: failures.append(name)

func _built(growth_rules: Growth, commands: Commands, catalog: Catalog, progression: Dictionary, type: String) -> Dictionary:
	var state: Dictionary = commands.initial_state(progression, 0); state.gold = 100000
	growth_rules.fix_run_loadout(state)
	var map: Dictionary = catalog.stage_map(0); var cell: int = map.tiles.find("build")
	return commands.apply(state, {"kind":"build","type":type,"x":cell % int(map.columns),"y":cell / int(map.columns)})

func _initialize() -> void:
	var growth := Growth.new(); var catalog := Catalog.new()
	check(growth.load_catalog() and catalog.load_catalog(), "catalog")
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	p.runes = 40000; p.clearedStageNumbers = [3, 7, 23, 26]
	check(Progression.requirement("research", "turretStartLevel") == 27, "fixed ID27")
	check(Progression.unlock_items(27).any(func(item): return item[0] == "숙련 배치"), "3-7 display")
	check(not growth.execute(p, {"kind":"startResearch","id":"turretStartLevel","nowMillis":1000}).ok, "3-6 clear stays locked")
	p.clearedStageNumbers.append(27)
	var quote: Dictionary = growth.research_quote(p, "turretStartLevel")
	check(quote.cost == 35000 and quote.durationMillis == 25200000, "35000 runes seven hours")
	var discounted := p.duplicate(true); discounted.researchLevels = {"researchEfficiency":20,"researchCostEfficiency":20}
	var discounted_quote: Dictionary = growth.research_quote(discounted, "turretStartLevel")
	check(discounted_quote.cost == 17500 and discounted_quote.durationMillis == 12600000, "same research efficiencies")
	var forged := p.duplicate(true); forged.clearedStageNumbers = [26]; forged.grandfatherUnlocks = ["research:turretStartLevel"]
	check(not Progression.has_unlock(forged, "research", "turretStartLevel"), "no nonexistent grandfather right")
	var poor := p.duplicate(true); poor.runes = 34999
	check(not growth.execute(poor, {"kind":"startResearch","id":"turretStartLevel","nowMillis":1000}).ok, "34999 runes insufficient")
	var started: Dictionary = growth.execute(p, {"kind":"startResearch","id":"turretStartLevel","nowMillis":1000})
	check(started.ok and started.state.runes == 5000, "start spends runes")
	check(int(growth.derive(started.state).get("turretStartLevelBonus", -1)) == 0, "no bonus while researching")
	var early: Dictionary = growth.execute(started.state, {"kind":"completeFinishedResearches","nowMillis":25200999})
	check(int(early.get("state", started.state).get("researchLevels", {}).get("turretStartLevel", 0)) == 0, "one moment early stays active")
	var finished: Dictionary = growth.execute(started.state, {"kind":"completeFinishedResearches","nowMillis":25201000})
	check(finished.ok and int(finished.state.researchLevels.turretStartLevel) == 1, "seven hours completes")
	var researched: Dictionary = finished.state
	check(not growth.execute(researched, {"kind":"startResearch","id":"turretStartLevel","nowMillis":25202000}).ok, "second level rejected")
	var commands := Commands.new(catalog, growth)
	for type in growth.data.turretRules:
		var plain: Dictionary = _built(growth, commands, catalog, p, type)
		check(plain.ok and int(plain.state.turrets[0].level) == 1, type + " without research starts at 1")
		var built: Dictionary = _built(growth, commands, catalog, researched, type)
		check(built.ok, type + " build")
		if not built.ok: continue
		var state: Dictionary = built.state
		var turret: Dictionary = state.turrets[0]
		var derived: Dictionary = commands.derived(state)
		var cost: int = commands.build_cost_from_derived(type, derived)
		check(int(turret.level) == 2, type + " starts at 2")
		check(int(state.gold) == 100000 - cost, type + " pays only the build cost")
		check(int(turret.investedGold) == cost, type + " free level stays out of investment")
		var quotes: Dictionary = commands.quotes(state, int(turret.id))
		check(int(quotes.sell) == int(float(cost) * float(derived.turretRefundPercent) / 100.0), type + " refund covers paid gold only")
		check(int(quotes.level) == int(commands.quotes(_leveled(commands, plain.state), int(plain.state.turrets[0].id)).level), type + " next price is the level 3 price")
		var emitted: Dictionary = commands.runtime_commands(state)[0].turret
		check(int(emitted.state.level) == 2, type + " battle hears level 2")
	var midrun: Dictionary = _built(growth, commands, catalog, p, "machinegun")
	midrun.state.progression = researched.duplicate(true)
	var later: int = commands.start_turret_level_from_derived("machinegun", commands.derived(midrun.state))
	check(int(midrun.state.turrets[0].level) == 1 and later == 2, "research finished mid-run lifts later builds only")
	check(commands.start_turret_level_from_derived("sniper", {"turretStartLevelBonus":2}) == 3, "later sources add up")
	check(commands.start_turret_level_from_derived("sniper", {"turretStartLevelBonus":99}) == commands.max_turret_level_from_derived("sniper", {}), "capped at max level")
	check(commands.start_turret_level_from_derived("sniper", {}) == 1, "missing bonus is level 1")
	check(Codec.ENUMS.ResearchType.has("turretStartLevel"), "codec knows the research")
	if not failures.is_empty():
		for failure in failures: printerr("FAIL ", failure)
		quit(1)
		return
	print("TURRET_START_LEVEL checks=", checks)
	quit()

func _leveled(commands: Commands, state: Dictionary) -> Dictionary:
	return commands.apply(state, {"kind":"level","id":int(state.turrets[0].id)}).state
