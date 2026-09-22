extends SceneTree
const OUT = "/Users/sejin/Documents/Codex/RuneNexus/design/fire_tower_concepts/runic_3d/scale-90"
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	root.size = Vector2i(960, 960)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var f: Dictionary = scene.last_frame.duplicate(true)
	f["turrets"] = [[701, 3.5, 3.5, PI/2.0, 0, 0.0, "magic", 1]]
	f["enemies"]=[];f["projectiles"]=[];f["impacts"]=[];f["buildPreview"]=null
	f["seq"]=900;f["time"]=1.0
	scene._apply_frame(f)
	var t: Node3D=scene.turrets[701]["root"]
	var model: Node3D = t.find_child("turret_root", true, false)
	if model == null: model = t
	assert(model.scale.is_equal_approx(Vector3.ONE * 0.9), "Model must retain 90% scale in combat")
	var center: Vector3=t.global_position+Vector3(0,.50,.035)
	scene.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	scene.camera.near=.05;scene.camera.far=100.0
	scene.camera.size=1.65;scene.camera.h_offset=0;scene.camera.v_offset=0
	for view in ["hero","rear","drone"]:
		var direction=Vector3(3.2,2.6,3) if view=="hero" else (Vector3(-2.6,2.5,-3) if view=="rear" else Vector3(0.1,5,1.5))
		scene.camera.position=center+direction
		scene.camera.look_at(center)
		for i in range(12):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"/godot-"+view+".png")
	print("Runic native three-view capture complete")
	scene.queue_free()
	await process_frame
	quit()
