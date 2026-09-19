extends "res://ui/battlefield_selection.gd"
## Validation-only A/B switch. Production source and visibility policy stay intact.
var cache_enabled := true

func prepare_context(camera: Camera3D, map_size: Vector2, world: Node3D, redraw := true) -> void:
	if cache_enabled:
		super.prepare_context(camera, map_size, world, redraw)
	else:
		# Exact pre-cache context preparation, without cache invalidation overhead.
		_camera = camera
		_world = world
		_map_size = map_size
		_tile = maxf(float(_frame.get("logicalTileSize", 48.0)), 1.0)
		if redraw:
			queue_redraw()

func _range_path(center: Vector2, radius: float) -> PackedVector2Array:
	return super._range_path(center, radius) if cache_enabled else _path(center, radius)
