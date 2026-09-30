extends SceneTree

const BASE = "/Users/sejin/Documents/Codex/RuneNexus/design/sniper_tower_concepts/2026-09-26/production/"
const OUTPUT = BASE + "optimized-game-distance/review/"

func _initialize() -> void:
	call_deferred("capture")

func mesh_bounds_pixels(model: Node3D, camera: Camera3D, ratio: Vector2) -> Rect2:
	var box := Rect2()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		for surface in range(mesh_node.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var pixel := camera.unproject_position(mesh_node.global_transform * vertex) * ratio
				if first:
					box = Rect2(pixel, Vector2.ZERO)
					first = false
				else: box = box.expand(pixel)
	return box

func capture() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	frame["turrets"] = []
	frame["enemies"] = []
	frame["impacts"] = []
	frame["projectiles"] = []
	frame["time"] = 0.0
	scene._apply_frame(frame)
	var viewport_size := root.get_visible_rect().size
	# Exact BattleHUD.battlefield_rect() formula, desktop safe insets = zero.
	var formal_rect := Rect2(Vector2(8,110), Vector2(viewport_size.x-16,viewport_size.y-302))
	var variants := {"original": BASE + "sniper-c-preview.glb"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--optimized="): variants["optimized"] = arg.trim_prefix("--optimized=")
	var results := {"viewport_logical": [viewport_size.x,viewport_size.y], "window_pixels": [root.size.x,root.size.y], "formal_rect": [formal_rect.position.x,formal_rect.position.y,formal_rect.size.x,formal_rect.size.y], "zoom":1.0,"columns":scene.columns,"rows":scene.rows,"map":frame["map"],"scale":1.0,"tile_center_grid":[3.5,4.5],"head_yaw":0.0,"renderer":RenderingServer.get_current_rendering_method(),"samples":[]}
	for variant in variants:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(variants[variant],state)
		if error != OK:
			push_error("GLB load failed %s: %s" % [variant,error]);quit(1);return
		var model := doc.generate_scene(state) as Node3D
		scene.world.add_child(model)
		model.position = Vector3(3.5-float(scene.columns)/2.0,0,4.5-float(scene.rows)/2.0)
		for mode in ["angled","drone"]:
			scene._battlefield_camera.stop_transition()
			scene.camera_mode = ""
			scene.options["camera"] = mode
			scene._update_camera()
			scene._battlefield_camera.fit_frame(viewport_size,frame,1.0,formal_rect,true)
			for index in range(32): await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			var physical := Vector2(shot.get_width(),shot.get_height())
			var bounds := mesh_bounds_pixels(model,scene.camera,physical/viewport_size)
			var crop := Rect2i(Vector2i(floor(bounds.position.x)-8,floor(bounds.position.y)-8),Vector2i(ceil(bounds.size.x)+16,ceil(bounds.size.y)+16)).intersection(Rect2i(Vector2i.ZERO,shot.get_size()))
			shot.save_png(OUTPUT + variant + "-" + mode + "-full.png")
			shot.get_region(crop).save_png(OUTPUT + variant + "-" + mode + "-crop-native.png")
			results["samples"].append({"variant":variant,"mode":mode,"physical_capture":[shot.get_width(),shot.get_height()],"camera_size":scene.camera.size,"camera_position":str(scene.camera.position),"camera_basis":str(scene.camera.basis),"camera_h_offset":scene.camera.h_offset,"camera_v_offset":scene.camera.v_offset,"pixels_per_tile_physical":physical.y/scene.camera.size,"projected_mesh_rect_pixels":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"crop_rect_pixels":[crop.position.x,crop.position.y,crop.size.x,crop.size.y]})
			print("CAPTURE ",variant," ",mode," viewport=",viewport_size," physical=",physical," size=",scene.camera.size," bounds=",bounds)
		model.queue_free()
		await process_frame
	var f := FileAccess.open(OUTPUT + "capture-conditions.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"));f.close()
	scene.queue_free()
	for index in range(4): await process_frame
	quit()
