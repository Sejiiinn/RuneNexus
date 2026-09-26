extends SceneTree
# _check_props is the bounded existing verifier from verify_chapter_three_stage.gd.
const OUT = "/Users/sejin/Documents/Codex/RuneNexus/design/chapter3_3d/environment_props/optimized-game-distance/integration/"
var failures := 0
func _initialize() -> void:
	call_deferred("verify")
func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _check_props(scene: Node3D, map: Dictionary) -> void:
	var library: Node3D = scene._chapter_three_props_library
	var entries: Array = scene.ChapterThreeProps.layout(library, map)
	_check(entries == scene.ChapterThreeProps.layout(library, map.duplicate(true)), "외곽 소품 배치 불안정")
	var group: Node3D = scene.terrain.get_node("chapter_three_props")
	_check(group.get_child_count() == entries.size() and entries.size() >= 5 and entries.size() <= 6, "외곽 소품 5~6개 배치 오류")
	var vents := {}
	for panel: Dictionary in scene.ChapterThreeTiles.panel_layout(map):
		if panel["kind"] == "panel_vent":
			vents[int(panel["index"]) * 4 + int(panel["side"])] = true
	var counts := {}
	var visible_kinds := {}
	for entry: Dictionary in entries:
		var kind: String = entry["kind"]
		counts[kind] = int(counts.get(kind, 0)) + 1
		if entry["side"] in [0, 1]:
			visible_kinds[kind] = true
		_check(not vents.has(int(entry["index"]) * 4 + int(entry["side"])), "기존 환기 패널 가림")
		_check(scene.ChapterThreeProps.clear_of_play(entry["bounds"], map), "소품이 플레이 영역 침범")
		print("Forge prop: %s cell=%s side=%d origin=%s" % [kind, entry["cell"], entry["side"], entry["pose"].origin])
	_check(entries.any(func(entry: Dictionary) -> bool: return entry["kind"] == "exhaust_vent" and entry["side"] == 0), "배기구 전면 방향 누락")
	_check(visible_kinds.size() == 3, "기본 시점에서 보이는 소품 종류 누락")
	for kind in scene.ChapterThreeProps.KINDS:
		_check(counts.get(kind, 0) >= 1 and counts.get(kind, 0) <= 2, "소품별 배치 수 변경: " + kind)
	for instance: Node3D in group.get_children():
		var kind: String = instance.get_meta("prop_kind")
		var source: Node3D = library.find_child(kind, true, false)
		var bounds: AABB = scene.ChapterThreeProps.mesh_bounds(source)
		_check(bounds.position.z >= -.001, "벽체 장식이 타일 안쪽을 침범")
		_check(bounds.position.z <= .006, "장식의 벽 체결면이 외벽에서 분리됨")
		_check(bounds.position.y >= -.505, "장식이 타일 기단 아래로 돌출")
		if kind == "exhaust_vent":
			_check(absf(bounds.position.y + .5) < .006, "배기구 하우징이 기단까지 이어지지 않음")
			_check(bounds.end.y <= .31, "배기구 굴뚝이 승인 높이보다 과하게 솟음")
		_check(instance.scale.is_equal_approx(Vector3.ONE), "소품 원본 스케일 변경")
		_check(instance is MeshInstance3D and source is MeshInstance3D, "소품 병합 메시 누락")
		if instance is MeshInstance3D and source is MeshInstance3D:
			_check(instance.mesh == source.mesh, "소품 원본 메시 미공유")
			for surface in range(instance.mesh.get_surface_count()):
				var material: Material = instance.get_active_material(surface)
				_check(material is StandardMaterial3D and material == source.get_active_material(surface), "소품 native PBR 원본 미공유")

func verify() -> void:
	var frames_path := ""
	var baseline_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):frames_path=arg.trim_prefix("--frames=")
		if arg.begins_with("--baseline="):baseline_path=arg.trim_prefix("--baseline=")
	if frames_path.is_empty() or baseline_path.is_empty():quit(1);return
	var frames: Array = JSON.parse_string(FileAccess.get_file_as_string(frames_path))
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(baseline_path,state)!=OK:quit(1);return
	var baseline := doc.generate_scene(state) as Node3D
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1440,3120)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.scaling_3d_scale=1.0
	viewport.msaa_3d=Viewport.MSAA_2X
	root.add_child(viewport)
	var scene: Node3D=load("res://main.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	scene.set_process(false)
	# Forge libraries are loaded lazily when the first chapter-three map is applied.
	var initial: Dictionary=frames[0].duplicate(true)
	initial["turrets"]=[];initial["enemies"]=[];initial["projectiles"]=[];initial["impacts"]=[];initial["sceneEpoch"]=1
	scene._apply_frame(initial)
	var library: Node3D=scene._chapter_three_props_library
	if library==null:push_error("Chapter-three library failed to load");quit(1);return
	var loaded := {}
	var expected := {"elbow_pipe":6816,"side_conduit":9024,"exhaust_vent":6588}
	for kind in expected:
		var mesh: MeshInstance3D=library.find_child(kind,true,false)
		var tris := 0
		for surface in range(mesh.mesh.get_surface_count()):tris+=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
		_check(tris==expected[kind],"Wrong imported geometry for "+kind)
		_check(mesh.mesh.get_surface_count()==1,"Extra draw surface for "+kind)
		var actual_bounds: AABB=scene.ChapterThreeProps.mesh_bounds(mesh)
		var original_bounds: AABB=scene.ChapterThreeProps.mesh_bounds(baseline.find_child(kind,true,false))
		_check(actual_bounds.is_equal_approx(original_bounds),"AABB changed for "+kind)
		loaded[kind]={"triangles":tris,"surfaces":mesh.mesh.get_surface_count(),"bounds_position":str(actual_bounds.position),"bounds_size":str(actual_bounds.size),"mesh_resource_path":mesh.mesh.resource_path}
	var records: Array=[]
	for index in range(frames.size()):
		var frame: Dictionary=frames[index].duplicate(true)
		frame["turrets"]=[];frame["enemies"]=[];frame["projectiles"]=[];frame["impacts"]=[];frame["sceneEpoch"]=index+1
		scene._apply_frame(frame)
		_check_props(scene,frame["map"])
		var actual: Array=scene.ChapterThreeProps.layout(library,frame["map"])
		var original: Array=scene.ChapterThreeProps.layout(baseline,frame["map"])
		_check(actual.size()==original.size(),"Stage%d count differs from original"%(index+11))
		var layout: Array=[]
		var triangles := 0
		for i in range(mini(actual.size(),original.size())):
			_check(actual[i].kind==original[i].kind and actual[i].cell==original[i].cell and actual[i].side==original[i].side and actual[i].pose.is_equal_approx(original[i].pose),"Original placement changed")
			layout.append({"kind":actual[i].kind,"cell":str(actual[i].cell),"side":actual[i].side,"pose":str(actual[i].pose)})
			triangles+=expected[actual[i].kind]
		var id: int = scene.terrain.get_node("chapter_three_props").get_instance_id()
		frame["seq"]=1;scene._apply_frame(frame)
		_check(id==scene.terrain.get_node("chapter_three_props").get_instance_id(),"Same map recreated props")
		records.append({"stage":index+11,"count":actual.size(),"placed_triangles":triangles,"original_layout_equal":true,"layout":layout})
		print("APPLIED_STAGE_PROPS stage=",index+11," count=",actual.size()," triangles=",triangles," failures=",failures)
	var frame: Dictionary=frames[0].duplicate(true)
	frame["turrets"]=[];frame["enemies"]=[];frame["projectiles"]=[];frame["impacts"]=[];frame["sceneEpoch"]=10;frame["time"]=0.0
	scene._apply_frame(frame)
	scene._battlefield_camera.stop_transition();scene.camera_mode="";scene.options["camera"]="angled";scene._update_camera()
	var physical := Vector2(viewport.size)
	var logical := physical/minf(physical.x/440.0,physical.y/760.0)
	var formal := Rect2(Vector2(8,110),Vector2(logical.x-16,logical.y-302))
	scene._battlefield_camera.fit_frame(logical,frame,1.0,formal,true)
	for i in range(32):await process_frame
	await RenderingServer.frame_post_draw
	var shot:=viewport.get_texture().get_image()
	_check(shot.get_size()==Vector2i(1440,3120),"Physical viewport size wrong")
	shot.save_png(OUT+"stage11-applied-qhd.png")
	var file:=FileAccess.open(OUT+"integration-check.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"runtime_library_scene":library.scene_file_path,"loaded_meshes":loaded,"stages":records,"capture":{"file":"stage11-applied-qhd.png","physical":[1440,3120],"logical":[logical.x,logical.y],"formal_rect":str(formal),"camera_size":scene.camera.size,"camera_position":str(scene.camera.position),"zoom":1.0,"safe_insets":[0,0,0,0],"scaling_3d_scale":viewport.scaling_3d_scale,"renderer":RenderingServer.get_current_rendering_method()}},"\t"));file.close()
	baseline.free();scene.queue_free()
	for i in range(3):await process_frame
	print("APPLIED_PROPS_INTEGRATION_FAILURES ",failures)
	quit(0 if failures==0 else 1)
