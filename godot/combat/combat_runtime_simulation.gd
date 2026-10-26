extends "res://combat/combat_runtime_weapons.gd"
## Fixed-step simulation, spawns, turret records, route checks and batch commands.

func _start_wave(raw: Dictionary, reset_core: bool) -> void:
	if defense.configured and defense.failed: return
	wave_configured = true
	wave.start(raw)
	if wave.active:
		portal_alert = 0.55
		_emit({"kind":Kinds.WAVE_STARTED,"waveId":wave.id})
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

func _configure_combat(config: Dictionary) -> void:
	_boss_damage_bonus_rate = clampf(float(config.get("bossDamageBonusRate", 0.0)), 0.0, 0.2)
	_direct_damage_training_bonus_rate = _training_rate(config.get("directDamageTrainingBonusRate", 0.0))
	_splash_damage_training_bonus_rate = _training_rate(config.get("splashDamageTrainingBonusRate", 0.0))
	_damage_over_time_training_bonus_rate = _training_rate(config.get("damageOverTimeTrainingBonusRate", 0.0))

func _check_native_wave_complete() -> void:
	if terminal: return
	if wave.finish_if_empty(_has_core_target()):
		var recovery: float = defense.recover_round()
		if recovery>0:
			_nexus_health_number(recovery)
			_emit({"kind":Kinds.CORE_RECOVERED,"amount":recovery})
		running = false
		core.reset_cycle()
		_refresh_turret_stats()
		_emit({"kind":Kinds.WAVE_COMPLETED,"waveId":wave.id})

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
	if command.get("kind") == Kinds.COMMAND_SPAWN:
		var problem := _validate_spawn_route({"enemy":command.get("enemy",{})},routes)
		if not problem.is_empty(): return problem
	if command.get("kind") == Kinds.COMMAND_WAVE_START:
		for request in command.get("wave", {}).get("spawnQueue", []):
			var problem := _validate_spawn_route(request,routes)
			if not problem.is_empty(): return problem
	if command.get("kind") == Kinds.COMMAND_LAYOUT and (command.has("routes") or command.has("spawnPortalId")):
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
	# Frozen run build activates the perk for every turret type. Refresh keeps
	# earned charges; a checkpoint restores them but breaks partial idle time.
	t.stockpileEnabled = bool(t.statInput.get("coreEffects", {}).get("hasStockpileFire", false))
	t.stockpileCharges = clampi(int(old.get("stockpileCharges", raw.get("stockpileCharges", state.get("stockpileCharges", 0)))), 0, STOCKPILE_MAX_CHARGES) if t.stockpileEnabled else 0
	t.stockpileIdleElapsed = float(old.get("stockpileIdleElapsed", 0.0)) if t.stockpileEnabled else 0.0
	t.stockpilePrefiring = bool(old.get("stockpilePrefiring", false)) if t.stockpileEnabled else false
	_apply_sync(t)
	t.stats = Stats.shared_stats_at(t.statInput, int(t.statInput.level))
	turrets[id] = t

func _command(c: Dictionary) -> void:
	match c.get("kind", ""):
		Kinds.COMMAND_COMBAT_CONFIG:
			_configure_combat(c.config)
		Kinds.COMMAND_WAVE_START:
			_start_wave(c.wave, true)
		Kinds.COMMAND_WAVE_CANCEL:
			wave.cancel()
			running = false
			pending_steps.clear()
		Kinds.COMMAND_CORE_CONFIG:
			core.configure(c.config,c.get("state",{}))
			_refresh_turret_stats()
		Kinds.COMMAND_RESET_CORE_CYCLE:
			core.reset_cycle()
			_refresh_turret_stats()
		Kinds.COMMAND_EMERGENCY_CHARGE:
			core.emergency_charge(float(c.get("recoveryRate",0)))
		Kinds.COMMAND_DEFENSE_CONFIG:
			defense.configure(c.config)
		Kinds.COMMAND_DEFENSE_RESTORE:
			defense.restore(c.state)
			core.emergency_charge_used_this_round = defense.emergency_charge_used_this_round
			terminal = defense.failed
		Kinds.COMMAND_LAYOUT:
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
				if p.has("landing"): p.landing = (p.landing-old_origin)*ratio+origin
				p.remaining *= ratio
				p.attack = p.attack.duplicate(true)
				for key in ["range","splashRadius","projectileSpeed","lightningChainJumpRange"]: p.attack[key] *= ratio
			for puddle in puddles:
				puddle.position = (puddle.position-old_origin)*ratio+origin
				puddle.radius *= ratio
		Kinds.COMMAND_SPAWN: _spawn(c.enemy)
		Kinds.COMMAND_TURRET: _turret(c.turret)
		Kinds.COMMAND_RESET_TRAIT_STATE:
			var turret: Dictionary = turrets.get(str(c.id), {})
			if not turret.is_empty():
				if bool(c.get("primary", false)):
					turret.overheatTarget = 0
					turret.overheatStacks = 0
				for key in ["suppressiveTarget", "suppressiveHits"]: turret[key] = 0
				for key in ["cleanup", "lastBaseCooldown", "lightningElapsed"]: turret[key] = 0.0
				turret.recent = {}
		Kinds.COMMAND_REMOVE_TURRET:
			var removed: Dictionary = turrets.get(str(c.id), {})
			if not removed.is_empty():
				for e in enemies.values():
					Enemy.clear_burn_source(e, {"x": removed.state.get("x"), "y": removed.state.get("y")})
			turrets.erase(str(c.id))
		Kinds.COMMAND_RIFT_MARK:
			if enemies.has(str(c.enemyId)):
				Enemy.add_rift_mark(enemies[str(c.enemyId)], c.damageAmplification, c.duration)
		Kinds.COMMAND_CORE_DAMAGE:
			if enemies.has(str(c.enemyId)):
				var result: Dictionary = Enemy.apply_hit(enemies[str(c.enemyId)], {"damage": c.damage})
				_collect(result.get("events", []), {}, true)
				_emit({"kind": Kinds.CORE_DAMAGE, "enemyId": c.enemyId, "damage": result.get("actualDamage", 0.0)})

func _step(dt: float) -> void:
	if running: defense.step(dt)
	_target_candidates_ready = false
	clock += dt
	# Most steps expire nothing; rebuild only when one entry has ended.
	var visual_expired := false
	for v in visual_effects:
		if not clock - float(v.born) < float(v.duration):
			visual_expired = true
			break
	if visual_expired:
		visual_effects = visual_effects.filter(func(v):
			if clock - float(v.born) < float(v.duration): return true
			_prepared_effects.erase(int(v.id))
			return false)
	# Local to this step: commands and direct fixture edits cannot stale the index.
	var burn_sources: Dictionary = {}
	for e in enemies.values():
		if _alive(e):
			_collect(Enemy.step(e, dt, [], -1, _target_damage_multiplier(e), _damage_over_time_training_bonus_rate), burn_sources)
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
	if not puddles.is_empty(): _tick_puddles(dt)
	if not corroding.is_empty(): _apply_corrosion()
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
