extends RefCounted
## Deterministic performance fixture, NOT a port of production combat rules.
## Rendering consumes the unchanged production frame protocol and assets.
const FIXED_DT := 1.0 / 60.0
const RATES := {"cannon": 0.4, "magic": 0.59, "arrow": 2.27, "frost": 0.4}
var speed := 1.0
var paused := false
var counters := {}
var scenario := "normal"
var game_time := 0.0
var visual_time := 0.0
var _accumulator := 0.0
var _fixture := {}
var _turrets: Array = []
var _enemies: Array = []
var _projectiles: Array = []
var _effects: Array = []
var _impacts: Array = []
var _path: Array[Vector2] = []
var _next_id := 1000
var _sequence := 0
var _stationary := false
var _stationary_targets := {}

func configure(fixture: Dictionary, selected_scenario: String, selected_speed: float) -> void:
	_fixture = fixture.duplicate(true)
	scenario = selected_scenario
	speed = maxf(0.0, selected_speed)
	paused = false
	game_time = 0.0
	visual_time = 0.0
	_accumulator = 0.0
	_sequence = 0
	_next_id = 1000
	counters = {"steps": 0, "shots": 0, "hits": 0, "deaths": 0, "respawns": 0, "burn_ticks": 0, "slows": 0, "peak_projectiles": 0}
	_stationary_targets.clear()
	_turrets.clear()
	_enemies.clear()
	_projectiles.clear()
	_effects.clear()
	_impacts.clear()
	_path = _ordered_path(fixture["map"])
	if fixture.has("path_tiles"):
		_path.clear()
		for point: Array in fixture.path_tiles:
			_path.append(Vector2(float(point[0]), float(point[1])))
	_stationary = scenario in ["cannon", "magic", "cannon1x", "magic1x", "magic4x", "barrage_cannon", "barrage_magic", "normal", "fire", "fire_4x", "stress_4x"]
	var default_type := "cannon" if "cannon" in scenario or scenario == "normal" else "magic"
	for source: Array in fixture.get("turrets", []):
		var data: Array = source.duplicate(true)
		data[3] = 0.0
		data[4] = 0
		data[5] = 0.0
		data[6] = ["arrow", "cannon", "magic", "frost", "cannon", "magic"][_turrets.size() % 6] if scenario == "combat_normal" else default_type
		_turrets.append({"data": data, "cooldown": 0.0})
	var count := 96 if scenario in ["stress", "stress_4x", "combat_stress"] else (3 if _stationary else 24)
	var sources: Array = fixture.get("enemies", [])
	for i in range(count):
		var distance := float(i) / count * maxf(1.0, _path.size() - 1.0)
		var point := _point_at(distance)
		if _stationary and not sources.is_empty():
			if i < sources.size():
				point = Vector2(float(sources[i][1]), float(sources[i][2]))
			else:
				point = _point_at((0.05 + 0.9 * i / 96.0) * (_path.size() - 1))
		var appearance: Array = sources[i % sources.size()] if not sources.is_empty() else []
		_enemies.append({"id": 100 + i, "point": point, "distance": distance, "hp": 1000000000.0 if _stationary else 90.0, "burn": 0.0, "slow": 0.0, "burn_clock": 0.0, "angle": float(appearance[3]) if appearance.size() > 3 else 0.0, "phase": float(appearance[4]) if appearance.size() > 4 else i * 0.61803398875, "scale": float(appearance[5]) if appearance.size() > 5 else 1.25, "type": str(appearance[7]) if appearance.size() > 7 else "tank"})

func set_paused(value: bool) -> void:
	paused = value

func step(real_delta: float) -> Dictionary:
	if not paused:
		_accumulator += maxf(real_delta, 0.0) * speed
		# Never silently discard elapsed time when frames are slow.
		while _accumulator + 0.000000001 >= FIXED_DT:
			_tick(FIXED_DT)
			_accumulator -= FIXED_DT
	_sequence += 1
	return _frame()

func _tick(dt: float) -> void:
	game_time += dt
	visual_time += dt / maxf(speed, 0.000001)
	counters.steps += 1
	for enemy: Dictionary in _enemies:
		enemy.burn = maxf(0.0, enemy.burn - dt)
		enemy.slow = maxf(0.0, enemy.slow - dt)
		if enemy.burn > 0.0:
			enemy.burn_clock += dt
			if enemy.burn_clock >= 0.28:
				enemy.burn_clock -= 0.28
				enemy.hp -= 3.0
				counters.burn_ticks += 1
				_add_effect("damage", enemy.point, 0.7, "3", true)
		if not _stationary:
			var previous: Vector2 = enemy.point
			enemy.distance += dt * 0.35 * (0.8 if enemy.slow > 0.0 else 1.0)
			if enemy.distance >= _path.size() - 1:
				enemy.distance = 0.0
				counters.respawns += 1
			enemy.point = _point_at(enemy.distance)
			enemy.angle = (enemy.point - previous).angle()
	for turret: Dictionary in _turrets:
		var data: Array = turret.data
		data[5] = maxf(0.0, float(data[5]) - dt * 8.0)
		turret.cooldown -= dt
		var origin := Vector2(float(data[1]), float(data[2]))
		var target: Dictionary = _nearest_target(int(data[0]), origin)
		if target.is_empty():
			continue
		data[3] = (target.point - origin).angle()
		if turret.cooldown > 0.0:
			continue
		turret.cooldown += 1.0 / float(RATES[data[6]])
		data[4] += 1
		data[5] = 1.0
		counters.shots += 1
		if data[6] == "frost":
			for enemy: Dictionary in _enemies:
				if origin.distance_to(enemy.point) < 2.2:
					enemy.slow = 1.0
					enemy.hp -= 4.0
					counters.slows += 1
			continue
		_next_id += 1
		var flight_origin: Vector2 = origin + (target.point - origin).normalized() * 0.164 if data[6] == "magic" else origin
		_projectiles.append({"id": _next_id, "point": flight_origin, "origin": flight_origin, "target": target, "type": data[6], "owner": data[0], "shot": data[4], "end": -1.0, "direction": (target.point - origin).normalized()})
	for i in range(_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = _projectiles[i]
		if projectile.end >= 0.0:
			if visual_time - projectile.end >= 0.14:
				_projectiles.remove_at(i)
			continue
		var target: Dictionary = projectile.target
		var travel := (420.0 / 48.0 if projectile.type == "magic" else (620.0 / 48.0 if projectile.type == "arrow" else 340.0 / 48.0)) * dt
		projectile.direction = (target.point - projectile.point).normalized()
		if projectile.point.distance_to(target.point) <= travel:
			projectile.point = target.point
			projectile.end = visual_time
			_hit(target, projectile.type)
		else:
			projectile.point += projectile.direction * travel
	counters.peak_projectiles = maxi(counters.peak_projectiles, _projectiles.size())
	for enemy: Dictionary in _enemies:
		if enemy.hp <= 0.0:
			counters.deaths += 1
			# Defensive invalidation if a long fixture run exhausts the tank HP.
			_stationary_targets.clear()
			_add_effect("death", enemy.point, 0.75, "")
			enemy.hp = 90.0
			enemy.distance = 0.0
			enemy.point = _point_at(0.0)
			enemy.burn = 0.0
			enemy.slow = 0.0
			counters.respawns += 1
	for collection in [_effects, _impacts]:
		for i in range(collection.size() - 1, -1, -1):
			if game_time - float(collection[i].start) >= float(collection[i].duration):
				collection.remove_at(i)

func _nearest_target(turret_id: int, origin: Vector2) -> Dictionary:
	# Stationary fixture positions and turret origins never change after configure.
	# Keep the same dictionary reference, tie ordering and combat state as a scan.
	# Moving combat fixtures deliberately retain the original full search.
	if _stationary and _stationary_targets.has(turret_id):
		return _stationary_targets[turret_id]
	var target: Dictionary = {}
	var nearest := INF
	for enemy: Dictionary in _enemies:
		var distance := origin.distance_squared_to(enemy.point)
		if distance < nearest:
			nearest = distance
			target = enemy
	if _stationary:
		_stationary_targets[turret_id] = target
	return target

func _hit(target: Dictionary, type: String) -> void:
	counters.hits += 1
	target.hp -= 25.0 if type == "cannon" else (16.0 if type == "magic" else 7.0)
	_add_effect("damage", target.point, 0.7, "16" if type == "magic" else "25")
	if type == "magic":
		target.burn = 3.0
	if type == "cannon":
		_next_id += 1
		_impacts.append({"id": _next_id, "point": target.point, "start": game_time, "duration": 0.45})
		for enemy: Dictionary in _enemies:
			if enemy != target and enemy.point.distance_to(target.point) < 0.875:
				enemy.hp -= 12.0

func _add_effect(kind: String, point: Vector2, duration: float, label: String, burn_number: bool = false) -> void:
	_next_id += 1
	_effects.append({"id": _next_id, "kind": kind, "start": game_time, "duration": duration, "x": point.x, "y": point.y, "tileSize": float(_fixture.get("pixelsPerTile", 48.0)), "color": 0xffff8a2a if burn_number else 0xffffa34b, "motion": "fallArc" if burn_number else "rise", "text": label, "feedback": "normal", "enemyType": "tank", "enemyTypeIndex": 4, "scale": 1.0})

func _frame() -> Dictionary:
	var frame: Dictionary = _fixture.duplicate(false)
	frame.merge({"seq": _sequence, "sceneEpoch": 1, "presentationVersion": 2, "time": visual_time, "map": _fixture["map"], "turrets": [], "enemies": [], "projectiles": [], "impacts": [], "buildPreview": null, "nexusHpRatio": 1.0, "nexusHit": 0.0, "portalAlert": 0.0}, true)
	for turret: Dictionary in _turrets:
		frame.turrets.append(turret.data.duplicate())
	for enemy: Dictionary in _enemies:
		frame.enemies.append([enemy.id, enemy.point.x, enemy.point.y, enemy.angle, enemy.phase, enemy.scale, 0.0, enemy.type, enemy.burn > 0.0, enemy.slow > 0.0, false, false])
	for p: Dictionary in _projectiles:
		frame.projectiles.append([p.id, p.point.x, p.point.y, p.direction.x, p.direction.y, p.type, p.origin.x, p.origin.y, p.owner, p.shot, false, p.end, p.target.point.x, p.target.point.y])
	for impact: Dictionary in _impacts:
		frame.impacts.append([impact.id, impact.point.x, impact.point.y, 0.875, (game_time - impact.start) / impact.duration])
	var effects := []
	for effect: Dictionary in _effects:
		var item: Dictionary = effect.duplicate()
		item["age"] = game_time - item.start
		item.erase("start")
		effects.append(item)
	var presentation: Dictionary = _fixture.get("presentation", {}).duplicate(true)
	presentation["effects"] = {"items": effects}
	var labels: Dictionary = presentation.get("labels", {"logicalTileSize": 48.0})
	var old_labels: Array = labels.get("enemies", [])
	var new_labels := []
	for i in range(_enemies.size()):
		var enemy: Dictionary = _enemies[i]
		var label: Dictionary = old_labels[i % old_labels.size()].duplicate(true) if not old_labels.is_empty() else {"size": [32.0, 32.0], "maxArmor": 0.0, "maxShield": 0.0}
		label.merge({"id": enemy.id, "position": [enemy.point.x, enemy.point.y], "hp": enemy.hp, "maxHp": 1000000000.0 if _stationary else 90.0, "effectTime": game_time}, true)
		new_labels.append(label)
	labels["enemies"] = new_labels
	presentation["labels"] = labels
	frame["presentation"] = presentation
	return frame

func _ordered_path(map: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var tiles: Array = map.tiles
	var width := int(map.columns)
	var current := tiles.find("spawn")
	if current < 0:
		current = tiles.find("path")
	var visited := {}
	while current >= 0:
		visited[current] = true
		result.append(Vector2(current % width + 0.5, floori(float(current) / width) + 0.5))
		var next := -1
		for offset in [1, width, -1, -width]:
			var candidate: int = current + offset
			if candidate < 0 or candidate >= tiles.size() or visited.has(candidate):
				continue
			if absi(candidate % width - current % width) + absi(floori(float(candidate) / width) - floori(float(current) / width)) != 1:
				continue
			if tiles[candidate] in ["path", "core"]:
				next = candidate
				break
		current = next
	return result

func _point_at(distance: float) -> Vector2:
	if _path.is_empty():
		return Vector2(4.5, 4.5)
	var index := clampi(int(distance), 0, _path.size() - 1)
	return _path[index].lerp(_path[mini(index + 1, _path.size() - 1)], distance - index)
