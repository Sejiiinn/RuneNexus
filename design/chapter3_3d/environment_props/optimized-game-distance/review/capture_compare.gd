extends SceneTree

const BASE = "/Users/sejin/Documents/Codex/RuneNexus/"
const OUTPUT = BASE + "design/chapter3_3d/environment_props/optimized-game-distance/review/"

func _initialize() -> void:
	call_deferred("capture")

func mesh_bounds_pixels(model: Node3D, camera: Camera3D, ratio: Vector2) -> Rect2:
	var box := Rect2()
	var first := true
	for child in ([model] if model is MeshInstance3D else []) + model.find_children("*", "MeshInstance3D", true, false):
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
	var frame: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"build/godot/chapter_three_frames.json"))[0].duplicate(true)
	frame["turrets"] = []
	frame["enemies"] = []
	frame["impacts"] = []
	frame["projectiles"] = []
	frame["time"] = 0.0
	scene._apply_frame(frame)
	assert(scene._using_forge)
	var entries: Array = scene.ChapterThreeProps.layout(scene._chapter_three_props_library,frame["map"])
	var previous_group = scene.terrain.get_node("chapter_three_props")
	var prop_layers = previous_group.get_child(0).layers
	previous_group.free()
	var original_layout: Array = []
	for entry in entries: original_layout.append({"kind":entry.kind,"cell":str(entry.cell),"side":entry.side,"pose":str(entry.pose)})
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
	var results := {"viewport_logical": [viewport_size.x,viewport_size.y], "host_window_pixels": [root.size.x,root.size.y], "physical_render_target":[output_viewport.size.x,output_viewport.size.y], "app_reference_logical":[440,760], "content_scale_mode":"canvas_items", "content_scale_aspect":"expand", "logical_to_physical_scale":app_scale, "safe_insets_assumed":[0,0,0,0], "render_path":"explicit 1440x3120 SubViewport; no PNG resizing", "hardware":"macOS Godot mobile renderer, not Android screenshot", "scaling_3d_scale":output_viewport.scaling_3d_scale,"scaling_3d_mode":output_viewport.scaling_3d_mode,"msaa_3d":output_viewport.msaa_3d, "formal_rect": [formal_rect.position.x,formal_rect.position.y,formal_rect.size.x,formal_rect.size.y], "zoom":1.0,"columns":scene.columns,"rows":scene.rows,"map":frame["map"],"runtime_extra_scale":1.0,"body_comparison_vfx":false,"original_layout":original_layout,"head_yaw":0.0,"renderer":RenderingServer.get_current_rendering_method(),"samples":[]}
	for variant in variants:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(variants[variant],state)
		if error != OK:
			push_error("GLB load failed %s: %s" % [variant,error]);quit(1);return
		var library := doc.generate_scene(state) as Node3D
		var model := Node3D.new()
		scene.terrain.add_child(model)
		var representative := {}
		var fresh_layout: Array = scene.ChapterThreeProps.layout(library,frame["map"])
		var layout_equal := entries.size()==fresh_layout.size()
		for i in range(mini(entries.size(),fresh_layout.size())):
			layout_equal = layout_equal and entries[i].kind==fresh_layout[i].kind and entries[i].cell==fresh_layout[i].cell and entries[i].side==fresh_layout[i].side
		results[variant+"_automatic_layout_matches_original"] = layout_equal
		var contracts := {}
		for entry in entries:
			var source: Node3D = library.find_child(entry.kind,true,false)
			var bounds: AABB = scene.ChapterThreeProps.mesh_bounds(source)
			assert(bounds.position.z>=-.001 and bounds.position.z<=.006 and bounds.position.y>=-.505)
			if entry.kind=="exhaust_vent": assert(absf(bounds.position.y+.5)<.006 and bounds.end.y<=.31)
			assert(scene.ChapterThreeProps.clear_of_play(entry.pose*bounds,frame["map"]))
			contracts[entry.kind] = {"bounds_position":str(bounds.position),"bounds_size":str(bounds.size),"wall_anchor_pass":true}
			var instance := source.duplicate() as Node3D
			model.add_child(instance)
			instance.transform = entry.pose
			for mesh in [instance]+instance.find_children("*","MeshInstance3D",true,false):
				if mesh is MeshInstance3D:
					mesh.layers=prop_layers
					for surface in range(mesh.mesh.get_surface_count()):
						var colors=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
						var material=mesh.get_active_material(surface)
						if colors!=null and not colors.is_empty() and material is StandardMaterial3D: material.vertex_color_use_as_albedo=true
			if not representative.has(entry.kind): representative[entry.kind]=instance
		results[variant+"_contracts"] = contracts
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
			shot.save_png(OUTPUT+variant+"-"+mode+"-full.png")
			var crops := {}
			for kind in representative:
				var instance=representative[kind]
				# mesh_bounds_pixels includes root MeshInstance3D as well as children.
				var bounds := mesh_bounds_pixels(instance,scene.camera,Vector2.ONE)
				var crop:=Rect2i(Vector2i(floor(bounds.position.x)-8,floor(bounds.position.y)-8),Vector2i(ceil(bounds.size.x)+16,ceil(bounds.size.y)+16))
				shot.get_region(crop).save_png(OUTPUT+variant+"-"+mode+"-"+kind+"-native.png")
				crops[kind]={"rect":str(crop),"projected_bounds":str(bounds)}
			results.samples.append({"variant":variant,"mode":mode,"physical_capture":[shot.get_width(),shot.get_height()],"camera_size":scene.camera.size,"camera_position":str(scene.camera.position),"camera_h_offset":scene.camera.h_offset,"camera_v_offset":scene.camera.v_offset,"crops":crops})
			print("CAPTURE ",variant," ",mode," ",crops)

		model.queue_free()
		library.free()
		await process_frame
	var f := FileAccess.open(OUTPUT + "capture-conditions.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"));f.close()
	scene.queue_free()
	for index in range(4): await process_frame
	quit()
