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
	assert(effects._effect_nodes.size() == 12)
	assert(not effects._effect_nodes.has(11) and not effects._effect_nodes.has(12), "3D battlefield must not create legacy flame/frost impact canvases")
	assert(effects.items[10]["style"] == "flame" and effects.items[11]["style"] == "frost", "suppressed effects must remain acknowledged to prevent Flutter fallback")
	assert(effects.get_child(10) == effects._effect_nodes[13] and effects.get_child(11) == effects._effect_nodes[14], "remaining effects must preserve draw order across skipped impacts")
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
	# Event lifecycle uses combat dt and preserves the old discrete arc formula.
	var event := {"id": 100, "kind": "damage", "born": 10.0, "bornSquared": 2.0, "duration": 0.75,
		"x": 5.0, "y": 5.0, "tileSize": 48.0, "text": "12", "motion": "fallArc", "arcDirection": -1}
	effects.apply_frame({"clock": 10.0, "squaredSteps": 2.0, "events": [event]})
	var event_surface: Node2D = effects._effect_nodes[100]
	effects.apply_frame({"clock": 10.15, "squaredSteps": 2.0125, "events": [event]})
	assert(effects._effect_nodes[100] == event_surface)
	assert(is_equal_approx(effects.items[0]["age"], 0.15))
	var offset: Array = effects.items[0]["screenOffset"]
	assert(is_equal_approx(float(offset[0]), -6.3))
	assert(is_equal_approx(float(offset[1]), -28 * 0.15 + 64 * (0.15 * 0.15 + 0.0125)))
	effects.apply_frame({"clock": 10.15, "squaredSteps": 2.0125})
	assert(effects.items.size() == 1, "ACK removal of event payload must preserve native lifetime")
	for frame in range(2):
		await process_frame
	assert(is_equal_approx(effects.items[0]["age"], 0.15), "wall time never ages native effects")
	effects.apply_frame({"clock": 11.0, "squaredSteps": 3.0, "events": [event]})
	assert(effects.items.is_empty(), "expiry frees native event even while an old payload retries")
	effects.apply_frame({"clock": 11.0, "squaredSteps": 3.0, "events": [event]})
	assert(effects.items.is_empty(), "expired retry cannot resurrect the event")
	var short_event := event.duplicate(true)
	short_event["id"] = 101
	short_event["retainedAge"] = 0.1
	short_event["retainedSquared"] = 0.01
	effects.apply_frame({"clock": 11.0, "events": [short_event]})
	assert(effects.items.size() == 1 and is_equal_approx(effects.items[0]["age"], 0.1), "coalesced one-tick event retains one drawable delivery")
	effects.apply_frame({"clock": 11.0, "events": [short_event]})
	assert(effects.items.is_empty(), "repeated expired delivery is shown only once")
	var live := event.duplicate(true)
	live["id"] = 102
	live["born"] = 11.0
	effects.apply_frame({"clock": 11.0, "events": [live]})
	assert(effects.items.size() == 1)
	effects.apply_frame({"clock": 11.0, "generation": 1})
	assert(effects.items.is_empty(), "combat cancellation clears native-owned effects without resetting combat clock")
	effects.clear()
	# Event and prior snapshot paths must produce identical effect dictionaries.
	var impact_events := []
	for style in ["spark", "sniperBlast", "flame", "frost", "lightning", "lightningBlast"]:
		var duration := 0.36 if style in ["sniperBlast", "lightningBlast"] else 0.28
		impact_events.append({"id": 200 + impact_events.size(), "kind": "impact", "style": style,
			"born": 0.0, "bornSquared": 0.0, "duration": duration, "x": 5.0, "y": 5.0,
			"tileSize": 48.0, "color": 0xffabcdef, "radius": 24.0})
	effects.apply_frame({"clock": 0.0, "events": impact_events})
	assert(effects.items.size() == 6 and effects._effect_nodes.size() == 4)
	assert(not effects._effect_nodes.has(202) and not effects._effect_nodes.has(203))
	var spark_surface: Node2D = effects._effect_nodes[200]
	effects.apply_frame({"clock": 0.14})
	assert(effects._effect_nodes[200] == spark_surface)
	for item in effects.items:
		assert(is_equal_approx(item["age"], 0.14))
		var snapshot: Dictionary = impact_events[int(item["id"]) - 200].duplicate(true)
		snapshot["age"] = 0.14
		assert(effects.effect_transform(item).is_equal_approx(effects.effect_transform(snapshot)))
	effects.apply_frame({"clock": 0.14, "events": impact_events})
	assert(effects.items.size() == 6 and is_equal_approx(effects.items[0]["age"], 0.14))
	effects.apply_frame({"clock": 0.28})
	assert(effects.items.size() == 2)
	assert(effects.items[0]["style"] == "sniperBlast" and effects.items[1]["style"] == "lightningBlast")
	effects.apply_frame({"clock": 0.36, "events": impact_events})
	assert(effects.items.is_empty())
	effects.apply_frame({"clock": 0.36, "events": [{"id": 300, "kind": "impact", "style": "blast"}]})
	assert(effects.items.is_empty(), "cannon blast retains its separate native pipeline")
	# Mixed creation kinds share bounded retries and preserve draw order.
	var mixed := []
	for index in range(300):
		var kind: String = ["impact", "damage", "death", "gem"][index % 4]
		mixed.append({"id": 400 + index, "kind": kind, "style": "spark", "born": 0.36,
			"bornSquared": 0.0, "duration": 0.75, "x": 5.0, "y": 5.0, "tileSize": 48.0})
	effects.apply_frame({"clock": 0.36, "events": mixed})
	assert(effects.items.size() == 256 and effects.items[0]["id"] == 444)
	effects.apply_frame({"clock": 0.5, "events": mixed})
	assert(effects.items.size() == 256 and is_equal_approx(effects.items[0]["age"], 0.14))
	effects.apply_frame({"clock": 2.0})
	assert(effects.items.is_empty() and effects._effect_nodes.is_empty())
	effects.clear()
	# Blast events share the reliable bounded journal but never the Canvas path.
	var mixed_blasts := []
	for index in range(300):
		mixed_blasts.append({"id": 800 + index, "kind": "blast" if index % 2 == 0 else "gem",
			"born": 0.0, "bornSquared": 0.0, "duration": 1.7, "x": 5.0, "y": 5.0,
			"tileSize": 48.0, "radius": 72.0})
	effects.apply_frame({"clock": 0.0, "events": mixed_blasts})
	assert(effects._events.size() == 256 and effects.blast_impacts.size() == 128 and effects.items.size() == 128)
	assert(effects._effect_nodes.size() == 128 and effects.blast_impacts[0][0] == 844)
	effects.apply_frame({"clock": .425, "events": mixed_blasts})
	assert(effects._events.size() == 256 and is_equal_approx(effects.blast_impacts[0][4], .25))
	effects.apply_frame({"clock": 1.7})
	assert(effects.blast_impacts.is_empty() and effects.items.is_empty())
	var delayed := {"id": 1200, "kind": "blast", "born": 0.0, "bornSquared": 0.0,
		"duration": .42, "retainedAge": .1, "tileSize": 48.0, "radius": 24.0}
	effects.apply_frame({"clock": 2.0, "events": [delayed]})
	assert(effects.blast_impacts.size() == 1 and is_equal_approx(effects.blast_impacts[0][4], .1 / .42))
	effects.apply_frame({"clock": 2.0, "events": [delayed]})
	assert(effects.blast_impacts.is_empty(), "coalesced expired blast draws at most one retained delivery sample")
	effects.clear()
	# Linked events share enemy logical positions, not animated visual offsets.
	var beam := {"id": 1300, "kind": "coreBeam", "born": 0.0, "bornSquared": 0.0,
		"duration": .14, "x": 5.0, "y": 5.0, "tileSize": 48.0,
		"points": [[5.0, 5.0], [6.0, 6.0]], "targetIds": [50]}
	var rift := {"id": 1301, "kind": "rift", "born": 0.0, "bornSquared": 0.0,
		"duration": .42, "x": 5.0, "y": 5.0, "tileSize": 48.0,
		"points": [[6.0, 6.0], [7.0, 7.0]], "targetIds": [50, 51]}
	var target_rows := [[50, 60.0, 60.0, 0, 0, 1, 0, "normal", false, false, false, false, 6.2, 6.3],
		[51, 70.0, 70.0, 0, 0, 1, 0, "normal", false, false, false, false, 7.2, 7.3]]
	effects.apply_frame({"clock": .03, "events": [beam, rift], "targets": target_rows})
	assert(effects.items[0]["points"] == [[5.0, 5.0], [6.2, 6.3]])
	assert(effects.items[1]["points"] == [[6.2, 6.3], [7.2, 7.3]])
	assert(is_equal_approx(effects.items[0]["age"], .03))
	target_rows[0][12] = 6.4
	effects.apply_frame({"clock": .06, "targets": target_rows})
	assert(effects.items[0]["points"][1] == [6.4, 6.3], "ACK does not stop target following")
	assert(effects.items[0]["points"][0] == [5.0, 5.0], "beam source is fixed")
	effects.apply_frame({"clock": .06, "targets": []})
	assert(effects.items[0]["points"][1] == [6.4, 6.3], "removed target freezes beam endpoint")
	assert(effects.items[1]["points"].is_empty(), "dead/unmounted rift links disappear")
	effects.present(camera, Vector2(10, 10), world)
	await process_frame
	assert(is_equal_approx(effects.items[0]["age"], .06), "camera and pause do not age links")
	effects.apply_frame({"clock": .14})
	assert(effects.items.size() == 1 and effects.items[0]["kind"] == "rift")
	effects.apply_frame({"clock": .42})
	assert(effects.items.is_empty())
	beam["id"] = 1302
	rift["id"] = 1303
	effects.apply_frame({"clock": .5, "events": [beam, rift]})
	assert(effects.items.size() == 2, "coalesced links get a single delivery sample")
	assert(effects.items[0]["points"][1] == [6.0, 6.0], "target dead before delivery preserves initial beam endpoint")
	assert(effects.items[1]["points"].is_empty())
	effects.apply_frame({"clock": .5, "events": [beam, rift]})
	assert(effects.items.is_empty(), "late retries cannot resurrect expired links")
	effects.apply_frame({"generation": 1, "clock": .5, "events": [beam]})
	assert(effects.items.size() == 1)
	effects.apply_frame({"generation": 2, "clock": .5})
	assert(effects.items.is_empty(), "generation reset removes old links")
	effects.apply_frame({"generation": 1, "clock": .5, "events": [beam]})
	assert(effects.items.is_empty(), "stale generation cannot resurrect links")
	effects.clear()
	# Chain source and target move independently; the original pixel seed and
	# amplitude are preserved before applying the battlefield projection.
	var chain := {"id": 1400, "kind": "chain", "born": 0.0, "bornSquared": 0.0,
		"duration": .37, "tileSize": 48.0, "scale": 1.4, "boltSeed": 5420.0,
		"points": [[100.0 / 48, 120.0 / 48], [150.0 / 48, 150.0 / 48]], "targetIds": [50, 51]}
	var math_points: Array = effects._chain_points(chain)
	var start_px := Vector2(100, 120)
	var end_px := Vector2(150, 150)
	var delta_px := end_px - start_px
	var normal_px := Vector2(-delta_px.y, delta_px.x).normalized()
	for i in range(1, 5):
		var expected := (start_px + delta_px * (i / 5.0) + normal_px *
			(sin(5420.0 + i * 1.7) * .5 * minf(18.0 * 1.4, delta_px.length() * .16))) / 48.0
		assert(Vector2(math_points[i][0], math_points[i][1]).distance_to(expected) < .000001, "chain zigzag must preserve original pixel math")
	effects.apply_frame({"clock": .03, "events": [chain], "targets": target_rows})
	assert(effects.items[0]["points"].size() == 6)
	assert(effects.items[0]["points"][0] == [6.4, 6.3])
	assert(effects.items[0]["x"] == 6.4 and effects.items[0]["y"] == 6.3, "camera anchor follows chain source")
	assert(effects.items[0]["points"][5] == [7.2, 7.3])
	assert(chain["points"].size() == 2, "receiver must not mutate sender creation payload")
	target_rows[1][12] = 7.8
	effects.apply_frame({"clock": .09, "targets": [target_rows[1]]})
	assert(effects.items[0]["points"][0] == [6.4, 6.3], "missing source freezes independently")
	assert(effects.items[0]["points"][5] == [7.8, 7.3], "target still follows after source death and ACK")
	effects.apply_frame({"clock": .09, "targets": []})
	assert(effects.items[0]["points"][5] == [7.8, 7.3], "missing target freezes independently")
	effects.present(camera, Vector2(12, 10), world)
	await process_frame
	assert(is_equal_approx(effects.items[0]["age"], .09), "resize/camera cannot age chain")
	effects.apply_frame({"clock": .37})
	assert(effects.items.is_empty(), "custom chain duration is authoritative")
	chain["id"] = 1401
	chain["retainedAge"] = .05
	effects.apply_frame({"clock": .5, "events": [chain]})
	assert(effects.items.size() == 1 and is_equal_approx(effects.items[0]["age"], .05))
	assert(effects.items[0]["points"][0] == chain["points"][0], "dead before first delivery preserves initial source")
	assert(effects.items[0]["points"][5] == chain["points"][1], "dead before first delivery preserves initial target")
	effects.apply_frame({"clock": .5, "events": [chain]})
	assert(effects.items.is_empty(), "expired retry cannot restart chain")
	effects.apply_frame({"generation": 1, "clock": .5, "events": [chain]})
	assert(effects.items.size() == 1)
	effects.apply_frame({"generation": 2, "clock": .5})
	effects.apply_frame({"generation": 1, "clock": .5, "events": [chain]})
	assert(effects.items.is_empty(), "stale generation cannot resurrect chain")
	chain["points"] = [[2.0, 3.0], [2.0, 3.0]]
	assert(effects._chain_points(chain) == chain["points"], "zero length remains a two-point spark")
	effects.clear()
	var charge := {"id": 1500, "kind": "charge", "born": 0.0, "bornSquared": 0.0,
		"duration": .3, "tileSize": 48.0, "scale": 1.0, "color": 0xffabcdef,
		"ownerId": 71, "attachmentRadius": .4756, "x": 0.0, "y": 0.0}
	var turret := [71, 2.0, 3.0, 0.0]
	effects.apply_frame({"clock": .1, "events": [charge], "turrets": [turret]})
	assert(effects.items.size() == 1)
	assert(is_equal_approx(effects.items[0]["x"], 2.4756))
	assert(is_equal_approx(effects.items[0]["y"], 3.0))
	assert(is_equal_approx(effects.items[0]["age"], .1))
	turret[3] = PI / 2
	effects.apply_frame({"clock": .1, "turrets": [turret]})
	assert(is_equal_approx(effects.items[0]["x"], 2.0))
	assert(is_equal_approx(effects.items[0]["y"], 3.4756), "ACK charge follows existing turret angle")
	effects.present(camera, Vector2(16, 12), world)
	assert(is_equal_approx(effects.items[0]["age"], .1), "camera/resize does not advance charge")
	effects.apply_frame({"clock": .299, "turrets": [turret]})
	assert(effects.items.size() == 1)
	effects.apply_frame({"clock": .3, "turrets": [turret]})
	assert(effects.items.is_empty(), "charge must expire at exact fire time")
	charge["id"] = 1501
	charge["retainedAge"] = .1
	effects.apply_frame({"clock": .4, "events": [charge], "turrets": [turret]})
	assert(effects.items.is_empty(), "coalesced expired charge must never show before an already released strike")
	effects.apply_frame({"clock": .4, "events": [charge], "turrets": [turret]})
	assert(effects.items.is_empty(), "retry must not restart charge")
	charge["id"] = 1502
	charge["born"] = .4
	effects.apply_frame({"clock": .4, "events": [charge], "turrets": [turret]})
	assert(effects.items.size() == 1)
	effects.apply_frame({"generation": 1, "clock": .4, "turrets": [turret]})
	effects.apply_frame({"generation": 0, "clock": .4, "events": [charge], "turrets": [turret]})
	assert(effects.items.is_empty(), "cancel before ACK rejects old generation start")
	charge["id"] = 1503
	effects.apply_frame({"generation": 1, "clock": .4, "events": [charge], "turrets": [turret]})
	assert(effects.items.size() == 1)
	effects.apply_frame({"generation": 1, "clock": .4, "turrets": []})
	assert(effects.items.is_empty(), "removed owner cannot leave charge at stale position")
	effects.clear()
	print("Battlefield effects: original ground/billboard transforms, anchor movement, additive gem passes, duplicate frame, pause, copy ownership, camera and all effect kinds passed")
	quit(0)
