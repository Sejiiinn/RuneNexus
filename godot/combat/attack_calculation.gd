extends RefCounted
## Read-only numerical mirror. No nodes, HP, reward or save mutations.

static func resistance_multiplier(resistance: float) -> float:
	return 1.0 - (0.9 if resistance > 0.9 else resistance)

static func damage_multiplier(input: Dictionary, include_extra_tags: bool = true) -> float:
	var resistance: float = input.get("familyResistance", 0.0)
	match input["family"]:
		"physical":
			resistance -= float(input.get("enemyPhysicalReduction", 0.0)) + float(input.get("attackPhysicalReduction", 0.0))
		"elemental":
			resistance -= float(input.get("enemyElementalReduction", 0.0))
	var multiplier := resistance_multiplier(resistance)
	var tags: Dictionary = {}
	for tag in input.get("tags", []):
		tags[tag] = true
	if include_extra_tags:
		for tag in input.get("extraTags", []):
			tags[tag] = true
	var tag_resistances: Dictionary = input.get("tagResistances", {})
	for tag in tags:
		multiplier *= resistance_multiplier(tag_resistances.get(tag, 0.0))
	return multiplier

static func resolve(input: Dictionary) -> Dictionary:
	var resistance: Dictionary = input["resistance"]
	var multiplier := damage_multiplier(resistance)
	var effects: Array = []
	var status: Dictionary = input.get("status", {})
	if status.get("hasDamageOverTime", false):
		var burn_multiplier := damage_multiplier(resistance, false)
		# Reuse the firing roll, with half of its bonus; direct-only traits stay separate.
		var burn_critical_multiplier := 1.0 + (float(status.get("criticalMultiplier", 1.0)) - 1.0) * 0.5
		effects.append({"type": "burn", "damagePerSecond": float(status["damage"]) * float(status["burnDamagePerSecondScale"]) * float(status.get("damageScale", 1.0)) * burn_multiplier * float(status.get("damageOverTimeDamageMultiplier", 1.0)) * burn_critical_multiplier,
			"duration": float(status["burnDurationSeconds"]) * float(status.get("damageOverTimeDurationMultiplier", 1.0)),
			"damageMultiplier": burn_multiplier, "ignoreArmorReduction": status.get("ignoresArmorReduction", false)})
	var slow_duration: float = status.get("slowDuration", 0.0)
	var slow_multiplier: float = status.get("slowMultiplier", 1.0)
	if slow_duration > 0.0 and slow_multiplier < 1.0:
		effects.append({"type": "slow", "multiplier": slow_multiplier, "duration": slow_duration})
		if status.get("appliesFrostCrack", false):
			effects.append({"type": "elementalVulnerability", "bonus": 0.15, "duration": slow_duration})
	return {"damage": float(input["baseDamage"]) * float(input.get("traitMultiplier", 1.0)) * multiplier,
		"resistanceMultiplier": multiplier, "effects": effects}
