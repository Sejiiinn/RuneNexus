extends "res://combat/combat_runtime_frame.gd"
## Persistent combat authority. Commands, simulation time and events are ACKed once.
## Public entry: session clock, message protocol, reset and snapshots. The
## layers below it (state → targeting → damage → weapons → simulation → frame)
## may only call downward; GDScript rejects an upward call at parse time.

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
		if command.get("kind") == Kinds.COMMAND_LAYOUT:
			var teleport_error := Teleports.validate_compiled(teleport_pairs,command.get("path",path))
			if not teleport_error.is_empty():
				return {"accepted":false,"reason":"invalidTeleportPairs","detail":teleport_error}
	var clock_change: bool = same_native_epoch and packet.get("session") is Dictionary and _changes_clock_controls(packet.session)
	if clock_change: clock_control_changing.emit()
	var ack_event := int(packet.get("ackEvent", 0))
	for event in events:
		if int(event.id) <= ack_event and event.kind in Kinds.ACK_REMOVES_ENEMY:
			if event.kind == Kinds.KILL: _retain_death_presentation(event)
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
	_sync_stats_ready = false
	defense = Defense.new()
	wave_configured = false
	terminal = false
	pending_steps.clear()
	sequence = -1
	enemies.clear()
	turrets.clear()
	projectiles.clear()
	puddles.clear()
	corroding.clear()
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
	_configure_combat(b.get("combatConfig", {}))
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

func snapshot() -> Dictionary:
	var enemy_states: Array = []
	for e in enemies.values():
		enemy_states.append(Enemy.snapshot(e))
	var turret_states: Array = []
	for t in turrets.values():
		var state := {"id": t.id}
		for key in ["cooldown", "aimAngle", "aimProgress", "aimTargetId", "shotSequence", "directDamageDealt", "splashDamageDealt", "chainDamageDealt", "burnDamageDealt", "stockpileEnabled", "stockpileCharges", "stockpileIdleElapsed"]:
			state[key] = t[key]
		state.stockpileChargeInterval = 1.0 / _normal_attack_rate(t) + _normal_aim_duration(t)
		turret_states.append(state)
	var wave_state: Dictionary = wave.snapshot()
	return {"stateRevision":state_revision,"session":session_snapshot(),"defense":defense.snapshot(),"wave":wave_state,"core":core.snapshot(),"accepted": true, "epoch": epoch, "ackSequence": sequence, "enemies": enemy_states, "turrets": turret_states, "events": events.duplicate(true), "clock": clock}
