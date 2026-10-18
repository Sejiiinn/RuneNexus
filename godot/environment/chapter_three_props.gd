extends RefCounted

const Tiles = preload("res://environment/chapter_three_tiles.gd")
const KINDS = ["elbow_pipe", "side_conduit", "exhaust_vent"]

static func _inside(cell: Vector2i, columns: int, rows: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows

## 외부와 연결된 빈 영역만 선택해 전장 내부 구멍을 장식하지 않는다.
static func exterior_cells(map: Dictionary) -> Dictionary:
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var tiles: Array = map["tiles"]
	var exterior := {}
	var pending: Array[Vector2i] = []
	for index in range(tiles.size()):
		var cell := Vector2i(index % columns, floori(float(index) / columns))
		if tiles[index] == "blocked" and (cell.x == 0 or cell.y == 0 or cell.x == columns - 1 or cell.y == rows - 1):
			exterior[cell] = true
			pending.append(cell)
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		for direction: Vector2i in Tiles.SIDE_STEPS:
			var neighbor := cell + direction
			if _inside(neighbor, columns, rows) and not exterior.has(neighbor) and tiles[neighbor.y * columns + neighbor.x] == "blocked":
				exterior[neighbor] = true
				pending.append(neighbor)
	return exterior

static func mesh_bounds(node: Node3D, parent_pose := Transform3D.IDENTITY) -> AABB:
	var pose := parent_pose * node.transform
	var result := AABB()
	var initialized := false
	if node is MeshInstance3D:
		result = pose * node.get_aabb()
		initialized = true
	for child in node.get_children():
		if child is Node3D:
			var bounds := mesh_bounds(child, pose)
			result = result.merge(bounds) if initialized else bounds
			initialized = true
	return result

static func footprint(bounds: AABB) -> Rect2:
	return Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))

static func clear_of_play(bounds: AABB, map: Dictionary) -> bool:
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var tiles: Array = map["tiles"]
	var area := footprint(bounds)
	for index in range(tiles.size()):
		if tiles[index] == "blocked":
			continue
		var center := Vector2(index % columns + .5 - columns / 2.0, floori(float(index) / columns) + .5 - rows / 2.0)
		# 외벽 Z=.45의 부착은 허용하고 실제 상판 안쪽은 비운다.
		if area.intersects(Rect2(center - Vector2.ONE * .449, Vector2.ONE * .898)):
			return false
	return true

const BASE_COUNT := 5
const MAX_COUNT := 12

## 3-1~3-5의 5개 밀도를 기준으로 둔다. 타일이 성기게 퍼져 빈 공간이 넓은 맵만
## 노출 벽면 8면당 1개까지 늘린다. 맵 데이터만으로 정해 같은 맵은 같은 수를 유지한다.
static func target_count(map: Dictionary) -> int:
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var tiles: Array = map["tiles"]
	var low := Vector2i(columns, rows)
	var high := Vector2i(-1, -1)
	var occupied := 0
	var walls := 0
	for index in range(tiles.size()):
		if tiles[index] == "blocked":
			continue
		var cell := Vector2i(index % columns, floori(float(index) / columns))
		low = low.min(cell)
		high = high.max(cell)
		occupied += 1
		if tiles[index] not in ["path", "build"]:
			continue
		for side in range(4):
			if Tiles.exposed(map, index, side):
				walls += 1
	if occupied == 0:
		return BASE_COUNT
	var area := (high.x - low.x + 1) * (high.y - low.y + 1)
	if float(occupied) / area >= .56:
		return BASE_COUNT
	return clampi(roundi(walls / 8.0), BASE_COUNT, MAX_COUNT)

## exterior_only=false이면 맵 안쪽의 두 칸 이상 빈 공간을 향한 외벽도 후보로 쓴다.
static func _candidates(map: Dictionary, exterior_only: bool) -> Array[Dictionary]:
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var tiles: Array = map["tiles"]
	var exterior := exterior_cells(map)
	var vents := {}
	for entry: Dictionary in Tiles.panel_layout(map):
		if entry["kind"] == "panel_vent":
			vents[int(entry["index"]) * 4 + int(entry["side"])] = true
	var landmarks: Array[Vector2i] = []
	for index in range(tiles.size()):
		if tiles[index] in ["spawn", "core"]:
			landmarks.append(Vector2i(index % columns, floori(float(index) / columns)))
	if not exterior_only:
		# 추가 소품은 전송 장치 주변도 비워 입·출구 표시를 가리지 않는다.
		for pair: Dictionary in map.get("teleportPairs", []):
			for role in ["entrance", "exit"]:
				landmarks.append(Vector2i(int(pair[role][0]), int(pair[role][1])))
	var candidates: Array[Dictionary] = []
	for index in range(tiles.size()):
		if tiles[index] not in ["path", "build"]:
			continue
		var cell := Vector2i(index % columns, floori(float(index) / columns))
		if landmarks.any(func(point: Vector2i) -> bool: return point.distance_squared_to(cell) <= 2):
			continue
		for side in range(4):
			if vents.has(index * 4 + side):
				continue
			var outward: Vector2i = Tiles.SIDE_STEPS[side]
			var open := true
			for distance: int in [1, 2]:
				var neighbor := cell + outward * distance
				if not _inside(neighbor, columns, rows):
					continue
				if (exterior_only and not exterior.has(neighbor)) or tiles[neighbor.y * columns + neighbor.x] != "blocked":
					open = false
			if open:
				candidates.append({"index": index, "side": side, "cell": cell})
	return candidates

static func _pose(candidate: Dictionary, map: Dictionary) -> Transform3D:
	var cell: Vector2i = candidate["cell"]
	var rotation := Basis(Vector3.UP, float(candidate["side"]) * PI / 2.0)
	var offset := Vector3(0, 0, .45) # 공용 원점: 외벽 상단, +Z가 바깥쪽
	var point := Vector3(cell.x + .5 - int(map["columns"]) / 2.0, 0, cell.y + .5 - int(map["rows"]) / 2.0)
	return Transform3D(rotation, point + rotation * offset)

## 가장 가까운 기존 소품과의 칸 거리 제곱. 실제 메시가 겹치면 -1.
static func _clearance(bounds: AABB, cell: Vector2i, placed: Array[Dictionary]) -> float:
	var distance := 100.0
	for previous in placed:
		distance = minf(distance, cell.distance_squared_to(previous["cell"]))
		if footprint(bounds).intersects(footprint(previous["bounds"]).grow(.12)):
			return -1.0
	return distance

static func layout(library: Node3D, map: Dictionary) -> Array[Dictionary]:
	var result := _base_layout(library, map)
	var target := target_count(map)
	if result.size() < BASE_COUNT or target <= result.size():
		return result
	# 기존 5개 위치는 그대로 두고, 넓은 맵에서만 안쪽 빈 공간을 향한 벽까지 넓혀 추가한다.
	var candidates := _candidates(map, false)
	for minimum_spacing_squared: float in [9.0, 4.0]:
		while result.size() < target:
			var kind: String = KINDS[result.size() % KINDS.size()]
			var source := library.find_child(kind, true, false) as Node3D
			if source == null:
				return []
			var local_bounds := mesh_bounds(source)
			var best := {}
			# 고정 카메라에서 보이는 +Z·+X 외벽을 먼저 채우고, 없을 때만 뒤쪽 면을 쓴다.
			for sides: Array in [[0, 1], [0, 1, 2, 3]]:
				var best_score := -INF
				for candidate in candidates:
					var side: int = candidate["side"]
					if side not in sides:
						continue
					var pose := _pose(candidate, map)
					var bounds := pose * local_bounds
					if not clear_of_play(bounds, map):
						continue
					var distance := _clearance(bounds, candidate["cell"], result)
					if distance < minimum_spacing_squared:
						continue
					var score := distance + (.3 if kind == "exhaust_vent" and side == 0 else 0.0) + float(posmod(candidate["index"] * 73 + side * 29, 101)) / 1000.0
					if score > best_score:
						best_score = score
						best = candidate.duplicate()
						best.merge({"kind": kind, "pose": pose, "bounds": bounds})
				if not best.is_empty():
					break
			if best.is_empty():
				break
			result.append(best)
	return result

static func _base_layout(library: Node3D, map: Dictionary, minimum_spacing_squared := 9.0) -> Array[Dictionary]:
	var candidates := _candidates(map, true)
	var result: Array[Dictionary] = []
	for slot in range(BASE_COUNT):
		var kind: String = KINDS[slot % KINDS.size()]
		var source := library.find_child(kind, true, false) as Node3D
		if source == null:
			return []
		var local_bounds := mesh_bounds(source)
		var best := {}
		var best_score := -INF
		var best_front := false
		for candidate in candidates:
			var cell: Vector2i = candidate["cell"]
			var side: int = candidate["side"]
			# 각 종류의 첫 배치는 고정 카메라 쪽 외벽에 둔다.
			if slot < 3 and side not in [0, 1]:
				continue
			var pose := _pose(candidate, map)
			var bounds := pose * local_bounds
			if not clear_of_play(bounds, map):
				continue
			var distance := _clearance(bounds, cell, result)
			if distance < minimum_spacing_squared:
				continue
			var score := distance + (.3 if side in [0, 1] else 0.0) + float(posmod(candidate["index"] * 73 + side * 29, 101)) / 1000.0
			if result.is_empty():
				score = -float(cell.x + cell.y) + (.3 if side in [0, 1] else 0.0)
			# 배기구의 주황 전면은 +Z 쪽 외벽에서 가장 잘 읽힌다.
			# 안전한 +Z 후보가 없을 때만 기존 +X 후보를 사용한다.
			var front := slot == 2 and side == 0
			if (front and not best_front) or (front == best_front and score > best_score):
				best_front = front
				best_score = score
				best = candidate.duplicate()
				best.merge({"kind": kind, "pose": pose, "bounds": bounds})
		if not best.is_empty():
			result.append(best)
	# 좁고 긴 맵에서만 간격을 3칸에서 2칸으로 줄인다. 실제 메시 간격·외벽·환기구 검사는 유지한다.
	# 기존 5개 배치가 가능한 맵(11)은 처음 선택한 위치를 그대로 사용한다.
	if result.size() < BASE_COUNT and minimum_spacing_squared > 4.0:
		return _base_layout(library, map, 4.0)
	return result

static func populate(terrain: Node3D, library: Node3D, map: Dictionary) -> bool:
	var entries := layout(library, map)
	if entries.size() < BASE_COUNT:
		return false
	var container := Node3D.new()
	container.name = "chapter_three_props"
	terrain.add_child(container)
	for entry in entries:
		var source := library.find_child(entry["kind"], true, false) as Node3D
		var instance := source.duplicate() as Node3D
		instance.transform = entry["pose"]
		instance.set_meta("prop_kind", entry["kind"])
		instance.set_meta("grid_cell", entry["cell"])
		instance.set_meta("mount_side", entry["side"])
		container.add_child(instance)
	return true
