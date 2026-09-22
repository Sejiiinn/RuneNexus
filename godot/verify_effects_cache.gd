extends SceneTree

const Effects = preload("res://ui/battlefield_effects.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _effect(id: int, kind := "damage", age := 0.1) -> Dictionary:
	return {"id": id, "kind": kind, "age": age, "duration": 0.75, "x": 4.0, "y": 4.0,
		"tileSize": 48.0, "color": 0xffabcdef, "scale": 1.0, "radius": 24.0,
		"text": "약점 123", "feedback": "neutral", "motion": "rise", "screenOffset": [0.0, -3.4],
		"points": [[4.0, 4.0], [5.0, 5.0]], "enemyType": "boss", "enemyTypeIndex": 5}

func _verify() -> void:
	var effects := Effects.new()
	root.add_child(effects)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 8, 6)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	effects.prepare_context(camera, Vector2(8, 8), world)

	# Owned dispatch may share immutable entries, never the mutable list container.
	var source := {"items": [_effect(1), _effect(2, "blast")]}
	var original: Dictionary = source.duplicate(true)
	effects.apply_frame(source, true)
	assert(source == original)
	assert(is_same(effects.items[0], source.items[0]))
	assert(not is_same(effects.items, source.items))
	assert(effects.items.size() == 2 and effects._effect_nodes.size() == 1)
	assert(not effects._effect_nodes.has(2), "snapshot blast is exclusively a 3D effect")
	var surface: Node2D = effects._effect_nodes[1]
	var glyph: Node2D = surface.glyph
	var glyph_revision: int = glyph.draw_revision
	var glyph_transform: Transform2D = glyph.transform
	var stable_key: Array = surface.draw_key
	var stable_order: Array = effects._sorted_indices
	effects.apply_frame(source, true)
	effects.prepare_context(camera, Vector2(8, 8), world)
	assert(is_same(stable_key, surface.draw_key), "unchanged age/context must retain draw inputs")
	assert(is_same(stable_order, effects._sorted_indices), "dynamic frame keeps sorted index cache")
	assert(glyph.draw_revision == glyph_revision)

	var advanced := _effect(1, "damage", 0.3)
	advanced.screenOffset = [0.0, -10.2]
	advanced.motion = "fallArc"
	advanced.feedback = "resisted"
	effects.apply_frame({"items": [advanced]}, true)
	var ink_revision: int = glyph.draw_revision
	var factor := (1.0 - 0.4 * 0.48) * 0.82
	var expected: Transform2D = effects.effect_transform(advanced) * Transform2D(0, Vector2.ONE * factor, 0, Vector2(0, 2))
	assert(glyph.transform.is_equal_approx(expected))
	assert(is_equal_approx(glyph.modulate.a, 0.6))
	assert(not glyph.transform.is_equal_approx(glyph_transform))
	var aged: Dictionary = advanced.duplicate(true)
	aged.age = 0.45
	aged.screenOffset = [0.0, -15.3]
	effects.apply_frame({"items": [aged]}, true)
	assert(glyph.draw_revision == ink_revision, "age changes transform/alpha, not glyph commands")
	assert(is_equal_approx(glyph.modulate.a, 0.4))
	camera.position = Vector3(1, 10, 0.01)
	camera.look_at(Vector3.ZERO)
	effects.prepare_context(camera, Vector2(8, 8), world)
	var moved: Transform2D = glyph.transform
	assert(glyph.draw_revision == ink_revision and effects.items[0].age == 0.45)
	world.position.x = 0.2
	effects.present(camera, Vector2(8, 8), world)
	assert(not moved.is_equal_approx(glyph.transform), "world shake must invalidate projections")

	var saved_pose := camera.transform
	camera.look_at(camera.position + Vector3(0, 1, 1))
	effects.prepare_context(camera, Vector2(8, 8), world)
	assert(not surface.visible, "behind-camera surfaces remain unmaterialized for drawing")
	camera.transform = saved_pose
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	effects.prepare_context(camera, Vector2(8, 8), world)
	assert(surface.visible)
	var perspective_factor := (1.0 - 0.6 * 0.48) * 0.82
	var perspective_expected: Transform2D = effects.effect_transform(aged) * Transform2D(0, Vector2.ONE * perspective_factor, 0, Vector2(0, 3))
	assert(glyph.transform.is_equal_approx(perspective_expected), "perspective keeps local billboard anchor/scale")
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	effects.prepare_context(camera, Vector2(8, 8), world)

	# Default callers retain the established owned-copy contract.
	effects.apply_frame(source)
	source.items[0].age = 0.5
	assert(effects.items[0].age == 0.1)
	effects.clear()
	assert(source.items.size() == 2, "clear never modifies caller storage")
	assert(effects._surface_pool.is_empty() and effects.get_child_count() == 0)

	# Pool reuse crosses blend modes/kinds without retaining glyphs or stale passes.
	effects.apply_frame({"items": [_effect(10, "gem")]})
	var gem: Node2D = effects._effect_nodes[10]
	var mixed: Node2D = gem.mix_surface
	assert(gem.material == effects._additive and mixed.visible)
	effects.apply_frame({"items": []})
	assert(effects._surface_pool.size() == 1 and effects.get_child_count() == 0)
	effects.apply_frame({"items": [_effect(11)]})
	assert(effects._effect_nodes[11] == gem)
	assert(gem.material == null and not mixed.visible and gem.glyph.visible)
	effects.apply_frame({"items": [_effect(12, "gem")]})
	assert(effects._effect_nodes[12] == gem and gem.mix_surface == mixed)
	assert(not gem.glyph.visible and mixed.visible and mixed.material == null)

	# Hidden ingestion still advances journal/3D blast lifetime; no surface work.
	effects.set_canvas_enabled(false)
	assert(effects._effect_nodes.is_empty())
	effects.apply_frame({"clock": 1.0, "items": [_effect(20)], "events": [
		{"id": 1000, "kind": "blast", "born": 0.5, "bornSquared": 0.0, "duration": 1.7, "radius": 72.0, "tileSize": 48.0}]})
	assert(effects.blast_impacts.size() == 1 and effects._effect_nodes.is_empty())
	effects.prepare_context(camera, Vector2(8, 8), world)
	assert(effects._effect_nodes.is_empty())
	effects.set_canvas_enabled(true)
	assert(effects._effect_nodes.size() == 1 and effects._effect_nodes.has(20))
	effects.hide()
	effects.apply_frame({"clock": 3.0, "items": [_effect(21)]})
	assert(effects._effect_nodes.is_empty() and effects.blast_impacts.is_empty())
	effects.show()
	assert(effects._effect_nodes.has(21) and not effects._effect_nodes.has(20))

	# Ordered blend hierarchy follows IDs even if source order changes.
	effects.apply_frame({"items": [_effect(33), _effect(31, "gem"), _effect(32, "blast"), _effect(30)]})
	assert(effects.get_child(0) == effects._effect_nodes[30])
	assert(effects.get_child(1) == effects._effect_nodes[31])
	assert(effects.get_child(2) == effects._effect_nodes[33])
	var many: Array = []
	for id in range(100, 200): many.append(_effect(id))
	effects.apply_frame({"items": many})
	effects.apply_frame({"items": []})
	assert(effects._surface_pool.size() == Effects.MAX_SURFACE_POOL)
	effects.clear()
	assert(effects._surface_pool.is_empty())

	# Bridge-specific static geometry/text caches remain bounded and reusable.
	for id in range(300): effects._metrics(str(id), 15)
	assert(effects._text_metrics.size() == 256)
	effects.apply_frame({"items": [_effect(300, "death"), _effect(301, "diamond"), _effect(302, "gem")]})
	for frame in range(3): await process_frame
	var death: Node2D = effects._effect_nodes[300]
	assert(death.death_styles.size() == 18, "headless draw must exercise boss particle cache")
	var saved_styles: Array = death.death_styles.duplicate()
	var next_death := _effect(300, "death", 0.2)
	effects.apply_frame({"items": [next_death, _effect(301, "diamond", 0.2), _effect(302, "gem", 0.6)]})
	for frame in range(3): await process_frame
	assert(death.death_styles == saved_styles, "death keeps particle StyleBoxes across frames")
	effects.clear()
	print("Effects cache: immutable dispatch, snapshot blast, glyph/time/camera, sort order, blend pool, hidden ingestion, bounded caches passed")
	quit(0)
