extends RefCounted
## Analysis-only run summary (docs/run_log_design.md). Built once when a run
## finishes and sent after its settlement; never saved or used for rewards.
const StageDifficulty = preload("res://content/stage_difficulty.gd")
const StageChallenges = preload("res://content/stage_challenges.gd")
const SCHEMA_VERSION := 1
const DAMAGE_FIELDS := ["directDamageDealt", "splashDamageDealt", "chainDamageDealt", "burnDamageDealt"]

## `arrivals` counts core contacts by "type:rarity" in this session only.
static func build(state: Dictionary, stage: Dictionary, runtime, arrivals: Dictionary, resumed: bool) -> Dictionary:
	var run_id: Variant = state.get("economyRunId")
	if not run_id is String or run_id.is_empty(): return {}
	var success: bool = str(state.get("phase", "")) == "success"
	var live: Dictionary = runtime.turrets if runtime != null and runtime.get("turrets") is Dictionary else {}
	var turrets: Array = []
	for turret in state.get("turrets", []):
		# Same source as the result screen: run state damage is only refreshed for saves.
		var damage := float(turret.get("damageDealt", 0))
		if live.has(str(turret.id)):
			damage = 0.0
			for field in DAMAGE_FIELDS: damage += float(live[str(turret.id)].get(field, 0))
		turrets.append({"type": turret.type, "x": int(turret.x), "y": int(turret.y), "level": int(turret.level),
			"gems": turret.get("equippedGemSlots", []).filter(func(gem): return gem != null),
			"primaryTrait": turret.get("primaryTrait"), "secondaryTrait": turret.get("secondaryTrait"),
			"targetPriority": turret.get("targetPriority", "first"), "damage": roundi(damage)})
	var cores: Array = []
	for core in state.get("supportCores", []):
		cores.append({"x": int(core.x), "y": int(core.y), "family": core.get("family", "")})
	var progression: Dictionary = state.get("progression", {})
	var upgrades := 0
	for key in progression:
		if str(key).ends_with("UpgradeLevel"): upgrades += int(progression[key])
	var research := 0
	for level in progression.get("researchLevels", {}).values(): research += int(level)
	var core_ranks := 0
	for rank in progression.get("corePassiveNodeRanks", {}).values(): core_ranks += int(rank)
	var modules: Variant = progression.get("turretModules", {})
	var defense = runtime.defense if runtime != null else null
	var stage_id := int(stage.id)
	return {"schemaVersion": SCHEMA_VERSION, "runId": run_id, "clientBuild": 0,
		"stageId": stage_id, "difficulty": StageDifficulty.of(state), "success": success,
		"completedRounds": int(state.get("completedRounds", 0)), "waveCount": int(stage.get("waveCount", 0)),
		"coreHp": roundi(defense.hp) if defense != null else 0, "coreHpMax": roundi(defense.max_hp) if defense != null else 0,
		"challengeMet": success and StageChallenges.met(state, stage_id),
		"peakTurrets": int(state.get(StageChallenges.PEAK_FIELD, 0)),
		"turretTypesUsed": state.get(StageChallenges.TYPES_FIELD, []).duplicate(),
		"arrivals": arrivals.duplicate(), "resumed": resumed,
		"turrets": turrets, "supportCores": cores,
		"upgradeLevels": upgrades, "researchLevels": research, "coreNodeRanks": core_ranks,
		"totalCorePoints": int(progression.get("totalCorePoints", 0)),
		"moduleCount": modules.get("items", []).size() if modules is Dictionary else 0,
		"clearedStages": progression.get("clearedStageNumbers", []).size()}
