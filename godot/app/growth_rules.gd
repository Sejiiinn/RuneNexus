extends RefCounted
const StageProgression = preload("res://content/stage_progression.gd")
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

func missing_research_prerequisites(p: Dictionary, key: String) -> Array:
	var prerequisites: Dictionary = StageProgression.research_prerequisites(key)
	return prerequisites.keys().filter(func(prerequisite): return _research(p, prerequisite) < int(prerequisites[prerequisite]))

func research_prerequisites_met(p: Dictionary, key: String) -> bool:
	return missing_research_prerequisites(p, key).is_empty()

# Prerequisite research always rechecks its fixed stage gate and research chain.
func research_chain_blocked(p: Dictionary, key: String) -> bool:
	return not StageProgression.research_prerequisites(key).is_empty() and (not StageProgression.has_unlock(p,"research",key) or not research_prerequisites_met(p,key))

func _research(p: Dictionary, key: String) -> int:
	if not StageProgression.has_unlock(p,"research",key) or not research_prerequisites_met(p,key): return 0
	return clampi(int(p.get("researchLevels", {}).get(key, 0)), 0, int(data.research.get(key, {}).get("maxLevel", 0)))

func max_link_slots(p: Dictionary) -> int:
	if _research(p,"linkExpansionOne") < 1: return 3
	return 5 if _research(p,"linkExpansionTwo") >= 1 else 4

func _level(p: Dictionary, key: String) -> int:
	var definition: Dictionary = data.permanentUpgrades.get(key, {})
	return clampi(int(p.get(definition.get("field", key + "UpgradeLevel"), 0)) if StageProgression.has_unlock(p,"upgrade",key) else 0, 0, int(definition.get("maxLevel", 0)))

func core_catalog(p: Dictionary = {}) -> Dictionary:
	var revision := int(p.get("corePassiveTreeRevision", 4))
	if revision == int(data.get("core", {}).get("revision", 5)): return data.core
	if revision >= 0 and revision <= 4: return data.get("legacyCore", data.get("core", {}))
	return {}

func core_effects(p: Dictionary) -> Dictionary:
	var catalog := core_catalog(p)
	if catalog.is_empty(): return {}
	var out: Dictionary = catalog.get("effectDefaults", {}).duplicate(true)
	for node in catalog.nodes:
		var definition: Dictionary = catalog.nodes[node]
		var rank := clampi(int(p.get("corePassiveNodeRanks", {}).get(node, 0)), 0, int(definition.maxRank))
		var effects: Dictionary = definition.effects[rank]
		for key in effects:
			if effects[key] is bool: out[key] = out.get(key, false) or effects[key]
			elif key.ends_with("Multiplier"): out[key] = float(out.get(key, 1.0)) * float(effects[key])
			else: out[key] = float(out.get(key, 0.0)) + float(effects[key])
	return out

## A v4 stage is never stopped or reconfigured by migration. Finished records
## retain their old frozen catalog even when their account allocation is reset.
## This only prepares an owned candidate; the lifecycle persists it atomically.
func migrate_core_tree(envelope: Dictionary) -> Dictionary:
	var out := envelope.duplicate(true)
	var p: Dictionary = out.get("progression", {})
	var revision := int(p.get("corePassiveTreeRevision", 4))
	if revision >= 5: return {"changed":false,"deferred":false,"state":out}
	var run: Variant = out.get("activeRun")
	if run is Dictionary and not str(run.get("phase", "preparation")) in ["success", "failure", "coreDestruction"]:
		return {"changed":false,"deferred":true,"state":out}
	if run is Dictionary:
		if not run.has("runCorePassiveTreeRevision"): run.runCorePassiveTreeRevision = revision
		if not run.has("runCorePassiveNodeRanks"): run.runCorePassiveNodeRanks = p.get("corePassiveNodeRanks", {}).duplicate(true)
	var ranks: Dictionary = p.get("corePassiveNodeRanks", {}).duplicate(true)
	p.corePassiveLegacyAllocation = {"revision":revision,"ranks":ranks,"refundedPoints":core_spent_points(ranks, revision)}
	p.corePassiveTreeRevision = 5
	p.corePassiveNodeRanks = {}
	out.progression = p
	return {"changed":true,"deferred":false,"state":out}

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

## Shared by full configuration and kill settlement; these rewards do not depend
## on board diversity or module equipment, so do not build turret configurations.
func kill_rewards(p: Dictionary, run_levels: Dictionary = {}) -> Dictionary:
	if data.is_empty(): return {}
	var kill_gold := _level(p, "killGold") * _c("killGoldBonusPerUpgradeLevel") if StageProgression.has_unlock(p,"upgrade","killGold") else 0.0
	var effects: Array = data.runUpgrades.killGold.effects
	var run_bonus := float(effects[clampi(int(run_levels.get("killGold", 0)), 0, effects.size() - 1)])
	return {
		"killGoldBonusRate":kill_gold + run_bonus,
		"bossBountyBonusRate":_level(p, "bossBounty") * _c("bossBountyBonusPerUpgradeLevel"),
		"bossKillGemShardBonus":int(_research(p, "crystalRecovery") * _c("bossGemShardsPerCrystalRecoveryLevel"))}

func derive(p: Dictionary, context: Dictionary = {}) -> Dictionary:
	if data.is_empty(): return {}
	var core := core_effects(p)
	if core.is_empty(): return {}
	var count := int(context.get("distinctTurretTypeCount", 0))
	var gems := int(context.get("distinctEquippedGemTypeCount", 0))
	var combined: float = core.combinedFrontMultiplier if count >= 4 else 1.0
	var run_levels: Dictionary = context.get("runUpgradeLevels", {})
	var rewards := kill_rewards(p, run_levels)
	var result := {
		"initialGold": int((_c("baseInitialGold") + _level(p, "startingGold") * _c("startingGoldPerUpgradeLevel")) * float(core.get("startingGoldMultiplier", 1.0))),
		"maxNexusHp": (_c("baseNexusHp") + _level(p, "nexusHp")) * core.nexusMaxHpMultiplier,
		"startingGemShards": int(_research(p, "gemAttunement") * _c("gemShardsPerGemAttunementLevel")),
		"maxTurretLinkSlots": max_link_slots(p),
		"canSetTurretTargetPriority": _research(p, "turretTargetPriority") > 0,
		"turretRefundPercent": minf(82.0, _c("baseTurretRefundPercent") + _research(p, "emergencySale") * _c("emergencySaleRefundPercentPerLevel") + float(core.get("turretRefundBonusRate", 0.0)) * 100.0) if int(p.get("corePassiveTreeRevision", 4)) >= 5 else int(_c("baseTurretRefundPercent") + _research(p, "emergencySale") * _c("emergencySaleRefundPercentPerLevel")),
		"permanentLinkCostMultiplier": 1.0 - _level(p, "linkCostOptimization") * _c("permanentCostReductionPerUpgradeLevel"),
		"permanentTurretLevelUpCostMultiplier": 1.0 - _level(p, "turretLevelUpOptimization") * _c("permanentCostReductionPerUpgradeLevel"),
		"firstLinkUpgradeDiscountRate": _research(p, "linkMaintenance") * _c("linkMaintenanceDiscountPerLevel"),
		"runUpgradeCostMultiplier": 1.0 - _research(p, "runUpgradeCostOptimization") * _c("runUpgradeCostDiscountPerLevel"),
		"passiveTurretBuildCostMultiplier": core.buildCostMultiplier * combined,
		"passiveTurretLevelUpCostMultiplier": (1.0 - core.diversityDiscountPerType * clampi(count - 1, 0, 4)) * combined * float(core.get("turretLevelUpCostMultiplier", 1.0)),
		"passiveTurretLinkCostMultiplier": core.linkCostMultiplier * combined,
		"passiveTraitShardCostMultiplier": core.traitShardCostMultiplier,
		"passiveNumericGemEffectMultiplier": 1.0 + (core.gemSpectrumPerType * mini(gems, 6) if gems >= 3 else 0.0),
		"waveClearGoldBonus": int(_level(p, "supply") * _c("supplyGoldPerUpgradeLevel")),
		"killGoldBonusRate": rewards.killGoldBonusRate,
		"bossBountyBonusRate": rewards.bossBountyBonusRate,
		"bossDamageBonusRate": _level(p, "bossDamageTraining") * _c("bossDamageTrainingBonusPerUpgradeLevel"),
		"directDamageTrainingBonusRate": _level(p, "directDamageTraining") * _c("directDamageTrainingBonusPerUpgradeLevel"),
		"splashDamageTrainingBonusRate": _level(p, "splashDamageTraining") * _c("splashDamageTrainingBonusPerUpgradeLevel"),
		"damageOverTimeTrainingBonusRate": _level(p, "damageOverTimeTraining") * _c("damageOverTimeTrainingBonusPerUpgradeLevel"),
		"bossKillGemShardBonus": rewards.bossKillGemShardBonus,
		"runeResonanceBonusRate": _research(p, "runeResonance") * _c("runeResonanceBonusPerLevel"),
		"roundClearGoldMultiplier": core.roundClearGoldMultiplier,
		"coreEffects": core,
		"runUpgradeMaxLevelBonuses": {}, "turretStatInputs": {},
	}
	result.defenseConfig = {"maxHp": result.maxNexusHp}
	if int(p.get("corePassiveTreeRevision", 4)) >= 5:
		result.defenseConfig.nexusAdditionalHpRate = core.get("nexusAdditionalHpRate", 0.0)
		result.defenseConfig.baseMaxHp = _c("baseNexusHp") + _level(p, "nexusHp")
		result.defenseConfig.hasIndomitableFortress = core.get("hasIndomitableFortress", false)
	result.maxTurretLevelBonus = int(core.get("maxTurretLevelBonus", 0))
	for key in ["roundRecoveryRate", "damageRestorationRate", "impactDispersionRate", "threatWeakeningRate", "emergencyRecoveryRate", "hasFinalDefense"]: result.defenseConfig[key] = core[key]
	for type in ["towerDamage", "killGold", "waveGold"]:
		result.runUpgradeMaxLevelBonuses[type] = int(_research(p, type + "LimitExpansion") * _c("runUpgradeLimitExpansionMaxLevelPerLevel"))
	var wave_level := clampi(int(run_levels.get("waveGold", 0)), 0, int(data.runUpgrades.waveGold.maxLevel) + result.runUpgradeMaxLevelBonuses.waveGold)
	result.waveClearGoldBonus += int(data.runUpgrades.waveGold.effects[wave_level])
	result.availableTurretTypes = ["arrow", "cannon", "magic", "frost"]
	if StageProgression.has_unlock(p,"turret","sniper"): result.availableTurretTypes.append("sniper")
	if StageProgression.has_unlock(p,"turret","lightning"): result.availableTurretTypes.append("lightning")
	if StageProgression.has_unlock(p,"turret","poison"): result.availableTurretTypes.append("poison")
	result.supportCoreUnlocked = StageProgression.has_unlock(p,"feature","supportCore")
	result.availableGemTypes = []
	for gem in data.gems:
		if not StageProgression.has_unlock(p,"gem",gem): continue
		result.availableGemTypes.append(gem)
	for type in data.module.pools.keys():
		var physical: bool = type in ["arrow", "cannon", "sniper"]
		# Poison is its own family with its own training, never physical or elemental.
		var family_key := "poisonDamageTraining" if type == "poison" else "physicalDamageTraining" if physical else "elementalDamageTraining"
		var family_training: float = _level(p, family_key) * _c("familyDamageTrainingBonusPerUpgradeLevel")
		var run_bonus: float = int(run_levels.get("towerDamage", 0)) * float(data.get("runUpgrades", {}).get("towerDamage", {}).get("effectPerLevel", 0))
		result.turretStatInputs[type] = {
			"moduleEffect": module_effect(p, type),
			"coreEffects": core,
			"towerDamageMultiplier": 1.0 + run_bonus + _level(p, "fireTraining") * _c("fireTrainingDamagePerUpgradeLevel") + family_training,
			"criticalChanceProgressionBonusRate": _research(p, "criticalChance") * _c("criticalChanceBonusPerResearchLevel") if StageProgression.has_unlock(p,"research","criticalChance") else 0.0,
			"criticalDamageProgressionBonusRate": _level(p, "criticalDamage") * _c("criticalDamageBonusPerUpgradeLevel") if StageProgression.has_unlock(p,"upgrade","criticalDamage") else 0.0,
			"passiveNumericGemEffectMultiplier": result.passiveNumericGemEffectMultiplier,
			"corePassiveTurretDamageMultiplier": 1.0 + (core.turretDamageAmplification if context.get("attackSyncActive", false) else 0.0),
			"corePassiveTurretAttackRateMultiplier": 1.0 + (core.turretAttackRateAmplification if context.get("attackSyncActive", false) else 0.0),
		}
		# Keep neutral legacy stat inputs byte-for-byte unchanged. The public DoT
		# statistic includes training; firing strips it before storing raw DPS.
		if result.damageOverTimeTrainingBonusRate > 0.0:
			result.turretStatInputs[type].damageOverTimeTrainingBonusRate = result.damageOverTimeTrainingBonusRate
	return result

func combat_config(effects: Dictionary) -> Dictionary:
	var result := {}
	for key in ["bossDamageBonusRate", "directDamageTrainingBonusRate", "splashDamageTrainingBonusRate", "damageOverTimeTrainingBonusRate"]:
		result[key] = effects.get(key, 0.0)
	return result

func research_quote(p: Dictionary, type: String) -> Dictionary:
	if not data.research.has(type): return {}
	var definition: Dictionary = data.research[type]
	var level := _research(p, type)
	var cost := maxi(1, roundi(float(definition.costs[level]) / (1.0 + _research(p, "researchCostEfficiency") * _c("researchCostEfficiencyPerLevel"))))
	var duration := maxi(1, roundi(float(definition.durations[level]) / (1.0 + _research(p, "researchEfficiency") * _c("researchEfficiencyPerLevel"))))
	var elapsed := clampi(int(p.get("researchElapsedMillis", {}).get(type, 0)), 0, duration - 1)
	return {"cost": cost, "durationMillis": duration, "remainingMillis": duration - elapsed, "level": level}

func core_spent_points(ranks: Dictionary, revision: int = 5) -> int:
	var catalog := core_catalog({"corePassiveTreeRevision":revision})
	if catalog.is_empty(): return -1
	var spent := 0
	for key in ranks:
		if not catalog.nodes.has(key) or not ranks[key] is int: return -1
		var rank: int = ranks[key]
		var node: Dictionary = catalog.nodes[key]
		if rank < 0 or rank > int(node.maxRank): return -1
		for i in range(rank): spent += int(node.rankCosts[i])
	return spent

func core_accessible_nodes(ranks: Dictionary, revision: int = 5) -> Array:
	var catalog := core_catalog({"corePassiveTreeRevision":revision})
	if catalog.is_empty(): return []
	var accessible: Array = catalog.startingNodes.duplicate()
	var index := 0
	while index < accessible.size():
		var key: String = str(accessible[index])
		index += 1
		if catalog.nodes[key].get("terminal", false) or int(ranks.get(key, 0)) < 3: continue
		for neighbor in catalog.nodes[key].neighbors:
			if not neighbor in accessible: accessible.append(neighbor)
	return accessible

func _valid_core(ranks: Dictionary, points: int, revision: int = 5) -> bool:
	var spent := core_spent_points(ranks, revision)
	if spent < 0 or spent > points: return false
	var accessible := core_accessible_nodes(ranks, revision)
	for key in ranks:
		if int(ranks[key]) > 0 and not key in accessible: return false
	return true

func valid_core_ranks(p: Dictionary, ranks: Dictionary) -> bool:
	return _valid_core(ranks, int(p.get("totalCorePoints", 0)), int(p.get("corePassiveTreeRevision", 4)))

## A single refund never silently removes descendants. The UI may show the
## separately confirmed bundle, or the always-free full reset, to the player.
func core_refund_preview(p: Dictionary, id: String, target_rank: int) -> Dictionary:
	var revision := int(p.get("corePassiveTreeRevision", 4))
	var before: Dictionary = p.get("corePassiveNodeRanks", {})
	var ranks := before.duplicate()
	if target_rank < 0 or target_rank >= int(before.get(id, 0)):
		return {"valid":false,"ranks":ranks,"orphaned":[],"refundedPoints":0}
	if target_rank == 0: ranks.erase(id)
	else: ranks[id] = target_rank
	var accessible := core_accessible_nodes(ranks, revision)
	var orphaned := []
	var bundle := ranks.duplicate()
	for key in ranks:
		if int(ranks[key]) > 0 and not key in accessible:
			orphaned.append(key)
			bundle.erase(key)
	return {"valid":valid_core_ranks(p,ranks),"ranks":ranks,"orphaned":orphaned,
		"refundedPoints":core_spent_points(before,revision)-core_spent_points(ranks,revision),
		"bundleRanks":bundle,"bundleRefundedPoints":core_spent_points(before,revision)-core_spent_points(bundle,revision)}

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
			if not data.permanentUpgrades.has(id) or not StageProgression.has_unlock(state,"upgrade",id): return rejected
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
			if ranks == state.corePassiveNodeRanks or not valid_core_ranks(state, ranks): return rejected
			state.corePassiveNodeRanks = ranks
			state.corePassiveTreeRevision = int(state.get("corePassiveTreeRevision", 4))
		"equipCoreCombatSkill":
			if not id in ["guardianBeam", "riftMark"] or not StageProgression.has_unlock(state,"core",id): return rejected
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
					if not StageProgression.has_unlock(state,"research",id) or not research_prerequisites_met(state,id): return rejected
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
		if data.research.has(active.type) and not research_chain_blocked(state,active.type):
			state.researchLevels[active.type] = clampi(int(active.targetLevel), 0, int(data.research[active.type].maxLevel))
			state.researchElapsedMillis.erase(active.type)
	return changed

## Stage and round are zero-based catalog indices, as in run_commands.
## Updating this configuration preserves the native skill's active timers.
## Core skill a run starting now would use: the selection, or Guardian Beam
## when Rift Mark is not unlocked. null when no skill is equipped.
func run_core_combat_skill(p: Dictionary) -> Variant:
	var skill: Variant = p.get("coreCombatSkill", "guardianBeam")
	if skill == "riftMark" and not StageProgression.has_unlock(p,"core","riftMark"): return "guardianBeam"
	return skill

## A run's loadout is fixed when its stage starts: core skill, core passive
## ranks and equipped turret modules. Growth (upgrades, research) is not part of
## it and applies to the running stage at once. Fields already present (a
## restored save) are kept; saves from before the loadout was recorded fix it
## at their first restore.
func fix_run_loadout(state: Dictionary) -> void:
	var p: Dictionary = state.get("progression", {})
	if not state.has("runCoreCombatSkill"): state.runCoreCombatSkill = run_core_combat_skill(p)
	if not state.has("runCorePassiveTreeRevision"): state.runCorePassiveTreeRevision = int(p.get("corePassiveTreeRevision", 4))
	if not state.has("runCorePassiveNodeRanks"): state.runCorePassiveNodeRanks = p.get("corePassiveNodeRanks", {}).duplicate(true)
	if not state.has("runTurretModules"):
		state.runTurretModules = p.get("turretModules", {}).get("items", []).filter(func(item): return item.get("equipped", false)).map(func(item): return item.duplicate(true))

## Progression for a run's combat effects: live growth with the run's fixed
## loadout (see fix_run_loadout). Read-only; shares unchanged nested values.
func run_effect_progression(state: Dictionary) -> Dictionary:
	var p: Dictionary = state.get("progression", {})
	if not state.has("runCorePassiveNodeRanks") and not state.has("runTurretModules"): return p
	var out := p.duplicate()
	if state.has("runCorePassiveNodeRanks"):
		out.corePassiveNodeRanks = state.runCorePassiveNodeRanks
		out.corePassiveTreeRevision = int(state.get("runCorePassiveTreeRevision", p.get("corePassiveTreeRevision", 4)))
	if state.has("runTurretModules"): out.turretModules = {"items": state.runTurretModules}
	return out

func core_config(state: Dictionary, stage: int, round_index: int, catalog) -> Dictionary:
	if not data.get("coreConfig") is Dictionary or catalog == null or stage < 0 or stage >= catalog.stage_count():
		error = "Missing core configuration or stage"
		return {}
	var p: Dictionary = run_effect_progression(state) if state.has("progression") else state
	var effects := core_effects(p)
	if effects.is_empty():
		error = "Unsupported core tree catalog"
		return {}
	var config: Dictionary = data.coreConfig.duplicate(true)
	var skill: Variant = state.get("runCoreCombatSkill") if state.has("runCoreCombatSkill") else run_core_combat_skill(p)
	if skill != null and not skill in ["guardianBeam", "riftMark"]: skill = "guardianBeam"
	config.runSkill = skill
	config.cooldownRecoveryMultiplier = 1.0 + effects.cooldownRecoveryRate
	config.killCoreChargeRate = effects.get("killCoreChargeRate", 0.0)
	config.powerMultiplier = effects.coreSkillPowerMultiplier
	config.powerEveryThirdMultiplier = effects.thirdCoreSkillPowerMultiplier / effects.coreSkillPowerMultiplier
	config.attackSyncDamageMultiplier = 1.0 + effects.turretDamageAmplification
	config.attackSyncAttackRateMultiplier = 1.0 + effects.turretAttackRateAmplification
	var count: int = catalog.wave_count(stage)
	if count == 0:
		error = "Stage has no core HP reference"
		return {}
	config.normalMaxHp = float(catalog.wave_durability(stage, clampi(round_index, 0, count - 1), "normal").maxHp)
	return config
