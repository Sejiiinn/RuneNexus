extends RefCounted
## Existing Dart GameSaveData v2 wire contract, including v1 migration.
## Enum IDs and scalar field rules mirror lib/data/save/game_save*.dart.
const CoreTree = preload("res://content/generated_core_tree.gd")
const ENUMS = {
	"ResearchType": [
		"researchEfficiency",
		"researchCostEfficiency",
		"turretTargetPriority",
		"linkExpansionOne",
		"gemAttunement",
		"bossBounty",
		"criticalChance",
		"emergencySale",
		"linkMaintenance",
		"crystalRecovery",
		"runeResonance",
		"runUpgradeCostOptimization",
		"towerDamageLimitExpansion",
		"killGoldLimitExpansion",
		"waveGoldLimitExpansion",
		"linkExpansionTwo"
	],
	"TurretType": [
		"arrow",
		"cannon",
		"magic",
		"frost",
		"sniper",
		"lightning"
	],
	"TurretTraitType": [
		"overheatMagazine",
		"lightweightBarrel",
		"shrapnelShell",
		"compressedCharge",
		"highHeatBurn",
		"lingeringEmbers",
		"ignitionBurst",
		"chainIgnition",
		"rapidCooling",
		"spreadingChill",
		"frostCrack",
		"coolingCycle",
		"suppressiveFire",
		"chainCleanup",
		"expandedBlastCore",
		"fractureImpact",
		"deadeyeFocus",
		"quickScope",
		"exposedMark",
		"finishingShot",
		"branchCurrent",
		"focusedLightning",
		"lightningRecovery",
		"currentAmplification"
	],
	"TurretTargetPriority": [
		"first",
		"last",
		"strongest",
		"weakest",
		"nearest"
	],
	"CoreCombatSkill": [
		"guardianBeam",
		"riftMark"
	],
	"DailyQuestType": [
		"clearWaves",
		"killBosses",
		"killEnemies",
		"buyRunUpgrades"
	],
	"AutoStartMode": [
		"pauseEachRound",
		"skipBossRounds",
		"fullAuto"
	],
	"GamePhase": [
		"preparation",
		"wave",
		"reward",
		"coreDestruction",
		"success",
		"failure",
		"restored"
	],
	"EnemyType": [
		"normal",
		"armored",
		"shielded",
		"fast",
		"tank",
		"boss",
		"shieldBoss",
		"forgeBoss"
	],
	"RunUpgradeType": [
		"towerDamage",
		"killGold",
		"waveGold"
	],
	"TurretModulePart": [
		"core",
		"barrel",
		"frame"
	],
	"TurretModuleGrade": [
		"normal",
		"magic",
		"rare",
		"unique"
	],
	"TurretModuleFamily": [
		"rapidCore",
		"balancedBarrel",
		"stableFrame",
		"blastCore",
		"heavyBarrel",
		"reinforcedFrame",
		"ignitionCore",
		"emberBarrel",
		"heatSinkFrame",
		"frostCore",
		"coldBarrel",
		"coolingFrame",
		"scopeCore",
		"precisionBarrel",
		"anchorFrame",
		"currentCore",
		"coilBarrel",
		"insulatedFrame"
	],
	"TurretModuleOptionType": [
		"damageIncrease",
		"attackRateIncrease",
		"criticalChanceBonus",
		"criticalDamageBonus",
		"rangeIncrease",
		"levelUpCostDiscount",
		"linkUpgradeCostDiscount",
		"buildCostDiscount",
		"highLevelUpgradeCostDiscount",
		"gemEffectIncrease",
		"splashRadiusIncrease",
		"damageOverTimeIncrease",
		"burnDurationIncrease",
		"slowDurationIncrease",
		"slowStrengthBonus",
		"lightningChainDamageIncrease",
		"projectileSpeedIncrease",
		"splashSecondaryDamageBonus",
		"lightningChainRangeIncrease",
		"aimSpeedIncrease"
	],
	"GemType": [
		"attackSpeed",
		"range",
		"physicalDamage",
		"elementalDamage",
		"lightWeapon",
		"heavyWeapon",
		"damageOverTime",
		"explosion",
		"chain",
		"criticalChance",
		"aimSpeed",
		"damageAmplifier",
		"armorPiercing",
		"multipleProjectiles",
		"piercing"
	]
}
const SCALARS = {
	"SavedProgression": {
		"runes": [
			"intValue",
			null
		],
		"growthVersion": [
			"nonNegativeInt",
			null
		],
		"bossBountyUpgradeLevel": [
			"nonNegativeInt",
			null
		],
		"totalPlayTimeMillis": [
			"nonNegativeInt",
			null
		],
		"freeDiamonds": [
			"intValue",
			null
		],
		"paidDiamonds": [
			"intValue",
			null
		],
		"dailyQuestDayKey": [
			"intValue",
			-1
		],
		"lastDailyQuestSeenMillis": [
			"intValue",
			null
		],
		"dailyQuestClockRollbackDetected": [
			"boolValue",
			null
		],
		"dailyAttendanceRewardClaimed": [
			"boolValue",
			null
		],
		"dailyQuestAllCompleteClaimed": [
			"boolValue",
			null
		],
		"weeklyQuestWeekKey": [
			"intValue",
			-1
		],
		"weeklyQuestAllCompleteClaimed": [
			"boolValue",
			null
		],
		"weeklyAttendanceRewardClaimed": [
			"boolValue",
			null
		],
		"lastRunRuneReward": [
			"intValue",
			null
		],
		"startingGoldUpgradeLevel": [
			"intValue",
			null
		],
		"nexusHpUpgradeLevel": [
			"intValue",
			null
		],
		"supplyUpgradeLevel": [
			"intValue",
			null
		],
		"fireTrainingUpgradeLevel": [
			"intValue",
			null
		],
		"physicalDamageTrainingUpgradeLevel": [
			"intValue",
			null
		],
		"elementalDamageTrainingUpgradeLevel": [
			"intValue",
			null
		],
		"criticalChanceUpgradeLevel": [
			"intValue",
			null
		],
		"criticalDamageUpgradeLevel": [
			"intValue",
			null
		],
		"killGoldUpgradeLevel": [
			"intValue",
			null
		],
		"emergencySaleUpgradeLevel": [
			"intValue",
			null
		],
		"linkCostOptimizationUpgradeLevel": [
			"intValue",
			null
		],
		"turretLevelUpOptimizationUpgradeLevel": [
			"intValue",
			null
		],
		"unlockedStageCount": [
			"intValue",
			1
		],
		"researchSlotTwoUnlocked": [
			"boolValue",
			null
		],
		"totalCorePoints": [
			"nonNegativeInt",
			null
		],
		"lastRunCorePointReward": [
			"nonNegativeInt",
			null
		],
		"lastRunTurretModuleTicketReward": [
			"nonNegativeInt",
			null
		],
		"corePassiveTreeRevision": [
			"intValue",
			null
		]
	},
	"SavedActiveResearch": {
		"targetLevel": [
			"intValue",
			1
		],
		"startedAtMillis": [
			"intValue",
			null
		],
		"durationMillis": [
			"intValue",
			null
		],
		"initialElapsedMillis": [
			"intValue",
			null
		]
	},
	"SavedTurret": {
		"x": [
			"intValue",
			null
		],
		"y": [
			"intValue",
			null
		],
		"level": [
			"intValue",
			1
		],
		"slotLimit": [
			"intValue",
			1
		],
		"cooldown": [
			"doubleValue",
			null
		],
		"investedGold": [
			"intValue",
			null
		],
		"damageDealt": [
			"doubleValue",
			null
		],
		"directDamageDealt": [
			"doubleValue",
			null
		],
		"splashDamageDealt": [
			"doubleValue",
			null
		],
		"chainDamageDealt": [
			"doubleValue",
			null
		],
		"burnDamageDealt": [
			"doubleValue",
			null
		]
	},
	"SavedBurnInstance": {
		"damageMultiplier": [
			"doubleValue",
			1
		],
		"sourceX": [
			"nullableIntValue",
			null
		],
		"sourceY": [
			"nullableIntValue",
			null
		],
		"ignoreArmorReduction": [
			"boolValue",
			null
		],
		"remaining": [
			"doubleValue",
			null
		],
		"damagePerSecond": [
			"doubleValue",
			null
		]
	},
	"SavedCoreCombatSkillStats": {
		"directDamageDealt": [
			"doubleValue",
			null
		],
		"bonusDamageDealt": [
			"doubleValue",
			null
		],
		"activationCount": [
			"intValue",
			null
		]
	},
	"SavedEnemy": {
		"maxHp": [
			"doubleValue",
			null
		],
		"hp": [
			"doubleValue",
			null
		],
		"shield": [
			"doubleValue",
			null
		],
		"shieldBroken": [
			"boolValue",
			null
		],
		"armor": [
			"doubleValue",
			null
		],
		"distanceTravelled": [
			"doubleValue",
			null
		],
		"burnDamageMultiplier": [
			"doubleValue",
			1
		],
		"poisonRemaining": [
			"doubleValue",
			null
		],
		"poisonDamagePerSecond": [
			"doubleValue",
			null
		],
		"poisonDamageMultiplier": [
			"doubleValue",
			1
		],
		"poisonStacks": [
			"intValue",
			null
		],
		"physicalVulnerabilityRemaining": [
			"doubleValue",
			null
		],
		"physicalVulnerabilityBonus": [
			"doubleValue",
			null
		],
		"elementalVulnerabilityRemaining": [
			"doubleValue",
			null
		],
		"elementalVulnerabilityBonus": [
			"doubleValue",
			null
		],
		"laneOffsetRatio": [
			"doubleValue",
			null
		],
		"riftMarkRemaining": [
			"doubleValue",
			null
		],
		"riftMarkDamageAmplification": [
			"doubleValue",
			null
		]
	},
	"SavedSpawnRequest": {
		"delay": [
			"doubleValue",
			null
		]
	},
	"SavedSlowInstance": {
		"remaining": [
			"doubleValue",
			null
		],
		"multiplier": [
			"doubleValue",
			1
		]
	},
	"SavedPreferences": {
		"selectedStageNumber": [
			"intValue",
			1
		]
	},
	"SavedRunState": {
		"gold": [
			"intValue",
			null
		],
		"gemShards": [
			"intValue",
			null
		],
		"nexusHp": [
			"doubleValue",
			null
		],
		"stageNumber": [
			"intValue",
			1
		],
		"mapSignature": [
			"stringValue",
			null
		],
		"roundIndex": [
			"intValue",
			null
		],
		"completedRounds": [
			"intValue",
			null
		],
		"killGoldFractionWallet": [
			"doubleValue",
			null
		],
		"economyRunId": [
			"stringValue",
			null
		],
		"pendingEconomyDiamonds": [
			"intValue",
			null
		],
		"roundNexusHpLost": [
			"doubleValue",
			null
		],
		"emergencyChargeUsedThisRound": [
			"boolValue",
			null
		],
		"finalDefenseUsedThisRound": [
			"boolValue",
			null
		]
	},
	"SavedTurretModuleInventory": {},
	"SavedTurretModule": {
		"acquiredOrder": [
			"intValue",
			null
		],
		"equipped": [
			"boolValue",
			null
		],
		"id": [
			"stringValue",
			null
		]
	},
	"SavedTurretModuleOption": {
		"value": [
			"intValue",
			null
		]
	}
}


static func _is_map(v: Variant) -> bool:
	if not v is Dictionary: return false
	for key in v:
		if not key is String and not key is StringName: return false
	return true

static func _map(v: Variant) -> Dictionary:
	return v if _is_map(v) else {}

static func _int(v: Variant, fallback: Variant = 0) -> Variant:
	if v is int: return v
	if v is float:
		# Dart double.toInt saturates finite values outside signed int64. Native
		# float casts differ by CPU, and float(INT64_MAX) rounds up to 2^63.
		# Compare before casting; return the exact integer bounds directly.
		if v >= 9223372036854775808.0: return 9223372036854775807
		if v <= -9223372036854775808.0: return -9223372036854775807 - 1
		return int(v)
	return fallback

static func _is_dart_integer_space(code: int) -> bool:
	return (code >= 9 and code <= 13) or code in [32, 133, 160, 5760, 8232, 8233, 8239, 8287, 12288, 65279] or (code >= 8192 and code <= 8202)

# Matches Dart int.tryParse(key), followed by the stage-key > 0 filter.
# Negative values (including unsigned hex with bit 63 set) are not stage IDs.
static func _positive_stage_key(key: String) -> int:
	var start := 0
	var end := key.length()
	while start < end and _is_dart_integer_space(key.unicode_at(start)): start += 1
	while end > start and _is_dart_integer_space(key.unicode_at(end - 1)): end -= 1
	if start == end: return 0
	if key[start] == "-": return 0
	if key[start] == "+": start += 1
	var base := 10
	if end - start >= 2 and key[start] == "0" and key[start + 1] in ["x", "X"]:
		base = 16
		start += 2
	if start == end: return 0
	var value := 0
	for i in range(start, end):
		var code := key.unicode_at(i)
		var digit := code - 48
		if base == 16 and code >= 65 and code <= 70: digit = code - 55
		elif base == 16 and code >= 97 and code <= 102: digit = code - 87
		if digit < 0 or digit >= base: return 0
		# Check before arithmetic: Godot's string conversion saturates overflow.
		@warning_ignore("integer_division")
		var limit: int = (9223372036854775807 - digit) / base
		if value > limit: return 0
		value = value * base + digit
	return value

static func _enum(name: String, v: Variant, fallback: Variant = null) -> Variant:
	return v if v is String and v in ENUMS[name] else fallback

static func _fields(name: String, v: Dictionary) -> Dictionary:
	var out := {}
	for key in SCALARS[name]:
		var spec: Array = SCALARS[name][key]
		var x: Variant = v.get(key)
		match spec[0]:
			"intValue": out[key] = _int(x, spec[1] if spec[1] != null else 0)
			"nonNegativeInt": out[key] = maxi(0, _int(x))
			"nullableIntValue": out[key] = _int(x, null)
			"doubleValue": out[key] = float(x) if (x is int or x is float) else float(spec[1] if spec[1] != null else 0)
			"boolValue": out[key] = x if x is bool else (spec[1] if spec[1] != null else false)
			"stringValue": out[key] = x if x is String and not x.is_empty() else null
	return out

static func _enum_map(name: String, v: Variant) -> Dictionary:
	var out := {}
	for key in _map(v):
		if _enum(name, key) != null: out[key] = _int(v[key])
	return out

static func _list(v: Variant, name: String = "", unique: bool = false, nullable: bool = false) -> Array:
	var out := []
	if not v is Array: return out
	for item in v:
		var parsed: Variant = _enum(name, item) if not name.is_empty() and name not in ["int", "string"] else item
		if name == "int": parsed = _int(item)
		if name == "string": parsed = item if item is String and not item.is_empty() else null
		if name == "int" and parsed <= 0: continue
		if parsed == null and not nullable: continue
		if not unique or not out.has(parsed): out.append(parsed)
	return out

static func _objects(v: Variant, name: String) -> Array:
	var out := []
	if v is Array:
		for item in v:
			var parsed: Variant = _object(name, item)
			if parsed != null: out.append(parsed)
	return out

static func _skill(v: Dictionary, key: String, fallback: Variant) -> Variant:
	if not v.has(key): return fallback
	return null if v[key] == null else _enum("CoreCombatSkill", v[key], "guardianBeam")

static func is_canonical_v2(v: Variant) -> bool:
	return _is_map(v) and _int(v.get("version")) == 2 and _is_map(v.get("preferences")) and _is_map(v.get("progression")) and _is_map(v.get("turretModules")) and v.has("activeRun") and (v.activeRun == null or _is_map(v.activeRun)) and _valid_core_wire(v)

# Legacy readers intentionally retain their historical normalization. The new
# schema must fail closed instead of deleting unknown allocations on reload.
static func _valid_core_wire(v: Dictionary) -> bool:
	var p: Dictionary = v.progression
	if not _valid_core_revision(p, "corePassiveTreeRevision"): return false
	var revision: int = _int(p.get("corePassiveTreeRevision"), 4)
	if revision == 5:
		if not p.get("corePassiveTreeRevision") is int or not _strict_core_ranks(p.get("corePassiveNodeRanks", {}), revision): return false
	var run: Variant = v.activeRun
	if run is Dictionary:
		if not _valid_core_revision(run, "runCorePassiveTreeRevision"): return false
		var run_revision: int = _int(run.get("runCorePassiveTreeRevision"), revision)
		if run_revision == 5:
			if not run.has("runCorePassiveTreeRevision") or not run.has("runCorePassiveNodeRanks"): return false
			if not _strict_core_ranks(run.runCorePassiveNodeRanks, run_revision): return false
	return true

static func _valid_core_revision(value: Dictionary, field: String) -> bool:
	if not value.has(field): return true
	return value[field] is int and value[field] >= 0 and value[field] <= CoreTree.CURRENT_REVISION

static func _strict_core_ranks(value: Variant, revision: int) -> bool:
	if not _is_map(value): return false
	var nodes: Dictionary = CoreTree.CATALOGS.get(str(revision), {}).get("nodes", {})
	for key in value:
		if not nodes.has(key) or not value[key] is int or value[key] < 0 or value[key] > int(nodes[key].maxRank): return false
	return true

# Envelope validation above intentionally matches Dart's permissive reader.
# A writer must receive the equivalent of a typed GameSaveData.toJson(), not a
# malformed dictionary whose fields would silently normalize to zero on reload.
static func is_normalized_v2(v: Variant) -> bool:
	return is_canonical_v2(v) and _same_typed_value(v, decode(v))

static func _same_typed_value(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same_typed_value(a[key], b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not _same_typed_value(a[index], b[index]): return false
		return true
	return a == b

static func decode(v: Variant) -> Variant:
	if not _is_map(v): return null
	if not _valid_core_revision(_map(v.get("progression")), "corePassiveTreeRevision"): return null
	var legacy: bool = _int(v.get("version")) == 1
	if not legacy and not is_canonical_v2(v): return null
	var progression := _progression(_map(v.get("progression")))
	var prefs: Dictionary = {"selectedStageNumber": v.get("stageNumber"), "autoStartMode": v.get("autoStartMode")} if legacy else v.preferences
	var preferences := _fields("SavedPreferences", prefs)
	preferences.autoStartMode = _enum("AutoStartMode", prefs.get("autoStartMode"), "pauseEachRound")
	var run: Variant = _run(v if legacy else v.activeRun, progression.coreCombatSkill, progression.corePassiveTreeRevision)
	if legacy and not _has_progress(run): run = null
	return {"version": 2, "savedAtMillis": _int(v.get("savedAtMillis")), "preferences": preferences, "progression": progression, "turretModules": _inventory(_map(v.get("progression") if legacy else v.get("turretModules")), legacy), "activeRun": run}

static func _progression(v: Dictionary) -> Dictionary:
	var out := _fields("SavedProgression", v)
	if v.has("gemResetTickets"): out.gemResetTickets = maxi(0, _int(v.get("gemResetTickets")))
	if v.has("progressionVersion"):
		out.progressionVersion = maxi(0, _int(v.get("progressionVersion")))
		out.unlockedStageIds = _list(v.get("unlockedStageIds"),"int",true)
		out.grandfatherUnlocks = _list(v.get("grandfatherUnlocks"),"string",true)
	for key in ["dailyQuestProgress", "weeklyQuestProgress"]: out[key] = _enum_map("DailyQuestType", v.get(key))
	for key in ["claimedDailyQuestRewards", "claimedWeeklyQuestRewards"]: out[key] = _list(v.get(key), "DailyQuestType", true)
	for key in ["weeklyAttendanceDayKeys", "clearedStageNumbers", "claimedCorePointStageRewards"]: out[key] = _list(v.get(key), "int", true)
	out.claimedEventIds = _list(v.get("claimedEventIds"), "string", true)
	out.bestRoundsByStage = {}
	for key in _map(v.get("bestRoundsByStage")):
		var n := _positive_stage_key(str(key))
		var value: int = _int(v.bestRoundsByStage[key])
		if n > 0 and value > 0: out.bestRoundsByStage[str(n)] = value
	for key in ["researchLevels", "researchElapsedMillis"]: out[key] = _enum_map("ResearchType", v.get(key))
	out.activeResearches = _objects(v.get("activeResearches"), "SavedActiveResearch")
	out.researchSlotTwoUnlocked = v.researchSlotTwoUnlocked if v.get("researchSlotTwoUnlocked") is bool else out.activeResearches.size() > 1
	out.coreCombatSkill = _skill(v, "coreCombatSkill", "guardianBeam")
	out.corePassiveTreeRevision = _int(v.get("corePassiveTreeRevision"), 4)
	out.corePassiveNodeRanks = _core_ranks(v.get("corePassiveNodeRanks"), out.corePassiveTreeRevision)
	if v.get("corePassiveLegacyAllocation") is Dictionary:
		var archive: Dictionary = v.corePassiveLegacyAllocation
		var revision: int = _int(archive.get("revision"), 4)
		out.corePassiveLegacyAllocation = {"revision":revision,"ranks":_core_ranks(archive.get("ranks"),revision),"refundedPoints":maxi(0,_int(archive.get("refundedPoints")))}
	if out.growthVersion >= 1:
		out.erase("criticalChanceUpgradeLevel")
		out.erase("emergencySaleUpgradeLevel")
	return out

static func _core_ranks(v: Variant, revision: int = 4) -> Dictionary:
	var out := {}
	var nodes: Dictionary = CoreTree.CATALOGS.get(str(5 if revision == 5 else 4), {}).get("nodes", {})
	for key in _map(v):
		if nodes.has(key) and _int(v[key]) > 0: out[key] = mini(_int(v[key]), int(nodes[key].maxRank))
	return out

static func _optional_float(out: Dictionary, v: Dictionary, key: String, maximum: float = INF) -> void:
	if not v.has(key): return
	var value: Variant = v[key]
	out[key] = clampf(float(value), 0.0, maximum) if (value is int or value is float) and is_finite(float(value)) else 0.0

static func _optional_bool(out: Dictionary, v: Dictionary, key: String) -> void:
	if v.has(key): out[key] = v[key] if v[key] is bool else false


static func _inventory(v: Dictionary, legacy: bool) -> Dictionary:
	var names := ["tickets", "drawCount", "ticketPurchaseCount", "itemSequence", "items"]
	var old := ["turretModuleTickets", "turretModuleDrawCount", "turretModuleTicketPurchaseCount", "turretModuleItemSequence", "ownedTurretModules"]
	var m := {}
	for i in names.size():
		var key: String = old[i] if legacy else names[i]
		if v.has(key): m[names[i]] = v[key]
	var sequence: int = maxi(0, _int(m.get("itemSequence")))
	var draws: int = maxi(0, _int(m.get("drawCount"))) if m.has("drawCount") else sequence
	return {"tickets": _int(m.get("tickets")), "drawCount": draws, "ticketPurchaseCount": maxi(0, _int(m.get("ticketPurchaseCount"))) if m.has("ticketPurchaseCount") else draws, "itemSequence": sequence, "items": _objects(m.get("items"), "SavedTurretModule")}

static func _run(v: Variant, skill: Variant, tree_revision: int = 4) -> Variant:
	if not _is_map(v): return null
	var out := _fields("SavedRunState", v)
	out.phase = _enum("GamePhase", v.get("phase"), "preparation")
	var purchased: Variant = v.get("isPurchasedGemReward", v.get("paidGemRoll", false))
	out.isPurchasedGemReward = purchased is bool and purchased
	out.enemies = _objects(v.get("enemies"), "SavedEnemy")
	out.spawnQueue = _objects(v.get("spawnQueue"), "SavedSpawnRequest")
	out.turrets = _objects(v.get("turrets"), "SavedTurret")
	out.rewardReturnPhase = _enum("GamePhase", v.get("rewardReturnPhase"), "wave" if out.phase == "reward" and out.isPurchasedGemReward and (not out.enemies.is_empty() or not out.spawnQueue.is_empty()) else null)
	out.runCoreCombatSkill = _skill(v, "runCoreCombatSkill", skill)
	out.runCoreCombatSkillStats = _fields("SavedCoreCombatSkillStats", _map(v.get("runCoreCombatSkillStats")))
	out.runUpgradeLevels = _enum_map("RunUpgradeType", v.get("runUpgradeLevels"))
	out.gemInventory = _enum_map("GemType", v.get("gemInventory"))
	out.rewardOptions = _list(v.get("rewardOptions"), "GemType")
	out.pendingEconomyDiamonds = clampi(_int(v.get("pendingEconomyDiamonds")), 0, 1000000)
	if v.has("gemRerollsUsed"): out.gemRerollsUsed = clampi(_int(v.get("gemRerollsUsed")), 0, 3)
	# Loadout fixed at stage start; absent in saves written before it was recorded.
	if v.has("runCorePassiveTreeRevision"): out.runCorePassiveTreeRevision = _int(v.runCorePassiveTreeRevision, tree_revision)
	if v.has("runCorePassiveNodeRanks"): out.runCorePassiveNodeRanks = _core_ranks(v.runCorePassiveNodeRanks, int(out.get("runCorePassiveTreeRevision", tree_revision)))
	_optional_float(out, v, "nexusAdditionalHp")
	_optional_float(out, v, "nexusInvulnerableRemaining", 3.0)
	_optional_bool(out, v, "nexusAdditionalHpGranted")
	_optional_bool(out, v, "indomitableUsedThisStage")
	if v.has("runTurretModules"): out.runTurretModules = _objects(v.runTurretModules, "SavedTurretModule")
	for key in ["gemOfferRevision", "gemOfferEquipRevision", "gemEconomyRevision"]:
		if v.has(key): out[key] = maxi(0, _int(v.get(key)))
	for key in ["gemOfferId", "gemOfferStatus"]:
		if v.get(key) is String: out[key] = v[key]
	if v.has("gemDeckLog"): out.gemDeckLog = _deck_log(v.gemDeckLog)
	return out

# Generation-10 deck runs: one entry per presented offer, replayed by the server.
static func _deck_log(v: Variant) -> Array:
	var out := []
	if not v is Array: return out
	for item in v:
		if not _is_map(item): continue
		var choice: Variant = item.get("choice")
		if not choice is String or (not choice.is_empty() and choice != "shards" and _enum("GemType", choice) == null): continue
		match item.get("kind"):
			"wave": out.append({"kind": "wave", "wave": maxi(0, _int(item.get("wave"))), "rerolls": clampi(_int(item.get("rerolls")), 0, 3), "choice": choice})
			"purchase": out.append({"kind": "purchase", "sequence": maxi(1, _int(item.get("sequence"))), "choice": choice})
	return out

static func _has_progress(v: Dictionary) -> bool:
	if v.phase in ["wave", "reward"] or v.roundIndex > 0 or v.completedRounds > 0 or v.killGoldFractionWallet > 0: return true
	for key in ["runUpgradeLevels", "gemInventory", "turrets", "enemies", "spawnQueue", "rewardOptions"]:
		if not v[key].is_empty(): return true
	return false

static func _object(name: String, v: Variant) -> Variant:
	if not _is_map(v): return null
	var out := _fields(name, v)
	var required := {}
	if name in ["SavedEnemy", "SavedSpawnRequest"] and v.has("routeId"):
		if not v.routeId is String or v.routeId.is_empty(): return null
		out.routeId = v.routeId
	match name:
		"SavedActiveResearch": required = {"type": "ResearchType"}
		"SavedTurret": required = {"type": "TurretType"}
		"SavedEnemy": required = {"type": "EnemyType"}
		"SavedSpawnRequest": required = {"enemyType": "EnemyType"}
		"SavedTurretModuleOption": required = {"type": "TurretModuleOptionType"}
		"SavedTurretModule": required = {"turretType": "TurretType", "part": "TurretModulePart", "family": "TurretModuleFamily", "grade": "TurretModuleGrade"}
	for key in required:
		out[key] = _enum(required[key], v.get(key))
		if out[key] == null: return null
	match name:
		"SavedTurretModule":
			out.options = _objects(v.get("options"), "SavedTurretModuleOption")
			if out.id == null or out.options.is_empty(): return null
		"SavedTurret":
			if v.has("stockpileCharges"): out.stockpileCharges = clampi(_int(v.stockpileCharges), 0, 2)
			out.equippedGems = _list(v.get("equippedGems"), "GemType")
			out.equippedGemSlots = _list(v.get("equippedGemSlots"), "GemType", false, true) if v.has("equippedGemSlots") else out.equippedGems.duplicate()
			out.targetPriority = _enum("TurretTargetPriority", v.get("targetPriority"), "first")
			out.primaryTrait = _enum("TurretTraitType", v.get("primaryTrait"))
			out.secondaryTrait = _enum("TurretTraitType", v.get("secondaryTrait"))
		"SavedBurnInstance":
			if out.remaining <= 0 or out.damagePerSecond <= 0: return null
		"SavedSlowInstance":
			if not is_finite(out.multiplier) or out.multiplier < 0 or out.multiplier >= 1 or not is_finite(out.remaining) or out.remaining <= 0: return null
		"SavedEnemy":
			_optional_bool(out, v, "firstControlApplied")
			_optional_float(out, v, "stunRemaining")
			_optional_float(out, v, "freezeRemaining")
			out.burnRemaining = float(v.get("burnRemaining")) if v.get("burnRemaining") is float or v.get("burnRemaining") is int else 0.0
			out.burnDamagePerSecond = float(v.get("burnDamagePerSecond")) if v.get("burnDamagePerSecond") is float or v.get("burnDamagePerSecond") is int else 0.0
			out.burnInstances = _objects(v.get("burnInstances"), "SavedBurnInstance")
			if out.burnInstances.is_empty() and out.burnRemaining > 0 and out.burnDamagePerSecond > 0:
				out.burnInstances.append({"remaining": out.burnRemaining, "damagePerSecond": out.burnDamagePerSecond, "damageMultiplier": out.burnDamageMultiplier, "sourceX": null, "sourceY": null, "ignoreArmorReduction": false})
			out.slowInstances = _objects(v.get("slowInstances"), "SavedSlowInstance")
			out.diamondReward = 0 if out.type in ["boss", "shieldBoss", "forgeBoss"] else clampi(_int(v.get("diamondReward")), 0, 3)
	return out
