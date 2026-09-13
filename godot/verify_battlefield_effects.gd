extends SceneTree

const Effects = preload("res://ui/battlefield_effects.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var effects := Effects.new()
	root.add_child(effects)
	assert(effects._font.variation_opentype.get(Effects.WEIGHT_AXIS) == 900.0, "source w900 font weight must use the numeric OpenType tag")
	assert(effects._font.base_font.fallbacks[0].variation_opentype.get(Effects.WEIGHT_AXIS) == 900.0, "Korean fallback must preserve the same w900 weight")
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 8, 6)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	var items := []
	var id := 0
	for kind in ["damage", "diamond", "charge", "chain", "coreBeam", "rift", "gem", "death"]:
		id += 1
		items.append({"id": id, "kind": kind, "age": 0.1, "duration": 0.75, "x": 5.0, "y": 5.0, "tileSize": 48.0, "color": 0xffabcdef, "text": "약점 +123", "feedback": "weak", "motion": "fallArc", "radius": 24.0, "scale": 1.0, "hasImage": true, "points": [[5, 5], [6, 6]], "enemyType": "boss", "enemyTypeIndex": 5})
	for style in ["spark", "sniperBlast", "flame", "frost", "lightning", "lightningBlast"]:
		id += 1
		items.append({"id": id, "kind": "impact", "style": style, "age": 0.1, "duration": 0.28, "x": 5.0, "y": 5.0, "tileSize": 48.0, "color": 0xffabcdef, "radius": 24.0})
	effects.apply_frame({"items": items})
	effects.present(camera, Vector2(10, 10), world)
	assert(effects.items.size() == 14)
	assert(effects._effect_nodes.size() == 14)
	var stable_surface: Node2D = effects._effect_nodes[1]
	var gem_surface: Node2D = effects._effect_nodes[7]
	assert(gem_surface.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "gem seal/sparks/glow must preserve Flutter BlendMode.plus")
	assert(gem_surface.mix_surface.material == null and not gem_surface.mix_surface.use_parent_material, "gem solid fill must use normal alpha over its additive glow")
	var reference := {"kind": "death", "x": 5.0, "y": 5.0, "tileSize": 48.0}
	var origin := camera.unproject_position(world.to_global(Vector3.ZERO))
	var bx := (camera.unproject_position(world.to_global(Vector3.RIGHT)) - origin) / 48.0
	var by := (camera.unproject_position(world.to_global(Vector3.BACK)) - origin) / 48.0
	assert(not is_equal_approx(bx.length(), by.length()), "fixture must distinguish ground tilt from billboard")
	for kind in ["death", "impact", "gem", "charge", "chain", "coreBeam", "rift"]:
		reference["kind"] = kind
		var pose: Transform2D = effects.effect_transform(reference)
		assert(pose.origin.is_equal_approx(origin), "effects must retain source height 0")
		assert(pose.x.is_equal_approx(bx) and pose.y.is_equal_approx(by), "%s must preserve the original ground Canvas transform" % kind)
	for kind in ["damage", "diamond"]:
		reference["kind"] = kind
		reference["screenOffset"] = [12.0, -18.0]
		var pose: Transform2D = effects.effect_transform(reference)
		var moving_anchor := camera.unproject_position(world.to_global(Vector3(12.0 / 48.0, 0, -18.0 / 48.0)))
		assert(pose.origin.is_equal_approx(moving_anchor), "%s moving source coordinates must use ground projection" % kind)
		assert(pose.x.is_equal_approx(Vector2(bx.length(), 0)) and pose.y.is_equal_approx(Vector2(0, bx.length())), "%s glyph alone must remain billboard" % kind)
	var original_age: float = effects.items[0]["age"]
	effects.apply_frame({"items": items})
	assert(effects.items.size() == 14, "repeated frame must not duplicate effects")
	assert(effects._effect_nodes[1] == stable_surface, "same effect ID must reuse its canvas surface")
	assert(effects.items[0]["age"] == original_age, "repeated frame must not restart age")
	items[0]["age"] = 0.5
	assert(effects.items[0]["age"] == original_age, "effect state must own its snapshot")
	for frame in range(4):
		await process_frame
	assert(effects.items[0]["age"] == original_age, "presentation must not advance simulation during pause")
	camera.position = Vector3(0, 10, 0.01)
	camera.look_at(Vector3.ZERO)
	effects.present(camera, Vector2(10, 10), world)
	for frame in range(2):
		await process_frame
	effects.apply_frame({"items": [items[0]]})
	assert(effects._effect_nodes.size() == 1 and effects.get_child_count() == 1, "removed effects must free both blend passes")
	effects.clear()
	assert(effects.items.is_empty() and effects._effect_nodes.is_empty() and effects.get_child_count() == 0)
	print("Battlefield effects: original ground/billboard transforms, anchor movement, additive gem passes, duplicate frame, pause, copy ownership, camera and all effect kinds passed")
	quit(0)
