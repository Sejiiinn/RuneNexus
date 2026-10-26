extends "res://combat/combat_runtime_damage.gd"
## Turret firing and every weapon delivery: projectiles, lobs, puddles, lightning.

## Read-only production/UI observation; normal timings exclude stockpile amplification.
## Cooldown is nominal (before the existing per-shot random 0.95..1.05 jitter).
func stockpile_firing_state(turret_id: int) -> Dictionary:
	var t: Dictionary = turrets.get(str(turret_id), {})
	if t.is_empty(): return {}
	var cooldown := 1.0 / _normal_attack_rate(t)
	var aim := _normal_aim_duration(t)
	return {"enabled":t.stockpileEnabled,"charges":t.stockpileCharges,
		"idleElapsed":t.stockpileIdleElapsed,"chargeInterval":cooldown+aim,
		"normalCooldown":cooldown,"normalAimDuration":aim,
		"speedMultiplier":_stockpile_aim_multiplier(t) if t.stockpileEnabled and t.stockpileCharges > 0 else 1.0}

func _tick_turret(t: Dictionary, dt: float) -> void:
	var ready_dt := maxf(0.0, dt - maxf(0.0, float(t.cooldown)))
	t.cooldown = maxf(0, float(t.cooldown) - dt)
	t.cleanup = maxf(0, float(t.cleanup) - dt)
	t.fireFeedback = maxf(0, float(t.fireFeedback) - dt)
	t.lightningElapsed += dt
	if not t.recent.is_empty():
		for id in t.recent.keys():
			t.recent[id] -= dt
			if t.recent[id] <= 0:
				t.recent.erase(id)
	if not running or t.cooldown > 0 or t.stockpilePrefiring:
		t.aimProgress = 0
		return
	var s: Dictionary = t.stats
	var definition: Dictionary = t.statInput.definition
	var centered: bool = definition.centeredAreaAttack
	var radius: float = s.centeredAreaRadius if centered else s.range
	var target: Dictionary = {}
	var retained_aim := false
	if definition.instantHit:
		var existing: Dictionary = enemies.get(str(t.aimTargetId), {})
		if not existing.is_empty() and _alive(existing) and _vec(t.position).distance_to(_pos(existing)) <= radius + _target_radius(existing):
			target = existing
			retained_aim = true
	if target.is_empty():
		target = _target(_vec(t.position), radius, t.get("targetPriority", t.state.get("targetPriority", "first")), [], true)
	if target.is_empty():
		t.aimProgress = 0
		if t.stockpileEnabled: _charge_stockpile(t, ready_dt)
		return
	# Acquisition breaks the continuous no-target interval even if this target
	# dies or leaves before firing. Completed charges survive interrupted aim.
	if t.stockpileEnabled: t.stockpileIdleElapsed = 0.0
	var stockpiled: bool = t.stockpileEnabled and t.stockpileCharges > 0
	if definition.instantHit:
		if not retained_aim and str(t.aimTargetId) != str(target.id):
			t.aimProgress = 0
		t.aimTargetId = target.id
		t.aimProgress += dt * (_stockpile_aim_multiplier(t) if stockpiled else 1.0)
		t.aimAngle = (_pos(target) - _vec(t.position)).angle()
		if t.aimProgress < s.aimDuration:
			return
	var crit: float = s.criticalDamageMultiplier if rng.randf() < s.criticalChance else 1.0
	var attack := Stats.firing_stats(t.statInput, s, crit)
	attack.definition = definition
	attack.burnDamagePerSecondScale = 0.5
	attack.burnDurationSeconds = 2.0
	if definition.type == "poison":
		# 착탄은 범위 피해만 준다. 독은 남은 웅덩이(독 장판)가 맡는다.
		attack.hasDamageOverTime = false
	t.cooldown = (0.95 + rng.randf() * 0.1) / _normal_attack_rate(t)
	if stockpiled and definition.type != "lightning":
		t.stockpileCharges -= 1
		t.cooldown /= _stockpile_cooldown_multiplier(t)
	t.lastBaseCooldown = t.cooldown
	t.lightningElapsed = 0.0
	t.aimProgress = 0.0
	t.aimAngle = (_pos(target) - _vec(t.position)).angle()
	t.shotSequence += 1
	t.fireFeedback = 0.18
	if centered:
		_visual("impact", _vec(t.position), t, {"style":"frost", "radius":radius})
		var center := _vec(t.position)
		for candidate: Array in _target_candidate_view():
			var e: Dictionary = candidate[0]
			if _alive(e) and center.distance_to(candidate[1]) <= radius + float(candidate[2]):
				_hit(t, attack, e, 1.0, "splash", false)
	elif definition.instantHit:
		_visual("impact", _pos(target), t, {"style":"sniperBlast", "radius":12.0 * board_scale})
		_impact(t, attack, target, _pos(target))
	elif definition.type == "lightning":
		var charge_time := 0.3 / (_stockpile_aim_multiplier(t) if stockpiled else 1.0)
		t.stockpilePrefiring = t.stockpileEnabled
		_visual("charge", _vec(t.position), t, {"duration":charge_time, "ownerId":int(t.id), "attachmentRadius":0.4})
		delayed.append({"kind": "charge", "timer": charge_time, "owner": str(t.id), "attack": attack, "stockpiled":stockpiled})
	elif definition.type == "poison":
		_lob(t, attack, _vec(t.position), target)
	else:
		var projectile_origin := _vec(t.position)
		if definition.type == "magic":
			projectile_origin += Vector2.from_angle(t.aimAngle) * tile_size * 0.82 * 0.2
		for index in range(int(s.projectileCount)):
			var angle: float = t.aimAngle + (index - (int(s.projectileCount) - 1) / 2.0) * PI / 18.0
			_projectile(t, attack, projectile_origin, Vector2.from_angle(angle), int(attack.chainCount), [], false, (s.range + 64.0 * board_scale) * PROJECTILE_TRAVEL_MULTIPLIER)

func _projectile(t: Dictionary, a: Dictionary, from: Vector2, direction: Vector2, chains: int, excluded: Array, chained: bool, distance: float, pierces: int = -1) -> void:
	projectile_id += 1
	projectiles.append({"id": projectile_id, "owner": str(t.id), "attack": a, "position": from, "origin": from, "direction": direction.normalized(), "remaining": distance, "chains": chains, "pierces": maxi(0, int(a.get("pierceCount", 0))) if pierces < 0 else pierces, "excluded": excluded.duplicate(), "chained": chained, "shot": t.shotSequence})

# A lobbed glob ignores bodies on the way and follows its target until it lands.
func _lob(t: Dictionary, a: Dictionary, from: Vector2, target: Dictionary) -> void:
	projectile_id += 1
	var landing := _pos(target)
	projectiles.append({"id": projectile_id, "owner": str(t.id), "attack": a, "position": from, "origin": from, "direction": (landing - from).normalized(), "remaining": from.distance_to(landing), "chains": 0, "pierces": 0, "excluded": [], "chained": false, "shot": t.shotSequence, "lobTarget": str(target.id), "landing": landing})

func _move_lob(t: Dictionary, p: Dictionary, dt: float) -> void:
	var target: Dictionary = enemies.get(p.lobTarget, {})
	if _alive(target): p.landing = _pos(target)
	var offset: Vector2 = p.landing - p.position
	var step := float(p.attack.projectileSpeed) * dt
	if offset.length() > step:
		p.direction = offset.normalized()
		p.position += p.direction * step
		p.remaining = offset.length() - step
		projectiles.append(p)
		return
	p.position = p.landing
	_add_puddle(t, p.attack, p.position)
	_venom_burst(t, p.attack, p.position)

## 바닥 착탄 폭발: 대상 구분 없이 반경 안 모든 적에게 100% 범위 피해와, 그 피해 기준 독 1중첩(공통 규칙).
func _venom_burst(t: Dictionary, a: Dictionary, at: Vector2) -> void:
	var radius := maxf(10.0 * board_scale, float(a.splashRadius))
	var rules := _puddle_rules(a)
	var burst := a.duplicate()
	burst.hasDamageOverTime = true
	burst.poisonDurationSeconds = float(rules.stackSeconds)
	burst.poisonDamagePerSecondScale = float(rules.hitShare) / float(rules.stackSeconds)
	var hit: Array = []
	for candidate: Array in _target_candidate_view():
		if _alive(candidate[0]) and at.distance_squared_to(candidate[1]) <= radius * radius: hit.append(candidate[0])
	for e: Dictionary in hit:
		if _alive(e): _hit(t, burst, e, 1.0, "splash", false)

## 웅덩이 하나와 그 연출(착탄 폭발 겸용)을 남긴다. 포탑당 상한을 넘으면 가장 오래된 것부터 지운다.
func _add_puddle(t: Dictionary, a: Dictionary, at: Vector2) -> void:
	var radius := maxf(10.0 * board_scale, float(a.splashRadius))
	var duration := float(_puddle_rules(a).duration)
	var owned: Array = puddles.filter(func(item): return item.owner == str(t.id))
	while owned.size() >= int(poison_puddle.maxCount):
		var oldest: Dictionary = owned.pop_front()
		puddles.erase(oldest)
		visual_effects = visual_effects.filter(func(v): return int(v.id) != int(oldest.visualId))
	_visual("blast", at, t, {"style": "venom", "variant": "venom", "duration": maxf(VENOM_SPLASH_DURATION, duration), "radius": radius})
	puddles.append({"owner": str(t.id), "position": at, "radius": radius, "remaining": duration, "attack": _poison_stack_attack(a), "visualId": visual_id})
	if not t.has("puddleTick"): t.puddleTick = 0.0

func _puddle_rules(a: Dictionary) -> Dictionary:
	if not bool(a.get("venomPool", false)): return poison_puddle
	var rules := poison_puddle.duplicate()
	rules.merge(venom_pool_puddle, true)
	return rules

## 웅덩이가 거는 독 중첩 하나의 공격. 포탑 피해의 절반을 기준으로 공통 규칙을 적용한다.
## 치명타는 중첩을 걸 때마다 _poison_stack이 판정한다.
func _poison_stack_attack(a: Dictionary) -> Dictionary:
	var rules := _puddle_rules(a)
	var stack := a.duplicate()
	stack.hasDamageOverTime = true
	stack.criticalMultiplier = 1.0
	stack.poisonDurationSeconds = float(rules.stackSeconds)
	stack.poisonDamagePerSecondScale = float(rules.puddleBase) * float(rules.hitShare) / float(rules.stackSeconds)
	return stack

## 포탑마다 주기 하나: 그 포탑의 웅덩이 어느 하나에라도 서 있는 적에게 독 1중첩.
func _tick_puddles(dt: float) -> void:
	var by_owner := {}
	var alive_puddles: Array = []
	for puddle in puddles:
		puddle.remaining -= dt
		if puddle.remaining <= 0.0: continue
		alive_puddles.append(puddle)
		if not by_owner.has(puddle.owner): by_owner[puddle.owner] = []
		by_owner[puddle.owner].append(puddle)
	puddles = alive_puddles
	for owner: String in by_owner:
		var t: Dictionary = turrets.get(owner, {})
		if t.is_empty(): continue
		t.puddleTick = float(t.get("puddleTick", 0.0)) + dt
		if t.puddleTick < float(poison_puddle.tick): continue
		t.puddleTick -= float(poison_puddle.tick)
		var owned: Array = by_owner[owner]
		for candidate: Array in _target_candidate_view():
			var e: Dictionary = candidate[0]
			if not _alive(e): continue
			for puddle: Dictionary in owned:
				if puddle.position.distance_squared_to(candidate[1]) <= float(puddle.radius) * float(puddle.radius):
					_poison_stack(t, puddle.attack, e)
					break
	for owner: String in turrets:
		if not by_owner.has(owner) and turrets[owner].has("puddleTick"): turrets[owner].puddleTick = 0.0

func _move_projectile(p: Dictionary, dt: float, broadphase: Dictionary = {}) -> void:
	var t: Dictionary = turrets.get(p.owner, {})
	if t.is_empty(): return
	if p.has("landing"):
		_move_lob(t, p, dt)
		return
	var step := minf(p.remaining, float(p.attack.projectileSpeed) * dt)
	while true:
		var from: Vector2 = p.position
		var movement: Vector2 = p.direction * step
		var collision := _first_projectile_collision(from, movement, p.attack, p.excluded, broadphase)
		var hit: Dictionary = collision.target
		var traveled := step * (float(collision.fraction) if not hit.is_empty() else 1.0)
		p.position = from + p.direction * traveled
		p.remaining = maxf(0.0, p.remaining - traveled)
		step = maxf(0.0, step - traveled)
		if hit.is_empty():
			if p.remaining > 0: projectiles.append(p)
			return
		p.excluded.append(str(hit.id))
		var terminal_impact := int(p.get("pierces", 0)) <= 0
		_impact(t, p.attack, hit, p.position, 0.5 if p.chained else 1.0, p.chained, p.direction, terminal_impact)
		if not terminal_impact:
			p.pierces -= 1
			# Keep traversing this same swept segment. Exclusion guarantees overlap
			# progress without skipping nearby targets with an artificial offset.
			if p.remaining <= 0: return
			continue
		if p.chains > 0:
			var chain_range := 110.0 * board_scale * float(p.attack.get("chainJumpRangeMultiplier", 1.0))
			var next := _target(p.position, chain_range, "nearest", p.excluded)
			if not next.is_empty():
				_projectile(t, p.attack, p.position, _pos(next) - p.position, int(p.chains) - 1, p.excluded, true, chain_range * PROJECTILE_TRAVEL_MULTIPLIER, 0)
		return

func _release(d: Dictionary) -> void:
	var t: Dictionary = turrets.get(d.owner, {})
	if t.is_empty():
		return
	var a: Dictionary = d.attack
	var from := _vec(t.position) if d.kind == "charge" else _vec(d.position)
	var excluded: Array = d.get("excluded", [])
	# Reacquire at discharge so dead/out-of-range enemies cannot be hit. Only
	# the first strike uses the turret priority; chained jumps retain first.
	var priority: String = t.get("targetPriority", t.state.get("targetPriority", "first")) if d.kind == "charge" else "first"
	var target := _target(from, a.range if d.kind == "charge" else a.lightningChainJumpRange, priority, excluded, d.kind == "charge")
	var used := int(d.get("used", 0))
	if d.kind == "charge": t.stockpilePrefiring = false
	if target.is_empty():
		_lightning_complete(t, a, used)
		return
	# Charge/cancel never spends a stored shot. A valid first discharge does.
	if d.kind == "charge" and bool(d.get("stockpiled", false)) and t.stockpileCharges > 0:
		t.stockpileCharges -= 1
		t.lastBaseCooldown /= _stockpile_cooldown_multiplier(t)
		t.cooldown = maxf(0.0, float(t.lastBaseCooldown) - float(t.lightningElapsed))
	var visual_source_id := -1 if d.kind == "charge" or excluded.is_empty() else int(excluded[-1])
	_visual("chain", from, t, {"points":[[from.x,from.y],[_pos(target).x, _pos(target).y]], "targetIds":[-1,target.id], "sourceTargetId":visual_source_id})
	_impact(t, a, target, _pos(target), 1.0 if d.kind == "charge" else float(a.lightningChainDamageMultiplier), d.kind != "charge")
	excluded.append(str(target.id))
	if d.kind != "charge":
		used += 1
	if used < int(a.lightningChainMaxJumps):
		delayed.append({"kind": "chain", "timer": 0.07, "owner": d.owner, "attack": a, "position": [_pos(target).x, _pos(target).y], "excluded": excluded, "used": used})
	else:
		_lightning_complete(t, a, used)

func _lightning_complete(t: Dictionary, a: Dictionary, used: int) -> void:
	if t.stats.appliesLightningRecovery:
		var unused := maxi(0, int(a.lightningChainMaxJumps) - used)
		t.cooldown = minf(t.cooldown, maxf(0, float(t.lastBaseCooldown) / (1 + unused * 0.15) - float(t.lightningElapsed)))

func _impact(t: Dictionary, a: Dictionary, target: Dictionary, at: Vector2, scale: float = 1.0, chained: bool = false, direction: Vector2 = Vector2.ZERO, terminal_impact: bool = true) -> void:
	var style: String = IMPACT_STYLES.get(a.definition.type, "spark")
	if not terminal_impact and style == "blast": style = "spark"
	var radius: float = a.splashRadius * (0.5 if chained else 1.0) if terminal_impact else 0.0
	var extra := {"style":style,"radius":maxf(10.0 * board_scale, radius)}
	if terminal_impact and a.definition.type == "sniper" and a.splashRadius > 0:
		# Explosion sniper hits get their own 3D energy blast whose shockwave stops
		# at the real splash radius, instead of a stretched flat spark.
		# Presentation only: damage routing is unchanged.
		style = "blast"
		extra.merge({"variant":"sniperEnergy", "duration":SNIPER_BLAST_DURATION})
	if terminal_impact and a.definition.type == "arrow" and direction != Vector2.ZERO:
		# Presentation routing only: the 3D ricochet uses the incoming flight and
		# the struck body's lane offset. Damage and collision stay unchanged.
		extra.merge({"turretType":"arrow", "targetId":int(target.id), "direction":[direction.x, direction.y]})
	# 독액 착탄 연출은 웅덩이(_add_puddle)가 함께 그린다.
	if style != "venom": _visual("blast" if style == "blast" else "impact", at, t, extra)
	var impacted: Array = [target]
	if radius > 0:
		# Targets are live enemy entries; identity avoids deep Dictionary compares.
		for candidate: Array in _target_candidate_view():
			var e: Dictionary = candidate[0]
			if not is_same(e, target) and _alive(e) and at.distance_squared_to(candidate[1]) <= radius * radius:
				impacted.append(e)
	for e in impacted:
		if _alive(e):
			var primary: bool = is_same(e, target)
			_hit(t, a, e, scale * (1.0 if primary else float(a.splashSecondaryDamageMultiplier)), ("chain" if chained else "direct") if primary else "splash", primary and not chained, chained)
