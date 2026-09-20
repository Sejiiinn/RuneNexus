extends RefCounted
## Persistent combat authority. Commands, simulation time and events are ACKed once.
const Enemy = preload("res://combat/native_enemy_state.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Attack = preload("res://combat/attack_calculation.gd")
var epoch: int = -1
var active: bool = false
var running: bool = true
var elapsed: float:
	get: return clock
var sequence: int = -1
var enemies: Dictionary = {}
var turrets: Dictionary = {}
var projectiles: Array = []
var delayed: Array = []
var events: Array = []
var visual_effects: Array = []
var visual_id: int = 1000000000
var event_id: int = 0
var projectile_id: int = 0
var clock: float = 0.0
var path: Array = []
var origin := Vector2.ZERO
var tile_size: float = 1.0
var board_scale: float = 1.0
var rng := RandomNumberGenerator.new()

func process_command(packet: Dictionary) -> Dictionary:
	if epoch != packet.get("epoch"):
		if not packet.has("bootstrap"):
			return {"accepted": false, "reason": "bootstrapRequired", "epoch": packet.get("epoch"), "ackSequence": -1}
		_reset(packet)
	if int(packet.get("sequence", -1)) <= sequence:
		return snapshot()
	if sequence >= 0 and int(packet.sequence) != sequence + 1:
		return {"accepted": false, "reason": "sequenceGap", "epoch": epoch, "ackSequence": sequence}
	var ack_event := int(packet.get("ackEvent", 0))
	for event in events:
		if int(event.id) <= ack_event and event.kind in ["kill","arrival"]:
			enemies.erase(str(event.enemyId))
	events = events.filter(func(e): return int(e.id) > ack_event)
	running = bool(packet.get("running", running))
	for command in packet.get("commands", []):
		_command(command)
	if packet.has("steps"):
		for step in packet.steps:
			running = bool(step.get("running", running))
			for command in step.get("commands", []):
				_command(command)
			if float(step.get("dt", 0)) > 0:
				_step(float(step.dt))
			for command in step.get("commandsAfter", []):
				_command(command)
	elif packet.has("dtSteps"):
		for dt in packet.dtSteps:
			if float(dt) > 0: _step(float(dt))
	elif float(packet.get("dt", 0)) > 0:
		_step(float(packet.dt))
	sequence = int(packet.sequence)
	return snapshot()

func _reset(packet: Dictionary) -> void:
	epoch = int(packet.epoch)
	active = true
	sequence = -1
	enemies.clear()
	turrets.clear()
	projectiles.clear()
	delayed.clear()
	events.clear()
	visual_effects.clear()
	event_id = 0
	clock = 0
	var b: Dictionary = packet.bootstrap
	rng.seed = int(b.get("seed", 71423))
	path = _path(b.get("path", []))
	origin = _vec(b.get("origin", [0, 0]))
	tile_size = maxf(0.001, b.get("tileSize", 1.0))
	board_scale = b.get("boardDistanceScale", 1.0)
	for e in b.get("enemies", []):
		_spawn(e)
	for t in b.get("turrets", []):
		_turret(t)

func _path(raw: Array) -> Array:
	var result: Array = []
	for point in raw:
		var v := _vec(point)
		result.append({"x": v.x, "y": v.y})
	return result

func _spawn(raw: Dictionary) -> void:
	var value: Dictionary = raw.get("state", {}).duplicate(true)
	value.merge(raw, true)
	value.path = _path(raw.get("path", path))
	value.boardDistanceScale = board_scale
	value.collisionRadius = raw.get("radius", raw.get("collisionRadius", 8.0))
	enemies[str(raw.id)] = Enemy.create(value)

func _turret(raw: Dictionary) -> void:
	var id := str(raw.id)
	var old: Dictionary = turrets.get(id, {})
	var t := raw.duplicate(true)
	var state: Dictionary = t.get("state", {})
	for key in ["cooldown", "aimProgress", "aimTargetId", "aimAngle", "shotSequence", "directDamageDealt", "splashDamageDealt", "chainDamageDealt", "burnDamageDealt", "cleanup", "recent", "overheatTarget", "overheatStacks", "suppressiveTarget", "suppressiveHits", "lastBaseCooldown", "lightningElapsed", "fireFeedback"]:
		t[key] = old.get(key, raw.get(key, state.get(key, {} if key == "recent" else 0)))
	t.stats = Stats.stats_at(t.statInput, int(t.statInput.level))
	turrets[id] = t

func _command(c: Dictionary) -> void:
	match c.get("kind", ""):
		"layout":
			var old_origin := origin
			var old_tile := tile_size
			origin = _vec(c.get("origin", [origin.x,origin.y]))
			tile_size = float(c.get("tileSize", tile_size))
			var ratio := tile_size / maxf(old_tile,0.001)
			board_scale = float(c.get("boardDistanceScale", board_scale))
			path = _path(c.get("path", path))
			for e in enemies.values():
				e.boardDistanceScale = board_scale
				e.collisionRadius = _radius(e)*ratio
				if e.has("targetingRadius"): e.targetingRadius *= ratio
				if e.has("presentationSize"): e.presentationSize = [e.presentationSize[0]*ratio,e.presentationSize[1]*ratio]
				Enemy.update_path(e,path)
			for t in turrets.values():
				var p := (_vec(t.position)-old_origin)*ratio+origin
				t.position = [p.x,p.y]
				t.statInput.boardDistanceScale = board_scale
				t.stats = Stats.stats_at(t.statInput,int(t.statInput.level))
			for p in projectiles:
				p.position = (p.position-old_origin)*ratio+origin
				p.origin = (p.origin-old_origin)*ratio+origin
				p.remaining *= ratio
				p.attack = p.attack.duplicate(true)
				for key in ["range","splashRadius","projectileSpeed","lightningChainJumpRange"]: p.attack[key] *= ratio
		"spawn": _spawn(c.enemy)
		"turret": _turret(c.turret)
		"removeTurret":
			var removed: Dictionary = turrets.get(str(c.id), {})
			if not removed.is_empty():
				for e in enemies.values():
					Enemy.clear_burn_source(e, {"x": removed.state.get("x"), "y": removed.state.get("y")})
			turrets.erase(str(c.id))
		"riftMark":
			if enemies.has(str(c.enemyId)):
				Enemy.add_rift_mark(enemies[str(c.enemyId)], c.damageAmplification, c.duration)
		"coreDamage":
			if enemies.has(str(c.enemyId)):
				var result: Dictionary = Enemy.apply_hit(enemies[str(c.enemyId)], {"damage": c.damage})
				_collect(result.get("events", []))
				_emit({"kind": "coreDamage", "enemyId": c.enemyId, "damage": result.get("actualDamage", 0.0)})

func _step(dt: float) -> void:
	clock += dt
	visual_effects = visual_effects.filter(func(v): return clock - float(v.born) < float(v.duration))
	for e in enemies.values():
		if _alive(e):
			_collect(Enemy.step(e, dt, path))
	for t in turrets.values():
		_tick_turret(t, dt)
	var pending := delayed
	delayed = []
	for d in pending:
		d.timer -= dt
		if d.timer > 0:
			delayed.append(d)
		else:
			_release(d)
	var moving := projectiles
	projectiles = []
	for p in moving:
		_move_projectile(p, dt)

func _tick_turret(t: Dictionary, dt: float) -> void:
	t.cooldown = maxf(0, float(t.cooldown) - dt)
	t.cleanup = maxf(0, float(t.cleanup) - dt)
	t.fireFeedback = maxf(0, float(t.fireFeedback) - dt)
	t.lightningElapsed += dt
	for id in t.recent.keys():
		t.recent[id] -= dt
		if t.recent[id] <= 0:
			t.recent.erase(id)
	if not running or t.cooldown > 0:
		t.aimProgress = 0
		return
	var s: Dictionary = t.stats
	var definition: Dictionary = t.statInput.definition
	var centered: bool = definition.centeredAreaAttack
	var radius: float = s.centeredAreaRadius if centered else s.range
	var target := _target(_vec(t.position), radius, t.get("targetPriority", t.state.get("targetPriority", "first")), [], true)
	if target.is_empty():
		t.aimProgress = 0
		return
	if definition.instantHit:
		var existing: Dictionary = enemies.get(str(t.aimTargetId), {})
		if not existing.is_empty() and _alive(existing) and _vec(t.position).distance_to(_pos(existing)) <= radius + _target_radius(existing):
			target = existing
		elif str(t.aimTargetId) != str(target.id):
			t.aimProgress = 0
		t.aimTargetId = target.id
		t.aimProgress += dt
		t.aimAngle = (_pos(target) - _vec(t.position)).angle()
		if t.aimProgress < s.aimDuration:
			return
	var crit: float = s.criticalDamageMultiplier if rng.randf() < s.criticalChance else 1.0
	var attack := Stats.firing_stats(t.statInput, s, crit)
	attack.definition = definition
	attack.burnDamagePerSecondScale = 0.5
	attack.burnDurationSeconds = 2.0
	t.cooldown = (0.95 + rng.randf() * 0.1) / maxf(0.001, s.attackRate / (1.4 if t.statInput.chainCleanupActive else 1.0) * (1.4 if t.cleanup > 0 else 1.0))
	t.lastBaseCooldown = t.cooldown
	t.lightningElapsed = 0.0
	t.aimProgress = 0.0
	t.aimAngle = (_pos(target) - _vec(t.position)).angle()
	t.shotSequence += 1
	t.fireFeedback = 0.18
	if centered:
		_visual("impact", _vec(t.position), t, {"style":"frost", "radius":radius})
		for e in enemies.values():
			if _alive(e) and _vec(t.position).distance_to(_pos(e)) <= radius + _target_radius(e):
				_hit(t, attack, e, 1.0, "splash", false)
	elif definition.instantHit:
		_visual("impact", _pos(target), t, {"style":"sniperBlast", "radius":12.0 * board_scale})
		_impact(t, attack, target, _pos(target))
	elif definition.type == "lightning":
		_visual("charge", _vec(t.position), t, {"duration":0.3, "ownerId":int(t.id), "attachmentRadius":0.4})
		delayed.append({"kind": "charge", "timer": 0.3, "owner": str(t.id), "attack": attack})
	else:
		var projectile_origin := _vec(t.position)
		if definition.type == "magic":
			projectile_origin += Vector2.from_angle(t.aimAngle) * tile_size * 0.82 * 0.2
		for index in range(int(s.projectileCount)):
			var angle: float = t.aimAngle + (index - (int(s.projectileCount) - 1) / 2.0) * PI / 18.0
			_projectile(t, attack, projectile_origin, Vector2.from_angle(angle), int(attack.chainCount), [], false, s.range + 64.0 * board_scale)

func _target(from: Vector2, radius: float, priority: String, excluded: Array = [], body: bool = false) -> Dictionary:
	var selected: Dictionary = {}
	var score := -INF
	var tie := -INF
	for e in enemies.values():
		if not _alive(e) or str(e.id) in excluded:
			continue
		var distance := from.distance_squared_to(_pos(e))
		if distance > pow(radius + (_target_radius(e) if body else 0.0), 2):
			continue
		var progress: float = e.get("distanceTravelled", 0.0)
		var current_score := progress
		var current_tie := -distance
		match priority:
			"last": current_score = -progress
			"strongest":
				current_score = _durability(e)
				current_tie = progress
			"weakest":
				current_score = -_durability(e)
				current_tie = progress
			"nearest":
				current_score = -distance
				current_tie = progress
		if selected.is_empty() or current_score > score or (current_score == score and current_tie > tie):
			selected = e
			score = current_score
			tie = current_tie
	return selected

func _projectile(t: Dictionary, a: Dictionary, from: Vector2, direction: Vector2, chains: int, excluded: Array, chained: bool, distance: float) -> void:
	projectile_id += 1
	projectiles.append({"id": projectile_id, "owner": str(t.id), "attack": a, "position": from, "origin": from, "direction": direction.normalized(), "remaining": distance, "chains": chains, "excluded": excluded.duplicate(), "chained": chained, "shot": t.shotSequence})

func _move_projectile(p: Dictionary, dt: float) -> void:
	var t: Dictionary = turrets.get(p.owner, {})
	if t.is_empty():
		return
	var step := minf(p.remaining, float(p.attack.projectileSpeed) * dt)
	var from: Vector2 = p.position
	var movement: Vector2 = p.direction * step
	var first := INF
	var hit: Dictionary = {}
	var radii := {"arrow": 3.5, "cannon": 7.0, "magic": 4.0}
	for e in enemies.values():
		if not _alive(e) or str(e.id) in p.excluded:
			continue
		var offset := from - _pos(e)
		var radius: float = _radius(e) + float(radii.get(p.attack.definition.type, 3.5)) * board_scale
		var c := offset.length_squared() - radius * radius
		var fraction := 0.0
		if c > 0:
			var length_squared := movement.length_squared()
			if length_squared <= 0:
				continue
			var b := offset.dot(movement)
			var discriminant := b * b - length_squared * c
			if discriminant < 0:
				continue
			fraction = (-b - sqrt(discriminant)) / length_squared
			if fraction < 0 or fraction > 1:
				continue
		if fraction < first:
			first = fraction
			hit = e
	p.position = from + movement * (first if not hit.is_empty() else 1.0)
	p.remaining -= step
	if hit.is_empty():
		if p.remaining > 0:
			projectiles.append(p)
		return
	p.excluded.append(str(hit.id))
	_impact(t, p.attack, hit, p.position, 0.5 if p.chained else 1.0, p.chained)
	if p.chains > 0:
		var next := _target(p.position, 110.0 * board_scale, "nearest", p.excluded)
		if not next.is_empty():
			_projectile(t, p.attack, p.position, _pos(next) - p.position, int(p.chains) - 1, p.excluded, true, 110.0 * board_scale)

func _release(d: Dictionary) -> void:
	var t: Dictionary = turrets.get(d.owner, {})
	if t.is_empty():
		return
	var a: Dictionary = d.attack
	var from := _vec(t.position) if d.kind == "charge" else _vec(d.position)
	var excluded: Array = d.get("excluded", [])
	var target := _target(from, a.range if d.kind == "charge" else a.lightningChainJumpRange, "first", excluded, d.kind == "charge")
	var used := int(d.get("used", 0))
	if target.is_empty():
		_lightning_complete(t, a, used)
		return
	_visual("chain", from, t, {"points":[[_pos(target).x, _pos(target).y]], "targetIds":[target.id]})
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

func _impact(t: Dictionary, a: Dictionary, target: Dictionary, at: Vector2, scale: float = 1.0, chained: bool = false) -> void:
	var style: String = {"arrow":"spark", "magic":"flame", "cannon":"blast", "lightning":"lightning"}.get(a.definition.type, "spark")
	_visual("blast" if style == "blast" else "impact", at, t, {"style":style,"radius":maxf(10.0 * board_scale, a.splashRadius * (0.5 if chained else 1.0))})
	var impacted: Array = [target]
	var radius: float = a.splashRadius * (0.5 if chained else 1.0)
	if radius > 0:
		for e in enemies.values():
			if e != target and _alive(e) and at.distance_squared_to(_pos(e)) <= radius * radius:
				impacted.append(e)
	for e in impacted:
		if _alive(e):
			var primary: bool = e == target
			_hit(t, a, e, scale * (1.0 if primary else float(a.splashSecondaryDamageMultiplier)), ("chain" if chained else "direct") if primary else "splash", primary and not chained)

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

func _hit(t: Dictionary, a: Dictionary, e: Dictionary, scale: float, kind: String, direct: bool) -> void:
	e.hitFlashTimer = 0.1
	var source := {"x": int(t.state.get("x", 0)), "y": int(t.state.get("y", 0))}
	var burn: Dictionary = Enemy.burn_transfer(e, source)
	var burst: float = float(burn.get("damagePerSecond", 0)) * 2.0 * float(a.damageOverTimeDurationMultiplier) * 0.3 if direct and a.appliesIgnitionBurst else 0.0
	var trait_multiplier := _traits(t, a, e) if direct else 1.0
	var family: String = a.definition.damageFamily
	var resistance := {"family": family, "familyResistance": e.get("familyResistances", {}).get(family, 0.0), "tags": a.definition.attackTags, "tagResistances": e.get("tagResistances", {}), "attackPhysicalReduction": a.physicalResistanceReduction, "enemyPhysicalReduction": e.get("physicalVulnerabilityBonus", 0.0) if float(e.get("physicalVulnerabilityRemaining", 0)) > 0 else 0.0, "enemyElementalReduction": e.get("elementalVulnerabilityBonus", 0.0) if float(e.get("elementalVulnerabilityRemaining", 0)) > 0 else 0.0}
	var status := a.duplicate()
	status.damageScale = scale
	var resolved := Attack.resolve({"baseDamage": float(a.damage) * float(a.criticalMultiplier) * scale, "traitMultiplier": trait_multiplier, "resistance": resistance, "status": status})
	for effect in resolved.effects:
		match effect.type:
			"slow": Enemy.add_slow(e, effect.multiplier, effect.duration)
			"elementalVulnerability": Enemy.add_vulnerability(e, "elemental", effect.bonus, effect.duration)
			"burn":
				effect.sourceX = source.x
				effect.sourceY = source.y
				Enemy.add_burn(e, effect)
	var transfer := Enemy.burn_transfer(e, source) if a.spreadsChainIgnition else {}
	var result: Dictionary = Enemy.apply_hit(e, {"damage": resolved.damage, "ignoreArmorReduction": a.ignoresArmorReduction, "burnTransfer": transfer})
	_visual("damage", _pos(e), t, {"text":str(roundi(float(result.get("actualDamage", 0)))), "duration":0.65})
	t[kind + "DamageDealt"] += float(result.get("actualDamage", 0))
	if float(result.get("bonusDamage", 0)) > 0:
		_emit({"kind":"coreBonusDamage","enemyId":e.id,"damage":result.bonusDamage})
	_collect(result.get("events", []))
	if burst > 0 and _alive(e):
		result = Enemy.apply_hit(e, {"damage": burst, "ignoreArmorReduction": a.ignoresArmorReduction, "burnTransfer": transfer})
		t.directDamageDealt += float(result.get("actualDamage", 0))
		if float(result.get("bonusDamage", 0)) > 0:
			_emit({"kind":"coreBonusDamage","enemyId":e.id,"damage":result.bonusDamage})
		_collect(result.get("events", []))

func _collect(items: Array) -> void:
	for raw in items:
		var event: Dictionary = raw.duplicate(true)
		var type: String = event.get("type", "")
		if type == "killed":
			event.kind = "kill"
			_spread_burn(event)
			for t in turrets.values():
				if float(t.recent.get(str(event.enemyId), 0)) > 0:
					t.cleanup = 3.0
		elif type == "coreArrival":
			event.kind = "arrival"
		else:
			event.effectKind = raw.get("kind", "")
			event.kind = type
			if type == "damage":
				event.damageKind = raw.get("kind", "burn")
				if float(raw.get("bonusDamage", 0)) > 0:
					_emit({"kind":"coreBonusDamage","enemyId":raw.enemyId,"damage":raw.bonusDamage})
				if raw.get("kind") == "burn":
					for t in turrets.values():
						if t.state.get("x") == raw.get("sourceX") and t.state.get("y") == raw.get("sourceY"):
							t.burnDamageDealt += float(raw.get("damage", 0))
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

func _emit(event: Dictionary) -> void:
	event_id += 1
	event.id = event_id
	events.append(event)

func snapshot() -> Dictionary:
	var enemy_states: Array = []
	for e in enemies.values():
		enemy_states.append(Enemy.snapshot(e))
	var turret_states: Array = []
	for t in turrets.values():
		var state := {"id": t.id}
		for key in ["cooldown", "aimAngle", "aimProgress", "aimTargetId", "shotSequence", "directDamageDealt", "splashDamageDealt", "chainDamageDealt", "burnDamageDealt"]:
			state[key] = t[key]
		turret_states.append(state)
	return {"accepted": true, "epoch": epoch, "ackSequence": sequence, "enemies": enemy_states, "turrets": turret_states, "events": events.duplicate(true), "clock": clock}

func decorate_frame(base: Dictionary) -> Dictionary:
	if not active:
		return base
	var frame := base.duplicate(true)
	var rows: Array = []
	var labels: Array = []
	for e in enemies.values():
		if not _alive(e): continue
		var logical := (_pos(e) - origin) / tile_size
		var p := logical + _visual_enemy_offset(e) / tile_size
		var burning: bool = not e.burnInstances.is_empty()
		var slowed: bool = not e.slowInstances.is_empty()
		var poisoned: bool = float(e.poisonRemaining) > 0
		var diamond: bool = int(e.get("diamondReward", 0)) > 0
		rows.append([e.id, p.x,p.y,e.facingAngle,e.visualPhase,e.get("presentationScale",_radius(e)*2.0/tile_size),e.hitFlashTimer,e.get("type","normal"),burning,slowed,poisoned,diamond,logical.x,logical.y])
		labels.append({"id":e.id,"position":[p.x,p.y],"size":e.get("presentationSize",[_radius(e)*2,_radius(e)*2]),"hp":e.hp,"maxHp":e.maxHp,"armor":e.armor,"maxArmor":e.maxArmor,"shield":e.shield,"maxShield":e.maxShield,"effectTime":e.statusEffectTime,"enemyCount":enemies.size(),"burning":burning,"slowed":slowed,"poisoned":poisoned,"riftMarked":e.riftMarkRemaining>0,"diamondCarrier":diamond})
	frame.enemies = rows
	frame.turrets = []
	for t in turrets.values():
		var p := (_vec(t.position)-origin)/tile_size
		frame.turrets.append([t.id,p.x,p.y,t.aimAngle,t.shotSequence,t.fireFeedback/0.18,t.statInput.definition.type,t.statInput.level])
	if frame.has("presentation"):
		if not frame.presentation.has("labels"): frame.presentation.labels = {}
		frame.presentation.labels.enemies = labels
		frame.presentation.labels.logicalTileSize = tile_size
	frame.erase("projectileEvents")
	frame.projectiles = []
	frame.impacts = []
	for v in visual_effects:
		if v.kind == "blast":
			frame.impacts.append([v.id,v.x,v.y,float(v.radius)/tile_size,clampf((clock-float(v.born))/float(v.duration),0,1)])
	for p in projectiles:
		var at: Vector2 = (p.position - origin) / tile_size
		var start: Vector2 = (p.origin - origin) / tile_size
		frame.projectiles.append([p.id, at.x, at.y, p.direction.x, p.direction.y, p.attack.definition.type, start.x, start.y, int(p.owner), p.shot, p.chained, -1, null, null])
	if frame.has("presentation") and frame.presentation.has("effects"):
		var effects: Dictionary = frame.presentation.effects
		var items: Array = effects.get("items", []).duplicate(true)
		for v in visual_effects:
			var item: Dictionary = v.duplicate(true)
			item.age = clock - float(v.born)
			items.append(item)
		effects.items = items
	return frame

func _visual(kind: String, at: Vector2, t: Dictionary, extra: Dictionary = {}) -> void:
	visual_id += 1
	var pos := (at - origin) / tile_size
	var colors := {"arrow":0xffffdf9e, "cannon":0xffffb066, "magic":0xffff713d, "frost":0xff94e6ff, "sniper":0xffffeec4, "lightning":0xffc7d8ff}
	var v := {"id":visual_id, "kind":kind, "born":clock, "duration":0.28, "x":pos.x, "y":pos.y, "tileSize":tile_size, "scale":board_scale, "color":colors.get(t.statInput.definition.type, 0xffffffff), "points":[], "screenOffset":[0,0], "feedback":"neutral", "motion":"rise", "arcDirection":1}
	v.merge(extra, true)
	var points: Array = []
	for point in v.points:
		var p := (_vec(point) - origin) / tile_size
		points.append([p.x,p.y])
	v.points = points
	visual_effects.append(v)

func _visual_enemy_offset(e: Dictionary) -> Vector2:
	var lane: float = e.get("laneOffsetRatio", 0.0)
	if lane == 0 or e.path.size() < 2: return Vector2.ZERO
	var distance: float = e.distanceTravelled
	var sample := 48.0 * board_scale * 0.4
	var before := _point_at(e.path, distance - sample)
	var after := _point_at(e.path, distance + sample)
	var tangent := after - before
	if tangent.length_squared() <= 0.001: return Vector2.ZERO
	var total := 0.0
	for index in range(1,e.path.size()): total += _vec(e.path[index]).distance_to(_vec(e.path[index-1]))
	var fade := clampf(minf(distance,total-distance)/(48.0*board_scale*0.55),0,1)
	return Vector2(-tangent.y,tangent.x).normalized()*lane*48.0*board_scale*fade

func _point_at(points: Array, distance: float) -> Vector2:
	var left := maxf(0,distance)
	for index in range(1,points.size()):
		var from := _vec(points[index-1])
		var to := _vec(points[index])
		var length := from.distance_to(to)
		if length > 0 and left <= length: return from.lerp(to,left/length)
		left -= length
	return _vec(points[-1])

func _alive(e: Dictionary) -> bool:
	return float(e.get("hp", 0)) > 0 and not e.get("arrived", false) and not e.get("isDead", false)
func _target_radius(e: Dictionary) -> float:
	return float(e.get("targetingRadius", float(e.get("presentationSize", [_radius(e)*2])[0])*0.5))
func _radius(e: Dictionary) -> float:
	return float(e.get("collisionRadius", e.get("radius", 8.0)))
func _durability(e: Dictionary) -> float:
	return float(e.get("hp", 0)) + maxf(0, e.get("armor", 0)) + maxf(0, e.get("shield", 0))
func _pos(e: Dictionary) -> Vector2:
	return Vector2(float(e.get("x", 0)), float(e.get("y", 0)))
func _vec(raw) -> Vector2:
	if raw is Vector2:
		return raw
	if raw is Array:
		return Vector2(float(raw[0]), float(raw[1])) if raw.size() >= 2 else Vector2.ZERO
	return Vector2(float(raw.get("x", 0)), float(raw.get("y", 0)))
