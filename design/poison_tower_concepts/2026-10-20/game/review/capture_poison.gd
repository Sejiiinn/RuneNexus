extends SceneTree

const OUTPUT = "/Users/sejin/Documents/Codex/RuneNexus/design/poison_tower_concepts/2026-10-20/game/review/"

func _initialize() -> void:
	call_deferred("capture")

func bounds_px(models: Array, camera: Camera3D) -> Rect2:
	var box := Rect2(); var first := true
	for model: Node3D in models:
		for mesh_node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for s in range(mesh_node.mesh.get_surface_count()):
				for v in mesh_node.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					var p := camera.unproject_position(mesh_node.global_transform * v)
					if first: box = Rect2(p, Vector2.ZERO); first = false
					else: box = box.expand(p)
	return box

func shot(vp: SubViewport, name: String, crop: Rect2i = Rect2i()) -> void:
	for i in range(24): await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	if crop.size != Vector2i.ZERO: image = image.get_region(crop.intersection(Rect2i(Vector2i.ZERO, image.get_size())))
	image.save_png(OUTPUT + name + ".png")
	print("SHOT ", name, " ", image.get_size())

func capture() -> void:
	root.content_scale_size = Vector2i(440, 760)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var vp := SubViewport.new()
	vp.size = Vector2i(1440, 3120); vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.msaa_3d = Viewport.MSAA_2X
	root.add_child(vp)
	var scene: Node3D = load("res://main.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	scene.set_process(false)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	frame["enemies"] = []; frame["impacts"] = []; frame["projectiles"] = []; frame["time"] = 0.0
	# Same tile row: poison next to existing turrets for scale. aim PI/2 = barrel toward +Z.
	frame["turrets"] = [[1, 2.5, 4.5, PI / 2 + 0.55, 0, 0, "magic", 1], [2, 3.5, 4.5, PI / 2 + 0.55, 0, 0, "poison", 1],
		[3, 4.5, 4.5, PI / 2 + 0.55, 0, 0, "cannon", 1], [4, 3.5, 5.5, PI / 2 - 0.9, 0, 0, "poison", 1]]
	scene.apply_frame(frame)
	var units = scene._units if "_units" in scene else null
	var size := Vector2(vp.size) / minf(vp.size.x / 440.0, vp.size.y / 760.0)
	var rect := Rect2(Vector2(8, 110), Vector2(size.x - 16, size.y - 302))
	var poison: Array = []
	for t in scene.turrets.values():
		if t["type"] == "poison": poison.append(t["root"])
	var all: Array = scene.turrets.values().map(func(t): return t["root"])
	print("POISON_NODES ", poison.size(), " head=", scene.turrets[2]["head"] != null, " barrel=", scene.turrets[2]["barrel"] != null, " muzzle=", scene.turrets[2]["muzzle"].global_position)
	for mode in ["angled", "drone"]:
		scene._battlefield_camera.stop_transition(); scene.camera_mode = ""; scene.options["camera"] = mode
		scene._update_camera(); scene._battlefield_camera.fit_frame(size, frame, 1.0, rect, true)
		for i in range(8): await process_frame
		var b := bounds_px(all, scene.camera)
		await shot(vp, "game-" + mode, Rect2i(Vector2i(b.position) - Vector2i(40, 40), Vector2i(b.size) + Vector2i(80, 80)))
		await shot(vp, "game-" + mode + "-full")
	# Close look at the runtime turret with the game's own lighting/materials.
	var cam := Camera3D.new(); scene.world.add_child(cam)
	var target: Node3D = scene.turrets[2]["root"]
	cam.fov = 22; cam.position = target.global_position + Vector3(3.6, 2.9, 4.05); cam.look_at(target.global_position + Vector3(0, 0.38, 0))
	cam.make_current()
	var c := bounds_px([target], cam)
	await shot(vp, "close", Rect2i(Vector2i(c.position) - Vector2i(60, 60), Vector2i(c.size) + Vector2i(120, 120)))
	scene.queue_free()
	for i in range(4): await process_frame
	quit()
