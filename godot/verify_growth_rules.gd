extends SceneTree
const Growth = preload("res://app/growth_rules.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Json = preload("res://app/save_json.gd")
var failures: Array = []
var assertions := 0
func check(value: bool, label: String) -> void:
	assertions += 1
	if not value: failures.append(label)
func near(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return absf(float(a)-float(b)) < 0.0000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not near(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not near(a[i], b[i]): return false
		return true
	return a == b
func _init() -> void:
	var growth := Growth.new()
	check(growth.load_catalog(), "load")
	if growth.data.is_empty(): quit(1); return
	var path := ProjectSettings.globalize_path("res://../test/fixtures/growth_progression_cases.json")
	var fixtures: Dictionary = Json.parse_record(FileAccess.get_file_as_string(path)).value
	for sample in fixtures.cases:
		var outcome := growth.execute(sample.before, sample.command)
		check(outcome.ok == sample.ok, sample.name + ": accepted")
		check(near(outcome.state, sample.after), sample.name + ": complete state")
		for pair in [[sample.before, sample.derived], [sample.after, sample.afterDerived]]:
			var d := growth.derive(pair[0])
			for key in ["initialGold", "maxNexusHp", "startingGemShards", "maxTurretLinkSlots", "canSetTurretTargetPriority", "firstLinkUpgradeDiscountRate", "bossKillGemShardBonus", "runeResonanceBonusRate", "runUpgradeCostMultiplier", "bossBountyBonusRate", "permanentLinkCostMultiplier", "permanentTurretLevelUpCostMultiplier", "waveClearGoldBonus"]:
				check(near(d[key], pair[1][key]), sample.name + ": " + key)
	for sample in growth.data.core.verificationCases:
		check(near(growth.core_effects({"corePassiveNodeRanks":sample.ranks}), sample.effects), "combined core effects " + str(sample.ranks))
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	p.runes = 1000000
	p.clearedStageNumbers = [1,2,3,4,5,6,7,8,9,10]
	p.totalCorePoints = 100
	var start := growth.execute(p, {"type":"startResearch", "id":"researchEfficiency", "nowMillis":1000})
	check(start.ok, "timed research start")
	var quote := growth.research_quote(p, "researchEfficiency")
	var cancel := growth.execute(start.state, {"type":"cancelResearch", "id":"researchEfficiency", "nowMillis":1100})
	check(cancel.ok and cancel.state.runes == p.runes and cancel.state.researchElapsedMillis.researchEfficiency == 100, "cancel retains time refunds runes")
	var resumed := growth.execute(cancel.state, {"type":"startResearch", "id":"researchEfficiency", "nowMillis":2000})
	check(resumed.ok and resumed.state.activeResearches[0].durationMillis == quote.durationMillis - 100, "resume remaining duration")
	var complete := growth.execute(resumed.state, {"type":"completeFinishedResearches", "nowMillis":2000 + quote.durationMillis})
	check(complete.ok and complete.state.researchLevels.researchEfficiency == 1 and complete.state.researchElapsedMillis.is_empty(), "elapsed completion")
	check(not growth.execute(complete.state, {"type":"completeFinishedResearches", "nowMillis":2000 + quote.durationMillis}).ok, "completion idempotence")
	check(not growth.execute(p, {"type":"setCorePassiveRank", "id":"attackOverclock", "rank":1}).ok, "core unreachable rejected")
	var core := growth.execute(p, {"type":"setCorePassiveRank", "id":"attackHaste", "rank":3})
	check(core.ok and growth.derive(core.state).coreEffects.cooldownRecoveryRate > 0, "core allocation effects")
	check(growth.execute(core.state, {"type":"resetCorePassiveTree"}).ok, "core reset")
	check(not growth.execute(p, {"type":"upgradePermanent", "id":"startingGold", "scope":"server"}).ok, "server scope rejected")
	for kind in ["unlockResearchSlotTwo", "completeResearchWithDiamonds", "drawTurretModules", "disassembleTurretModule"]:
		check(not growth.execute(p, {"type":kind}).ok, "authority retained " + kind)
	var family: String = growth.data.module.families.arrow.core
	p.turretModules = {"items":[{"id":"m1","turretType":"arrow","part":"core","family":family,"grade":"normal","equipped":false,"options":[{"type":"damageIncrease","value":999}]}]}
	var equip := growth.execute(p, {"type":"equipTurretModule", "id":"m1"})
	check(equip.ok, "existing module equip")
	var effect := growth.module_effect(equip.state, "arrow")
	check(effect.damageIncreaseRate == float(growth.data.module.ranges.damageIncrease.normal.max)/100.0, "module valid pool clamp")
	check(growth.execute(equip.state, {"type":"unequipTurretModule", "id":"m1"}).ok, "module unequip")
	_core_runtime(growth)
	print(JSON.stringify({"assertions":assertions,"failures":failures}))
	if failures.is_empty(): print("PASS growth rules")
	quit(0 if failures.is_empty() else 1)

func _core_runtime(growth) -> void:
	var catalog := Catalog.new()
	check(catalog.load_catalog(), "core catalog load")
	check(growth.data.get("coreConfig") is Dictionary, "core configuration source exported")
	if not growth.data.get("coreConfig") is Dictionary: return
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	p.unlockedStageCount = 6
	p.totalCorePoints = 10000
	var allocation: Dictionary = {}
	for key in growth.data.core.nodes: allocation[key] = int(growth.data.core.nodes[key].maxRank)
	var allocated: Dictionary = growth.execute(p, {"type":"setCorePassiveRanks", "ranks":allocation})
	check(allocated.ok, "full connected core allocation")
	var selected: Dictionary = growth.execute(allocated.state, {"type":"equipCoreCombatSkill", "id":"riftMark"})
	check(selected.ok, "rift selection")
	var config: Dictionary = growth.core_config({"progression":selected.state}, 0, 0, catalog)
	var enemy := {"id":31,"hp":100000.0,"maxHp":100000.0,"x":50.0,"y":0.0,"type":"normal","path":[],"speed":0.0}
	var runtime := Runtime.new()
	runtime.process_command({"epoch":1,"sequence":0,"running":true,"dt":0.0,"bootstrap":{"enemies":[enemy],"turrets":[],"coreConfig":config,"wave":{"id":1,"active":true,"spawnQueue":[]}}})
	check(runtime.core.skill == "riftMark", "selected core reaches runtime")
	var interval: float = runtime.core.interval()
	check(near(interval, float(growth.data.coreConfig.riftMarkInterval) / config.cooldownRecoveryMultiplier), "growth cooldown reaches runtime")
	runtime.process_command({"epoch":1,"sequence":1,"running":true,"dt":interval})
	check(runtime.core.activation_count == 1, "selected core activates after interval")
	check(near(runtime.enemies["31"].riftMarkDamageAmplification, float(config.riftMarkDamageAmplification) * config.powerMultiplier), "selected core actual mark strength")
	runtime.process_command({"epoch":1,"sequence":2,"running":true,"dt":interval})
	runtime.process_command({"epoch":1,"sequence":3,"running":true,"dt":interval})
	check(runtime.core.activation_count == 3 and near(runtime.enemies["31"].riftMarkDamageAmplification, float(config.riftMarkDamageAmplification) * config.powerMultiplier * config.powerEveryThirdMultiplier), "third activation growth power")
	var next: Dictionary = growth.core_config({"progression":selected.state}, 0, 1, catalog)
	check(next.normalMaxHp == float(catalog.data.stages[0].waves[1].enemyDurability.normal.maxHp) and next.normalMaxHp != config.normalMaxHp, "round normal HP source")
	var timer: float = runtime.core.cooldown
	runtime.process_command({"epoch":1,"sequence":4,"dt":0.0,"commands":[{"kind":"coreConfig","config":next}]})
	check(runtime.core.cooldown == timer and runtime.core.activation_count == 3, "round config preserves timers")
	var unequipped: Dictionary = growth.execute(selected.state, {"type":"unequipCoreCombatSkill"})
	var off: Dictionary = growth.core_config({"progression":unequipped.state}, 0, 1, catalog)
	runtime.process_command({"epoch":1,"sequence":5,"dt":interval,"commands":[{"kind":"coreConfig","config":off}]})
	check(runtime.core.skill == null and runtime.core.activation_count == 3, "unequip stops runtime activations")
