extends "res://environment/battlefield_environment_build.gd"
## Battlefield environment entry: per-frame updates, occupancy, clear and dispose.
## Layers below it (state -> libraries -> build) may only call downward; GDScript
## rejects an upward call at parse time.

func update_occupancy(units: Array, supported_types: Dictionary, extra_tiles: Array = []) -> void:
	var occupied := Vector2i.ZERO
	if _using_dressing:
		var tiles: Array = extra_tiles.duplicate()
		for row: FrameRows.Turret in FrameRows.rows("turrets", units):
			if supported_types.has(row.type):
				tiles.append(Vector2i(floori(row.x), floori(row.y)))
		for tile: Vector2i in tiles:
			var x := tile.x
			var z := tile.y
			if x >= 0 and x < columns and z >= 0 and z < rows:
				var slot := _build_tile_slots[z * columns + x]
				if slot >= 0 and slot < 16:
					occupied.x |= 1 << slot
				elif slot >= 16 and slot < 32:
					occupied.y |= 1 << (slot - 16)
	if occupied != _occupied_build_tiles:
		_occupied_build_tiles = occupied
		if _foliage_material != null:
			_foliage_material.set_shader_parameter("occupied_build_tiles", occupied)

func update_frame(frame: Dictionary) -> void:
	var time := float(frame.get("time", 0.0))
	for device in _teleport_devices:
		device.update_time(time)
	if _portal_material != null:
		_portal_material.set_shader_parameter("battle_time", time)
		_portal_material.set_shader_parameter("alert", clampf(float(frame.get("portalAlert", 0.0)), 0.0, 1.0))
	ChapterThreeDebris.animate(_floating_debris, time)
	var core_hit := clampf(float(frame.get("nexusHit", 0.0)), 0.0, 1.0)
	for core: Dictionary in _cores:
		var crystal: Node3D = core["crystal"]
		# 석재 받침은 고정하고 결정만 원본 피벗에서 부유·회전.
		crystal.position = core["rest_position"] + Vector3(0.0, sin(time * 2.5) * 0.018, 0.0)
		crystal.basis = Basis(Vector3.UP, time * 0.22) * core["rest_basis"]
		crystal.scale *= 1.0 + core_hit * 0.025

func clear() -> void:
	# Lobby/restart clears presentation only; selected-map source resources stay reusable.
	_clear_instances()
	_using_authored = false
	_using_dressing = false
	_using_forge = false
	_using_chapter_environment = false
	_environment_bounds = AABB()

func dispose() -> void:
	clear()
	for property in ["_terrain_library", "_chapter_three_props_library", "_chapter_three_debris_library", "_chapter_three_terrain_library",
			"_chapter_two_terrain_library", "_chapter_two_props_library", "_dressing_library"]:
		_free_library(property)
	_release_paving()
	_release_chapter_environment()
	_release_landmarks()
	for variant: Dictionary in _dressing_variants:
		if is_instance_valid(variant.get("library")):
			variant["library"].free()
		variant.erase("library")
	_foliage_material = null
	_resource_map = {}
	_world_environment.sky = null
	_sky_path = ""
	TeleportDevice.release_resources()
	StageResources.release(_loaded_resource_paths)
	_loaded_resource_paths.clear()
