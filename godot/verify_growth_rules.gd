extends SceneTree
const Growth = preload("res://app/growth_rules.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Json = preload("res://app/save_json.gd")
const StageProgression = preload("res://content/stage_progression.gd")
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
		# Original fixtures retain historical acquired levels and effects. Six
		# permanent commands formerly bypassed their UI gate; the approved
		# progression contract now rejects those unqualified level-zero buys.
		var old_ui_gates := {"physicalDamageTraining":7,"elementalDamageTraining":7,"criticalDamage":4,"killGold":1,"linkCostOptimization":9,"turretLevelUpOptimization":9}
		var gate_key := str(sample.command.get("id",sample.command.get("type","")))
		var gated: bool = sample.ok and sample.command.get("kind",sample.command.get("type")) in ["upgradePermanent","permanentUpgrade"] and old_ui_gates.has(gate_key) and int(sample.before.get(gate_key+"UpgradeLevel",0)) == 0 and int(old_ui_gates[gate_key]) not in sample.before.get("clearedStageNumbers",[])
		check(outcome.ok == (false if gated else sample.ok), sample.name + ": accepted")
		check(near(outcome.state, sample.before if gated else sample.after), sample.name + ": complete state")
		for pair in [[sample.before, sample.derived], [sample.after, sample.afterDerived]]:
			var d := growth.derive(pair[0])
			for run_level in [0, 1, 10, 11, 20, 21, 30]:
				var levels := {"killGold":run_level}
				var rewards: Dictionary = growth.kill_rewards(pair[0], levels)
				var full: Dictionary = growth.derive(pair[0], {"runUpgradeLevels":levels,"distinctTurretTypeCount":4,"distinctEquippedGemTypeCount":3})
				for key in rewards: check(rewards[key] == full[key],sample.name+": reward subset " + key + " level=" + str(run_level))
			for key in ["initialGold", "maxNexusHp", "startingGemShards", "maxTurretLinkSlots", "canSetTurretTargetPriority", "firstLinkUpgradeDiscountRate", "bossKillGemShardBonus", "runeResonanceBonusRate", "runUpgradeCostMultiplier", "bossBountyBonusRate", "permanentLinkCostMultiplier", "permanentTurretLevelUpCostMultiplier", "waveClearGoldBonus"]:
				check(near(d[key], pair[1][key]), sample.name + ": " + key)
	for sample in growth.data.legacyCore.verificationCases:
		check(near(growth.core_effects({"corePassiveNodeRanks":sample.ranks}), sample.effects), "combined core effects " + str(sample.ranks))
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	p.corePassiveTreeRevision = 4 # Historical allocation assertions retain the old catalog.
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
	_initial_research(growth)
	_boss_damage_training(growth)
	_damage_type_training(growth)
	_poison_turret(growth)
	_core_runtime(growth)
	print(JSON.stringify({"assertions":assertions,"failures":failures}))
	if failures.is_empty(): print("PASS growth rules")
	quit(0 if failures.is_empty() else 1)

func _initial_research(growth) -> void:
	for revision in [4, 5]:
		var fresh: Dictionary = growth.data.defaultProgression.duplicate(true)
		fresh.corePassiveTreeRevision = revision
		fresh.runes = 100000
		fresh.clearedStageNumbers = []
		check(not growth.derive(fresh).canSetTurretTargetPriority and near(growth.derive(fresh).turretRefundPercent, 75), "initial research effects require completion revision %d" % revision)
		for id in ["emergencySale", "turretTargetPriority"]:
			var quote: Dictionary = growth.research_quote(fresh, id)
			var started: Dictionary = growth.execute(fresh, {"kind":"startResearch", "id":id, "nowMillis":100})
			check(started.ok and started.state.runes == fresh.runes - quote.cost and int(started.state.researchLevels.get(id, 0)) == 0, "initial research starts with normal cost and time: %s revision %d" % [id, revision])
			if not started.ok: continue
			var finished: Dictionary = growth.execute(started.state, {"kind":"completeFinishedResearches", "nowMillis":100 + quote.durationMillis})
			check(finished.ok and finished.state.researchLevels.get(id) == 1 and finished.state.clearedStageNumbers.is_empty(), "initial research completes without stage clears: %s revision %d" % [id, revision])
			if not finished.ok: continue
			var effects: Dictionary = growth.derive(finished.state)
			check(near(effects.turretRefundPercent, 76) if id == "emergencySale" else effects.canSetTurretTargetPriority, "initial research effect applies before 1-1: %s revision %d" % [id, revision])
		check(not growth.execute(fresh, {"kind":"startResearch", "id":"criticalChance", "nowMillis":100}).ok, "other research stage gates remain revision %d" % revision)
		check(not growth.execute(fresh, {"kind":"upgradePermanent", "id":"killGold"}).ok, "kill gold remains gated at 1-1 revision %d" % revision)

func _boss_damage_training(growth) -> void:
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	p.runes = 67576
	p.clearedStageNumbers = [23] # 2-8 is not the 2-9 fixed ID24 gate.
	var buy := {"kind":"upgradePermanent", "id":"bossDamageTraining"}
	var locked: Dictionary = growth.execute(p, buy)
	check(not locked.ok and locked.state == p, "boss training locked purchase is atomic")
	var forged := p.duplicate(true)
	forged.bossDamageTrainingUpgradeLevel = 40
	check(near(growth.derive(forged).bossDamageBonusRate, 0.0), "boss training has no effect before its stage gate")
	var legacy := p.duplicate(true)
	legacy.erase("progressionVersion")
	check(not growth.execute(legacy, buy).ok, "new boss training has no legacy default entitlement")
	p.clearedStageNumbers.append(24)
	var base: Dictionary = growth.derive(p)
	check(near(base.bossDamageBonusRate, 0.0), "missing boss training field means level zero")
	var short := p.duplicate(true)
	short.runes = 199
	var rejected: Dictionary = growth.execute(short, buy)
	check(not rejected.ok and rejected.state == short, "boss training insufficient runes is atomic")
	var costs: Array = growth.data.permanentUpgrades.bossDamageTraining.costs
	check(costs[0] == 200 and costs[9] == 434 and costs[19] == 1028 and costs[29] == 2434 and costs[39] == 5763, "approved boss training cost milestones")
	for level in range(1, 41):
		var before: int = p.runes
		var purchased: Dictionary = growth.execute(p, buy)
		check(purchased.ok, "boss training purchase " + str(level))
		if not purchased.ok: return
		p = purchased.state
		check(p.bossDamageTrainingUpgradeLevel == level and before - int(p.runes) == int(costs[level-1]), "boss training one purchase one level and debit " + str(level))
	check(p.runes == 0 and near(growth.derive(p).bossDamageBonusRate, 0.2), "boss training 40 levels cost 67576 and grant additive 20 percent")
	p.runes = 100000
	var capped: Dictionary = growth.execute(p, buy)
	check(not capped.ok and capped.state == p, "boss training level 40 purchase is blocked without debit")
	var trained: Dictionary = growth.derive(p)
	base.erase("bossDamageBonusRate")
	trained.erase("bossDamageBonusRate")
	check(near(base, trained), "boss training leaves generic turret damage and all other growth unchanged")

func _core_runtime(growth) -> void:
	var catalog := Catalog.new()
	check(catalog.load_catalog(), "core catalog load")
	check(growth.data.get("coreConfig") is Dictionary, "core configuration source exported")
	if not growth.data.get("coreConfig") is Dictionary: return
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	p.unlockedStageCount = 11
	p.clearedStageNumbers = [20] # New progression reaches chapter two after fixed ID20.
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
	check(next.normalMaxHp == float(catalog.wave_durability(0,1,"normal").maxHp) and next.normalMaxHp != config.normalMaxHp, "round normal HP source")
	var timer: float = runtime.core.cooldown
	runtime.process_command({"epoch":1,"sequence":4,"dt":0.0,"commands":[{"kind":"coreConfig","config":next}]})
	check(runtime.core.cooldown == timer and runtime.core.activation_count == 3, "round config preserves timers")
	var unequipped: Dictionary = growth.execute(selected.state, {"type":"unequipCoreCombatSkill"})
	var off: Dictionary = growth.core_config({"progression":unequipped.state}, 0, 1, catalog)
	runtime.process_command({"epoch":1,"sequence":5,"dt":interval,"commands":[{"kind":"coreConfig","config":off}]})
	check(runtime.core.skill == null and runtime.core.activation_count == 3, "unequip stops runtime activations")

# Poison opens on the first 2-8 clear (stage ID 23) only, never through legacy
# rights. Its family training is poison damage training (same curve, same 2-8
# gate), never physical or elemental training.
func _poison_turret(growth) -> void:
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	# 17 opens family training so the exclusion is observable.
	p.clearedStageNumbers = [1, 17, 22]
	p.physicalDamageTrainingUpgradeLevel = 10
	p.elementalDamageTrainingUpgradeLevel = 10
	p.poisonDamageTrainingUpgradeLevel = 4
	p.fireTrainingUpgradeLevel = 3
	p.runes = 1000000
	var locked: Dictionary = growth.derive(p)
	check(not "poison" in locked.availableTurretTypes, "poison locked before 2-8")
	check(not "poisonDamage" in locked.availableGemTypes, "poison damage gem locked before 2-8")
	check(near(locked.turretStatInputs.poison.towerDamageMultiplier, 1.0 + 3 * growth._c("fireTrainingDamagePerUpgradeLevel")), "locked forged poison training has no effect")
	var rejected: Dictionary = growth.execute(p, {"kind":"upgradePermanent", "id":"poisonDamageTraining"})
	check(not rejected.ok and rejected.state == p, "poison training buy locked before 2-8")
	# New content ignores grandfathered rights, whether forged or from old run evidence.
	var forged := p.duplicate(true)
	forged.grandfatherUnlocks = ["turret:poison", "upgrade:poisonDamageTraining", "gem:poisonDamage", "gem:armorPiercing"]
	var forged_view: Dictionary = growth.derive(forged)
	check(not "poison" in forged_view.availableTurretTypes and not growth.execute(forged, {"kind":"upgradePermanent", "id":"poisonDamageTraining"}).ok, "poison ignores grandfathered rights")
	check(not "poisonDamage" in forged_view.availableGemTypes and "armorPiercing" in forged_view.availableGemTypes, "poison damage gem ignores grandfathered rights; legacy gems keep them")
	var migrated: Dictionary = StageProgression.migrate_progression({"unlockedStageCount":30}, {"turrets":[{"type":"poison", "equippedGemSlots":["poisonDamage", "armorPiercing"]}, {"type":"lightning"}], "gemInventory":{"poisonDamage":1}, "rewardOptions":["poisonDamage"]})
	check(not "turret:poison" in migrated.grandfatherUnlocks and "turret:lightning" in migrated.grandfatherUnlocks, "old run evidence grants legacy turrets only")
	check(not "gem:poisonDamage" in migrated.grandfatherUnlocks and "gem:armorPiercing" in migrated.grandfatherUnlocks, "old run evidence grants legacy gems only")
	var legacy := p.duplicate(true)
	legacy.erase("progressionVersion")
	legacy.unlockedStageCount = 30
	var legacy_view: Dictionary = growth.derive(legacy)
	check(not "poison" in legacy_view.availableTurretTypes, "poison has no legacy entitlement")
	check(not "poisonDamage" in legacy_view.availableGemTypes and "range" in legacy_view.availableGemTypes, "poison damage gem has no legacy entitlement")
	p.clearedStageNumbers.append(23)
	var open: Dictionary = growth.derive(p)
	check("poison" in open.availableTurretTypes, "poison opens on 2-8 first clear")
	check("poisonDamage" in open.availableGemTypes, "poison damage gem opens on 2-8 first clear")
	var poison: Dictionary = open.turretStatInputs.get("poison", {})
	var fire: float = 3 * growth._c("fireTrainingDamagePerUpgradeLevel")
	var family: float = 10 * growth._c("familyDamageTrainingBonusPerUpgradeLevel")
	var poison_family: float = 4 * growth._c("familyDamageTrainingBonusPerUpgradeLevel")
	check(near(poison.get("towerDamageMultiplier", 0.0), 1.0 + fire + poison_family), "poison gets poison training, not physical/elemental")
	check(near(open.turretStatInputs.magic.towerDamageMultiplier, 1.0 + fire + family), "elemental turret ignores poison training")
	check(near(open.turretStatInputs.arrow.towerDamageMultiplier, 1.0 + fire + family), "physical turret ignores poison training")
	var definition: Dictionary = growth.data.permanentUpgrades.poisonDamageTraining
	check(int(definition.maxLevel) == 50 and definition.costs == growth.data.permanentUpgrades.elementalDamageTraining.costs, "poison training shares the elemental curve")
	var bought: Dictionary = growth.execute(p, {"kind":"upgradePermanent", "id":"poisonDamageTraining"})
	check(bought.ok and int(bought.state.poisonDamageTrainingUpgradeLevel) == 5 and int(bought.state.runes) == 1000000 - int(definition.costs[4]), "poison training buy after 2-8")
	check(poison.has("moduleEffect") and poison.moduleEffect.values().all(func(v): return v == 0.0), "poison has neutral module effect")
	# Poison modules: venomCore rolls poison duration; burn duration never reaches poison.
	var moduled := p.duplicate(true)
	moduled.turretModules = {"items":[
		{"id":"p1","turretType":"poison","part":"core","family":"venomCore","grade":"rare","equipped":true,"options":[{"type":"poisonDurationIncrease","value":20},{"type":"splashRadiusIncrease","value":10},{"type":"burnDurationIncrease","value":20}]},
		{"id":"m1","turretType":"magic","part":"core","family":"ignitionCore","grade":"rare","equipped":true,"options":[{"type":"poisonDurationIncrease","value":20}]}]}
	var moduled_view: Dictionary = growth.derive(moduled)
	var poison_module: Dictionary = moduled_view.turretStatInputs.poison.moduleEffect
	check(near(poison_module.poisonDurationIncreaseRate, 0.2) and near(poison_module.splashRadiusIncreaseRate, 0.1) and near(poison_module.burnDurationIncreaseRate, 0.0), "poison core applies only its own pool")
	check(near(moduled_view.turretStatInputs.magic.moduleEffect.poisonDurationIncreaseRate, 0.0), "flame core cannot roll poison duration")

func _damage_type_training(growth) -> void:
	var keys := ["directDamageTraining", "splashDamageTraining", "damageOverTimeTraining"]
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	p.clearedStageNumbers = [25]
	p.runes = 1000000
	var neutral: Dictionary = growth.derive(p)
	for key in keys:
		var buy := {"kind":"upgradePermanent", "id":key}
		var rejected: Dictionary = growth.execute(p,buy)
		check(not rejected.ok and rejected.state == p,key+" locked buy is atomic before fixed ID26")
		var forged := p.duplicate(true)
		forged[key+"UpgradeLevel"] = 80
		check(near(growth.derive(forged)[key+"BonusRate"],0.0),key+" locked forged level has no effect")
		forged.erase("progressionVersion")
		check(not growth.execute(forged,buy).ok,key+" has no legacy default entitlement")
		for type in neutral.turretStatInputs:
			check(not neutral.turretStatInputs[type].has("damageOverTimeTrainingBonusRate"),"neutral optional stat input absent "+type)
	p.clearedStageNumbers.append(26)
	for key in keys:
		var costs: Array = growth.data.permanentUpgrades[key].costs
		check(int(growth.data.permanentUpgrades[key].maxLevel) == 80,key+" level cap80")
		var base := 300 if key == "directDamageTraining" else 200
		check(costs.size() == 81 and int(costs[0]) == base,key+" preserves starting cost")
		check(near(growth.data.constants[key+"UpgradeCostMultiplier"],1.055),key+" gentler cost curve")
		for index in range(80):
			check(int(costs[index]) == int(round(base*pow(1.055,index))),key+" rounded cost at "+str(index))
		var poor := p.duplicate(true)
		poor.runes = int(costs[0])-1
		var rejected: Dictionary = growth.execute(poor,{"kind":"upgradePermanent", "id":key})
		check(not rejected.ok and rejected.state == poor,key+" insufficient rune buy is atomic")
		for level in range(1,81):
			var before: int = p.runes
			var purchased: Dictionary = growth.execute(p,{"kind":"upgradePermanent", "id":key})
			check(purchased.ok,key+" buy level "+str(level))
			if not purchased.ok: return
			p = purchased.state
			check(int(p[key+"UpgradeLevel"]) == level and before-int(p.runes) == int(costs[level-1]),key+" one debit per level "+str(level))
			check(near(growth.derive(p)[key+"BonusRate"],level*0.005),key+" additive 0.5 percent per level "+str(level))
		var capped: Dictionary = growth.execute(p,{"kind":"upgradePermanent", "id":key})
		check(not capped.ok and capped.state == p,key+" buy beyond80 has no debit")
	var trained: Dictionary = growth.derive(p)
	var config: Dictionary = growth.combat_config(trained)
	for key in keys: check(near(config[key+"BonusRate"],0.4),key+" latest config40 percent")
	for type in trained.turretStatInputs:
		var actual: Dictionary = trained.turretStatInputs[type].duplicate(true)
		check(near(actual.damageOverTimeTrainingBonusRate,0.4),type+" exposes trained DoT stat")
		actual.erase("damageOverTimeTrainingBonusRate")
		check(near(actual,neutral.turretStatInputs[type]),type+" training preserves base damage and other layers")
	var catalog := Catalog.new()
	check(catalog.load_catalog(),"damage training catalog load")
	var trained_input: Dictionary = catalog.turret("magic",{"statInput":trained.turretStatInputs.magic})
	check(not trained_input.is_empty() and near(trained_input.get("damageOverTimeTrainingBonusRate"),0.4),"catalog accepts optional trained DoT scalar")
	check(catalog.turret("magic",{"statInput":{"damageOverTimeTrainingBonusRate":0.41}}).is_empty(),"catalog rejects excessive training stat scalar")
