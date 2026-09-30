extends RefCounted
## Optional map feature. Compile tile coordinates to stable original-path indices.
static func validate_map(map: Dictionary) -> String:
	var pairs: Variant = map.get("teleportPairs",[])
	if not pairs is Array: return "teleportPairs must be an array"
	# Legacy presentation-only maps may omit a route entirely.
	if not map.has("path"): return "" if pairs.is_empty() else "Missing teleport path"
	if not map.path is Array: return "Invalid teleport path"
	var colors := {}
	var occupied := {}
	var jumps := {}
	for pair in pairs:
		if not pair is Dictionary or pair.get("color") not in ["blue","orange"]: return "Invalid teleport color"
		if colors.has(pair.color): return "Duplicate teleport color: " + pair.color
		colors[pair.color] = true
		var indices := []
		for role in ["entrance","exit"]:
			var point: Variant = pair.get(role)
			if not point is Array or point.size() != 2 or not point[0] is int or not point[1] is int: return "Invalid teleport " + role + " coordinates"
			if point[0] < 0 or point[1] < 0 or point[0] >= map.columns or point[1] >= map.rows: return "Teleport endpoint outside map"
			if map.tiles[point[1]*map.columns+point[0]] != "path": return "Teleport endpoint must be a path tile"
			if map.path.count(point) != 1: return "Teleport endpoint must occur once on original path"
			var index: int = map.path.find(point)
			if occupied.has(index): return "Overlapping teleport endpoints"
			occupied[index] = true
			indices.append(index)
		if indices[0] >= indices[1]: return "Teleport entrance must precede exit"
		jumps[indices[0]] = indices[1]
	for index in range(map.path.size()-1):
		var from: Array = map.path[index]
		var to: Array = map.path[index+1]
		if absi(from[0]-to[0])+absi(from[1]-to[1]) != 1 and jumps.get(index,-1) != index+1:
			return "Disconnected path edge must be a teleport entrance-to-exit jump"
	return ""

static func compile_map(map: Dictionary) -> Array:
	var result := []
	for pair in map.get("teleportPairs",[]):
		result.append({"color":pair.color,"entranceIndex":map.path.find(pair.entrance),"exitIndex":map.path.find(pair.exit)})
	return result

static func validate_compiled(pairs: Variant,path: Variant) -> String:
	if not pairs is Array: return "teleportPairs must be an array"
	if pairs.is_empty(): return ""
	if not path is Array: return "Teleport path must be an array"
	var colors := {}
	var occupied := {}
	for pair in pairs:
		if not pair is Dictionary or pair.get("color") not in ["blue","orange"]: return "Invalid teleport color"
		if colors.has(pair.color): return "Duplicate teleport color"
		colors[pair.color] = true
		if not pair.get("entranceIndex") is int or not pair.get("exitIndex") is int: return "Teleport indices must be integers"
		if pair.entranceIndex < 0 or pair.exitIndex >= path.size() or pair.entranceIndex >= pair.exitIndex: return "Invalid teleport index order"
		for index in [pair.entranceIndex,pair.exitIndex]:
			if occupied.has(index): return "Overlapping teleport endpoints"
			occupied[index] = true
	return ""
