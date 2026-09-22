extends RefCounted
## Local session progression rules. Never performs network or persistent writes.
const Json = preload("res://app/save_json.gd")
var data: Dictionary = {}
var error := ""

func load_catalog(path: String = "res://content/growth_content.json") -> bool:
	var parsed: Dictionary = Json.parse_record(FileAccess.get_file_as_string(path))
	if not parsed.ok or not parsed.value is Dictionary:
		error = "Invalid growth catalog"
		return false
	data = parsed.value
	return data.has_all(["permanentUpgrades", "research", "constants", "core", "module"])

func _c(key: String) -> float:
	return float(data.constants.get(key, 0))

func _research(p: Dictionary, key: String) -> int:
	return clampi(int(p.get("researchLevels", {}).get(key, 0)), 0, int(data.research.get(key, {}).get("maxLevel", 0)))

func _level(p: Dictionary, key: String) -> int:
	var definition: Dictionary = data.permanentUpgrades.get(key, {})
	return clampi(int(p.get(definition.get("field", key + "UpgradeLevel"), 0)), 0, int(definition.get("maxLevel", 0)))

func core_effects(p: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for node in data.core.nodes:
		var def: Dictionary = data.core.nodes[node]
		var rank := clampi(int(p.get("corePassiveNodeRanks", {}).get(node, 0)), 0, int(def.maxRank))
		var effects: Dictionary = def.effects[rank]
		for key in effects:
			if effects[key] is bool: out[key] = out.get(key, false) or effects[key]
			elif key.ends_with("Multiplier"): out[key] = float(out.get(key, 1.0)) * float(effects[key])
			else: out[key] = float(out.get(key, 0.0)) + float(effects[key])
	return out

func module_effect(p: Dictionary, type: String) -> Dictionary:
	var result: Dictionary = {}
	for sample in data.module.effects.values():
		for key in sample: result[key] = 0.0
	var slots := {}
	for item in p.get("turretModules", {}).get("items", []):
		if not item.get("equipped", false) or item.get("turretType") != type: continue
		var part: String = str(item.get("part", ""))
		if slots.has(part) or data.module.families.get(type, {}).get(part) != item.get("family"): continue
		slots[part] = true
		var seen := {}
		for option in item.get("options", []):
			var key: String = str(option.get("type", ""))
			if seen.has(key) or not key in data.module.pools.get(type, {}).get(part, []): continue
			var limits: Dictionary = data.module.ranges.get(key, {}).get(item.get("grade"), {})
			if limits.is_empty(): continue
			seen[key] = true
			var value := clampf(float(option.get("value", 0)), float(limits.min), float(limits.max)) / 100.0
			for field in data.module.effects[key]: result[field] += value * float(data.module.effects[key][field])
	return result

func derive(p: Dictionary, context: Dictionary = {}) -> Dictionary:
	if data.is_empty(): return {}
	var core := core_effects(p)
	var count := int(context.get("distinctTurretTypeCount", 0))
	var gems := int(context.get("distinctEquippedGemTypeCount", 0))
	var combined: float = core.combinedFrontMultiplier if count >= 4 else 1.0
	var cleared: Array = p.get("clearedStageNumbers", [])
	var economy_unlocked: bool = int(data.constants.get("economyUpgradeUnlockStage", 1)) in cleared
	var result := {
		"initialGold": int(_c("baseInitialGold") + _level(p, "startingGold") * _c("startingGoldPerUpgradeLevel")),
		"maxNexusHp": (_c("baseNexusHp") + _level(p, "nexusHp")) * core.nexusMaxHpMultiplier,
		"startingGemShards": int(_research(p, "gemAttunement") * _c("gemShardsPerGemAttunementLevel")),
		"maxTurretLinkSlots": 4 if _research(p, "linkExpansionOne") >= int(data.research.get("linkExpansionOne", {}).get("maxLevel", 1)) else 3,
		"canSetTurretTargetPriority": _research(p, "turretTargetPriority") > 0,
		"turretRefundPercent": int(_c("baseTurretRefundPercent") + (_research(p, "emergencySale") * _c("emergencySaleRefundPercentPerLevel") if economy_unlocked else 0)),
		"permanentLinkCostMultiplier": 1.0 - _level(p, "linkCostOptimization") * _c("permanentCostReductionPerUpgradeLevel"),
		"permanentTurretLevelUpCostMultiplier": 1.0 - _level(p, "turretLevelUpOptimization") * _c("permanentCostReductionPerUpgradeLevel"),
		"firstLinkUpgradeDiscountRate": _research(p, "linkMaintenance") * _c("linkMaintenanceDiscountPerLevel"),
		"runUpgradeCostMultiplier": 1.0 - _research(p, "runUpgradeCostOptimization") * _c("runUpgradeCostDiscountPerLevel"),
		"passiveTurretBuildCostMultiplier": core.buildCostMultiplier * combined,
		"passiveTurretLevelUpCostMultiplier": (1.0 - core.diversityDiscountPerType * clampi(count - 1, 0, 4)) * combined,
		"passiveTurretLinkCostMultiplier": core.linkCostMultiplier * combined,
		"passiveTraitShardCostMultiplier": core.traitShardCostMultiplier,
		"passiveNumericGemEffectMultiplier": 1.0 + (core.gemSpectrumPerType * mini(gems, 6) if gems >= 3 else 0.0),
		"waveClearGoldBonus": int(_level(p, "supply") * _c("supplyGoldPerUpgradeLevel")),
		"killGoldBonusRate": _level(p, "killGold") * _c("killGoldBonusPerUpgradeLevel") if economy_unlocked else 0.0,
		"bossBountyBonusRate": _level(p, "bossBounty") * _c("bossBountyBonusPerUpgradeLevel"),
		"bossKillGemShardBonus": int(_research(p, "crystalRecovery") * _c("bossGemShardsPerCrystalRecoveryLevel")),
		"runeResonanceBonusRate": _research(p, "runeResonance") * _c("runeResonanceBonusPerLevel"),
		"roundClearGoldMultiplier": core.roundClearGoldMultiplier,
		"coreEffects": core,
		"runUpgradeMaxLevelBonuses": {}, "turretStatInputs": {},
	}
	result.defenseConfig = {"maxHp": result.maxNexusHp}
	for key in ["roundRecoveryRate", "damageRestorationRate", "impactDispersionRate", "threatWeakeningRate", "emergencyRecoveryRate", "hasFinalDefense"]: result.defenseConfig[key] = core[key]
	for type in ["towerDamage", "killGold", "waveGold"]:
		result.runUpgradeMaxLevelBonuses[type] = int(_research(p, type + "LimitExpansion") * _c("runUpgradeLimitExpansionMaxLevelPerLevel"))
	var run_levels: Dictionary = context.get("runUpgradeLevels", {})
	result.killGoldBonusRate += int(run_levels.get("killGold", 0)) * float(data.runUpgrades.killGold.effectPerLevel)
	var wave_level := clampi(int(run_levels.get("waveGold", 0)), 0, int(data.runUpgrades.waveGold.maxLevel) + result.runUpgradeMaxLevelBonuses.waveGold)
	result.waveClearGoldBonus += int(data.runUpgrades.waveGold.effects[wave_level])
	result.availableTurretTypes = ["arrow", "cannon", "magic", "frost"]
	if int(data.constants.get("sniperUnlockStage", 3)) in cleared: result.availableTurretTypes.append("sniper")
	if 6 in cleared: result.availableTurretTypes.append("lightning")
	result.availableGemTypes = []
	for gem in data.gems:
		if gem == "aimSpeed" and not int(data.constants.get("aimSpeedGemUnlockStage", 3)) in cleared: continue
		if gem == "armorPiercing" and not int(data.constants.get("armorPiercingGemUnlockStage", 3)) in cleared: continue
		result.availableGemTypes.append(gem)
	for type in data.module.pools:
		var physical: bool = type in ["arrow", "cannon", "sniper"]
		var run_bonus: float = int(run_levels.get("towerDamage", 0)) * float(data.get("runUpgrades", {}).get("towerDamage", {}).get("effectPerLevel", 0))
		result.turretStatInputs[type] = {
			"moduleEffect": module_effect(p, type),
			"towerDamageMultiplier": 1.0 + run_bonus + _level(p, "fireTraining") * _c("fireTrainingDamagePerUpgradeLevel") + _level(p, "physicalDamageTraining" if physical else "elementalDamageTraining") * _c("familyDamageTrainingBonusPerUpgradeLevel"),
			"criticalChanceProgressionBonusRate": _research(p, "criticalChance") * _c("criticalChanceBonusPerResearchLevel") if 4 in cleared else 0.0,
			"criticalDamageProgressionBonusRate": _level(p, "criticalDamage") * _c("criticalDamageBonusPerUpgradeLevel") if 4 in cleared else 0.0,
			"passiveNumericGemEffectMultiplier": result.passiveNumericGemEffectMultiplier,
			"corePassiveTurretDamageMultiplier": 1.0 + (core.turretDamageAmplification if context.get("attackSyncActive", false) else 0.0),
			"corePassiveTurretAttackRateMultiplier": 1.0 + (core.turretAttackRateAmplification if context.get("attackSyncActive", false) else 0.0),
		}
	return result

func research_quote(p: Dictionary, type: String) -> Dictionary:
	if not data.research.has(type): return {}
	var definition: Dictionary = data.research[type]
	var level := _research(p, type)
	var cost := maxi(1, roundi(float(definition.costs[level]) / (1.0 + _research(p, "researchCostEfficiency") * _c("researchCostEfficiencyPerLevel"))))
	var duration := maxi(1, roundi(float(definition.durations[level]) / (1.0 + _research(p, "researchEfficiency") * _c("researchEfficiencyPerLevel"))))
	var elapsed := clampi(int(p.get("researchElapsedMillis", {}).get(type, 0)), 0, duration - 1)
	return {"cost": cost, "durationMillis": duration, "remainingMillis": duration - elapsed, "level": level}

func _valid_core(ranks: Dictionary, points: int) -> bool:
	var accessible: Array = data.core.startingNodes.duplicate()
	var spent := 0
	for key in ranks:
		if not data.core.nodes.has(key) or not ranks[key] is int: return false
		var rank: int = ranks[key]
		var node: Dictionary = data.core.nodes[key]
		if rank < 0 or rank > int(node.maxRank): return false
		for i in range(rank): spent += int(node.rankCosts[i])
	if spent > points: return false
	var previous := -1
	while previous != accessible.size():
		previous = accessible.size()
		for key in accessible.duplicate():
			if int(ranks.get(key, 0)) >= 3:
				for neighbor in data.core.nodes[key].neighbors:
					if not neighbor in accessible: accessible.append(neighbor)
	for key in ranks:
		if int(ranks[key]) > 0 and not key in accessible: return false
	return true

func execute(p: Dictionary, command: Dictionary) -> Dictionary:
	var state := p.duplicate(true)
	var rejected := {"ok": false, "state": p.duplicate(true), "error": "Invalid local growth command"}
	if data.is_empty() or command.get("scope", "local") != "local": return rejected
	for key in ["researchLevels", "researchElapsedMillis", "corePassiveNodeRanks"]:
		if not state.has(key): state[key] = {}
	if not state.has("activeResearches"): state.activeResearches = []
	var action: String = str(command.get("kind", command.get("type", "")))
	var id: String = str(command.get("id", command.get("type", "") if command.has("kind") else ""))
	if action == "permanentUpgrade": action = "upgradePermanent"
	match action:
		"upgradePermanent":
			if not data.permanentUpgrades.has(id): return rejected
			var d: Dictionary = data.permanentUpgrades[id]
			var level := _level(state, id)
			if not d.get("enabled", true) or level >= int(d.maxLevel): return rejected
			var cost := int(d.costs[level])
			if int(state.get("runes", 0)) < cost: return rejected
			state.runes = int(state.get("runes", 0)) - cost
			state[d.field] = level + 1
		"setCorePassiveRanks", "setCorePassiveRank", "resetCorePassiveTree":
			var ranks: Dictionary = state.corePassiveNodeRanks.duplicate()
			if action == "resetCorePassiveTree": ranks = {}
			elif action == "setCorePassiveRanks":
				if not command.get("ranks") is Dictionary: return rejected
				ranks = command.ranks.duplicate()
			else: ranks[id] = command.get("rank", -1)
			for key in ranks.keys():
				if ranks[key] == 0: ranks.erase(key)
			if ranks == state.corePassiveNodeRanks or not _valid_core(ranks, int(state.get("totalCorePoints", 0))): return rejected
			state.corePassiveNodeRanks = ranks
			state.corePassiveTreeRevision = data.core.revision
		"equipCoreCombatSkill":
			if not id in ["guardianBeam", "riftMark"] or (id == "riftMark" and int(state.get("unlockedStageCount", 1)) < 6): return rejected
			state.coreCombatSkill = id
		"unequipCoreCombatSkill":
			if state.get("coreCombatSkill", "guardianBeam") == null: return rejected
			state.coreCombatSkill = null
		"equipTurretModule", "unequipTurretModule":
			var items: Array = state.get("turretModules", {}).get("items", [])
			var selected: Dictionary = {}
			for item in items:
				if item.get("id") == id: selected = item
			if selected.is_empty(): return rejected
			if action == "unequipTurretModule":
				if not selected.get("equipped", false): return rejected
				selected.equipped = false
			else:
				for item in items:
					if item.get("turretType") == selected.get("turretType") and item.get("part") == selected.get("part"): item.equipped = item.get("id") == id
		"startResearch", "cancelResearch", "completeFinishedResearches":
			if not command.get("nowMillis") is int or command.nowMillis < 0: return rejected
			var now: int = command.nowMillis
			if action == "completeFinishedResearches":
				if not _complete_research(state, now): return rejected
			else:
				if not data.research.has(id): return rejected
				var active_index := -1
				for i in range(state.activeResearches.size()):
					if state.activeResearches[i].type == id: active_index = i
				var quote := research_quote(state, id)
				if action == "startResearch":
					var d: Dictionary = data.research[id]
					if active_index >= 0 or quote.level >= int(d.maxLevel) or state.activeResearches.size() >= (2 if state.get("researchSlotTwoUnlocked", false) else 1): return rejected
					if int(d.requiredClearedStage) > 0 and not int(d.requiredClearedStage) in state.get("clearedStageNumbers", []): return rejected
					if int(state.get("runes", 0)) < quote.cost: return rejected
					state.runes = int(state.get("runes", 0)) - quote.cost
					state.activeResearches.append({"type": id, "targetLevel": quote.level + 1, "startedAtMillis": now, "durationMillis": quote.remainingMillis, "initialElapsedMillis": int(state.researchElapsedMillis.get(id, 0))})
				else:
					if active_index < 0: return rejected
					var active: Dictionary = state.activeResearches[active_index]
					if now >= int(active.startedAtMillis) + int(active.durationMillis):
						_complete_research(state, now)
					else:
						state.activeResearches.remove_at(active_index)
						state.runes = int(state.get("runes", 0)) + quote.cost
						var elapsed := clampi(int(active.get("initialElapsedMillis", 0)) + clampi(now - int(active.startedAtMillis), 0, int(active.durationMillis)), 0, quote.durationMillis - 1)
						if elapsed > 0: state.researchElapsedMillis[id] = elapsed
						else: state.researchElapsedMillis.erase(id)
		_:
			return rejected
	return {"ok": true, "state": state, "error": ""}

func _complete_research(state: Dictionary, now: int) -> bool:
	var changed := false
	for active in state.activeResearches.duplicate():
		if now < int(active.startedAtMillis) + int(active.durationMillis): continue
		state.activeResearches.erase(active)
		changed = true
		if data.research.has(active.type):
			state.researchLevels[active.type] = clampi(int(active.targetLevel), 0, int(data.research[active.type].maxLevel))
			state.researchElapsedMillis.erase(active.type)
	return changed

## Stage and round are zero-based catalog indices, as in run_commands.
## Updating this configuration preserves the native skill's active timers.
func core_config(state: Dictionary, stage: int, round_index: int, catalog) -> Dictionary:
	if not data.get("coreConfig") is Dictionary or catalog == null or stage < 0 or stage >= catalog.stage_count():
		error = "Missing core configuration or stage"
		return {}
	var p: Dictionary = state.get("progression", state)
	var effects := core_effects(p)
	var config: Dictionary = data.coreConfig.duplicate(true)
	var skill: Variant = state.get("runCoreCombatSkill", p.get("coreCombatSkill", "guardianBeam"))
	if not state.has("runCoreCombatSkill") and skill == "riftMark" and int(p.get("unlockedStageCount", 1)) < 6: skill = "guardianBeam"
	if skill != null and not skill in ["guardianBeam", "riftMark"]: skill = "guardianBeam"
	config.runSkill = skill
	config.cooldownRecoveryMultiplier = 1.0 + effects.cooldownRecoveryRate
	config.powerMultiplier = effects.coreSkillPowerMultiplier
	config.powerEveryThirdMultiplier = effects.thirdCoreSkillPowerMultiplier / effects.coreSkillPowerMultiplier
	config.attackSyncDamageMultiplier = 1.0 + effects.turretDamageAmplification
	config.attackSyncAttackRateMultiplier = 1.0 + effects.turretAttackRateAmplification
	var waves: Array = catalog.data.stages[stage].waves
	if waves.is_empty():
		error = "Stage has no core HP reference"
		return {}
	config.normalMaxHp = float(waves[clampi(round_index, 0, waves.size() - 1)].enemyDurability.normal.maxHp)
	return config
