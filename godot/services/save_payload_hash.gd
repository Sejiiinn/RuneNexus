extends RefCounted
## Wire ordering retained from the v2 Dart GameSaveData.toJson contract. Hashes
## in existing outboxes and rebase journals must survive engine migration.
const ORDERS = {
	"SavedProgression": [
		"runes",
		"growthVersion",
		"bossBountyUpgradeLevel",
		"totalPlayTimeMillis",
		"freeDiamonds",
		"paidDiamonds",
		"dailyQuestDayKey",
		"lastDailyQuestSeenMillis",
		"dailyQuestClockRollbackDetected",
		"dailyQuestProgress",
		"claimedDailyQuestRewards",
		"dailyAttendanceRewardClaimed",
		"dailyQuestAllCompleteClaimed",
		"weeklyQuestWeekKey",
		"weeklyQuestProgress",
		"claimedWeeklyQuestRewards",
		"weeklyQuestAllCompleteClaimed",
		"weeklyAttendanceDayKeys",
		"weeklyAttendanceRewardClaimed",
		"lastRunRuneReward",
		"startingGoldUpgradeLevel",
		"nexusHpUpgradeLevel",
		"supplyUpgradeLevel",
		"fireTrainingUpgradeLevel",
		"physicalDamageTrainingUpgradeLevel",
		"elementalDamageTrainingUpgradeLevel",
		"criticalChanceUpgradeLevel",
		"criticalDamageUpgradeLevel",
		"killGoldUpgradeLevel",
		"emergencySaleUpgradeLevel",
		"linkCostOptimizationUpgradeLevel",
		"turretLevelUpOptimizationUpgradeLevel",
		"unlockedStageCount",
		"bestRoundsByStage",
		"clearedStageNumbers",
		"researchLevels",
		"researchElapsedMillis",
		"activeResearches",
		"researchSlotTwoUnlocked",
		"coreCombatSkill",
		"totalCorePoints",
		"lastRunCorePointReward",
		"lastRunTurretModuleTicketReward",
		"corePassiveTreeRevision",
		"corePassiveNodeRanks",
		"claimedCorePointStageRewards",
		"claimedEventIds"
	],
	"SavedActiveResearch": [
		"type",
		"targetLevel",
		"startedAtMillis",
		"durationMillis",
		"initialElapsedMillis"
	],
	"SavedTurret": [
		"x",
		"y",
		"type",
		"level",
		"slotLimit",
		"cooldown",
		"equippedGems",
		"equippedGemSlots",
		"investedGold",
		"damageDealt",
		"directDamageDealt",
		"splashDamageDealt",
		"chainDamageDealt",
		"burnDamageDealt",
		"targetPriority",
		"primaryTrait",
		"secondaryTrait"
	],
	"SavedBurnInstance": [
		"remaining",
		"damagePerSecond",
		"damageMultiplier",
		"sourceX",
		"sourceY",
		"ignoreArmorReduction"
	],
	"GameSaveData": [
		"version",
		"savedAtMillis",
		"preferences",
		"progression",
		"turretModules",
		"activeRun"
	],
	"SavedCoreCombatSkillStats": [
		"directDamageDealt",
		"bonusDamageDealt",
		"activationCount"
	],
	"SavedEnemy": [
		"type",
		"maxHp",
		"hp",
		"shield",
		"shieldBroken",
		"armor",
		"distanceTravelled",
		"burnRemaining",
		"burnDamagePerSecond",
		"burnDamageMultiplier",
		"burnInstances",
		"poisonRemaining",
		"poisonDamagePerSecond",
		"poisonDamageMultiplier",
		"poisonStacks",
		"slowInstances",
		"physicalVulnerabilityRemaining",
		"physicalVulnerabilityBonus",
		"elementalVulnerabilityRemaining",
		"elementalVulnerabilityBonus",
		"laneOffsetRatio",
		"diamondReward",
		"riftMarkRemaining",
		"riftMarkDamageAmplification"
	],
	"SavedSpawnRequest": [
		"enemyType",
		"delay"
	],
	"SavedSlowInstance": [
		"multiplier",
		"remaining"
	],
	"SavedPreferences": [
		"selectedStageNumber",
		"autoStartMode"
	],
	"SavedRunState": [
		"gold",
		"gemShards",
		"nexusHp",
		"stageNumber",
		"mapSignature",
		"roundIndex",
		"completedRounds",
		"phase",
		"runUpgradeLevels",
		"killGoldFractionWallet",
		"gemInventory",
		"rewardOptions",
		"isPurchasedGemReward",
		"economyRunId",
		"pendingEconomyDiamonds",
		"rewardReturnPhase",
		"runCoreCombatSkill",
		"runCoreCombatSkillStats",
		"roundNexusHpLost",
		"emergencyChargeUsedThisRound",
		"finalDefenseUsedThisRound",
		"turrets",
		"enemies",
		"spawnQueue"
	],
	"SavedTurretModuleInventory": [
		"tickets",
		"drawCount",
		"ticketPurchaseCount",
		"itemSequence",
		"items"
	],
	"SavedTurretModule": [
		"id",
		"turretType",
		"part",
		"family",
		"grade",
		"options",
		"acquiredOrder",
		"equipped"
	],
	"SavedTurretModuleOption": [
		"type",
		"value"
	]
}
const CHILDREN = {"preferences": "SavedPreferences", "progression": "SavedProgression", "turretModules": "SavedTurretModuleInventory", "activeRun": "SavedRunState", "activeResearches": "SavedActiveResearch", "items": "SavedTurretModule", "options": "SavedTurretModuleOption", "turrets": "SavedTurret", "enemies": "SavedEnemy", "spawnQueue": "SavedSpawnRequest", "runCoreCombatSkillStats": "SavedCoreCombatSkillStats", "burnInstances": "SavedBurnInstance", "slowInstances": "SavedSlowInstance"}

static func hash_payload(payload: Dictionary) -> String:
	return encode(payload, "GameSaveData").sha256_text()

static func encode(value: Variant, kind: String = "") -> String:
	if value is Dictionary:
		var parts := PackedStringArray()
		var keys: Array = ORDERS.get(kind, value.keys())
		for key in keys:
			if not value.has(key): continue
			parts.append(JSON.stringify(str(key)) + ":" + encode(value[key], CHILDREN.get(key, "")))
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var parts := PackedStringArray()
		for item in value: parts.append(encode(item, kind))
		return "[" + ",".join(parts) + "]"
	if value is float: return _double(value)
	return JSON.stringify(value, "", false, true)

static func _double(value: float) -> String:
	# Godot's full-precision JSON gives shortest roundtrip digits, but switches
	# to scientific notation at different thresholds and pads small exponents.
	var text := JSON.stringify(value, "", false, true)
	var negative := text.begins_with("-")
	var unsigned := text.trim_prefix("-")
	var pieces := unsigned.split("e")
	if pieces.size() == 1: return text
	var exponent := int(pieces[1])
	var digits: String = pieces[0].replace(".", "")
	var out: String
	if exponent >= 21 or exponent < -6:
		out = pieces[0] + "e" + ("+" if exponent >= 0 else "") + str(exponent)
	elif exponent < 0:
		out = "0." + "0".repeat(-exponent - 1) + digits
	elif exponent + 1 >= digits.length():
		out = digits + "0".repeat(exponent + 1 - digits.length()) + ".0"
	else:
		out = digits.substr(0, exponent + 1) + "." + digits.substr(exponent + 1)
	return "-" + out if negative else out
