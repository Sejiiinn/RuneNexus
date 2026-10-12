extends RefCounted
## Persistent combat authority. Commands, simulation time and events are ACKed once.
const Teleports = preload("res://combat/teleport_pairs.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Wave = preload("res://combat/native_wave_state.gd")
const Defense = preload("res://combat/native_core_defense_state.gd")
const CoreSkill = preload("res://combat/native_core_skill_state.gd")
const Attack = preload("res://combat/attack_calculation.gd")
const EffectFormat = preload("res://combat/effect_presentation.gd")
const FrameRows = preload("res://presentation/frame_rows.gd")
# Match the authored 1.1-second cannon impact; generic hits last only 0.28s.
const BLAST_DURATION: float = 1.1
const PROJECTILE_RADII: Dictionary = {"arrow":3.5, "cannon":7.0, "magic":4.0}
# Extend fired shots without changing turret or chain target acquisition ranges.
const PROJECTILE_TRAVEL_MULTIPLIER: float = 3.0
# Game seconds, independent of render cadence and playback speed. Keep the
# existing 60 Hz integrators (including their cooldown/waypoint overshoot rules).
const FIXED_STEP: float = 1.0 / 60.0
## Canvas artwork is authored for 48-pixel tiles (bars, glyphs, line widths).
const LOGICAL_CANVAS_TILE := 48.0
const MAX_STEPS_PER_FRAME: int = 64
const STEP_EPSILON: float = 1.0e-10
# Emitted only after a complete step. Application events/commands may be settled
# synchronously here, before another step consumes debt in this render frame.
signal step_completed
# Host wall-clock boundaries accrue at the old controls without advancing the
# simulation. Bootstrap, stale packets and duplicate ACKs never emit these.
signal clock_control_changing
signal clock_control_changed
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
# ACK retires gameplay records before render. Keep only immutable death display
# data until the next presentation observation; never include it in saves.
var _presentation_deaths: Array = []
var visual_effects: Array = []
# Canonical static payloads are immutable; raw journal units stay compatible
# with public frames, 3D impacts and development sessions.
var _prepared_effects: Dictionary = {}
# Internal presentation frames reuse one row object per actor id; rows are
# rewritten in full each frame. Public snapshots always receive fresh rows.
var _frame_row_pool := {"enemies": {}, "turrets": {}, "projectiles": {}, "impacts": {}, "labels": {}}
# Step-local target candidates: [enemy, position, target radius, progress, id].
# Valid only from the end of movement until spawns, while positions and
# membership are fixed; alive state and durability are still read live.
var _target_candidates: Array = []
var _target_candidates_ready := false
# [min x, min y, max x, max y, max target radius] of the shared candidates.
var _target_bounds: Array = []
var visual_id: int = 1000000000
var damage_number_index: int = 0
var event_id: int = 0
var projectile_id: int = 0
var clock: float = 0.0
var simulation_tick: int = 0
var simulation_debt: float = 0.0
var clock_control_revision: int = 0
var _advancing_session: bool = false
var path: Array = []
var teleport_pairs: Array = []
var routes: Dictionary = {}
var spawn_portal_id := ""
var _path_revision := 0
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

func _session_time_enabled() -> bool:
	return active and native_session() and not bool(session.get("paused", false)) \
		and not bool(session.get("loading", false)) and not bool(session.get("backgrounded", false)) \
		and session.get("phase", "preparation") not in ["ended", "failure", "failed", "success", "restored"]

func _session_clock_gate() -> String:
	if not _session_time_enabled(): return "stopped"
	return "reward" if session.get("phase") == "reward" else "active"

func accrue_session_time(delta: float, host_active: bool = true) -> bool:
	if not host_active or not is_finite(delta) or delta <= 0 or not _session_time_enabled(): return false
	var phase: String = session.get("phase", "preparation")
	# Called by the render clock and before a host control change. This path may
	# only accrue time; it must never run combat or recursively collect/ACK events.
	nexus_alert = maxf(0, nexus_alert-delta)
	portal_alert = maxf(0, portal_alert-delta)
	wall_elapsed += delta
	if terminal and defense.failed and phase != "coreDestruction":
		phase = "coreDestruction"
		session.phase = phase
	if phase == "coreDestruction":
		# Collapse is a real-time presentation timer, not combat debt.
		destruction_elapsed = minf(3.2, destruction_elapsed + delta)
		effect_time += delta * 0.25
		effect_squared += pow(delta*0.25,2)
		clock += delta * 0.25
		if destruction_elapsed >= 3.2: session.phase = "failure"
	elif phase != "reward" and not terminal:
		simulation_debt += delta * clampf(float(session.get("speed", 1.0)), 0.1, 4.0)
	state_revision += 1
	return true

func advance_session(delta: float, host_active: bool = true) -> bool:
	if _advancing_session or not host_active or not is_finite(delta) or delta < 0 or not _session_time_enabled():
		return false
	var accrued := accrue_session_time(delta, host_active)
	var steps := 0
	var frame_epoch := epoch
	_advancing_session = true
	while simulation_debt + STEP_EPSILON >= FIXED_STEP and steps < MAX_STEPS_PER_FRAME:
		if not _session_time_enabled() or terminal or session.get("phase") in ["reward", "coreDestruction"]: break
		# A tiny negative remainder is floating-point subtraction noise only;
		# overload never clamps or drops legitimately earned game time.
		simulation_debt = maxf(0.0, simulation_debt - FIXED_STEP)
		simulation_tick += 1
		steps += 1
		effect_time += FIXED_STEP
		effect_squared += FIXED_STEP * FIXED_STEP
		var phase: String = session.get("phase", "preparation")
		running = bool(session.get("running", phase in ["wave", "running"])) and not (wave_configured and wave.completed)
		_step(FIXED_STEP)
		if terminal and defense.failed: session.phase = "coreDestruction"
		state_revision += 1
		step_completed.emit()
		# New bootstrap/load/retry explicitly begins a new clock. Never let an
		# old render's work continue in its replacement epoch.
		if epoch != frame_epoch: break
	_advancing_session = false
	return accrued or steps > 0

func submit_input(event: Dictionary) -> void:
	if not active or not native_session(): return
	_emit(event)
	state_revision += 1

func session_snapshot() -> Dictionary:
	var result := session.duplicate(true)
	result.merge({"wallElapsed": wall_elapsed, "effectTime": effect_time,"squaredSteps":effect_squared,
		"simulationTick":simulation_tick,"simulationDebt":simulation_debt,
		"coreDestructionElapsed": destruction_elapsed,"nexusAlert":nexus_alert/0.65}, true)
	return result

# Local application commands only need an ACK; host callers retain full snapshots.
func _changes_clock_controls(incoming: Dictionary) -> bool:
	for key in ["clock", "phase", "paused", "loading", "backgrounded", "speed"]:
		if incoming.has(key) and incoming[key] != session.get(key): return true
	return false

## Starts a new combat generation (stage entry, retry, restore) for the session
## that owns this runtime. Returns "" when accepted, otherwise the reason.
func start(new_epoch: int, bootstrap: Dictionary, session_state: Dictionary) -> String:
	var result := process_command({"epoch": new_epoch, "sequence": 0, "session": session_state, "bootstrap": bootstrap})
	return "" if result.get("accepted", false) else str(result.get("reason", "rejected"))

## Applies one in-process batch for the current generation, in order:
## acknowledged events (up to ack_event), the session patch, then commands.
## Returns "" when applied, otherwise the rejection reason (e.g. staleEpoch).
func apply_batch(batch_epoch: int, commands: Array, session_patch: Dictionary, ack_event: int) -> String:
	var result := process_command({"epoch": batch_epoch, "sequence": sequence + 1, "commands": commands, "session": session_patch, "ackEvent": ack_event}, false)
	return "" if result.get("accepted", false) else str(result.get("reason", "rejected"))

## Message-protocol adapter (epoch, sequence, ackEvent, optional host steps)
## retained for fixtures, previews and protocol regression checks. The session
## uses start() and apply_batch().
func process_command(packet: Dictionary, include_snapshot: bool = true) -> Dictionary:
	var same_native_epoch: bool = native_session() and int(packet.get("epoch", -1)) == epoch
	var previous_clock_gate := _session_clock_gate()
	if int(packet.get("epoch", -1)) < epoch:
		return {"accepted":false,"reason":"staleEpoch","epoch":epoch,"ackSequence":sequence}
	if epoch != packet.get("epoch"):
		if not packet.has("bootstrap"):
			return {"accepted": false, "reason": "bootstrapRequired", "epoch": packet.get("epoch"), "ackSequence": -1}
		var teleport_error := Teleports.validate_compiled(packet.bootstrap.get("teleportPairs",[]),packet.bootstrap.get("path",[]))
		if not teleport_error.is_empty():
			return {"accepted":false,"reason":"invalidTeleportPairs","detail":teleport_error}
		var route_error := _validate_routes(packet.bootstrap)
		if not route_error.is_empty(): return {"accepted":false,"reason":"invalidRoutes","detail":route_error}
		_reset(packet)
	if int(packet.get("sequence", -1)) <= sequence:
		return snapshot() if include_snapshot else {"accepted":true,"epoch":epoch,"ackSequence":sequence}
	if sequence >= 0 and int(packet.sequence) != sequence + 1:
		return {"accepted": false, "reason": "sequenceGap", "epoch": epoch, "ackSequence": sequence}
	for command in packet.get("commands",[]):
		var route_error := _validate_command_routes(command)
		if not route_error.is_empty(): return {"accepted":false,"reason":"invalidRoutes","detail":route_error}
		if command.get("kind") == "layout":
			var teleport_error := Teleports.validate_compiled(teleport_pairs,command.get("path",path))
			if not teleport_error.is_empty():
				return {"accepted":false,"reason":"invalidTeleportPairs","detail":teleport_error}
	var clock_change: bool = same_native_epoch and packet.get("session") is Dictionary and _changes_clock_controls(packet.session)
	if clock_change: clock_control_changing.emit()
	var ack_event := int(packet.get("ackEvent", 0))
	for event in events:
		if int(event.id) <= ack_event and event.kind in ["kill","arrival"]:
			if event.kind == "kill": _retain_death_presentation(event)
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
	if _session_clock_gate() != previous_clock_gate: clock_control_revision += 1
	sequence = int(packet.sequence)
	state_revision += 1
	if clock_change: clock_control_changed.emit()
	return snapshot() if include_snapshot else {"accepted":true,"epoch":epoch,"ackSequence":sequence}

func _reset(packet: Dictionary) -> void:
	epoch = int(packet.epoch)
	session = {}
	state_revision = 0
	wall_elapsed = 0.0
	# Runtime-only scheduler state is intentionally not added to the v2 save.
	# Checkpoint restore starts paused at its last simulated state, without old debt.
	simulation_tick = 0
	simulation_debt = 0.0
	clock_control_revision = 0
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
	_presentation_deaths.clear()
	visual_effects.clear()
	_prepared_effects.clear()
	_frame_row_pool = {"enemies": {}, "turrets": {}, "projectiles": {}, "impacts": {}, "labels": {}}
	event_id = 0
	clock = 0
	damage_number_index = 0
	var b: Dictionary = packet.bootstrap
	rng.seed = int(b.get("seed", 71423))
	path = _path(b.get("path", []))
	teleport_pairs = b.get("teleportPairs",[]).duplicate(true)
	spawn_portal_id = b.get("spawnPortalId", "")
	routes.clear()
	for route in b.get("routes", []):
		routes[route.id] = {"path":_path(route.path),"teleportPairs":route.get("teleportPairs",[]).duplicate(true),"spawnPortalId":route.get("spawnPortalId","")}
	_path_revision += 1
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
		var projectile: bool = not definition.instantHit and not definition.centeredAreaAttack and definition.type != "lightning"
		var rate: float = stats.attackRate / (1.4 if t.statInput.chainCleanupActive else 1.0) * (1.4 if t.cleanup>0 else 1.0)
		dps += float(stats.damage)*maxf(0,rate)*(int(stats.projectileCount) if projectile else 1)
		if "damageOverTime" in definition.attackTags:
			dps += float(stats.damage)*0.5*float(stats.damageOverTimeDamageMultiplier)
	return maxf(float(core.config.get("normalMaxHp",0))*float(core.config.get("guardianMinNormalHpRate",0.1)),dps*float(core.config.get("guardianBeamInterval",5))*float(core.config.get("guardianDpsRate",0.08)))

func _boss(e: Dictionary) -> bool:
	return bool(e.get("isBoss",false)) or e.get("type","") in ["boss","shieldBoss","forgeBoss"]

# Larger score means nearer the core. Subtracting each route's own length
# preserves every same-path ordering/tie while comparing unequal routes fairly.
func _progress_score(enemy: Dictionary) -> float:
	return float(enemy.get("distanceTravelled",0.0)) - float(enemy.get("_total",0.0))

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
		return _progress_score(a)>_progress_score(b) if durability_a == durability_b else durability_a>durability_b)
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
	_append_visual({"id":visual_id,"kind":kind,"born":clock,"duration":0.14 if kind == "coreBeam" else 0.42,"x":start.x,"y":start.y,"tileSize":tile_size,"scale":board_scale,"color":color,"points":points,"targetIds":ids,"screenOffset":[0,0]})

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
	_append_visual({"id":visual_id,"kind":"damage","born":clock,"duration":0.75,"x":at.x,"y":at.y,"tileSize":tile_size,"scale":board_scale,"color":0xff8ee6ff,"text":str(roundi(damage)),"feedback":"neutral","motion":"rise","arcDirection":1,"points":[],"screenOffset":[0,0]})

func _nexus_health_number(change: float) -> void:
	visual_id += 1
	var at := (_vec(path[-1])-origin)/tile_size if not path.is_empty() else Vector2.ZERO
	var value := ("+" if change>0 else "-")+String.num(absf(change),1)
	_append_visual({"id":visual_id,"kind":"damage","born":clock,"duration":0.75,"x":at.x,"y":at.y,"tileSize":tile_size,"scale":board_scale,"color":0xff72e0a2 if change>0 else 0xffff7043,"text":value,"feedback":"neutral","motion":"rise","arcDirection":1,"points":[],"screenOffset":[0,0]})

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

func _validate_routes(b: Dictionary) -> String:
	if b.has("spawnPortalId") and (not b.spawnPortalId is String or b.spawnPortalId.is_empty()): return "Invalid default spawn portal ID"
	if not b.get("routes", []) is Array: return "Routes must be an array"
	var ids := {}
	for route in b.get("routes", []):
		if not route is Dictionary or not route.get("id") is String or route.id.is_empty() or ids.has(route.id): return "Invalid/duplicate route ID"
		if route.has("spawnPortalId") and (not route.spawnPortalId is String or route.spawnPortalId.is_empty()): return "Invalid route spawn portal ID"
		if not route.get("path") is Array or route.path.size() < 2: return "Invalid route path"
		for point in route.path:
			if not ((point is Array and point.size() == 2) or (point is Dictionary and point.has_all(["x","y"]))): return "Invalid route point"
			var x: Variant = point[0] if point is Array else point.x
			var y: Variant = point[1] if point is Array else point.y
			if not (x is float or x is int) or not (y is float or y is int): return "Invalid route coordinates"
			var p := _vec(point)
			if not p.is_finite(): return "Non-finite route point"
		var problem := Teleports.validate_compiled(route.get("teleportPairs", []),route.path)
		if not problem.is_empty(): return problem
		ids[route.id] = true
	for enemy in b.get("enemies", []):
		var problem := _validate_spawn_route({"enemy":enemy},ids)
		if not problem.is_empty(): return problem
		problem = Teleports.validate_compiled(enemy.get("teleportPairs", []),enemy.get("path",b.get("path", [])))
		if not problem.is_empty(): return problem
	for request in b.get("wave", {}).get("spawnQueue", []):
		var problem := _validate_spawn_route(request,ids)
		if not problem.is_empty(): return problem
	return ""

func _validate_spawn_route(request: Dictionary, known_routes: Dictionary) -> String:
	# A request may carry route identity without duplicating it in its prepared
	# enemy. Validate every supplied copy before Wave.start normalizes them.
	var enemy_value: Variant = request.get("enemy",{})
	if not enemy_value is Dictionary: return "Invalid prepared spawn enemy"
	var state_value: Variant = enemy_value.get("state",{})
	if not state_value is Dictionary: return "Invalid prepared enemy state"
	var chosen: Variant = null
	for source: Dictionary in [request,enemy_value,state_value]:
		if not source.has("routeId"): continue
		if not source.routeId is String: return "Invalid spawn route ID"
		if chosen != null and chosen != source.routeId: return "Spawn route differs from prepared enemy"
		chosen = source.routeId
	if chosen != null and not chosen.is_empty() and not known_routes.has(chosen): return "Unknown spawn route"
	return ""

func _validate_command_routes(command: Dictionary) -> String:
	if command.get("kind") == "spawn":
		var problem := _validate_spawn_route({"enemy":command.get("enemy",{})},routes)
		if not problem.is_empty(): return problem
	if command.get("kind") == "waveStart":
		for request in command.get("wave", {}).get("spawnQueue", []):
			var problem := _validate_spawn_route(request,routes)
			if not problem.is_empty(): return problem
	if command.get("kind") == "layout" and (command.has("routes") or command.has("spawnPortalId")):
		var problem := _validate_routes(command)
		if not problem.is_empty(): return problem
	return ""

func _transform_path(points: Array, old_origin: Vector2, new_origin: Vector2, ratio: float) -> Array:
	var result: Array = []
	for point in points:
		var p := (_vec(point)-old_origin)*ratio+new_origin
		result.append({"x":p.x,"y":p.y})
	return result

func _spawn(raw: Dictionary) -> void:
	var value: Dictionary = raw.get("state", {}).duplicate(true)
	value.merge(raw, true)
	var route: Dictionary = routes.get(str(value.get("routeId", "")), {})
	var portal_id: String = route.get("spawnPortalId",spawn_portal_id)
	value.erase("spawnPortalId")
	if not portal_id.is_empty(): value.spawnPortalId = portal_id
	value.path = _path(route.get("path",value.get("path", path)))
	var pairs: Array = route.get("teleportPairs",value.get("teleportPairs",teleport_pairs))
	value.erase("teleportPairs")
	if not pairs.is_empty(): value.teleportPairs = pairs
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
	t.stats = Stats.shared_stats_at(t.statInput, int(t.statInput.level))
	turrets[id] = t

func _command(c: Dictionary) -> void:
	match c.get("kind", ""):
		"waveStart":
			_start_wave(c.wave, true)
		"waveCancel":
			wave.cancel()
			running = false
			pending_steps.clear()
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
			var old_path := path
			origin = _vec(c.get("origin", [origin.x,origin.y]))
			tile_size = float(c.get("tileSize", tile_size))
			var ratio := tile_size / maxf(old_tile,0.001)
			board_scale = float(c.get("boardDistanceScale", board_scale))
			path = _path(c.get("path", path))
			_path_revision += 1
			# Layout transforms every route, including custom per-enemy paths.
			for route in routes.values(): route.path = _transform_path(route.path,old_origin,origin,ratio)
			for route in c.get("routes", []): routes[route.id] = {"path":_path(route.path),"teleportPairs":route.get("teleportPairs",[]).duplicate(true),"spawnPortalId":route.get("spawnPortalId",routes.get(route.id,{}).get("spawnPortalId",""))}
			for e in enemies.values():
				e.boardDistanceScale = board_scale
				e.collisionRadius = _radius(e)*ratio
				if e.has("targetingRadius"): e.targetingRadius *= ratio
				if e.has("presentationSize"): e.presentationSize = [e.presentationSize[0]*ratio,e.presentationSize[1]*ratio]
				var selected_route: Dictionary = routes.get(str(e.get("routeId", "")),{})
				if not selected_route.is_empty():
					e.erase("teleportPairs")
					if not selected_route.teleportPairs.is_empty(): e.teleportPairs = selected_route.teleportPairs.duplicate(true)
				# Pair indices belong to the selected path and must be replaced
				# before update_path restores any teleport exit position.
				Enemy.update_path(e,selected_route.get("path",path if e.path == old_path else _transform_path(e.path,old_origin,origin,ratio)))
			for t in turrets.values():
				var p := (_vec(t.position)-old_origin)*ratio+origin
				t.position = [p.x,p.y]
				t.statInput.boardDistanceScale = board_scale
				t.stats = Stats.shared_stats_at(t.statInput,int(t.statInput.level))
			for index in range(wave.next_index,wave.queue.size()):
				var prepared: Dictionary = wave.queue[index].get("enemy",{})
				if prepared.is_empty(): continue
				var at := (_pos(prepared)-old_origin)*ratio+origin
				prepared.x = at.x
				prepared.y = at.y
				prepared.position = {"x":at.x,"y":at.y}
				var selected_route: Dictionary = routes.get(str(prepared.get("routeId", "")),{})
				if not selected_route.is_empty():
					prepared.erase("teleportPairs")
					if not selected_route.teleportPairs.is_empty(): prepared.teleportPairs = selected_route.teleportPairs.duplicate(true)
				prepared.path = selected_route.get("path",path if prepared.get("path",old_path) == old_path else _transform_path(prepared.get("path",old_path),old_origin,origin,ratio)).duplicate(true)
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
		"resetTraitState":
			var turret: Dictionary = turrets.get(str(c.id), {})
			if not turret.is_empty():
				if bool(c.get("primary", false)):
					turret.overheatTarget = 0
					turret.overheatStacks = 0
				for key in ["suppressiveTarget", "suppressiveHits"]: turret[key] = 0
				for key in ["cleanup", "lastBaseCooldown", "lightningElapsed"]: turret[key] = 0.0
				turret.recent = {}
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
	_target_candidates_ready = false
	clock += dt
	if not visual_effects.is_empty():
		visual_effects = visual_effects.filter(func(v):
			if clock - float(v.born) < float(v.duration): return true
			_prepared_effects.erase(int(v.id))
			return false)
	# Local to this step: commands and direct fixture edits cannot stale the index.
	var burn_sources: Dictionary = {}
	for e in enemies.values():
		if _alive(e):
			_collect(Enemy.step(e, dt), burn_sources)
			if terminal: return
	_finish_step(dt)

func _finish_step(dt: float) -> void:
	if terminal: return
	# Turret, delayed and projectile hits change health only, never positions or
	# membership, so their searches share one candidate list.
	_target_candidates = _target_candidate_list()
	_target_bounds = _candidate_bounds(_target_candidates)
	_target_candidates_ready = true
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
	# Hits do not move enemies; build only after movement and instant/delayed hits.
	var broadphase := _projectile_broadphase(moving.size())
	for p in moving:
		_move_projectile(p, dt, broadphase)
	# Spawns change membership; later searches read the live dictionary.
	_target_candidates_ready = false
	_target_candidates = []
	_target_bounds = []
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
		return
	if definition.instantHit:
		if not retained_aim and str(t.aimTargetId) != str(target.id):
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
		var center := _vec(t.position)
		for candidate: Array in _target_candidate_view():
			var e: Dictionary = candidate[0]
			if _alive(e) and center.distance_to(candidate[1]) <= radius + float(candidate[2]):
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
			_projectile(t, attack, projectile_origin, Vector2.from_angle(angle), int(attack.chainCount), [], false, (s.range + 64.0 * board_scale) * PROJECTILE_TRAVEL_MULTIPLIER)

func _target_candidate_list() -> Array:
	var candidates: Array = []
	for e in enemies.values():
		if _alive(e):
			candidates.append([e, _pos(e), _target_radius(e), _progress_score(e), str(e.id)])
	return candidates

func _target_candidate_view() -> Array:
	return _target_candidates if _target_candidates_ready else _target_candidate_list()

func _candidate_bounds(candidates: Array) -> Array:
	if candidates.is_empty(): return []
	var first: Vector2 = candidates[0][1]
	var bounds := [first.x, first.y, first.x, first.y, 0.0]
	for candidate: Array in candidates:
		var at: Vector2 = candidate[1]
		bounds[0] = minf(bounds[0], at.x); bounds[1] = minf(bounds[1], at.y)
		bounds[2] = maxf(bounds[2], at.x); bounds[3] = maxf(bounds[3], at.y)
		bounds[4] = maxf(bounds[4], float(candidate[2]))
	return bounds

# Conservative reject only: a search circle that misses every shared candidate
# position cannot select anything, so idle turrets skip the per-enemy scan.
func _bounds_reachable(from: Vector2, reach: float) -> bool:
	if _target_bounds.is_empty(): return false
	var dx := maxf(maxf(float(_target_bounds[0]) - from.x, 0.0), from.x - float(_target_bounds[2]))
	var dy := maxf(maxf(float(_target_bounds[1]) - from.y, 0.0), from.y - float(_target_bounds[3]))
	var limit := absf(reach) * 1.001 + 0.001
	return not (dx * dx + dy * dy > limit * limit)

func _target(from: Vector2, radius: float, priority: String, excluded: Array = [], body: bool = false) -> Dictionary:
	var selected: Dictionary = {}
	var score := -INF
	var tie := -INF
	if _target_candidates_ready and not _bounds_reachable(from, radius + (float(_target_bounds[4]) if body and not _target_bounds.is_empty() else 0.0)):
		return selected
	var check_excluded := not excluded.is_empty()
	for candidate: Array in _target_candidate_view():
		var e: Dictionary = candidate[0]
		if not _alive(e) or (check_excluded and candidate[4] in excluded):
			continue
		var distance := from.distance_squared_to(candidate[1])
		if distance > pow(radius + (float(candidate[2]) if body else 0.0), 2):
			continue
		var progress: float = candidate[3]
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

# A center occupies one cell, so candidates need no deduplication. The maximum
# enemy radius expands the swept segment bounds; the exact circle test below is
# still authoritative, including starting overlaps and zero-length movement.
func _projectile_broadphase(projectile_count: int) -> Dictionary:
	if projectile_count == 0: return {}
	var ordered: Array = enemies.values()
	if projectile_count < 8 or ordered.size() < 32:
		return {"ordered":ordered}
	var cells: Dictionary = {}
	var cell_size := maxf(1.0, 64.0 * absf(board_scale))
	var maximum_radius := 0.0
	for index in range(ordered.size()):
		var e: Dictionary = ordered[index]
		if not _alive(e): continue
		maximum_radius = maxf(maximum_radius, absf(_radius(e)))
		var at := _pos(e)
		var cell := Vector2i(floori(at.x / cell_size), floori(at.y / cell_size))
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(index)
	return {"ordered":ordered, "cells":cells, "cellSize":cell_size, "radius":maximum_radius}

func _projectile_candidates(from: Vector2, movement: Vector2, radius: float, broadphase: Dictionary) -> Array:
	if broadphase.is_empty(): return enemies.values()
	var ordered: Array = broadphase.ordered
	if not broadphase.has("cells"): return ordered
	var padding: float = broadphase.radius + absf(radius)
	var end := from + movement
	var size: float = broadphase.cellSize
	# One extra cell protects tangent/boundary candidates from float rounding.
	var low := Vector2i(floori((minf(from.x, end.x)-padding)/size)-1, floori((minf(from.y, end.y)-padding)/size)-1)
	var high := Vector2i(floori((maxf(from.x, end.x)+padding)/size)+1, floori((maxf(from.y, end.y)+padding)/size)+1)
	var cell_count := float(high.x-low.x+1) * float(high.y-low.y+1)
	# Long steps / large bodies must neither miss collisions nor walk huge grids.
	if cell_count >= ordered.size(): return ordered
	var indices: Array = []
	for y in range(low.y, high.y+1):
		for x in range(low.x, high.x+1):
			var cell := Vector2i(x, y)
			if broadphase.cells.has(cell): indices.append_array(broadphase.cells[cell])
	if indices.size() * 2 >= ordered.size(): return ordered
	# Equal fractions retain Dictionary insertion order, as in the full scan.
	indices.sort()
	var candidates: Array = []
	for index in indices: candidates.append(ordered[index])
	return candidates

func _move_projectile(p: Dictionary, dt: float, broadphase: Dictionary = {}) -> void:
	var t: Dictionary = turrets.get(p.owner, {})
	if t.is_empty():
		return
	var step := minf(p.remaining, float(p.attack.projectileSpeed) * dt)
	var from: Vector2 = p.position
	var movement: Vector2 = p.direction * step
	var first := INF
	var hit: Dictionary = {}
	var projectile_radius: float = float(PROJECTILE_RADII.get(p.attack.definition.type, 3.5)) * board_scale
	var length_squared := movement.length_squared()
	for e in _projectile_candidates(from, movement, projectile_radius, broadphase):
		if not _alive(e) or str(e.id) in p.excluded:
			continue
		var offset := from - _pos(e)
		var radius: float = _radius(e) + projectile_radius
		var c := offset.length_squared() - radius * radius
		var fraction := 0.0
		if c > 0:
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
	_impact(t, p.attack, hit, p.position, 0.5 if p.chained else 1.0, p.chained, p.direction)
	if p.chains > 0:
		var next := _target(p.position, 110.0 * board_scale, "nearest", p.excluded)
		if not next.is_empty():
			_projectile(t, p.attack, p.position, _pos(next) - p.position, int(p.chains) - 1, p.excluded, true, 110.0 * board_scale * PROJECTILE_TRAVEL_MULTIPLIER)

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
	if target.is_empty():
		_lightning_complete(t, a, used)
		return
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

func _impact(t: Dictionary, a: Dictionary, target: Dictionary, at: Vector2, scale: float = 1.0, chained: bool = false, direction: Vector2 = Vector2.ZERO) -> void:
	var style: String = {"arrow":"spark", "magic":"flame", "cannon":"blast", "lightning":"lightning"}.get(a.definition.type, "spark")
	var extra := {"style":style,"radius":maxf(10.0 * board_scale, a.splashRadius * (0.5 if chained else 1.0))}
	if a.definition.type == "arrow" and direction != Vector2.ZERO:
		# Presentation routing only: the 3D ricochet uses the incoming flight and
		# the struck body's lane offset. Damage and collision stay unchanged.
		extra.merge({"turretType":"arrow", "targetId":int(target.id), "direction":[direction.x, direction.y]})
	_visual("blast" if style == "blast" else "impact", at, t, extra)
	var impacted: Array = [target]
	var radius: float = a.splashRadius * (0.5 if chained else 1.0)
	if radius > 0:
		# Targets are live enemy entries; identity avoids deep Dictionary compares.
		for candidate: Array in _target_candidate_view():
			var e: Dictionary = candidate[0]
			if not is_same(e, target) and _alive(e) and at.distance_squared_to(candidate[1]) <= radius * radius:
				impacted.append(e)
	for e in impacted:
		if _alive(e):
			var primary: bool = is_same(e, target)
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
	var burn: Dictionary = Enemy.burn_transfer(e, source) if direct and a.appliesIgnitionBurst else {}
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

func _collect(items: Array, burn_sources: Dictionary = {}) -> void:
	for raw in items:
		var event: Dictionary = raw.duplicate(true)
		var type: String = event.get("type", "")
		if type == "killed":
			event.kind = "kill"
			_diamond_reward_visual(enemies.get(str(event.enemyId), {}))
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
					for t in _burn_source_turrets(raw, burn_sources):
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

func _retain_death_presentation(event: Dictionary) -> void:
	var enemy: Dictionary = enemies.get(str(event.enemyId), {})
	if enemy.is_empty(): return
	var display := event.duplicate(true)
	display.enemyPresentation = {
		"type":enemy.get("type", "normal"), "facingAngle":enemy.get("facingAngle", 0.0),
		"presentationScale":enemy.get("presentationScale", 0.48 if enemy.get("type") == "fast" else 0.55),
		"teleportSerial":enemy.get("teleportSerial", 0), "routeId":enemy.get("routeId", ""), "spawnPortalId":enemy.get("spawnPortalId", ""),
	}
	display.visualOffset = _visual_enemy_offset(enemy)
	_presentation_deaths.append(display)

func take_death_presentations() -> Array:
	var pending := _presentation_deaths
	_presentation_deaths = []
	return pending

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

func decorate_frame(base: Dictionary, reuse_static: bool = false, canonical_effects: bool = false) -> Dictionary:
	if not active:
		return base
	# Internal presentation (reuse_static) reads static map/selection read-only and
	# reuses row/label objects until the next internal call; consume it at once.
	# Public snapshots (the default) stay fully isolated for existing callers.
	var frame := base.duplicate(not reuse_static)
	# Canonical (internal) frames carry Canvas sizes in 48-pixel tile units, as
	# app_presentation.normalize produces for public snapshots.
	var canvas_tile := maxf(0.001, tile_size)
	var canvas_ratio := LOGICAL_CANVAS_TILE / canvas_tile
	var canvas_scaled: bool = canonical_effects and base.has("presentation") and not is_equal_approx(canvas_tile, LOGICAL_CANVAS_TILE)
	if reuse_static and base.get("presentation") is Dictionary:
		frame.presentation = base.presentation.duplicate()
		for group in ["effects", "selection", "labels"]:
			if frame.presentation.get(group) is Dictionary:
				frame.presentation[group] = frame.presentation[group].duplicate()
	if native_session():
		frame.time = effect_time
		frame.nexusHit = nexus_alert/0.65
		frame.portalAlert = portal_alert/0.55
		if frame.get("presentation") is Dictionary:
			for group in ["effects", "selection"]:
				if frame.presentation.get(group) is Dictionary:
					frame.presentation[group].clock = effect_time
					frame.presentation[group].time = effect_time
			if frame.presentation.get("selection") is Dictionary and not frame.presentation.selection.get("state", frame.presentation.selection).get("preserveLegacyOrnaments", false):
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
				# World shake is consumed as canonical screen pixels.
				frame.presentation.effects.shake = [shake*canvas_ratio,-shake*0.45*canvas_ratio] if canvas_scaled else [shake,-shake*0.45]
				frame.presentation.effects.squaredSteps = effect_squared
	if defense.configured:
		frame.nexusHpRatio = defense.hp/maxf(0.000001,defense.max_hp)
	var rows: Array = []
	var labels: Array = []
	var enemy_rows := {}
	var enemy_pool: Dictionary = _frame_row_pool.enemies
	var label_rows := {}
	var label_pool: Dictionary = _frame_row_pool.labels
	for e in enemies.values():
		if not _alive(e): continue
		# Dictionary.get evaluates its fallback first; avoid it for authored sizes.
		var logical := (_pos(e) - origin) / tile_size
		var p := logical + _visual_enemy_offset(e) / tile_size
		var burning: bool = not e.burnInstances.is_empty()
		var slowed: bool = not e.slowInstances.is_empty()
		var poisoned: bool = float(e.poisonRemaining) > 0
		var diamond: bool = int(e.get("diamondReward", 0)) > 0
		var row: FrameRows.Enemy = enemy_pool.get(e.id) if reuse_static else null
		if row == null: row = FrameRows.Enemy.new()
		if reuse_static: enemy_rows[e.id] = row
		# Typed row fields convert the runtime's numeric values on assignment.
		row.id = e.id; row.x = p.x; row.y = p.y
		row.facing = e.facingAngle; row.phase = e.visualPhase
		row.scale = e.presentationScale if e.has("presentationScale") else _radius(e)*2.0/tile_size; row.has_scale = true
		row.hit_flash = e.hitFlashTimer; row.type = e.get("type","normal")
		row.burning = burning; row.slowed = slowed; row.poisoned = poisoned; row.diamond = diamond
		row.has_logical = true; row.logical_x = logical.x; row.logical_y = logical.y
		row.teleport_serial = e.get("teleportSerial",0) if not e.get("teleportPairs", []).is_empty() else -1
		rows.append(row)
		var size: Array = e.presentationSize if e.has("presentationSize") else [_radius(e)*2,_radius(e)*2]
		if canvas_scaled: size = [float(size[0])*canvas_ratio,float(size[1])*canvas_ratio]
		# Dictionary.get evaluates its fallback eagerly; look up without one.
		var label = label_pool.get(e.id) if reuse_static else null
		if label == null: label = {}
		if reuse_static: label_rows[e.id] = label
		label.id = e.id; label.position = [p.x,p.y]; label.size = size
		label.hp = e.hp; label.maxHp = e.maxHp; label.armor = e.armor; label.maxArmor = e.maxArmor
		label.shield = e.shield; label.maxShield = e.maxShield; label.effectTime = e.statusEffectTime
		label.enemyCount = enemies.size(); label.burning = burning; label.slowed = slowed; label.poisoned = poisoned
		label.riftMarked = e.riftMarkRemaining>0; label.diamondCarrier = diamond
		labels.append(label)
	frame.enemies = rows
	frame.turrets = []
	var turret_rows := {}
	var turret_pool: Dictionary = _frame_row_pool.turrets
	for t in turrets.values():
		var p := (_vec(t.position)-origin)/tile_size
		var row: FrameRows.Turret = turret_pool.get(t.id) if reuse_static else null
		if row == null: row = FrameRows.Turret.new()
		if reuse_static: turret_rows[t.id] = row
		row.id = t.id; row.x = p.x; row.y = p.y; row.aim_angle = t.aimAngle
		row.shot_sequence = t.shotSequence; row.fire_feedback = t.fireFeedback/0.18
		row.type = t.statInput.definition.type; row.level = t.statInput.level
		row.extension = FrameRows.NO_EXTENSION
		if t.statInput.definition.type == "sniper":
			# Optional visual state only; damage, targeting and saved state stay native.
			var target: Dictionary=enemies.get(str(t.aimTargetId),{})
			var aiming: bool=running and session.get("phase","")=="wave" and float(t.aimProgress)>0 and float(t.cooldown)<=0
			aiming=aiming and not target.is_empty() and _alive(target) and _vec(t.position).distance_to(_pos(target))<=float(t.stats.range)+_target_radius(target)
			var ratio := clampf(float(t.aimProgress)/maxf(.000001,float(t.stats.aimDuration)),0.0,1.0) if aiming else 0.0
			row.extension = {"aimActive":aiming,"aimTargetId":int(t.aimTargetId),"aimProgress":float(t.aimProgress),"aimRatio":ratio}
		if t.statInput.definition.type == "frost":
			# Presentation extension only.
			# Saves retain remaining cooldown but not lastBaseCooldown; derive a safe
			# denominator from current attack speed without changing saved state.
			var duration := float(t.get("lastBaseCooldown", 0.0))
			if duration <= 0.0:
				duration = maxf(float(t.cooldown), 1.0 / maxf(.001, float(t.stats.attackRate)))
			row.extension = {"cooldown":t.cooldown, "duration":duration, "radius":float(t.stats.centeredAreaRadius)/tile_size}
		frame.turrets.append(row)
	if frame.has("presentation"):
		if not frame.presentation.has("labels"): frame.presentation.labels = {}
		frame.presentation.labels.enemies = labels
		frame.presentation.labels.logicalTileSize = LOGICAL_CANVAS_TILE if canvas_scaled else tile_size
		if native_session():
			frame.presentation.labels.core = null
			if session.get("phase") == "wave" and core.configured and core.skill != null and not path.is_empty():
				var center := (_vec(path[-1])-origin)/tile_size
				var progress := 1.0 if core.guardian_beam_active_remaining>0 else clampf(1.0-core.cooldown/maxf(0.000001,core.interval()),0,1)
				frame.presentation.labels.core = {"position":[center.x,center.y],"progress":progress,"accent":0xffcfa7ff if core.skill == "riftMark" else 0xff8ee6ff,"active":core.guardian_beam_active_remaining>0}
	frame.projectiles = []
	frame.impacts = []
	var impact_rows := {}
	var projectile_rows := {}
	for v in visual_effects:
		if v.kind == "blast":
			var impact: FrameRows.Impact = _frame_row_pool.impacts.get(v.id) if reuse_static else null
			if impact == null: impact = FrameRows.Impact.new()
			if reuse_static: impact_rows[v.id] = impact
			impact.id = v.id; impact.x = v.x; impact.y = v.y
			impact.radius = float(v.radius)/tile_size; impact.progress = clampf((clock-float(v.born))/float(v.duration),0,1)
			frame.impacts.append(impact)
	for p in projectiles:
		var at: Vector2 = (p.position - origin) / tile_size
		var start: Vector2 = (p.origin - origin) / tile_size
		var row: FrameRows.Projectile = _frame_row_pool.projectiles.get(p.id) if reuse_static else null
		if row == null: row = FrameRows.Projectile.new()
		if reuse_static: projectile_rows[p.id] = row
		row.id = p.id; row.x = at.x; row.y = at.y
		row.direction_x = p.direction.x; row.direction_y = p.direction.y; row.type = p.attack.definition.type
		row.has_launch = true; row.start_x = start.x; row.start_y = start.y
		row.has_owner = true; row.owner_id = int(p.owner); row.shot = p.shot; row.chained = p.chained
		row.finished_at = -1.0; row.has_end = false
		frame.projectiles.append(row)
	if reuse_static:
		_frame_row_pool = {"enemies": enemy_rows, "turrets": turret_rows, "projectiles": projectile_rows, "impacts": impact_rows, "labels": label_rows}
	if frame.has("presentation") and frame.presentation.has("effects"):
		var effects: Dictionary = frame.presentation.effects
		var items: Array = effects.get("items", []).duplicate(true)
		var presentation_events: Array = effects.get("events", []).duplicate(true)
		effects.erase("_canonicalNativeEffects")
		if canonical_effects:
			# Mixed base/legacy entries are owned copies, never cached or skipped.
			for legacy in items + presentation_events: EffectFormat.normalize(legacy)
			effects._canonicalNativeEffects = true
		for v in visual_effects:
			if v.kind == "diamond":
				# The receiver owns receipt display time after first delivery, even
				# when the source's short combat-time journal has already expired.
				presentation_events.append(_effect_frame(v, reuse_static, canonical_effects))
				continue
			var item: Dictionary = _effect_frame(v, reuse_static, canonical_effects)
			item.age = clock - float(v.born)
			if item.kind == "damage":
				item.screenOffset = [0,-34.0*float(item.age)]
			elif item.kind == "chain":
				item.points = v.points.duplicate(not reuse_static)
				var linked: Dictionary = enemies.get(str(item.targetIds[-1]),{})
				if not linked.is_empty() and _alive(linked):
					var end := (_pos(linked)-origin)/tile_size
					item.points[-1] = [end.x,end.y]
					v.points[-1] = [end.x,end.y]
			elif item.kind == "coreBeam":
				item.points = v.points.duplicate(not reuse_static)
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
		effects.events = presentation_events
	return frame

func _diamond_reward_visual(enemy: Dictionary) -> void:
	var amount := maxi(0, int(enemy.get("diamondReward", 0)))
	if amount == 0 or bool(enemy.get("isDebug", false)): return
	var at := (_pos(enemy) + _visual_enemy_offset(enemy) - origin) / tile_size
	visual_id += 1
	_append_visual({"id":visual_id,"kind":"diamond","born":clock,"bornSquared":effect_squared,
		"duration":1.05,"x":at.x,"y":at.y,"tileSize":tile_size,"scale":board_scale,
		"text":"+%d" % amount,"hasImage":true,"points":[],"screenOffset":[0,0]})

func _visual(kind: String, at: Vector2, t: Dictionary, extra: Dictionary = {}) -> void:
	visual_id += 1
	var pos := (at - origin) / tile_size
	var colors := {"arrow":0xffffdf9e, "cannon":0xffffb066, "magic":0xffff713d, "frost":0xff94e6ff, "sniper":0xffffeec4, "lightning":0xffc7d8ff}
	var v := {"id":visual_id, "kind":kind, "born":clock, "duration":0.28, "x":pos.x, "y":pos.y, "tileSize":tile_size, "scale":board_scale, "color":colors.get(t.statInput.definition.type, 0xffffffff), "points":[], "screenOffset":[0,0], "feedback":"neutral", "motion":"rise", "arcDirection":1}
	if t.statInput.definition.type == "lightning":
		v["turretType"] = "lightning"
		v["ownerId"] = int(t.id)
	v.merge(extra, true)
	if kind == "blast" and not extra.has("duration"):
		v.duration = BLAST_DURATION
	var points: Array = []
	for point in v.points:
		var p := (_vec(point) - origin) / tile_size
		points.append([p.x,p.y])
	v.points = points
	_append_visual(v)

func _append_visual(effect: Dictionary) -> void:
	visual_effects.append(effect)
	_prepared_effects[int(effect.id)] = {"source":effect,"payload":EffectFormat.prepare(effect)}

func _effect_frame(effect: Dictionary, reuse_static: bool, canonical: bool) -> Dictionary:
	if not canonical: return effect.duplicate(not reuse_static)
	var prepared: Dictionary = _prepared_effects.get(int(effect.id), {})
	if not prepared.is_empty() and is_same(prepared.source, effect):
		return prepared.payload.duplicate(not reuse_static)
	# Directly supplied fixture/legacy entries preserve their current values.
	var item := effect.duplicate(true)
	EffectFormat.normalize(item)
	return item

func _visual_enemy_offset(e: Dictionary) -> Vector2:
	var lane: float = e.get("laneOffsetRatio", 0.0)
	if lane == 0 or e.path.size() < 2: return Vector2.ZERO
	var distance: float = e.distanceTravelled
	var sample := 48.0 * board_scale * 0.4
	var before := Enemy.point_at_distance(e, distance - sample)
	var after := Enemy.point_at_distance(e, distance + sample)
	var tangent := after - before
	if tangent.length_squared() <= 0.001: return Vector2.ZERO
	var total: float = e._total
	var fade := clampf(minf(distance,total-distance)/(48.0*board_scale*0.55),0,1)
	return Vector2(-tangent.y,tangent.x).normalized()*lane*48.0*board_scale*fade

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
