extends "res://combat/combat_runtime_targeting.gd"
## Hits, traits, resistances, event settlement, burn/poison spread and core skills.

func _apply_sync(t: Dictionary) -> void:
	if not core.configured: return
	var sync: bool = core.attack_sync_remaining > 0
	t.statInput.corePassiveTurretDamageMultiplier = float(core.config.get("attackSyncDamageMultiplier",1.0)) if sync else 1.0
	t.statInput.corePassiveTurretAttackRateMultiplier = float(core.config.get("attackSyncAttackRateMultiplier",1.0)) if sync else 1.0

func _refresh_turret_stats() -> void:
	if not core.configured: return
	var sync: bool = core.attack_sync_remaining > 0
	var damage: float = float(core.config.get("attackSyncDamageMultiplier",1.0)) if sync else 1.0
	var rate: float = float(core.config.get("attackSyncAttackRateMultiplier",1.0)) if sync else 1.0
	if _sync_stats_ready and damage == _sync_stats_damage and rate == _sync_stats_rate: return
	_sync_stats_ready = true
	_sync_stats_damage = damage
	_sync_stats_rate = rate
	for t in turrets.values():
		var old_damage: float = t.statInput.corePassiveTurretDamageMultiplier
		var old_rate: float = t.statInput.corePassiveTurretAttackRateMultiplier
		t.statInput.corePassiveTurretDamageMultiplier = damage
		t.statInput.corePassiveTurretAttackRateMultiplier = rate
		if old_damage != float(t.statInput.corePassiveTurretDamageMultiplier) or old_rate != float(t.statInput.corePassiveTurretAttackRateMultiplier):
			t.stats = Stats.shared_stats_at(t.statInput,int(t.statInput.level))

func _has_core_target() -> bool:
	for e in enemies.values():
		if _alive(e): return true
	return false

func _core_base_damage() -> float:
	# Core update already decreased sync before reading activation-time DPS.
	_refresh_turret_stats()
	var dps := 0.0
	for t in turrets.values():
		var stats: Dictionary = t.stats
		var definition: Dictionary = t.statInput.definition
		var projectile: bool = Capabilities.supports_projectile(definition)
		var rate: float = stats.attackRate / (1.4 if t.statInput.chainCleanupActive else 1.0) * (1.4 if t.cleanup>0 else 1.0)
		dps += float(stats.damage)*(1.0 + float(t.statInput.get("coreEffects", {}).get("directDamageIncrease", 0.0)))*maxf(0,rate)*(int(stats.projectileCount) if projectile else 1)
		if "damageOverTime" in definition.attackTags:
			dps += float(stats.damage)*0.5*float(stats.damageOverTimeDamageMultiplier) / Stats.damage_over_time_training_multiplier(t.statInput)
	return maxf(float(core.config.get("normalMaxHp",0))*float(core.config.get("guardianMinNormalHpRate",0.1)),dps*float(core.config.get("guardianBeamInterval",5))*float(core.config.get("guardianDpsRate",0.08)))

func _core_beam_tick(tick_damage: float) -> void:
	var target: Dictionary = {}
	var progress := -INF
	for e in enemies.values():
		if _alive(e) and _progress_score(e)>progress:
			target = e
			progress = _progress_score(e)
	if target.is_empty(): return
	var cap: float = core.config.get("bossHpCapRate",0.025) if _boss(target) else core.config.get("enemyHpCapRate",0.35)
	cap *= float(target.maxHp)*float(core.config.get("guardianBeamTickInterval",0.1))/float(core.config.get("guardianBeamDuration",1.0))
	var damage := minf(tick_damage,cap)
	if damage <= 0: return
	target.hitFlashTimer = 0.1
	var result: Dictionary = Enemy.apply_hit(target,{"damage":damage})
	_collect(result.events, {}, true)
	core.direct_damage_dealt += float(result.actualDamage)
	core.bonus_damage_dealt += float(result.bonusDamage)
	if float(result.actualDamage)>0:
		_core_visual("coreBeam",[target],0xff8ee6ff)
		_core_damage_number(target,float(result.actualDamage))

func _core_rift_mark(power: float) -> void:
	var candidates: Array = enemies.values().filter(func(e): return _alive(e))
	candidates.sort_custom(func(a,b):
		var durability_a := _durability(a)
		var durability_b := _durability(b)
		return _progress_score(a)>_progress_score(b) if durability_a == durability_b else durability_a>durability_b)
	candidates = candidates.slice(0,int(core.config.get("riftMarkTargetCount",4)))
	for target in candidates:
		var amp: float = core.config.get("riftMarkBossDamageAmplification",0.125) if _boss(target) else core.config.get("riftMarkDamageAmplification",0.25)
		Enemy.add_rift_mark(target,amp*power,float(core.config.get("riftMarkDuration",5.0)))
		target.hitFlashTimer = 0.1
	_core_visual("rift",candidates,0xffcfa7ff)

## 직접 피해 없이 독 중첩 하나만 건다. 저항·지속피해 보정은 명중과 같은 계산을 쓴다.
func _poison_stack(t: Dictionary, a: Dictionary, e: Dictionary) -> void:
	var status := a.duplicate()
	status.damageScale = 1.0
	# 중첩마다 치명타 판정: 터지면 추가분의 50%를 반영한다(Attack.resolve 공통 규칙).
	var chance := float(t.stats.get("criticalChance", 0.0))
	status.criticalMultiplier = float(t.stats.criticalDamageMultiplier) if chance > 0.0 and rng.randf() < chance else 1.0
	var resolved := Attack.resolve({"baseDamage": 0.0, "resistance": _resistance(a, e), "status": status})
	for effect in resolved.effects:
		if effect.type == "poison": _add_poison(t, a, e, effect)

## 독 효과 하나를 출처·지속피해 증가·특성(농축·부식)과 함께 적에게 붙인다.
func _add_poison(t: Dictionary, a: Dictionary, e: Dictionary, effect: Dictionary) -> void:
	effect.sourceX = int(t.state.get("x", 0))
	effect.sourceY = int(t.state.get("y", 0))
	if a.has("damageOverTimeIncreaseMultiplier"): effect.damageOverTimeIncreaseMultiplier = a.damageOverTimeIncreaseMultiplier
	if a.has("poisonStackBonus"): effect.stackBonus = float(a.poisonStackBonus)
	if bool(a.get("poisonCorrosion", false)):
		effect.corrosive = true
		corroding[str(e.id)] = true
	Enemy.add_poison(e, effect)

## 부식 독소: 한 포탑의 부식 중첩이 3개 이상인 적만 물리 저항을 낮춘다.
func _apply_corrosion() -> void:
	for id: String in corroding.keys():
		var e: Dictionary = enemies.get(id, {})
		if e.is_empty() or not _alive(e):
			corroding.erase(id)
			continue
		var counts := {}
		for p: Dictionary in e.poisonInstances:
			if not bool(p.get("corrosive", false)) or float(p.remaining) <= 0.0: continue
			var key := "%s,%s" % [p.get("sourceX"), p.get("sourceY")]
			counts[key] = int(counts.get(key, 0)) + 1
		if counts.is_empty():
			corroding.erase(id)
		elif counts.values().max() >= int(CORROSION.stacks):
			Enemy.add_vulnerability(e, "physical", float(CORROSION.bonus), float(CORROSION.linger))

func _traits(t: Dictionary, a: Dictionary, e: Dictionary) -> float:
	var id := str(e.id)
	if a.appliesChainCleanup:
		t.recent[id] = 1.5
	if a.appliesSuppressiveFire:
		t.suppressiveHits = int(t.suppressiveHits) + 1 if str(t.suppressiveTarget) == id else 1
		t.suppressiveTarget = id
		if t.suppressiveHits >= 5:
			Enemy.add_vulnerability(e, "physical", 0.2, 2.0)
			t.suppressiveHits = 0
	if a.appliesExposedMark:
		Enemy.add_vulnerability(e, "physical", 0.15, 2.0)
	var multiplier := 1.0
	if a.appliesOverheatMagazine:
		t.overheatStacks = mini(15, int(t.overheatStacks) + 1) if str(t.overheatTarget) == id else 1
		t.overheatTarget = id
		multiplier *= 1.0 + float(t.overheatStacks) * 0.02
	if a.appliesCompressedCharge:
		multiplier *= 1.35
	if a.appliesFocusedLightning:
		multiplier *= 1.3
	if a.appliesFinishingShot and _durability(e) / maxf(1.0, float(e.maxHp) + float(e.get("maxArmor", 0)) + float(e.get("maxShield", 0))) <= 0.35:
		multiplier *= 1.45
	return multiplier

func _hit(t: Dictionary, a: Dictionary, e: Dictionary, scale: float, kind: String, direct: bool, chained: bool = false) -> void:
	e.hitFlashTimer = 0.1
	var source := {"x": int(t.state.get("x", 0)), "y": int(t.state.get("y", 0))}
	var burn: Dictionary = Enemy.burn_transfer(e, source, _damage_over_time_training_bonus_rate) if direct and a.appliesIgnitionBurst else {}
	var burst: float = Enemy.burn_damage_per_second(burn, _damage_over_time_training_bonus_rate) * 2.0 * float(a.damageOverTimeDurationMultiplier) * 0.3 if direct and a.appliesIgnitionBurst else 0.0
	var trait_multiplier := _traits(t, a, e) if direct else 1.0
	var resistance := _resistance(a, e)
	# Same-layer hit increases add before multiplication. They do not leak into DoT.
	var hit_increase := float(a.get("directDamageIncrease", 0.0)) + _direct_damage_training_bonus_rate
	if kind == "splash": hit_increase += float(a.get("splashDamageIncrease", 0.0)) + _splash_damage_training_bonus_rate
	elif kind == "chain": hit_increase += float(a.get("chainDamageIncrease", 0.0))
	# resolve only reads status; the per-hit scale travels beside the shared attack.
	var resolved := Attack.resolve({"baseDamage": float(a.damage) * float(a.criticalMultiplier) * scale * (1.0 + hit_increase), "traitMultiplier": trait_multiplier, "resistance": resistance, "status": a, "damageScale": scale})
	for effect in resolved.effects:
		match effect.type:
			"slow": Enemy.add_control(e, "slow", effect.duration, {"multiplier":effect.multiplier, "firstControlDurationMultiplier":a.get("firstControlDurationMultiplier", 1.0)})
			"elementalVulnerability": Enemy.add_vulnerability(e, "elemental", effect.bonus, effect.duration)
			"burn":
				effect.sourceX = source.x
				effect.sourceY = source.y
				if a.has("damageOverTimeIncreaseMultiplier"): effect.damageOverTimeIncreaseMultiplier = a.damageOverTimeIncreaseMultiplier
				Enemy.add_burn(e, effect)
			"poison": _add_poison(t, a, e, effect)
	var transfer := Enemy.burn_transfer(e, source, _damage_over_time_training_bonus_rate) if a.spreadsChainIgnition else {}
	# 독 계열 타격은 독 중독처럼 방어구 감쇄를 받지 않는다(방어구 내구도는 먼저 깎인다).
	var ignore_armor: bool = a.ignoresArmorReduction or a.definition.damageFamily == "poison"
	var result: Dictionary = Enemy.apply_hit(e, {"damage": resolved.damage, "ignoreArmorReduction": ignore_armor, "burnTransfer": transfer}, _target_damage_multiplier(e))
	_visual("damage", _pos(e), t, {"text":str(roundi(float(result.get("actualDamage", 0)))), "duration":0.65})
	t[kind + "DamageDealt"] += float(result.get("actualDamage", 0))
	_add_core_bonus_damage(float(result.get("bonusDamage", 0)))
	_collect(result.get("events", []))
	if burst > 0 and _alive(e):
		result = Enemy.apply_hit(e, {"damage": burst, "ignoreArmorReduction": ignore_armor, "burnTransfer": transfer}, _target_damage_multiplier(e))
		t.directDamageDealt += float(result.get("actualDamage", 0))
		_add_core_bonus_damage(float(result.get("bonusDamage", 0)))
		_collect(result.get("events", []))

func _resistance(a: Dictionary, e: Dictionary) -> Dictionary:
	var family: String = a.definition.damageFamily
	return {"family": family, "familyResistance": e.get("familyResistances", {}).get(family, 0.0), "tags": a.definition.attackTags, "tagResistances": e.get("tagResistances", {}), "attackPhysicalReduction": a.physicalResistanceReduction, "enemyPhysicalReduction": e.get("physicalVulnerabilityBonus", 0.0) if float(e.get("physicalVulnerabilityRemaining", 0)) > 0 else 0.0, "enemyElementalReduction": e.get("elementalVulnerabilityBonus", 0.0) if float(e.get("elementalVulnerabilityRemaining", 0)) > 0 else 0.0}

# Preserve all turrets at a source coordinate and their insertion order. Numeric
# coordinates may arrive as JSON floats or native ints; normalize just the keys.
func _burn_coordinate_key(value: Variant) -> Variant:
	return float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else value

func _burn_source_turrets(source: Dictionary, index: Dictionary) -> Array:
	if not index.has("rows"):
		var rows: Dictionary = {}
		for t in turrets.values():
			var x: Variant = _burn_coordinate_key(t.state.get("x"))
			var y: Variant = _burn_coordinate_key(t.state.get("y"))
			if not rows.has(x): rows[x] = {}
			if not rows[x].has(y): rows[x][y] = []
			rows[x][y].append(t)
		index.rows = rows
	var row: Dictionary = index.rows.get(_burn_coordinate_key(source.get("sourceX")), {})
	return row.get(_burn_coordinate_key(source.get("sourceY")), [])

func _collect(items: Array, burn_sources: Dictionary = {}, core_owned: bool = false) -> void:
	for raw in items:
		var type: String = raw.get("type", "")
		# Continuous damage is settled here into turret and core totals. No journal
		# reader consumes it, so per-tick burn/poison never wakes economy settlement.
		if type == Kinds.ENEMY_DAMAGE:
			_add_core_bonus_damage(float(raw.get("bonusDamage", 0)))
			# Poison shares the turret's existing DoT total; the save schema has no separate field.
			if raw.get("kind") in ["burn", "poison"]:
				for t in _burn_source_turrets(raw, burn_sources):
					if t.state.get("x") == raw.get("sourceX") and t.state.get("y") == raw.get("sourceY"):
						t.burnDamageDealt += float(raw.get("damage", 0))
			continue
		if type == Kinds.ENEMY_DAMAGE_NUMBER:
			_dot_damage_number(raw)
			continue
		var event: Dictionary = raw.duplicate(true)
		if type == Kinds.ENEMY_KILLED:
			event.kind = Kinds.KILL
			if not core_owned: core.charge_from_kill()
			_diamond_reward_visual(enemies.get(str(event.enemyId), {}))
			_spread_burn(event)
			for t in turrets.values():
				if float(t.recent.get(str(event.enemyId), 0)) > 0:
					t.cleanup = 3.0
		elif type == Kinds.ENEMY_CORE_ARRIVAL:
			event.kind = Kinds.ARRIVAL
			var enemy: Dictionary = enemies.get(str(event.enemyId),{})
			var result: Dictionary = defense.arrive(enemy,_boss(enemy),core.emergency_charge)
			event.merge(result,true)
			if float(result.damage)>0:
				nexus_alert = 0.65
				_nexus_health_number(-float(result.damage))
			_emit(event)
			if result.defeated:
				terminal = true
				running = false
				wave.cancel()
				pending_steps.clear()
				_emit({"kind":Kinds.CORE_DEFEATED,"enemyId":event.enemyId})
			continue
		else:
			event.effectKind = raw.get("kind", "")
			event.kind = type
		_emit(event)

func _spread_burn(event: Dictionary) -> void:
	var burn: Dictionary = event.get("burnTransfer", {})
	if burn.is_empty() or float(burn.get("remaining", 0)) <= 0:
		return
	var owner: Dictionary = {}
	for t in turrets.values():
		if t.state.get("x") == burn.get("sourceX") and t.state.get("y") == burn.get("sourceY") and t.stats.spreadsChainIgnition:
			owner = t
			break
	if owner.is_empty():
		return
	var target := _target(Vector2(event.x, event.y), 88.0 * board_scale, "first", [str(event.enemyId)])
	if target.is_empty():
		return
	var transfer := burn.duplicate(true)
	transfer.remaining *= 0.6
	Enemy.add_burn(target, transfer)
