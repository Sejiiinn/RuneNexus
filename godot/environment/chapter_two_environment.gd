extends RefCounted

## 챕터 2 외곽의 비플레이 칸에만 제한된 수의 공용 소품을 배치한다.
const PROP_NAMES := ["rune_pillar", "crystal_cluster", "void_fissure", "crystal_cluster"]
const NEIGHBORS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const PLAY_CLEARANCE := 0.04

static func _placement(model: Node3D, cell: Vector2i, kind: String, columns: int, rows: int, tiles: Array) -> Transform3D:
	var angle := float(posmod(cell.x + cell.y * 3, 4)) * PI / 2.0
	var rotation := Basis(Vector3.UP, angle)
	var local_bounds := _mesh_bounds(model)
	var rotated_bounds := Transform3D(rotation, Vector3.ZERO) * local_bounds
	var edge_offset := Vector2.ZERO
	var clearance := PLAY_CLEARANCE + 0.0001
	for offset: Vector2i in NEIGHBORS:
		var neighbor := cell + offset
		if _inside(neighbor, columns, rows) and tiles[neighbor.y * columns + neighbor.x] != "blocked":
			# 암반의 실제 경계만큼만 비켜 붙인다. 일괄 이동으로 생기는 넓은 공백을 피한다.
			if offset == Vector2i.LEFT:
				edge_offset.x = maxf(edge_offset.x, -0.5 + clearance - rotated_bounds.position.x)
			elif offset == Vector2i.RIGHT:
				edge_offset.x = minf(edge_offset.x, 0.5 - clearance - rotated_bounds.end.x)
			elif offset == Vector2i.UP:
				edge_offset.y = maxf(edge_offset.y, -0.5 + clearance - rotated_bounds.position.z)
			elif offset == Vector2i.DOWN:
				edge_offset.y = minf(edge_offset.y, 0.5 - clearance - rotated_bounds.end.z)
	var position := Vector3(cell.x + 0.5 - columns / 2.0, 0.0, cell.y + 0.5 - rows / 2.0)
	position.x += edge_offset.x
	position.z += edge_offset.y
	if kind == "void_fissure":
		position.y = -local_bounds.end.y
	return Transform3D(rotation, position)

static func _has_ground_clearance(bounds: AABB, columns: int, rows: int, tiles: Array) -> bool:
	# 넓어진 부유 암반은 이웃의 빈 칸까지 쓸 수 있지만 플레이 지면에는 닿지 않는다.
	if bounds.position.x < -columns / 2.0 - 0.45 or bounds.end.x > columns / 2.0 + 0.45 \
			or bounds.position.z < -rows / 2.0 - 0.45 or bounds.end.z > rows / 2.0 + 0.45:
		return false
	for index in range(tiles.size()):
		if tiles[index] == "blocked":
			continue
		var x := float(index % columns) - columns / 2.0
		var z := floorf(float(index) / columns) - rows / 2.0
		if bounds.position.x < x + 1.0 + PLAY_CLEARANCE and bounds.end.x > x - PLAY_CLEARANCE \
				and bounds.position.z < z + 1.0 + PLAY_CLEARANCE and bounds.end.z > z - PLAY_CLEARANCE:
			return false
	return true

static func _mesh_bounds(node: Node3D, parent_pose := Transform3D.IDENTITY) -> AABB:
	var pose: Transform3D = parent_pose * node.transform
	var bounds := AABB(pose.origin, Vector3.ZERO)
	if node is MeshInstance3D:
		bounds = pose * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			bounds = bounds.merge(_mesh_bounds(child, pose))
	return bounds

static func _inside(cell: Vector2i, columns: int, rows: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows

static func populate(terrain: Node3D, library: Node3D, map: Dictionary) -> bool:
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var tiles: Array = map["tiles"]
	var models := {}
	for kind in PROP_NAMES:
		if models.has(kind):
			continue
		var model := library.find_child(kind, true, false) as Node3D
		if model == null:
			push_error("챕터 2 환경 GLB 노드 누락: " + kind)
			return false
		var bounds := _mesh_bounds(model)
		# 소품을 받치는 부유 지형까지 포함한 제작 범위. 실제 플레이 칸과의 간격은 배치마다 검사한다.
		if bounds.position.x < -0.7001 or bounds.end.x > 0.7001 or bounds.position.z < -0.7001 or bounds.end.z > 0.7001:
			push_error("챕터 2 부유 지형이 1.4타일 제작 범위를 넘습니다: " + kind)
			return false
		models[kind] = model

	# 맵 바깥과 이어진 blocked 영역만 사용해 플레이 영역 안의 작은 구멍은 비운다.
	var exterior := {}
	var pending: Array[Vector2i] = []
	var landmarks: Array[Vector2i] = []
	for index in range(tiles.size()):
		var cell := Vector2i(index % columns, floori(float(index) / columns))
		if tiles[index] in ["spawn", "core"]:
			landmarks.append(cell)
		if tiles[index] == "blocked" and (cell.x == 0 or cell.y == 0 or cell.x == columns - 1 or cell.y == rows - 1):
			exterior[cell] = true
			pending.append(cell)
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		for offset: Vector2i in NEIGHBORS:
			var neighbor := cell + offset
			if _inside(neighbor, columns, rows) and not exterior.has(neighbor) and tiles[neighbor.y * columns + neighbor.x] == "blocked":
				exterior[neighbor] = true
				pending.append(neighbor)
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in pending:
		var touches_play := false
		for offset: Vector2i in NEIGHBORS:
			var neighbor := cell + offset
			if _inside(neighbor, columns, rows) and tiles[neighbor.y * columns + neighbor.x] != "blocked":
				touches_play = true
		var near_landmark := false
		for point: Vector2i in landmarks:
			near_landmark = near_landmark or cell.distance_squared_to(point) <= 2
		if touches_play and not near_landmark:
			candidates.append(cell)

	var container := Node3D.new()
	container.name = "chapter_two_environment"
	terrain.add_child(container)
	var chosen: Array[Vector2i] = []
	for kind in PROP_NAMES:
		var best := Vector2i(-1, -1)
		var best_score := -INF
		var best_pose := Transform3D.IDENTITY
		var model_bounds := _mesh_bounds(models[kind])
		for cell in candidates:
			var distance := 100.0
			for point in chosen:
				distance = minf(distance, cell.distance_squared_to(point))
			if distance < 9.0:
				continue
			var pose := _placement(models[kind], cell, kind, columns, rows, tiles)
			if not _has_ground_clearance(pose * model_bounds, columns, rows, tiles):
				continue
			# 같은 맵의 재진입은 같은 배치. 넓게 분산하되 타일마다 반복하지 않는다.
			var tie := float(posmod(cell.x * 73 + cell.y * 137 + columns * 19 + rows * 11, 997)) / 997.0
			var score := distance + tie
			if chosen.is_empty():
				# 첫 기둥은 상대적으로 뒤쪽 외곽에 두어 전장 중심을 가리지 않는다.
				score = float(columns + rows - cell.x - cell.y) + tie
			if score > best_score:
				best = cell
				best_score = score
				best_pose = pose
		if best.x < 0:
			continue
		var instance: Node3D = models[kind].duplicate()
		instance.transform = best_pose
		instance.set_meta("grid_cell", best)
		instance.set_meta("prop_kind", kind)
		container.add_child(instance)
		chosen.append(best)
		candidates.erase(best)
	return true
