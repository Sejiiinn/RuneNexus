extends RefCounted
const Capabilities = preload("res://combat/attack_capabilities.gd")
const ProjectileEffects = preload("res://combat/projectile_effects.gd")
## Pure stat calculation. App progression, timers and RNG are inputs.
# Shared content-addressed neutral results: combat, HUD and selection only differ
# in distances and transient core/cleanup multipliers. No session/save state lives
# here, and full input equality guards hash collisions and catalog replacement.
const SHARED_CACHE_LIMIT := 256
static var shared_calculation_count := 0
static var _shared_buckets: Dictionary = {}
static var _shared_order: Array = []

static func clear_shared_cache() -> void:
	_shared_buckets.clear()
	_shared_order.clear()

static func shared_stats_at(i: Dictionary, level: int) -> Dictionary:
	var neutral := i.duplicate()
	neutral.level = clampi(level,1,10 + int(i.get("coreEffects", {}).get("maxTurretLevelBonus", 0)))
	neutral.boardDistanceScale = 1.0
	neutral.corePassiveTurretDamageMultiplier = 1.0
	neutral.corePassiveTurretAttackRateMultiplier = 1.0
	neutral.chainCleanupActive = false
	# This distance belongs to firing_stats, not stats_at, and is already scaled
	# by the catalog. It cannot split otherwise identical neutral stat inputs.
	neutral.erase("lightningChainJumpRange")
	var key := hash(neutral)
	var bucket: Array = _shared_buckets.get(key,[])
	var found: Dictionary = {}
	for entry in bucket:
		if entry.input == neutral:
			found = entry
			break
	if found.is_empty():
		var parts := {}
		var result := stats_at(neutral,int(neutral.level),parts)
		shared_calculation_count += 1
		found = {"key":key,"input":neutral.duplicate(true),"stats":result,"parts":parts}
		if _shared_order.size() >= SHARED_CACHE_LIMIT:
			var oldest: Dictionary = _shared_order.pop_front()
			var old_bucket: Array = _shared_buckets[oldest.key]
			old_bucket.erase(oldest)
			if old_bucket.is_empty(): _shared_buckets.erase(oldest.key)
		# The evicted item might belong to this hash bucket.
		bucket = _shared_buckets.get(key,[])
		bucket.append(found)
		_shared_buckets[key] = bucket
		_shared_order.append(found)
	# Result fields are scalar; return an owned copy so runtime/UI decoration can
	# never alter cached neutral values or another consumer's transient buffs.
	var out: Dictionary = found.stats.duplicate()
	var m: Dictionary = i.moduleEffect
	out.damage = float(found.parts.damagePrefix) * ((1.0 + m.damageIncreaseRate) * i.towerDamageMultiplier * i.corePassiveTurretDamageMultiplier * (0.5 if "multipleProjectiles" in i.gems else 1.0))
	if i.chainCleanupActive: out.attackRate *= 1.4
	out.attackRate *= i.corePassiveTurretAttackRateMultiplier
	for field in ["range","projectileSpeed","splashRadius"]:
		out[field] *= i.boardDistanceScale
	# Preserve the original range-then-effect-area multiplication order.
	out.centeredAreaRadius = out.range * out.effectAreaMultiplier
	return out

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

# Optional intermediate capture preserves the exact final multiplication order
# when shared_stats_at applies transient buffs. The public result is unchanged.
static func stats_at(i: Dictionary, level: int, intermediates: Dictionary = {}) -> Dictionary:
	var d: Dictionary = i.definition
	var m: Dictionary = i.moduleEffect
	var gems: Array = i.gems
	var p = i.primaryTrait
	var s = i.secondaryTrait
	var core: Dictionary = i.get("coreEffects", {})
	var target_level := clampi(level, 1, 10 + int(core.get("maxTurretLevelBonus", 0)))
	var gem: float = (1.0 + m.gemEffectIncreaseRate) * i.passiveNumericGemEffectMultiplier
	var level_multiplier := pow(1.2, target_level - 1)
	level_multiplier += (level_multiplier - 1.0) * float(core.get("turretLevelDamageIncrease", 0.0))
	var damage: float = d.damage * level_multiplier
	# All actually equipped gems count, regardless of numeric/rule/support kind.
	damage *= 1.0 + min(gems.size(), 5) * float(core.get("equippedGemDamageAmplificationPerGem", 0.0))
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
	intermediates.damagePrefix = damage
	damage *= (1.0 + m.damageIncreaseRate) * i.towerDamageMultiplier * i.corePassiveTurretDamageMultiplier * (0.5 if "multipleProjectiles" in gems else 1.0)
	var range_value: float = d.range * (1.0 + (target_level - 1) * 0.033) * (1.0 + 0.2 * gem if "range" in gems else 1.0) * (1.15 if p == "spreadingChill" else 1.0) * (1.0 + m.rangeIncreaseRate + float(core.get("rangeIncrease", 0.0))) * i.boardDistanceScale
	var rate: float = d.attackRate * pow(1.05, target_level - 1) * (1.0 + 0.4 * gem if "attackSpeed" in gems else 1.0) * (1.0 + 0.2 * gem if "light" in d.attackTags and "lightWeapon" in gems else 1.0) * (1.1 if p == "lightweightBarrel" else 1.0) * (0.9 if p == "compressedCharge" else 1.0) * (1.2 if p == "coolingCycle" else 1.0) * (1.0 + m.attackRateIncreaseRate + float(core.get("attackRateIncrease", 0.0)))
	if i.chainCleanupActive:
		rate *= 1.4
	rate *= i.corePassiveTurretAttackRateMultiplier
	var projectile_speed: float = d.projectileSpeed * (1.3 if p == "lightweightBarrel" else 1.0) * (1.0 + m.projectileSpeedIncreaseRate + float(core.get("projectileSpeedIncrease", 0.0))) * i.boardDistanceScale
	var dot_damage := 1.0
	var dot_duration := 1.0
	if "damageOverTime" in d.attackTags:
		var bonus := 0.0
		if p == "highHeatBurn":
			bonus += 0.25
		bonus += m.damageOverTimeIncreaseRate + float(core.get("damageOverTimeIncrease", 0.0))
		dot_damage = 1.0 + bonus + float(i.get("damageOverTimeTrainingBonusRate", 0.0))
		if "damageOverTime" in gems:
			dot_damage *= 1.0 + 0.3 * gem
		bonus = 0.0
		if "damageOverTime" in gems:
			bonus += 0.3 * gem
		if p == "lingeringEmbers":
			bonus += 0.4
		bonus += m.burnDurationIncreaseRate + float(core.get("burnDurationIncrease", 0.0))
		dot_duration = 1.0 + bonus
		# Speed compresses any existing DoT, preserving a single application total.
		var dot_speed := maxf(0.000001, float(core.get("damageOverTimeSpeedMultiplier", 1.0)))
		dot_damage *= dot_speed
		dot_duration /= dot_speed
	var slow: float = d.slowMultiplier
	if slow > 0:
		var level_bonus: float = (target_level - 1) * 0.02 if d.type == "frost" else 0.0
		slow = clampf(slow - level_bonus - (0.08 if s == "rapidCooling" else 0.0) - m.slowStrengthBonusRate - float(core.get("slowStrengthBonus", 0.0)), 0.1, 1.0)
	var effect_area: float = 1.0 + float(core.get("splashRadiusIncrease", 0.0)) + (0.25 * gem if "explosion" in gems else 0.0) + (0.2 * gem if "heavy" in d.attackTags and "heavyWeapon" in gems else 0.0)
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
	var crit_bonus: float = (i.criticalChanceGemValue * gem if "criticalChance" in gems else 0.0) + i.criticalChanceProgressionBonusRate + m.criticalChanceBonusRate + float(core.get("criticalChanceBonus", 0.0)) + (0.2 if p == "deadeyeFocus" else 0.0) - (0.05 if p == "quickScope" else 0.0)
	var aim: float = d.aimDuration
	if d.instantHit and aim > 0:
		var gem_aim: float = 1.0 + i.aimSpeedGemValue * gem if "aimSpeed" in gems else 1.0
		var trait_aim: float = -0.2 if p == "deadeyeFocus" else (0.4 if p == "quickScope" else 0.0)
		var aim_speed: float = 1.0 + (target_level - 1) * 0.08 + m.aimSpeedIncreaseRate + trait_aim
		aim /= maxf(0.1, aim_speed) * gem_aim
	var fires_projectile: bool = Capabilities.supports_projectile(d)
	return {
		"damage": damage, "range": range_value, "attackRate": rate,
		"projectileSpeed": projectile_speed,
		"pierceCount": ProjectileEffects.pierce_count(i),
		"projectileCount": int(d.projectileCount) + (2 if "multipleProjectiles" in gems else 0),
		"damageOverTimeDamageMultiplier": dot_damage,
		"damageOverTimeDurationMultiplier": dot_duration,
		"slowMultiplier": slow,
		"slowDuration": d.slowDuration * (0.85 if p == "coolingCycle" else 1.0) * (1.0 + m.slowDurationIncreaseRate + float(core.get("controlDurationIncrease", 0.0))),
		"appliesFrostCrack": s == "frostCrack", "appliesIgnitionBurst": s == "ignitionBurst", "spreadsChainIgnition": s == "chainIgnition",
		"physicalResistanceReduction": 0.2 if s == "fractureImpact" else 0.0,
		"effectAreaMultiplier": effect_area, "centeredAreaRadius": range_value * effect_area,
		"splashSecondaryDamageMultiplier": 0.5 + (0.1 if s == "expandedBlastCore" else 0.0) + m.splashSecondaryDamageBonusRate + float(core.get("splashSecondaryDamageBonus", 0.0)),
		"splashRadius": splash,
		"chainCount": jumps if d.type == "lightning" else (2 if "chain" in gems and fires_projectile else 0),
		"ignoresArmorReduction": "armorPiercing" in gems,
		"lightningChainMaxJumps": jumps,
		"lightningChainDamageMultiplier": (0.7 if s == "currentAmplification" else 0.5) * (1.0 + m.lightningChainDamageIncreaseRate),
		"appliesLightningRecovery": s == "lightningRecovery",
		"criticalChance": clampf(d.criticalChance + crit_bonus, 0.0, 1.0),
		"criticalDamageMultiplier": d.criticalDamageMultiplier + i.criticalDamageProgressionBonusRate + m.criticalDamageBonusRate + float(core.get("criticalDamageBonus", 0.0)),
		"aimDuration": aim,
	}

# Only this additive layer is needed to apply live training to frozen DoT DPS.
# Gem amplification, burn criticals, speed and resistance remain in the raw DPS.
static func damage_over_time_increase_multiplier(i: Dictionary) -> float:
	var bonus := 0.25 if i.primaryTrait == "highHeatBurn" else 0.0
	bonus += i.moduleEffect.damageOverTimeIncreaseRate + float(i.get("coreEffects", {}).get("damageOverTimeIncrease", 0.0))
	return 1.0 + bonus

static func damage_over_time_training_multiplier(i: Dictionary) -> float:
	if not "damageOverTime" in i.definition.attackTags: return 1.0
	return 1.0 + float(i.get("damageOverTimeTrainingBonusRate", 0.0)) / damage_over_time_increase_multiplier(i)

static func firing_stats(i: Dictionary, stats: Dictionary, critical_multiplier: float) -> Dictionary:
	var out := {}
	for key in ["damage", "range", "effectAreaMultiplier", "centeredAreaRadius", "pierceCount", "chainCount", "splashRadius", "splashSecondaryDamageMultiplier", "projectileSpeed", "physicalResistanceReduction", "ignoresArmorReduction", "damageOverTimeDamageMultiplier", "damageOverTimeDurationMultiplier", "slowDuration", "slowMultiplier", "appliesFrostCrack", "appliesIgnitionBurst", "spreadsChainIgnition", "lightningChainMaxJumps", "lightningChainDamageMultiplier"]:
		out[key] = stats[key]
	if "damageOverTime" in i.definition.attackTags:
		if float(i.get("damageOverTimeTrainingBonusRate", 0.0)) > 0.0:
			out.damageOverTimeDamageMultiplier /= damage_over_time_training_multiplier(i)
		var increase := damage_over_time_increase_multiplier(i)
		if increase != 1.0: out.damageOverTimeIncreaseMultiplier = increase
	out.criticalMultiplier = critical_multiplier
	var core: Dictionary = i.get("coreEffects", {})
	out.directDamageIncrease = float(core.get("directDamageIncrease", 0.0))
	out.splashDamageIncrease = float(core.get("splashDamageIncrease", 0.0))
	out.chainDamageIncrease = float(core.get("lightningChainDamageIncrease", 0.0))
	out.chainJumpRangeMultiplier = 1.0 + float(core.get("lightningChainRangeIncrease", 0.0))
	out.firstControlDurationMultiplier = float(core.get("firstControlDurationMultiplier", 1.0))
	out.controlDurationMultiplier = 1.0 + float(core.get("controlDurationIncrease", 0.0))
	out.hasChain = "chain" in i.gems
	out.hasDamageOverTime = "damageOverTime" in i.definition.attackTags
	out.lightningChainJumpRange = i.lightningChainJumpRange * (1.0 + i.moduleEffect.lightningChainRangeIncreaseRate + float(core.get("lightningChainRangeIncrease", 0.0)))
	for trait_name in ["chainCleanup", "suppressiveFire", "exposedMark", "finishingShot"]:
		out["applies" + trait_name.left(1).to_upper() + trait_name.substr(1)] = i.secondaryTrait == trait_name
	for trait_name in ["overheatMagazine", "compressedCharge", "focusedLightning"]:
		out["applies" + trait_name.left(1).to_upper() + trait_name.substr(1)] = i.primaryTrait == trait_name
	return out
