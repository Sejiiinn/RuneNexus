extends SceneTree

const BASE = "/Users/sejin/Documents/Codex/RuneNexus/"
const OUTPUT = BASE + "design/fire_tower_concepts/runic_3d/optimized-game-distance/review/"

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
	# Formal app stretch reference. Render offscreen so macOS window limits never
	# resize the 1440x3120 3D target. HUD logical fit is computed separately.
	root.content_scale_size = Vector2i(440,760)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var output_viewport := SubViewport.new()
	output_viewport.size = Vector2i(1440,3120)
	output_viewport.own_world_3d = true
	output_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	output_viewport.scaling_3d_scale = 1.0
	output_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	output_viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(output_viewport)
	var scene: Node3D = load("res://main.tscn").instantiate()
	output_viewport.add_child(scene)
	await process_frame
	scene.set_process(false)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	frame["turrets"] = []
	frame["enemies"] = []
	frame["impacts"] = []
	frame["projectiles"] = []
	frame["time"] = 0.0
	scene._apply_frame(frame)
	var physical_size := Vector2(output_viewport.size)
	var app_scale := minf(physical_size.x/440.0,physical_size.y/760.0)
	var viewport_size := physical_size/app_scale
	# Exact BattleHUD.battlefield_rect() formula, desktop safe insets = zero.
	var formal_rect := Rect2(Vector2(8,110), Vector2(viewport_size.x-16,viewport_size.y-302))
	var variants := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--original="): variants["original"] = arg.trim_prefix("--original=")
		if arg.begins_with("--optimized="): variants["optimized"] = arg.trim_prefix("--optimized=")
	assert(variants.has("original") and variants.has("optimized"))
	var results := {"viewport_logical": [viewport_size.x,viewport_size.y], "host_window_pixels": [root.size.x,root.size.y], "physical_render_target":[output_viewport.size.x,output_viewport.size.y], "app_reference_logical":[440,760], "content_scale_mode":"canvas_items", "content_scale_aspect":"expand", "logical_to_physical_scale":app_scale, "safe_insets_assumed":[0,0,0,0], "render_path":"explicit 1440x3120 SubViewport; no PNG resizing", "hardware":"macOS Godot mobile renderer, not Android screenshot", "scaling_3d_scale":output_viewport.scaling_3d_scale,"scaling_3d_mode":output_viewport.scaling_3d_mode,"msaa_3d":output_viewport.msaa_3d, "formal_rect": [formal_rect.position.x,formal_rect.position.y,formal_rect.size.x,formal_rect.size.y], "zoom":1.0,"columns":scene.columns,"rows":scene.rows,"map":frame["map"],"glb_root_scale":0.9,"runtime_extra_scale":1.0,"body_comparison_vfx":false,"magic_rune_material":"Runes | prefix -> UNSHADED, current runtime behavior","tile_center_grid":[3.5,4.5],"head_yaw":0.0,"renderer":RenderingServer.get_current_rendering_method(),"samples":[]}
	for variant in variants:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(variants[variant],state)
		if error != OK:
			push_error("GLB load failed %s: %s" % [variant,error]);quit(1);return
		var model := doc.generate_scene(state) as Node3D
		scene.world.add_child(model)
		# Match current magic runtime material setup; preserve orange rune color.
		for child in model.find_children("*", "MeshInstance3D", true, false):
			for surface in range(child.mesh.get_surface_count()):
				var material := child.get_active_material(surface) as StandardMaterial3D
				if material != null and material.resource_name.begins_with("Runes |"):
					material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		model.position = Vector3(3.5-float(scene.columns)/2.0,0,4.5-float(scene.rows)/2.0)
		for mode in ["angled","drone"]:
			scene._battlefield_camera.stop_transition()
			scene.camera_mode = ""
			scene.options["camera"] = mode
			scene._update_camera()
			scene._battlefield_camera.fit_frame(viewport_size,frame,1.0,formal_rect,true)
			for index in range(32): await process_frame
			await RenderingServer.frame_post_draw
			var shot := output_viewport.get_texture().get_image()
			var physical := Vector2(shot.get_width(),shot.get_height())
			assert(shot.get_size()==Vector2i(1440,3120))
			assert(is_equal_approx(output_viewport.scaling_3d_scale,1.0))
			var bounds := mesh_bounds_pixels(model,scene.camera,Vector2.ONE)
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
