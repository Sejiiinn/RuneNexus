extends RefCounted
## Comparison-only pure port. App progression, timers and RNG are inputs.

static func resolve(i: Dictionary) -> Dictionary:
	var out := stats_at(i, int(i.level))
	out.levels = {}
	for level in [-4, 1, 3, 7, 10, 99]:
		var at := stats_at(i, level)
		out.levels[str(level)] = {}
		for key in ["damage", "range", "attackRate", "slowMultiplier", "aimDuration"]:
			out.levels[str(level)][key] = at[key]
	out.snapshot = firing_stats(i, out, 1.65)
	return out

static func stats_at(i: Dictionary, level: int) -> Dictionary:
	var d: Dictionary = i.definition
	var m: Dictionary = i.moduleEffect
	var gems: Array = i.gems
	var p = i.primaryTrait
	var s = i.secondaryTrait
	var target_level := clampi(level, 1, 10)
	var gem: float = (1.0 + m.gemEffectIncreaseRate) * i.passiveNumericGemEffectMultiplier
	var damage: float = d.damage * pow(1.2, target_level - 1)
	if d.damageFamily == "physical" and "physicalDamage" in gems:
		damage *= 1.0 + 0.4 * gem
	if d.damageFamily == "elemental" and "elementalDamage" in gems:
		damage *= 1.0 + 0.4 * gem
	if "light" in d.attackTags and "lightWeapon" in gems:
		damage *= 1.0 + 0.2 * gem
	if "heavy" in d.attackTags and "heavyWeapon" in gems:
		damage *= 1.0 + 0.3 * gem
	if p == "spreadingChill":
		damage *= 0.9
	if "damageAmplifier" in gems:
		damage *= 1.0 + 0.25 * gem
	damage *= (1.0 + m.damageIncreaseRate) * i.towerDamageMultiplier * i.corePassiveTurretDamageMultiplier * (0.5 if "multipleProjectiles" in gems else 1.0)
	var range_value: float = d.range * (1.0 + (target_level - 1) * 0.033) * (1.0 + 0.2 * gem if "range" in gems else 1.0) * (1.15 if p == "spreadingChill" else 1.0) * (1.0 + m.rangeIncreaseRate) * i.boardDistanceScale
	var rate: float = d.attackRate * pow(1.05, target_level - 1) * (1.0 + 0.4 * gem if "attackSpeed" in gems else 1.0) * (1.0 + 0.2 * gem if "light" in d.attackTags and "lightWeapon" in gems else 1.0) * (1.1 if p == "lightweightBarrel" else 1.0) * (0.9 if p == "compressedCharge" else 1.0) * (1.2 if p == "coolingCycle" else 1.0) * (1.0 + m.attackRateIncreaseRate)
	if i.chainCleanupActive:
		rate *= 1.4
	rate *= i.corePassiveTurretAttackRateMultiplier
	var projectile_speed: float = d.projectileSpeed * (1.3 if p == "lightweightBarrel" else 1.0) * (1.0 + m.projectileSpeedIncreaseRate) * i.boardDistanceScale
	var dot_damage := 1.0
	var dot_duration := 1.0
	if "damageOverTime" in d.attackTags:
		var bonus := 0.0
		if "damageOverTime" in gems:
			bonus += 0.3 * gem
		if p == "highHeatBurn":
			bonus += 0.25
		bonus += m.damageOverTimeIncreaseRate
		dot_damage = 1.0 + bonus
		bonus = 0.0
		if "damageOverTime" in gems:
			bonus += 0.3 * gem
		if p == "lingeringEmbers":
			bonus += 0.4
		bonus += m.burnDurationIncreaseRate
		dot_duration = 1.0 + bonus
	var slow: float = d.slowMultiplier
	if slow > 0:
		var level_bonus: float = (target_level - 1) * 0.02 if d.type == "frost" else 0.0
		slow = clampf(slow - level_bonus - (0.08 if s == "rapidCooling" else 0.0) - m.slowStrengthBonusRate, 0.1, 1.0)
	var effect_area: float = 1.0 + (0.25 * gem if "explosion" in gems else 0.0) + (0.2 * gem if "heavy" in d.attackTags and "heavyWeapon" in gems else 0.0)
	var splash := 0.0
	if not d.centeredAreaAttack:
		var base_radius: float = d.splashRadius if d.splashRadius > 0 else (i.explosionGemValue if "explosion" in gems else 0.0)
		var native_increase: float = (0.3 if p == "shrapnelShell" else 0.0) + (0.4 if s == "expandedBlastCore" else 0.0) + m.splashRadiusIncreaseRate
		splash = (base_radius * effect_area + d.splashRadius * native_increase) * i.boardDistanceScale
	var jumps := 0
	if d.type == "lightning":
		jumps = 2
		if "chain" in gems:
			jumps += 2
		if p == "branchCurrent":
			jumps += 1
		if p == "focusedLightning":
			jumps -= 1
		jumps = maxi(0, jumps)
	var crit_bonus: float = (i.criticalChanceGemValue * gem if "criticalChance" in gems else 0.0) + i.criticalChanceProgressionBonusRate + m.criticalChanceBonusRate + (0.2 if p == "deadeyeFocus" else 0.0) - (0.05 if p == "quickScope" else 0.0)
	var aim: float = d.aimDuration
	if d.instantHit and aim > 0:
		var gem_aim: float = 1.0 + i.aimSpeedGemValue * gem if "aimSpeed" in gems else 1.0
		var trait_aim: float = -0.2 if p == "deadeyeFocus" else (0.4 if p == "quickScope" else 0.0)
		var aim_speed: float = 1.0 + (target_level - 1) * 0.08 + m.aimSpeedIncreaseRate + trait_aim
		aim /= maxf(0.1, aim_speed) * gem_aim
	var fires_projectile: bool = not d.instantHit and not d.centeredAreaAttack and d.type != "lightning"
	return {
		"damage": damage, "range": range_value, "attackRate": rate,
		"projectileSpeed": projectile_speed,
		"projectileCount": int(d.projectileCount) + (2 if "multipleProjectiles" in gems else 0),
		"damageOverTimeDamageMultiplier": dot_damage,
		"damageOverTimeDurationMultiplier": dot_duration,
		"slowMultiplier": slow,
		"slowDuration": d.slowDuration * (0.85 if p == "coolingCycle" else 1.0) * (1.0 + m.slowDurationIncreaseRate),
		"appliesFrostCrack": s == "frostCrack", "appliesIgnitionBurst": s == "ignitionBurst", "spreadsChainIgnition": s == "chainIgnition",
		"physicalResistanceReduction": 0.2 if s == "fractureImpact" else 0.0,
		"effectAreaMultiplier": effect_area, "centeredAreaRadius": range_value * effect_area,
		"splashSecondaryDamageMultiplier": 0.5 + (0.1 if s == "expandedBlastCore" else 0.0) + m.splashSecondaryDamageBonusRate,
		"splashRadius": splash,
		"chainCount": jumps if d.type == "lightning" else (2 if "chain" in gems and fires_projectile else 0),
		"ignoresArmorReduction": "armorPiercing" in gems,
		"lightningChainMaxJumps": jumps,
		"lightningChainDamageMultiplier": (0.7 if s == "currentAmplification" else 0.5) * (1.0 + m.lightningChainDamageIncreaseRate),
		"appliesLightningRecovery": s == "lightningRecovery",
		"criticalChance": clampf(d.criticalChance + crit_bonus, 0.0, 1.0),
		"criticalDamageMultiplier": d.criticalDamageMultiplier + i.criticalDamageProgressionBonusRate + m.criticalDamageBonusRate,
		"aimDuration": aim,
	}

static func firing_stats(i: Dictionary, stats: Dictionary, critical_multiplier: float) -> Dictionary:
	var out := {}
	for key in ["damage", "range", "effectAreaMultiplier", "centeredAreaRadius", "chainCount", "splashRadius", "splashSecondaryDamageMultiplier", "projectileSpeed", "physicalResistanceReduction", "ignoresArmorReduction", "damageOverTimeDamageMultiplier", "damageOverTimeDurationMultiplier", "slowDuration", "slowMultiplier", "appliesFrostCrack", "appliesIgnitionBurst", "spreadsChainIgnition", "lightningChainMaxJumps", "lightningChainDamageMultiplier"]:
		out[key] = stats[key]
	out.criticalMultiplier = critical_multiplier
	out.hasChain = "chain" in i.gems
	out.hasDamageOverTime = "damageOverTime" in i.definition.attackTags
	out.lightningChainJumpRange = i.lightningChainJumpRange * (1.0 + i.moduleEffect.lightningChainRangeIncreaseRate)
	for trait_name in ["chainCleanup", "suppressiveFire", "exposedMark", "finishingShot"]:
		out["applies" + trait_name.left(1).to_upper() + trait_name.substr(1)] = i.secondaryTrait == trait_name
	for trait_name in ["overheatMagazine", "compressedCharge", "focusedLightning"]:
		out["applies" + trait_name.left(1).to_upper() + trait_name.substr(1)] = i.primaryTrait == trait_name
	return out
