extends RefCounted
## Static Canvas unit conversion shared by authored effects and legacy frames.
const LOGICAL_TILE := 48.0

static func normalize(effect: Dictionary) -> void:
	var source_tile := maxf(0.001, float(effect.get("tileSize", LOGICAL_TILE)))
	if is_equal_approx(source_tile, LOGICAL_TILE): return
	var ratio := LOGICAL_TILE / source_tile
	if effect.has("scale"): effect.scale = float(effect.scale) * ratio
	if effect.has("radius"): effect.radius = float(effect.radius) * ratio
	# Damage glyphs/offsets already use canonical pixels; anchors stay in tiles.
	if effect.get("kind") != "damage":
		var offset: Array = effect.get("screenOffset", [])
		if offset.size() == 2: effect.screenOffset = [float(offset[0])*ratio, float(offset[1])*ratio]
	effect.tileSize = LOGICAL_TILE

static func prepare(effect: Dictionary) -> Dictionary:
	var result := effect.duplicate(true)
	normalize(result)
	_freeze(result)
	return result

static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for child in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value: _freeze(child)
		value.make_read_only()
