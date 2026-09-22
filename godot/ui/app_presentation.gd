extends RefCounted
## The independent simulation uses one world unit per tile. Existing Canvas
## artwork has 48-pixel literals (bar height, glyph size, impact line width).
## Normalize ONLY the fresh decorated frame, never its runtime/base state.
const LOGICAL_TILE := 48.0

static func normalize(frame: Dictionary) -> Dictionary:
	var presentation: Dictionary = frame.get("presentation",{})
	var labels: Dictionary = presentation.get("labels",{})
	var source_tile := maxf(0.001,float(labels.get("logicalTileSize",LOGICAL_TILE)))
	var ratio := LOGICAL_TILE/source_tile
	if not labels.is_empty() and not is_equal_approx(source_tile,LOGICAL_TILE):
		for enemy: Dictionary in labels.get("enemies",[]):
			var dimensions: Array = enemy.get("size",[])
			if dimensions.size() == 2:
				enemy.size = [float(dimensions[0])*ratio,float(dimensions[1])*ratio]
		labels.logicalTileSize = LOGICAL_TILE
		# Core geometry derives its size from logicalTileSize. Its position and
		# enemy positions are ALREADY tile coordinates and must not be scaled.
	var effects: Dictionary = presentation.get("effects",{})
	for field in ["items","events"]:
		for effect: Dictionary in effects.get(field,[]):
			_normalize_effect(effect)
	# World shake is consumed as screen pixels, unlike the tile-space anchors.
	if not is_equal_approx(source_tile,LOGICAL_TILE):
		var shake: Array = effects.get("shake",[])
		if shake.size() == 2: effects.shake = [float(shake[0])*ratio,float(shake[1])*ratio]
	return frame

static func _normalize_effect(effect: Dictionary) -> void:
	var source_tile := maxf(0.001,float(effect.get("tileSize",LOGICAL_TILE)))
	if is_equal_approx(source_tile,LOGICAL_TILE): return
	var ratio := LOGICAL_TILE/source_tile
	if effect.has("scale"): effect.scale = float(effect.scale)*ratio
	if effect.has("radius"): effect.radius = float(effect.radius)*ratio
	# Native damage offsets are created with fixed 34-pixel/sec motion and its
	# font is a fixed 15 pixels: both are already canonical logical pixels.
	# Other offsets, when provided, follow the effect's source-scaled geometry.
	if effect.get("kind") != "damage":
		var offset: Array = effect.get("screenOffset",[])
		if offset.size() == 2: effect.screenOffset = [float(offset[0])*ratio,float(offset[1])*ratio]
	effect.tileSize = LOGICAL_TILE
	# x/y, points/endpoints, and attachmentRadius are tile-space anchors.
	# Top-level 3D impacts/projectiles likewise already use tile units.
