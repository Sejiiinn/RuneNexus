extends RefCounted

## 3장 전장 외곽의 부유 철골. 맵 데이터만으로 위치를 정해 같은 맵은 같은 배치를 유지한다.
const Props = preload("res://environment/chapter_three_props.gd")
const MODEL_PATH := "res://assets/environment/chapter3_floating_girders.glb"
const KINDS = ["girder_long_torn", "girder_bent_ripped", "girder_twisted_stub"]
## 시안의 넓은 H형 토막·두꺼운 찢긴 철판은 맵마다 소량(1~2개)만 섞는다.
const RARE_KINDS = ["girder_wide_flange_stub", "debris_torn_plate"]
const ALL_KINDS = KINDS + RARE_KINDS
## 넓은 철판은 기본 크기(약 0.85~1.1타일), 무거운 H형 토막은 조금 줄인다.
const RARE_SCALE = {"girder_wide_flange_stub": .85, "debris_torn_plate": 1.0}
const MIN_COUNT := 3
const MAX_COUNT := 7
## 실제 타일·벽 소품과 띄우는 최소 간격(타일 단위).
const CLEARANCE := .14
## 전투 시간 기준의 느린 상하 부유와 미세한 흔들림.
const BOB_HEIGHT := .035
const SWAY_ANGLE := .07

static func _occupied_rect(map: Dictionary) -> Rect2i:
	var columns := int(map["columns"])
	var tiles: Array = map["tiles"]
	var result := Rect2i()
	var initialized := false
	for index in range(tiles.size()):
		if tiles[index] == "blocked":
			continue
		var tile := Rect2i(index % columns, floori(float(index) / columns), 1, 1)
		result = result.merge(tile) if initialized else tile
		initialized = true
	return result

## 활성 영역 안 빈칸 12칸당 1개(3~7개). 3-1~3-5는 3개, 넓은 3-6~3-10은 4~7개가 된다.
static func target_count(map: Dictionary) -> int:
	var area := _occupied_rect(map)
	var columns := int(map["columns"])
	var empty := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if map["tiles"][y * columns + x] == "blocked":
				empty += 1
	return clampi(roundi(empty / 12.0), MIN_COUNT, MAX_COUNT)

static func rare_count(map: Dictionary) -> int:
	return 1 if target_count(map) < 6 else 2

static func total_count(map: Dictionary) -> int:
	return target_count(map) + rare_count(map)

static func _tile_rects(map: Dictionary) -> Array[Rect2]:
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var tiles: Array = map["tiles"]
	var rects: Array[Rect2] = []
	for index in range(tiles.size()):
		if tiles[index] != "blocked":
			var origin := Vector2(index % columns - columns / 2.0, floori(float(index) / columns) - rows / 2.0)
			rects.append(Rect2(origin, Vector2.ONE).grow(CLEARANCE))
	return rects

static func layout(library: Node3D, map: Dictionary, avoid: Array[Rect2] = []) -> Array[Dictionary]:
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var tiles: Array = map["tiles"]
	var area := _occupied_rect(map).grow(1)
	var blocked_rects := _tile_rects(map)
	for rect in avoid:
		blocked_rects.append(rect.grow(CLEARANCE))
	# 활성 영역과 한 칸 바깥 테두리의 빈칸 중 판에서 두 칸 안쪽만 쓴다.
	# 안쪽 빈 공간과 판 바로 옆을 우선해 멀리 떨어진 모서리로 흩어지지 않게 한다.
	var occupied: Array[Vector2i] = []
	for index in range(tiles.size()):
		if tiles[index] != "blocked":
			occupied.append(Vector2i(index % columns, floori(float(index) / columns)))
	var candidates: Array[Dictionary] = []
	var inner := _occupied_rect(map)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			var inside := x >= 0 and y >= 0 and x < columns and y < rows
			if inside and tiles[y * columns + x] != "blocked":
				continue
			var near := 99
			for tile in occupied:
				near = mini(near, maxi(absi(tile.x - x), absi(tile.y - y)))
			if near <= 2:
				candidates.append({"cell": cell, "inner": inner.has_point(cell), "near": near})
	var rng := RandomNumberGenerator.new()
	# 전역 난수와 전투 상태를 건드리지 않는다.
	rng.seed = JSON.stringify(tiles).hash() ^ 0x5a17
	var poses := {}
	for candidate in candidates:
		poses[candidate["cell"]] = {
			"jitter": Vector2(rng.randf_range(-.22, .22), rng.randf_range(-.22, .22)),
			"height": rng.randf_range(-.35, .12),
			# 원본 형태를 유지한 채 시안의 큰 잔해 크기로 키운다.
			"scale": rng.randf_range(1.45, 1.85),
			"yaw": rng.randf_range(0, TAU),
			"pitch": rng.randf_range(-.6, .6),
			"roll": rng.randf_range(-.45, .45),
			"phase": rng.randf_range(0, TAU),
			"tie": rng.randf(),
		}
	var target := target_count(map)
	var total := target + rare_count(map)
	var rare_start := posmod(JSON.stringify(tiles).hash(), RARE_KINDS.size())
	var result: Array[Dictionary] = []
	for minimum_spacing_squared: float in [6.25, 2.25]:
		while result.size() < total:
			var slot := result.size()
			var rare := slot >= target
			var kind: String = RARE_KINDS[(rare_start + slot - target) % RARE_KINDS.size()] if rare else KINDS[slot % KINDS.size()]
			var source := library.find_child(kind, true, false) as Node3D
			if source == null:
				return []
			var local_bounds := Props.mesh_bounds(source)
			var best := {}
			var best_score := -INF
			for candidate in candidates:
				var cell: Vector2i = candidate["cell"]
				var pose: Dictionary = poses[cell]
				var distance := 100.0
				for previous in result:
					distance = minf(distance, Vector2(cell).distance_squared_to(Vector2(previous["cell"])))
				if distance < minimum_spacing_squared:
					continue
				var jitter: Vector2 = pose["jitter"]
				var center := Vector2(cell.x + .5 - columns / 2.0, cell.y + .5 - rows / 2.0) + jitter
				var basis := (Basis(Vector3.UP, float(pose["yaw"])) * Basis(Vector3.RIGHT, float(pose["pitch"])) * Basis(Vector3.FORWARD, float(pose["roll"]))).scaled(Vector3.ONE * float(pose["scale"]) * (float(RARE_SCALE[kind]) if rare else 1.0))
				var transform := Transform3D(basis, Vector3(center.x, float(pose["height"]), center.y))
				var bounds := transform * local_bounds
				# 상하 부유 범위까지 포함해 타일·벽 소품과 겹치지 않게 한다.
				var area_xz := Props.footprint(bounds)
				if blocked_rects.any(func(rect: Rect2) -> bool: return rect.intersects(area_xz)):
					continue
				if result.any(func(previous: Dictionary) -> bool: return Props.footprint(previous["bounds"]).grow(.1).intersects(area_xz)):
					continue
				var score := minf(distance, 16.0) + (6.0 if candidate["inner"] else 0.0) + (2.0 if candidate["near"] == 1 else 0.0) + float(pose["tie"])
				if score > best_score:
					best_score = score
					best = {"kind": kind, "cell": cell, "pose": transform, "bounds": bounds, "phase": pose["phase"]}
			if best.is_empty():
				break
			result.append(best)
	return result

static func populate(terrain: Node3D, library: Node3D, map: Dictionary) -> Array[Dictionary]:
	# 이미 배치된 벽 부착 소품의 실제 메시 범위를 피한다.
	var avoid: Array[Rect2] = []
	var props := terrain.get_node_or_null("chapter_three_props")
	if props != null:
		for prop: Node3D in props.get_children():
			avoid.append(Props.footprint(Props.mesh_bounds(prop)))
	var entries := layout(library, map, avoid)
	var container := Node3D.new()
	container.name = "chapter_three_debris"
	terrain.add_child(container)
	var floating: Array[Dictionary] = []
	for entry in entries:
		var source := library.find_child(entry["kind"], true, false) as Node3D
		var instance := source.duplicate() as Node3D
		instance.transform = entry["pose"]
		instance.set_meta("debris_kind", entry["kind"])
		instance.set_meta("grid_cell", entry["cell"])
		container.add_child(instance)
		floating.append({"node": instance, "rest": entry["pose"], "phase": entry["phase"]})
	return floating

## 렌더 프레임마다 확정 전투 시간으로 위치를 정한다. 같은 시간은 같은 자세다.
static func animate(floating: Array[Dictionary], time: float) -> void:
	for item in floating:
		var node: Node3D = item["node"]
		if not is_instance_valid(node):
			continue
		var rest: Transform3D = item["rest"]
		var phase: float = item["phase"]
		var sway := Basis(Vector3.UP, sin(time * .21 + phase) * SWAY_ANGLE) * Basis(Vector3.RIGHT, sin(time * .33 + phase * 1.7) * SWAY_ANGLE * .5)
		node.transform = Transform3D(sway * rest.basis, rest.origin + Vector3(0, sin(time * .55 + phase) * BOB_HEIGHT, 0))
