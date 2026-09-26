extends SceneTree
const OUT = "/Users/sejin/Documents/Codex/RuneNexus/design/fire_tower_concepts/runic_3d/optimized-game-distance/integration/"
func _initialize() -> void:
	call_deferred("capture")
func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960,720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.scaling_3d_scale = 1.0
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	var scene: Node3D = load("res://main.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	scene.set_process(false)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	frame["turrets"] = [[701,3.5,3.5,-0.6,0,0.0,"magic",1]]
	frame["enemies"] = [];frame["projectiles"] = [];frame["impacts"] = [];frame["buildPreview"] = null
	frame["seq"] = 900;frame["time"] = 2.0
	scene._apply_frame(frame)
	var entry: Dictionary = scene.turrets[701]
	if not check(entry.has("fire_effect") and entry["flame_port"] != null,"Missing actual fire effect/port"):return
	var model: Node3D = entry["root"]
	# Godot's imported PackedScene adds a unit-scale scene wrapper.
	var authored_root: Node3D = model if model.name=="turret_root" else model.find_child("turret_root",true,false)
	if not check(authored_root != null and authored_root.scale.is_equal_approx(Vector3.ONE*.9),"Authored root scale is not .9"):return
	if not check(authored_root.global_basis.get_scale().is_equal_approx(Vector3.ONE*.9),"Global root scale is not .9"):return
	var body_triangles := 0
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			body_triangles += mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
	if not check(body_triangles==11411,"Loaded body is not optimized 11411 triangles"):return
	scene._battlefield_camera.stop_transition()
	scene.camera.position = model.position+Vector3(3.3,2.6,4.4)
	scene.camera.look_at(model.position+Vector3(.1,.42,0))
	scene.camera.size = 2.55;scene.camera.h_offset=0;scene.camera.v_offset=0
	var base: Transform3D = model.global_transform
	var rest_z: float = entry["barrel_rest_z"]
	var records: Array = []
	DirAccess.make_dir_recursive_absolute(OUT+"frames")
	for i in range(100):
		var time := 2.0+float(i)/30.0
		var angle := lerpf(-.6,.2,smoothstep(0,25,float(i)))
		if i>=60:angle=lerpf(.2,-.6,smoothstep(60,85,float(i)))
		frame["time"]=time;frame["seq"]=901+i
		frame["turrets"][0][3]=angle
		frame["turrets"][0][4]=1 if i>=30 else 0
		frame["turrets"][0][5]=1.0 if i==30 else 0.0
		frame["projectiles"]=[]
		if i>=31 and i<44:
			var travel := .78+float(i-31)*.052
			frame["projectiles"]=[[801,3.5+cos(.2)*travel,3.5+sin(.2)*travel,.2,0.0,"magic",3.5,3.5,701,1,false,-1.0,null,null]]
		scene._apply_frame(frame)
		# _apply_frame re-fits the gameplay camera. This separate diagnostic view
		# deliberately restores its close framing after the real frame update.
		scene.camera.position = model.position+Vector3(3.3,2.6,4.4)
		scene.camera.look_at(model.position+Vector3(.1,.42,0))
		scene.camera.size=2.55;scene.camera.h_offset=0;scene.camera.v_offset=0
		if not check(model.global_transform.is_equal_approx(base),"Fixed foundation moved"):return
		if not check(entry["fire_effect"]._flame.global_position.is_equal_approx(entry["flame_port"].global_position),"Attached flame detached from upper port"):return
		if i>=40 and not check(is_equal_approx(entry["barrel"].position.z,rest_z),"Barrel did not recover"):return
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.save_png(OUT+"frames/frame-%04d.png"%(i+1))
		var label := ""
		if i==0:label="idle"
		elif i==24:label="aim"
		elif i==32:label="fire"
		elif i==50:label="recovered"
		if not label.is_empty():shot.save_png(OUT+"runtime-"+label+".png")
		records.append({"frame":i+1,"time":time,"angle":angle,"barrel_z":entry["barrel"].position.z,"muzzle":str(entry["muzzle"].global_position),"upper_port":str(entry["flame_port"].global_position),"shot_pose":entry.has("shot_pose"),"active_projectiles":scene.projectiles.size(),"camera_size":scene.camera.size})
	var file := FileAccess.open(OUT+"runtime-check.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"loaded_body_triangles":body_triangles,"scene_wrapper_scale":str(model.scale),"authored_root_scale":str(authored_root.scale),"authored_root_global_scale":str(authored_root.global_basis.get_scale()),"physical_render_size":[960,720],"scaling_3d_scale":viewport.scaling_3d_scale,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Runtime attachment/aim/fire/recovery close view, not game-distance comparison","frames":records},"\t"));file.close()
	print("OPTIMIZED_FIRE_RUNTIME_CAPTURE_PASS triangles=",body_triangles," authored_scale=",authored_root.scale)
	scene.queue_free()
	for i in range(4):await process_frame
	quit()
