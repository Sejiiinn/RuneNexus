extends "res://combat/combat_runtime_state.gd"
## Target acquisition and projectile collision searches over the step candidates.

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

func _first_projectile_collision(from: Vector2, movement: Vector2, attack: Dictionary, excluded: Array, broadphase: Dictionary) -> Dictionary:
	var first := INF
	var hit: Dictionary = {}
	var projectile_radius: float = float(PROJECTILE_RADII.get(attack.definition.type, 3.5)) * board_scale
	var length_squared := movement.length_squared()
	for e in _projectile_candidates(from, movement, projectile_radius, broadphase):
		if not _alive(e) or str(e.id) in excluded:
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
	return {"target":hit, "fraction":first}
