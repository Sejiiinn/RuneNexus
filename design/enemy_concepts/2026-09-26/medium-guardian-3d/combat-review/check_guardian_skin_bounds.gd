extends SceneTree
var world: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	world=Node3D.new()
	root.add_child(world)
	var helper=load("res://presentation/guardian_preview.gd").new(world)
	helper.prepare()
	for mode in ["walk","death"]:
		var entry: Dictionary=helper._instantiate(helper._walk_scene if mode=="walk" else helper._death_scene,0.0)
		entry.root.scale=Vector3.ONE*0.55
		for age in [0.0,0.1083333,0.2166667,0.4]:
			entry.player.seek(age,true)
			entry.player.advance(0.0)
			var bounds:=AABB()
			var first:=true
			for mesh: MeshInstance3D in entry.root.find_children("*","MeshInstance3D",true,false):
				var skeleton:=mesh.get_node(mesh.skeleton) as Skeleton3D
				var skin:=mesh.skin
				for surface in range(mesh.mesh.get_surface_count()):
					var arrays:=mesh.mesh.surface_get_arrays(surface)
					var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
					var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
					var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
					for v in range(verts.size()):
						var p:=Vector3.ZERO
						for j in range(4):
							var bind:=bones[v*4+j]
							var bone:=skin.get_bind_bone(bind)
							if bone<0: bone=skeleton.find_bone(skin.get_bind_name(bind))
							p += (skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind)*verts[v])*weights[v*4+j]
						p=skeleton.global_transform*p
						if first: bounds=AABB(p,Vector3.ZERO);first=false
						else: bounds=bounds.expand(p)
			print("GUARDIAN_SKIN_BOUNDS ",mode," t=",age," ",bounds)
		entry.root.free()
	helper.clear()
	helper=null
	world.queue_free()
	await process_frame
	quit()
