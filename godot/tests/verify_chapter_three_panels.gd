extends SceneTree

const Tiles = preload("res://environment/chapter_three_tiles.gd")
var failures: Array[String] = []
var checks := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _has(layout: Array[Dictionary], index: int, side: int) -> bool:
	return layout.any(func(entry: Dictionary) -> bool: return entry.index == index and entry.side == side)

func _verify_map(map: Dictionary) -> void:
	var original := map.duplicate(true)
	var layout := Tiles.panel_layout(map)
	var variants := Tiles.variants(map)
	_check(layout == Tiles.panel_layout(map.duplicate(true)), "layout must be deterministic")
	_check(map == original, "layout must not mutate map")
	var columns := int(map.columns)
	var holes := {}
	for pair: Dictionary in map.get("teleportPairs", []):
		for role in ["entrance", "exit"]:
			var cell: Array = pair[role]
			holes[int(cell[1]) * columns + int(cell[0])] = true
	var seen := {}
	for entry: Dictionary in layout:
		var key: int = int(entry.index) * 4 + int(entry.side)
		_check(not seen.has(key), "duplicate panel")
		seen[key] = true
		if entry.kind == "panel_vent":
			_check(Tiles.exposed(map, entry.index, entry.side), "vent must stay exterior")
	for index in range(map.tiles.size()):
		for side in range(4):
			var present := _has(layout, index, side)
			if map.tiles[index] == "blocked":
				_check(not present, "blocked cell must not get panels")
				continue
			if Tiles.exposed(map, index, side):
				_check(present, "map edge or blocked gap panel lost")
				continue
			var step: Vector2i = Tiles.SIDE_STEPS[side]
			var neighbor: int = index + step.x + step.y * columns
			var open_pair: bool = holes.has(index) or holes.has(neighbor) or variants.get(index) == "grate_tile" or variants.get(neighbor) == "grate_tile"
			_check(present == open_pair, "closed/open pair rule failed at %d:%d" % [index, side])
			_check(present == _has(layout, neighbor, (side + 2) % 4), "paired sides must be symmetric")

func _initialize() -> void:
	# All four shared-side directions, borders and blocked holes.
	_verify_map({"columns": 1, "rows": 1, "tiles": ["path"]})
	_verify_map({"columns": 1, "rows": 1, "tiles": ["blocked"]})
	_verify_map({"columns": 2, "rows": 2, "tiles": ["build", "build", "build", "build"]})
	_verify_map({"columns": 3, "rows": 3, "tiles": ["path", "build", "path", "spawn", "core", "build", "path", "blocked", "build"]})
	var line := {"columns": 7, "rows": 1, "tiles": ["spawn", "path", "path", "path", "path", "path", "core"]}
	_verify_map(line)
	_check(Tiles.variants(line).get(4) == "grate_tile", "fixture must contain a real grate")
	var new_stage := line.duplicate(true)
	new_stage["stage"] = 999
	_check(Tiles.panel_layout(new_stage) == Tiles.panel_layout(line), "new stage must use the same placement rule")
	var unknown := {"columns": 2, "rows": 1, "tiles": ["path", "future_tile"]}
	_check(Tiles.panel_layout(unknown).size() == 8, "unknown tile must not be assumed opaque")
	seed(9817)
	var expected_random := randf()
	seed(9817)
	Tiles.panel_layout(line)
	_check(randf() == expected_random, "panel placement must not consume global random state")
	var endpoints := {"columns": 3, "rows": 3, "tiles": ["path", "build", "path", "path", "build", "path", "path", "build", "path"], "teleportPairs": [{"entrance": [1, 1], "exit": [2, 2]}]}
	_verify_map(endpoints)
	var layout := Tiles.panel_layout(endpoints)
	for side in range(4): _check(_has(layout, 4, side), "teleport host sides must remain")
	# The renderer's main terrain foundation for spawn/core is the solid path tile.
	_check(Tiles.panel_layout({"columns": 2, "rows": 1, "tiles": ["spawn", "core"]}).size() == 6, "landmark foundations can occlude")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var maps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
		for map: Dictionary in maps.values(): _verify_map(map)
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
