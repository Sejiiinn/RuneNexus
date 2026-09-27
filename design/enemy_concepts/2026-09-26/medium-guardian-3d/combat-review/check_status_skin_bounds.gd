extends SceneTree
const Units = preload("res://presentation/battlefield_units.gd")
func _initialize() -> void:
	call_deferred("run")
func bounds(mesh: MeshInstance3D, skeleton: Skeleton3D) -> AABB:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var result := AABB()
	for i in range(vertices.size()):
		var point := Vector3.ZERO
		for influence in range(4):
			var bind := bones[i*4+influence]
			var bone := mesh.skin.get_bind_bone(bind)
			if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
			point += (skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * vertices[i]) * weights[i*4+influence]
		point = mesh.global_transform * point
		result = AABB(point,Vector3.ZERO) if i == 0 else result.expand(point)
	return result
func run() -> void:
	var world := Node3D.new()
	var camera := Camera3D.new()
	root.add_child(world)
	root.add_child(camera)
	var units = Units.new(world,camera)
	units.configure(0.0,Vector2i(8,10),{"volume":true})
	units._sync_enemies([[1,4.0,5.0,PI/2.0,0.0,0.55,0.0,"normal",true,true]])
	var entry: Dictionary = units.enemies[1]
	var body: MeshInstance3D = entry.frost_bodies[0][0]
	var skeleton: Skeleton3D = body.get_node(body.skeleton)
	var failed := false
	for time in [0.0,0.1083,0.2167,0.325,0.4333]:
		entry.player.seek(time,true)
		entry.player.advance(0.0)
		skeleton.force_update_all_bone_transforms()
		var body_bounds := bounds(body,skeleton)
		for effect: MeshInstance3D in entry.frost.get_children()+entry.burn.get_children():
			var box := bounds(effect,skeleton)
			var maximum: float = maxf(box.size.x,maxf(box.size.y,box.size.z))
			failed = failed or maximum > 0.9 or box.position.distance_to(body_bounds.position) > 0.55
			print("STATUS_SKIN_BOUNDS time=",time," mesh=",effect.mesh.resource_path.get_file()," body=",body_bounds," effect=",box)
	units.clear()
	world.free()
	camera.free()
	print("GUARDIAN_STATUS_SKIN_BOUNDS ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
