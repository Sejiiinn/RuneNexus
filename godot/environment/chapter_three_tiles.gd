extends RefCounted

## 포탈에서 이동칸을 따라 네 칸마다 그레이팅을 배치한다. 맵 데이터는 바꾸지 않는다.
static func variants(map: Dictionary) -> Dictionary:
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var tiles: Array = map["tiles"]
	var distances := {}
	var pending: Array[int] = []
	for index in range(tiles.size()):
		if tiles[index] == "spawn":
			distances[index] = 0
			pending.append(index)
	var result := {}
	for index in range(tiles.size()):
		if tiles[index] == "build":
			var cell := Vector2i(index % columns, floori(float(index) / columns))
			result[index] = "plain_build_tile" if (cell.x * 3 + cell.y * 5) % 4 < 2 else "build_tile"
	var cursor := 0
	while cursor < pending.size():
		var index := pending[cursor]
		cursor += 1
		var cell := Vector2i(index % columns, floori(float(index) / columns))
		if tiles[index] == "path" and int(distances[index]) % 4 == 0:
			result[index] = "grate_tile"
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if next.x < 0 or next.y < 0 or next.x >= columns or next.y >= rows:
				continue
			var neighbor := next.y * columns + next.x
			if not distances.has(neighbor) and tiles[neighbor] in ["path", "core"]:
				distances[neighbor] = int(distances[index]) + 1
				pending.append(neighbor)
	return result

## 패널은 타일 중심 원점을 공유하며 +Z, +X, -Z, -X 순서로 회전한다.
const SIDE_STEPS = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]

static func exposed(map: Dictionary, index: int, side: int) -> bool:
	var columns := int(map["columns"])
	var cell: Vector2i = Vector2i(index % columns, floori(float(index) / columns)) + SIDE_STEPS[side]
	return cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= int(map["rows"]) or map["tiles"][cell.y * columns + cell.x] == "blocked"

static func panel_layout(map: Dictionary) -> Array[Dictionary]:
	var columns := int(map["columns"])
	var tiles: Array = map["tiles"]
	var tile_variants := variants(map)
	var rng := RandomNumberGenerator.new()
	# 전역 난수와 전투 상태를 건드리지 않고 같은 맵은 같은 장식을 유지한다.
	rng.seed = JSON.stringify(tiles).hash()
	var candidates: Array[Dictionary] = []
	for index in range(tiles.size()):
		if tiles[index] not in ["path", "build"]:
			continue
		var sides: Array[int] = []
		for side in range(4):
			if exposed(map, index, side):
				sides.append(side)
		if sides.is_empty():
			continue
		# 카메라 쪽 면이 노출된 칸은 그 면들 중 선택한다.
		var visible_sides := sides.filter(func(side: int) -> bool: return side in [0, 1])
		var side_choices: Array = visible_sides if not visible_sides.is_empty() else sides
		candidates.append({
			"index": index,
			"side": side_choices[rng.randi_range(0, side_choices.size() - 1)],
			"cell": Vector2i(index % columns, floori(float(index) / columns)),
			"category": tile_variants[index] if tiles[index] == "build" else "path",
			"rank": rng.randf(),
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["rank"] < b["rank"])
	var vents := {}
	var selected: Array[Vector2i] = []
	var limit := maxi(1, floori(float(tiles.size() - tiles.count("blocked")) / 10.0))
	# 두 건설 타일과 길에서 각각 뽑은 뒤 남은 수량은 전체 후보에서 뽑는다.
	var passes: Array[String] = ["build_tile", "plain_build_tile", "path"]
	for slot in range(limit):
		passes.append("")
	for category in passes:
		if vents.size() >= limit:
			break
		for candidate in candidates:
			if vents.has(candidate["index"]) or (category != "" and candidate["category"] != category):
				continue
			if selected.any(func(cell: Vector2i) -> bool:
				var delta: Vector2i = cell - candidate["cell"]
				return absi(delta.x) + absi(delta.y) < 2):
				continue
			vents[candidate["index"]] = candidate["side"]
			selected.append(candidate["cell"])
			break
	var layout: Array[Dictionary] = []
	for index in range(tiles.size()):
		if tiles[index] == "blocked":
			continue
		for side in range(4):
			layout.append({"index": index, "side": side, "kind": "panel_vent" if vents.get(index, -1) == side else "panel_solid"})
	return layout

## 공용 패널 메시를 두 묶음으로 배치한다. 맵 변경 시에만 생성한다.
static func populate_panels(terrain: Node3D, library: Node3D, map: Dictionary) -> bool:
	var layout := panel_layout(map)
	var group := Node3D.new()
	group.name = "chapter_three_panels"
	terrain.add_child(group)
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	for kind in ["panel_solid", "panel_vent"]:
		var source := library.find_child(kind, true, false) as MeshInstance3D
		if source == null:
			return false
		var entries := layout.filter(func(entry: Dictionary) -> bool: return entry["kind"] == kind)
		var batch := MultiMeshInstance3D.new()
		batch.name = kind
		batch.layers = source.layers
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = source.mesh
		batch.multimesh.instance_count = entries.size()
		batch.set_meta("panel_entries", entries)
		group.add_child(batch)
		for slot in range(entries.size()):
			var entry: Dictionary = entries[slot]
			var index: int = entry["index"]
			var point := Vector3(index % columns + .5 - columns / 2.0, 0.0, floori(float(index) / columns) + .5 - rows / 2.0)
			batch.multimesh.set_instance_transform(slot, Transform3D(Basis(Vector3.UP, float(entry["side"]) * PI / 2.0), point))
	return true
