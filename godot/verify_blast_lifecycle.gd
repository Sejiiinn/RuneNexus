extends SceneTree
const FrameRows = preload("res://presentation/frame_rows.gd")
const Projectiles = preload("res://presentation/battlefield_projectiles.gd")
const SniperBlast = preload("res://effects/sniper_energy_blast.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _verify() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.options["presentation_groups"] = ["effects"]
	var frame: Dictionary = scene.last_frame.duplicate(true)
	frame.merge({"sceneEpoch": 300, "seq": 0, "viewportRevision": 1,
		"viewport": [390, 844], "presentationVersion": 2, "impacts": []}, true)
	var blast := {"id": 100, "kind": "blast", "style": "blast", "born": 5.0,
		"bornSquared": 0.0, "duration": 1.7, "x": 4.0, "y": 5.0, "tileSize": 48.0, "radius": 72.0}
	var spark := {"id": 101, "kind": "impact", "style": "spark", "born": 5.0,
		"bornSquared": 0.0, "duration": 0.28, "x": 4.0, "y": 5.0, "tileSize": 48.0, "radius": 16.0}
	var effects: Node2D = scene._presentation_nodes["effects"]
	frame["presentation"] = {"effects": {"generation": 0, "clock": 5.0, "events": [blast, spark]}}
	scene.apply_frame(frame)
	scene._report_presentation()
	_check(scene.presentation().get("nativeBlastEffectEvents", false), "actual runtime must advertise separate blast event support")
	_check(scene.impacts.has(100) and effects._effect_nodes.has(101), "mixed events must route to their existing independent renderers")
	_check(not effects._effect_nodes.has(100) and effects.items.size() == 1, "blast must never create a Canvas surface")
	var impact: Node3D = scene.impacts[100]
	var sparks: MultiMesh = impact._sparks.multimesh
	var fragments: MultiMesh = impact._fragments.multimesh
	_check(sparks.instance_count == 56 and fragments.instance_count == 34, "existing batched particle counts changed")
	_check(is_equal_approx(impact._last_radius, 1.5), "source-pixel blast radius must convert to tiles exactly once")
	_check(impact.position.is_equal_approx(Vector3(4.0 - scene.columns / 2.0, 0, 5.0 - scene.rows / 2.0)), "3D anchor moved")
	frame["seq"] = 1
	frame["presentation"]["effects"]["clock"] = 5.425
	frame["presentation"]["effects"]["events"] = [] # ACK removes creation payload only.
	scene.apply_frame(frame)
	_check(scene.impacts[100] == impact and impact._sparks.multimesh == sparks and impact._fragments.multimesh == fragments, "same ID must reuse all existing 3D resources")
	_check(is_equal_approx(impact._volume_material.get_shader_parameter("u_progress"), 0.25), "instance duration must control progress, not the default duration")
	_check(is_equal_approx(impact._spark_material.get_shader_parameter("u_age"), 0.275), "existing GPU progress-to-age mapping changed")
	_check(is_equal_approx(impact._volume_material.get_shader_parameter("u_angle"), float(100 % 23) * 0.317), "ID-seeded appearance changed")
	_check(scene.impact_lights[0].light_energy > 0 and scene.impact_lights[0].visible, "existing shared impact light missing")
	_check(scene.impact_lights.slice(1).all(func(light): return not light.visible), "unused zero-energy impact lights must stay hidden")
	var saved: Array = FrameRows.serialized(scene.last_frame).impacts
	for i in range(3):
		scene.apply_frame(frame)
		scene._update_camera_visuals()
		scene.apply_options()
		await process_frame
	_check(FrameRows.serialized(scene.last_frame).impacts == saved, "duplicate frames, camera and options must not advance or reset progress")
	scene.options["volume"] = false
	scene.apply_options()
	_check(not impact.visible, "volume option must affect native event blasts")
	scene.options["volume"] = true
	scene.apply_options()
	_check(impact.visible and is_equal_approx(impact._volume_material.get_shader_parameter("u_progress"), .25), "volume restore must retain current age")
	# Legacy fallback is newer authority for a duplicate ID.
	frame["seq"] = 2
	frame["impacts"] = [[100, 4.0, 5.0, 1.5, 0.4]]
	scene.apply_frame(frame)
	_check(scene.last_frame["impacts"].size() == 1 and is_equal_approx(impact._volume_material.get_shader_parameter("u_progress"), .4), "legacy/native collision must prefer legacy without duplicate nodes")
	frame["seq"] = 3
	frame["impacts"] = []
	frame["presentation"]["effects"]["clock"] = 6.7
	scene.apply_frame(frame)
	_check(scene.impacts.is_empty() and scene.last_frame["impacts"].is_empty() and scene.impact_pool.has(impact), "expiry must recycle the 3D node and clear replay diagnostics")
	_check(scene.impact_lights.all(func(light): return not light.visible), "expired impact lights must be hidden")
	frame["seq"] = 4
	frame["presentation"]["effects"]["events"] = [blast]
	scene.apply_frame(frame)
	_check(scene.impacts.is_empty(), "late retry must not restart expired blast")
	var second := blast.duplicate(true)
	second["id"] = 102
	second["born"] = 6.7
	frame["seq"] = 5
	frame["presentation"]["effects"]["events"] = [second]
	scene.apply_frame(frame)
	_check(scene.impacts[102] == impact and impact._sparks.multimesh == sparks, "new blast must reuse the existing pool")
	# Explosion sniper blasts use their own pooled node and need no field cache.
	var energy := second.duplicate(true)
	energy["id"] = 103
	energy["variant"] = "sniperEnergy"
	energy["duration"] = 0.6
	energy["born"] = 6.6
	energy["radius"] = 42.5
	frame["seq"] = 6
	frame["presentation"]["effects"]["events"] = [energy]
	scene.apply_frame(frame)
	var energy_blast: Node3D = scene.impacts.get(103)
	_check(energy_blast is SniperBlast and scene.impacts[102] == impact, "energy blast must use its own renderer beside the cannon blast")
	if energy_blast is SniperBlast:
		_check(energy_blast.scale.is_equal_approx(Vector3.ONE * 42.5 / 48.0), "energy blast shockwave must scale to the splash radius in tiles")
		_check(energy_blast.position.is_equal_approx(Vector3(4.0 - scene.columns / 2.0, 0, 5.0 - scene.rows / 2.0)), "energy blast anchor moved")
		_check(is_equal_approx(energy_blast._materials[0].get_shader_parameter("u_age"), 0.1), "energy blast age must follow its own duration")
		var spark_transforms: MultiMesh = energy_blast._sparks.multimesh
		_check(range(spark_transforms.instance_count).all(func(i): return spark_transforms.get_instance_transform(i) == Transform3D.IDENTITY), "energy sparks need identity transforms or their shader positions collapse")
	_check(scene.impact_lights.any(func(light): return light.visible and light.light_color.is_equal_approx(Projectiles.IMPACT_LIGHT_COLORS["sniperEnergy"])), "energy blast light must use the teal color")
	_check(scene.impact_lights.any(func(light): return light.visible and light.light_color.is_equal_approx(Projectiles.IMPACT_LIGHT_COLORS[""])), "cannon blast light must keep its color")
	_check(FrameRows.serialized(scene.last_frame).impacts.any(func(row): return row.size() == 6 and row[5] == "sniperEnergy"), "energy variant must survive row serialization")
	_check(FrameRows.serialized(scene.last_frame).impacts.any(func(row): return row.size() == 5 and int(row[0]) == 102), "cannon rows must keep the five-value format")
	frame["seq"] = 7
	frame["presentation"]["effects"] = {"generation": 1, "clock": 6.8, "events": []}
	scene.apply_frame(frame)
	_check(scene.impacts.is_empty(), "combat cancellation must clear native 3D blasts")
	frame["seq"] = 8
	frame["presentation"]["effects"] = {"generation": 0, "clock": 6.8, "events": [second]}
	scene.apply_frame(frame)
	_check(scene.impacts.is_empty(), "stale generation must not revive cancelled blasts")
	# No effects payload preserves the full-array legacy/preview protocol.
	frame["seq"] = 9
	frame.erase("presentation")
	frame["impacts"] = [[200, 4, 5, 1.2, .3]]
	scene.apply_frame(frame)
	_check(scene.impacts.has(200) and is_equal_approx(scene.impacts[200]._volume_material.get_shader_parameter("u_progress"), .3), "legacy full impacts preview regressed")
	# Cannon blasts keep their lights ahead of explosion-sniper blasts.
	scene._update_impacts([[300, 1, 1, .9, .1, "sniperEnergy"], [301, 2, 1, .9, .1, "sniperEnergy"],
		[302, 3, 1, .9, .1, "sniperEnergy"], [303, 4, 1, .9, .1, "sniperEnergy"], [304, 5, 5, 1.2, .3]])
	_check(scene.impact_lights.any(func(light): return light.visible and light.light_color.is_equal_approx(Projectiles.IMPACT_LIGHT_COLORS[""])), "sniper blasts must not take the cannon blast light")
	scene._update_impacts([])
	scene.queue_free()
	await process_frame
	print("Blast lifecycle integration: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
