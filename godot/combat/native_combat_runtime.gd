extends RefCounted
## Persistent combat authority. Commands, simulation time and events are ACKed once.
const Enemy = preload("res://combat/native_enemy_state.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Wave = preload("res://combat/native_wave_state.gd")
const Defense = preload("res://combat/native_core_defense_state.gd")
const CoreSkill = preload("res://combat/native_core_skill_state.gd")
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
var damage_number_index: int = 0
var event_id: int = 0
var projectile_id: int = 0
var clock: float = 0.0
var path: Array = []
var origin := Vector2.ZERO
var tile_size: float = 1.0
var board_scale: float = 1.0
var rng := RandomNumberGenerator.new()
var wave = Wave.new()
var core = CoreSkill.new()
var defense = Defense.new()
var wave_configured: bool = false
var terminal: bool = false
var pending_steps: Array = []
# Only the session clock may advance production combat. Legacy step packets are
# retained for deterministic regression fixtures, never mixed with this clock.
var session: Dictionary = {}
var state_revision: int = 0
var wall_elapsed: float = 0.0
var effect_time: float = 0.0
var effect_squared: float = 0.0
var destruction_elapsed: float = 0.0
var nexus_alert: float = 0.0
var portal_alert: float = 0.0

func native_session() -> bool:
	return session.get("clock", "") == "godot"

func advance_session(delta: float, host_active: bool = true) -> bool:
	if not active or not native_session() or not host_active or delta <= 0:
		return false
	if bool(session.get("paused", false)) or bool(session.get("loading", false)) or bool(session.get("backgrounded", false)):
		return false
	var phase: String = session.get("phase", "preparation")
	if phase in ["ended", "failure", "failed", "success", "restored"]:
		return false
	# No catch-up after suspension; the same variable timestep used by the old
	# host is delivered once, scaled here and nowhere else.
	nexus_alert = maxf(0, nexus_alert-delta)
	portal_alert = maxf(0, portal_alert-delta)
	wall_elapsed += delta
	if terminal and defense.failed and phase != "coreDestruction":
		phase = "coreDestruction"
		session.phase = phase
	if phase == "coreDestruction":
		destruction_elapsed = minf(3.2, destruction_elapsed + delta)
		effect_time += delta * 0.25
		effect_squared += pow(delta*0.25,2)
		clock += delta * 0.25
		if destruction_elapsed >= 3.2: session.phase = "failure"
	elif phase != "reward":
		var dt := delta * clampf(float(session.get("speed", 1.0)), 0.1, 4.0)
		effect_time += dt
		effect_squared += dt*dt
		running = bool(session.get("running", phase in ["wave", "running"])) and not (wave_configured and wave.completed)
		if not terminal: _step(dt)
		if terminal and defense.failed: session.phase = "coreDestruction"
	state_revision += 1
	return true

func submit_input(event: Dictionary) -> void:
	if not active or not native_session(): return
	_emit(event)
	state_revision += 1

func session_snapshot() -> Dictionary:
	var result := session.duplicate(true)
	result.merge({"wallElapsed": wall_elapsed, "effectTime": effect_time,"squaredSteps":effect_squared,
		"coreDestructionElapsed": destruction_elapsed,"nexusAlert":nexus_alert/0.65}, true)
	return result

func process_command(packet: Dictionary) -> Dictionary:
	if int(packet.get("epoch", -1)) < epoch:
		return {"accepted":false,"reason":"staleEpoch","epoch":epoch,"ackSequence":sequence}
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
	if packet.get("session") is Dictionary:
		var incoming: Dictionary = packet.session.duplicate(true)
		# A delayed host phase must not roll back a native terminal transition.
		if native_session() and defense.failed and session.get("phase") in ["coreDestruction", "failure"]:
			incoming.erase("phase")
		session.merge(incoming, true)
		pending_steps.clear()
	running = bool(packet.get("running", running))
	for command in packet.get("commands", []):
		_command(command)
	if native_session():
		pass
	elif packet.has("steps"):
		pending_steps.append_array(packet.steps.duplicate(true))
	elif packet.has("dtSteps"):
		for dt in packet.dtSteps:
			pending_steps.append({"dt":dt,"running":running})
	elif float(packet.get("dt", 0)) > 0:
		pending_steps.append({"dt":packet.dt,"running":running})
	_drain_steps()
	sequence = int(packet.sequence)
	state_revision += 1
	return snapshot()

func _reset(packet: Dictionary) -> void:
	epoch = int(packet.epoch)
	session = {}
	state_revision = 0
	wall_elapsed = 0.0
	effect_time = float(packet.get("session", {}).get("effectTime", 0.0))
	effect_squared = float(packet.get("session", {}).get("squaredSteps", 0.0))
	destruction_elapsed = 0.0
	nexus_alert = 0.0
	portal_alert = 0.0
	active = true
	wave = Wave.new()
	core = CoreSkill.new()
	defense = Defense.new()
	wave_configured = false
	terminal = false
	pending_steps.clear()
	sequence = -1
	enemies.clear()
	turrets.clear()
	projectiles.clear()
	delayed.clear()
	events.clear()
	visual_effects.clear()
	event_id = 0
	clock = 0
	damage_number_index = 0
	var b: Dictionary = packet.bootstrap
	rng.seed = int(b.get("seed", 71423))
	path = _path(b.get("path", []))
	origin = _vec(b.get("origin", [0, 0]))
	tile_size = maxf(0.001, b.get("tileSize", 1.0))
	board_scale = b.get("boardDistanceScale", 1.0)
	for e in b.get("enemies", []):
		_spawn(e)
	if b.has("coreConfig"):
		core.configure(b.coreConfig,b.get("core",b.coreConfig.get("state",{})))
	if b.has("defense"):
		defense.configure(b.defense.get("config",{}),b.defense.get("state",{}))
		core.emergency_charge_used_this_round = defense.emergency_charge_used_this_round
		terminal = defense.failed
	if b.has("wave"):
		_start_wave(b.wave, false)
	if defense.configured:
		core.emergency_charge_used_this_round = defense.emergency_charge_used_this_round
	for t in b.get("turrets", []):
		_turret(t)

func _start_wave(raw: Dictionary, reset_core: bool) -> void:
	if defense.configured and defense.failed: return
	wave_configured = true
	wave.start(raw)
	if wave.active:
		portal_alert = 0.55
		_emit({"kind":"waveStarted","waveId":wave.id})
	terminal = false
	if raw.has("coreConfig"):
		core.configure(raw.coreConfig,raw.get("core",{}))
	elif raw.has("core"):
		core.restore_state(raw.core)
	elif reset_core:
		core.reset_cycle()
	if reset_core and defense.configured:
		defense.reset_round()
		core.emergency_charge_used_this_round = false
	_refresh_turret_stats()

func _drain_steps() -> void:
	if terminal:
		pending_steps.clear()
		return
	while not pending_steps.is_empty() and not terminal:
		var step: Dictionary = pending_steps.pop_front()
		for command in step.get("commands",[]): _command(command)
		running = bool(step.get("running",running)) and not (wave_configured and wave.completed)
		var dt := float(step.get("dt",0))
		if dt > 0: _step(dt)
		if terminal:
			pending_steps.clear()
			break
		for command in step.get("commandsAfter",[]): _command(command)

func _apply_sync(t: Dictionary) -> void:
	if not core.configured: return
	var sync: bool = core.attack_sync_remaining > 0
	t.statInput.corePassiveTurretDamageMultiplier = float(core.config.get("attackSyncDamageMultiplier",1.0)) if sync else 1.0
	t.statInput.corePassiveTurretAttackRateMultiplier = float(core.config.get("attackSyncAttackRateMultiplier",1.0)) if sync else 1.0

func _refresh_turret_stats() -> void:
	if not core.configured: return
	for t in turrets.values():
		var old_damage: float = t.statInput.corePassiveTurretDamageMultiplier
		var old_rate: float = t.statInput.corePassiveTurretAttackRateMultiplier
		_apply_sync(t)
		if old_damage != float(t.statInput.corePassiveTurretDamageMultiplier) or old_rate != float(t.statInput.corePassiveTurretAttackRateMultiplier):
			t.stats = Stats.stats_at(t.statInput,int(t.statInput.level))

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
		var projectile: bool = not definition.instantHit and not definition.centeredAreaAttack and definition.type != "lightning"
		var rate: float = stats.attackRate / (1.4 if t.statInput.chainCleanupActive else 1.0) * (1.4 if t.cleanup>0 else 1.0)
		dps += float(stats.damage)*maxf(0,rate)*(int(stats.projectileCount) if projectile else 1)
		if "damageOverTime" in definition.attackTags:
			dps += float(stats.damage)*0.5*float(stats.damageOverTimeDamageMultiplier)
	return maxf(float(core.config.get("normalMaxHp",0))*float(core.config.get("guardianMinNormalHpRate",0.1)),dps*float(core.config.get("guardianBeamInterval",5))*float(core.config.get("guardianDpsRate",0.08)))

func _boss(e: Dictionary) -> bool:
	return bool(e.get("isBoss",false)) or e.get("type","") in ["boss","shieldBoss","forgeBoss"]

func _core_beam_tick(tick_damage: float) -> void:
	var target: Dictionary = {}
	var progress := -INF
	for e in enemies.values():
		if _alive(e) and float(e.distanceTravelled)>progress:
			target = e
			progress = float(e.distanceTravelled)
	if target.is_empty(): return
	var cap: float = core.config.get("bossHpCapRate",0.025) if _boss(target) else core.config.get("enemyHpCapRate",0.35)
	cap *= float(target.maxHp)*float(core.config.get("guardianBeamTickInterval",0.1))/float(core.config.get("guardianBeamDuration",1.0))
	var damage := minf(tick_damage,cap)
	if damage <= 0: return
	target.hitFlashTimer = 0.1
	var result: Dictionary = Enemy.apply_hit(target,{"damage":damage})
	_collect(result.events)
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
		return float(a.distanceTravelled)>float(b.distanceTravelled) if durability_a == durability_b else durability_a>durability_b)
	candidates = candidates.slice(0,int(core.config.get("riftMarkTargetCount",4)))
	for target in candidates:
		var amp: float = core.config.get("riftMarkBossDamageAmplification",0.125) if _boss(target) else core.config.get("riftMarkDamageAmplification",0.25)
		Enemy.add_rift_mark(target,amp*power,float(core.config.get("riftMarkDuration",5.0)))
		target.hitFlashTimer = 0.1
	_core_visual("rift",candidates,0xffcfa7ff)

func _core_visual(kind: String, targets: Array, color: int) -> void:
	if targets.is_empty(): return
	visual_id += 1
	var start := (_vec(path[-1]) - origin)/tile_size if not path.is_empty() else Vector2.ZERO
	var points: Array = [[start.x,start.y]] if kind == "coreBeam" else []
	var ids: Array = []
	for target in targets:
		var p := (_pos(target)-origin)/tile_size
		points.append([p.x,p.y])
		ids.append(target.id)
	visual_effects.append({"id":visual_id,"kind":kind,"born":clock,"duration":0.14 if kind == "coreBeam" else 0.42,"x":start.x,"y":start.y,"tileSize":tile_size,"scale":board_scale,"color":color,"points":points,"targetIds":ids,"screenOffset":[0,0]})

func _core_damage_number(target: Dictionary, damage: float) -> void:
	var at := _pos(target)
	var source := _vec(path[-1]) if not path.is_empty() else origin
	var direction := source-at
	if direction.length_squared()>0.001:
		direction = direction.normalized()
		at += Vector2(direction.x*14.0,direction.y*6.0-10.0)*board_scale
	else:
		at.y -= 10.0*board_scale
	var angle := -PI*0.82+float(damage_number_index%7)*PI*0.27
	damage_number_index += 1
	at += Vector2.from_angle(angle)*8.0*board_scale
	at = (at-origin)/tile_size
	visual_id += 1
	visual_effects.append({"id":visual_id,"kind":"damage","born":clock,"duration":0.75,"x":at.x,"y":at.y,"tileSize":tile_size,"scale":board_scale,"color":0xff8ee6ff,"text":str(roundi(damage)),"feedback":"neutral","motion":"rise","arcDirection":1,"points":[],"screenOffset":[0,0]})

func _nexus_health_number(change: float) -> void:
	visual_id += 1
	var at := (_vec(path[-1])-origin)/tile_size if not path.is_empty() else Vector2.ZERO
	var value := ("+" if change>0 else "-")+String.num(absf(change),1)
	visual_effects.append({"id":visual_id,"kind":"damage","born":clock,"duration":0.75,"x":at.x,"y":at.y,"tileSize":tile_size,"scale":board_scale,"color":0xff72e0a2 if change>0 else 0xffff7043,"text":value,"feedback":"neutral","motion":"rise","arcDirection":1,"points":[],"screenOffset":[0,0]})

func _check_native_wave_complete() -> void:
	if terminal: return
	if wave.finish_if_empty(_has_core_target()):
		var recovery: float = defense.recover_round()
		if recovery>0:
			_nexus_health_number(recovery)
			_emit({"kind":"coreRecovered","amount":recovery})
		running = false
		core.reset_cycle()
		_refresh_turret_stats()
		_emit({"kind":"waveCompleted","waveId":wave.id})

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
	_apply_sync(t)
	t.stats = Stats.stats_at(t.statInput, int(t.statInput.level))
	turrets[id] = t

func _command(c: Dictionary) -> void:
	match c.get("kind", ""):
		"waveStart":
			_start_wave(c.wave, true)
		"coreConfig":
			core.configure(c.config,c.get("state",{}))
			_refresh_turret_stats()
		"resetCoreCycle":
			core.reset_cycle()
			_refresh_turret_stats()
		"emergencyCharge":
			core.emergency_charge(float(c.get("recoveryRate",0)))
		"defenseConfig":
			defense.configure(c.config)
		"defenseRestore":
			defense.restore(c.state)
			core.emergency_charge_used_this_round = defense.emergency_charge_used_this_round
			terminal = defense.failed
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
			for index in range(wave.next_index,wave.queue.size()):
				var prepared: Dictionary = wave.queue[index].get("enemy",{})
				if prepared.is_empty(): continue
				var at := (_pos(prepared)-old_origin)*ratio+origin
				prepared.x = at.x
				prepared.y = at.y
				prepared.position = {"x":at.x,"y":at.y}
				prepared.path = path.duplicate(true)
				prepared.boardDistanceScale = board_scale
				for key in ["collisionRadius","targetingRadius"]:
					if prepared.has(key): prepared[key] *= ratio
				if prepared.has("presentationSize"):
					prepared.presentationSize = [prepared.presentationSize[0]*ratio,prepared.presentationSize[1]*ratio]
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
			if terminal: return
	_finish_step(dt)

func _finish_step(dt: float) -> void:
	if terminal: return
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
	if running:
		for request in wave.advance(dt):
			_spawn(request.enemy)
		core.update(dt, _has_core_target, _core_base_damage, _core_beam_tick, _core_rift_mark)
		_refresh_turret_stats()
		_check_native_wave_complete()

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
	_visual("chain", from, t, {"points":[[from.x,from.y],[_pos(target).x, _pos(target).y]], "targetIds":[-1,target.id]})
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
				_emit({"kind":"coreDefeated","enemyId":event.enemyId})
			continue
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
	if core.configured and event.kind == "coreBonusDamage":
		core.bonus_damage_dealt += float(event.get("damage",0))
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
	var wave_state: Dictionary = wave.snapshot()
	return {"stateRevision":state_revision,"session":session_snapshot(),"defense":defense.snapshot(),"wave":wave_state,"core":core.snapshot(),"accepted": true, "epoch": epoch, "ackSequence": sequence, "enemies": enemy_states, "turrets": turret_states, "events": events.duplicate(true), "clock": clock}

func decorate_frame(base: Dictionary) -> Dictionary:
	if not active:
		return base
	var frame := base.duplicate(true)
	if native_session():
		frame.time = effect_time
		frame.nexusHit = nexus_alert/0.65
		frame.portalAlert = portal_alert/0.55
		if frame.get("presentation") is Dictionary:
			for group in ["effects", "selection"]:
				if frame.presentation.get(group) is Dictionary:
					frame.presentation[group].clock = effect_time
					frame.presentation[group].time = effect_time
			if frame.presentation.get("selection") is Dictionary:
				var aims: Array = []
				for t in turrets.values():
					var target: Dictionary = enemies.get(str(t.aimTargetId), {})
					if not target.is_empty():
						var point := (_pos(target)-origin)/tile_size
						aims.append([t.id,point.x,point.y,t.aimProgress])
				frame.presentation.selection.aim = aims
			if frame.presentation.get("effects") is Dictionary:
				# Dart's last sampled shake must never become a permanent offset.
				var shake := sin(destruction_elapsed*78)*(1.0-destruction_elapsed/3.2)*3.4*board_scale if destruction_elapsed>0 else 0.0
				frame.presentation.effects.shake = [shake,-shake*0.45]
				frame.presentation.effects.squaredSteps = effect_squared
	if defense.configured:
		frame.nexusHpRatio = defense.hp/maxf(0.000001,defense.max_hp)
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
		if native_session():
			frame.presentation.labels.core = null
			if session.get("phase") == "wave" and core.configured and core.skill != null and not path.is_empty():
				var center := (_vec(path[-1])-origin)/tile_size
				var progress := 1.0 if core.guardian_beam_active_remaining>0 else clampf(1.0-core.cooldown/maxf(0.000001,core.interval()),0,1)
				frame.presentation.labels.core = {"position":[center.x,center.y],"progress":progress,"accent":0xffcfa7ff if core.skill == "riftMark" else 0xff8ee6ff,"active":core.guardian_beam_active_remaining>0}
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
			if item.kind == "damage":
				item.screenOffset = [0,-34.0*float(item.age)]
			elif item.kind == "chain":
				var linked: Dictionary = enemies.get(str(item.targetIds[-1]),{})
				if not linked.is_empty() and _alive(linked):
					var end := (_pos(linked)-origin)/tile_size
					item.points[-1] = [end.x,end.y]
					v.points[-1] = [end.x,end.y]
			elif item.kind == "coreBeam":
				var linked: Dictionary = enemies.get(str(item.targetIds[0]),{})
				if not linked.is_empty() and _alive(linked):
					var end := (_pos(linked)-origin)/tile_size
					item.points[1] = [end.x,end.y]
					v.points[1] = [end.x,end.y]
			elif item.kind == "rift":
				item.points = []
				for id in item.targetIds:
					var linked: Dictionary = enemies.get(str(id),{})
					if not linked.is_empty() and _alive(linked):
						var end := (_pos(linked)-origin)/tile_size
						item.points.append([end.x,end.y])
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
