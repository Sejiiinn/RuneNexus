extends SceneTree

var OUTPUT := OS.get_environment("RUNE_FROST_COMPARE_DIR").trim_suffix("/")+"/"

func _initialize() -> void:
	if OS.get_environment("RUNE_FROST_COMPARE_DIR").is_empty():
		push_error("RUNE_FROST_COMPARE_DIR must point to an isolated output directory.")
		quit(1)
		return
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
	DirAccess.make_dir_recursive_absolute(OUTPUT)
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
	var results := {"viewport_logical": [viewport_size.x,viewport_size.y], "host_window_pixels": [root.size.x,root.size.y], "physical_render_target":[output_viewport.size.x,output_viewport.size.y], "app_reference_logical":[440,760], "content_scale_mode":"canvas_items", "content_scale_aspect":"expand", "logical_to_physical_scale":app_scale, "safe_insets_assumed":[0,0,0,0], "render_path":"explicit 1440x3120 SubViewport; no PNG resizing", "hardware":"macOS Godot mobile renderer, not Android screenshot", "scaling_3d_scale":output_viewport.scaling_3d_scale,"scaling_3d_mode":output_viewport.scaling_3d_mode,"msaa_3d":output_viewport.msaa_3d, "formal_rect": [formal_rect.position.x,formal_rect.position.y,formal_rect.size.x,formal_rect.size.y], "zoom":1.0,"columns":scene.columns,"rows":scene.rows,"map":frame["map"],"runtime_extra_scale":1.0,"before_sha256":FileAccess.get_sha256(variants.original),"after_sha256":FileAccess.get_sha256(variants.optimized),"body_comparison_vfx":false,"representative_state_comparison":true,"frost_state":"runtime configure; ready charge=1; mist off; standard light enabled","tile_center_grid":[3.5,4.5],"head_yaw":0.0,"renderer":RenderingServer.get_current_rendering_method(),"samples":[],"charge_surfaces":{}}
	var shared_crops := {}
	for variant in variants:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(variants[variant],state)
		if error != OK:
			push_error("GLB load failed %s: %s" % [variant,error]);quit(1);return
		var model := doc.generate_scene(state) as Node3D
		scene.world.add_child(model)
		model.position = Vector3(3.5-float(scene.columns)/2.0,0,4.5-float(scene.rows)/2.0)
		var effect = load("res://effects/frost_tower.gd").new()
		model.add_child(effect)
		var charge_surfaces: Array = []
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface)
				if material != null and ("cold aluminum fins" in material.resource_name or "cold circulating core" in material.resource_name):
					charge_surfaces.append({"mesh":str(model.get_path_to(mesh)),"material":material.resource_name,"triangles":mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3})
		assert(charge_surfaces.size()==3)
		results["charge_surfaces"][variant] = charge_surfaces
		effect.configure(model)
		effect.update_state(0.0,0,0.0,{"cooldown":0.0,"duration":2.0,"radius":1.58},false,true)
		assert(effect._fins.size()>0)
		for sample in [{"mode":"angled","zoom":1.0},{"mode":"drone","zoom":1.0},{"mode":"angled","zoom":2.5},{"mode":"drone","zoom":2.5}]:
			var mode: String = sample.mode
			var zoom: float = sample.zoom
			var label := mode + ("-detail" if zoom>1.0 else "")
			scene._battlefield_camera.stop_transition()
			scene.camera_mode = ""
			scene.options["camera"] = mode
			scene._update_camera()
			scene._battlefield_camera.fit_frame(viewport_size,frame,zoom,formal_rect,true)
			for index in range(32): await process_frame
			await RenderingServer.frame_post_draw
			var shot := output_viewport.get_texture().get_image()
			var physical := Vector2(shot.get_width(),shot.get_height())
			assert(shot.get_size()==Vector2i(1440,3120))
			assert(is_equal_approx(output_viewport.scaling_3d_scale,1.0))
			var bounds := mesh_bounds_pixels(model,scene.camera,Vector2.ONE)
			var crop := Rect2i(Vector2i(floor(bounds.position.x)-8,floor(bounds.position.y)-8),Vector2i(ceil(bounds.size.x)+16,ceil(bounds.size.y)+16)).intersection(Rect2i(Vector2i.ZERO,shot.get_size()))
			if variant == "original": shared_crops[label] = crop
			else: crop = shared_crops[label]
			assert(shot.save_png(OUTPUT + variant + "-" + label + "-full.png") == OK)
			assert(shot.get_region(crop).save_png(OUTPUT + variant + "-" + label + "-crop-native.png") == OK)
			results["samples"].append({"variant":variant,"mode":mode,"zoom":zoom,"physical_capture":[shot.get_width(),shot.get_height()],"camera_size":scene.camera.size,"camera_position":str(scene.camera.position),"camera_basis":str(scene.camera.basis),"camera_h_offset":scene.camera.h_offset,"camera_v_offset":scene.camera.v_offset,"pixels_per_tile_physical":physical.y/scene.camera.size,"projected_mesh_rect_pixels":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"crop_rect_pixels":[crop.position.x,crop.position.y,crop.size.x,crop.size.y]})
			print("CAPTURE ",variant," ",mode," viewport=",viewport_size," physical=",physical," size=",scene.camera.size," bounds=",bounds)
		# Relevant asset contract: charge material responds at empty/half/ready,
		# and the original shot-triggered mist still uses its shared 32 instances.
		# This fixture checks representative presentation states, not full combat.
		scene._battlefield_camera.stop_transition()
		scene.camera_mode = ""
		scene.options["camera"] = "angled"
		scene._update_camera()
		scene._battlefield_camera.fit_frame(viewport_size,frame,2.5,formal_rect,true)
		for state_sample in [
			{"label":"charge-empty","time":1.0,"shot":0,"cooldown":2.0,"show_mist":false,"expected":0.0},
			{"label":"charge-half","time":2.0,"shot":0,"cooldown":1.0,"show_mist":false,"expected":0.5},
			{"label":"charge-ready","time":3.0,"shot":0,"cooldown":0.0,"show_mist":false,"expected":1.0},
			{"label":"shot-mist","time":3.4,"shot":1,"cooldown":1.6,"show_mist":true,"expected":0.2}]:
			var label: String = state_sample.label
			if label == "shot-mist":
				effect.update_state(3.01,1,0.0,{"cooldown":1.99,"duration":2.0,"radius":1.58},true,true)
			effect.update_state(float(state_sample.time),int(state_sample.shot),0.0,{"cooldown":state_sample.cooldown,"duration":2.0,"radius":1.58},state_sample.show_mist,true)
			assert(is_equal_approx(effect.charge,float(state_sample.expected)))
			assert(is_equal_approx(effect.lamp.light_energy,float(state_sample.expected)*0.65))
			assert(effect.mist.visible == bool(state_sample.show_mist))
			assert(effect.mist.multimesh.instance_count == 32)
			for mesh in effect._fins:
				assert(is_equal_approx(float(mesh.get_instance_shader_parameter("charge")),float(state_sample.expected)))
			for index in range(24): await process_frame
			await RenderingServer.frame_post_draw
			var shot := output_viewport.get_texture().get_image()
			var crop: Rect2i = shared_crops["angled-detail"]
			assert(shot.save_png(OUTPUT+variant+"-"+label+"-full.png") == OK)
			assert(shot.get_region(crop).save_png(OUTPUT+variant+"-"+label+"-crop-native.png") == OK)
			results["samples"].append({"variant":variant,"label":label,"mode":"angled","zoom":2.5,"time":state_sample.time,"shot":state_sample.shot,"cooldown":state_sample.cooldown,"charge":effect.charge,"lamp_energy":effect.lamp.light_energy,"mist_visible":effect.mist.visible,"mist_instance_count":effect.mist.multimesh.instance_count,"mist_age":effect.mist_material.get_shader_parameter("age"),"camera_size":scene.camera.size,"camera_position":str(scene.camera.position),"camera_basis":str(scene.camera.basis),"crop_rect_pixels":[crop.position.x,crop.position.y,crop.size.x,crop.size.y]})
			print("STATE_CAPTURE ",variant," ",label," charge=",effect.charge," mist=",effect.mist.visible)
		model.queue_free()
		await process_frame
	var f := FileAccess.open(OUTPUT + "capture-conditions.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"));f.close()
	scene.queue_free()
	for index in range(4): await process_frame
	quit()
