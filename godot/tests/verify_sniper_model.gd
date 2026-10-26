extends SceneTree
## SWIFT asset/rig contract and existing frame-driven tracking/fire lifecycle.
const WeaponAtlas=preload("res://effects/weapon_atlas.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value: failures.append(label);push_error(label)
func sync(scene, time:float, angle:float, shots:int, feedback:float) -> void:
	scene.last_frame.time=time
	scene._sync_turrets([[71,2.5,3.5,angle,shots,feedback,"sniper",1]])
func run() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	sync(scene,1.0,0.0,0,0.0)
	var e:Dictionary=scene.turrets[71]
	check(e.head.get_parent().name=="turret_root" and e.root.is_ancestor_of(e.head) and e.barrel.get_parent()==e.head and e.muzzle.get_parent()==e.barrel,"root/head/barrel/muzzle ownership")
	check(e.root.scale.is_equal_approx(Vector3.ONE) and e.head.position.is_equal_approx(Vector3(0,.45,0)),"original scale and low head pivot")
	check(e.muzzle.position.is_equal_approx(Vector3(0,.326,1.099)),"approved long barrel muzzle marker")
	var triangles:=0
	var names:=[]
	for mesh:MeshInstance3D in e.root.find_children("*","MeshInstance3D",true,false):
		if mesh is WeaponAtlas or mesh.has_meta("exclude_selection_mask"): continue
		names.append(mesh.name)
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays:Array=mesh.mesh.surface_get_arrays(surface)
			triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
	check(triangles==9816 and names.size()==3,"approved SWIFT three meshes and 9816 triangles")
	check(e.root.find_children("*","CollisionObject3D",true,false).is_empty(),"visual asset adds no local physics")
	var first_direction:Vector3=e.muzzle.global_position-e.head.global_position
	sync(scene,1.1,PI/2,0,0.0)
	var second_direction:Vector3=e.muzzle.global_position-e.head.global_position
	check(first_direction.x>1 and absf(first_direction.z)<.001 and second_direction.z>1 and absf(second_direction.x)<.001,"native aim angle tracks both axes with full barrel")
	sync(scene,2.0,PI/2,1,1.0)
	check(e.sniper_effect.flash.visible and e.flashes.is_empty() and e.smokes.is_empty(),"new shot uses only approved solid effect")
	check(e.sniper_effect.flash.get_parent()==e.muzzle,"solid flash follows long muzzle")
	sync(scene,2.018,PI/2,1,1.0)
	check(is_equal_approx(e.barrel.position.z,-.045),"existing peak recoil .045 at .018 seconds")
	check(is_equal_approx(e.muzzle.global_position.z-e.head.global_position.z,1.054),"long muzzle follows barrel recoil")
	var held:Vector3=e.muzzle.global_position
	sync(scene,2.018,PI/2,1,1.0)
	check(e.muzzle.global_position.is_equal_approx(held),"paused combat clock holds recoil")
	sync(scene,2.16,PI/2,1,0.0)
	check(is_zero_approx(e.barrel.position.z) and not e.sniper_effect.flash.visible,"existing .14-second recovery and flash expiry")
	sync(scene,2.4,PI/2,1,0.0)
	check(not e.sniper_effect.line.visible,"idle effects hide after combat-clock expiry")
	scene._sync_build_preview([99,2.5,3.5,0,0,0,"sniper",1])
	check(scene._build_preview.head.find_child("turret_head_geometry",true,false)!=null,"build preview uses SWIFT mesh")
	var old_root=weakref(e.root);scene._sync_turrets([])
	check(old_root.get_ref()==null,"sale removes model and attached effects")
	sync(scene,3.0,0.0,5,1.0)
	check(not scene.turrets[71].sniper_effect.flash.visible and not scene.turrets[71].sniper_effect.line.visible,"restored shot history does not replay")
	var restored=weakref(scene.turrets[71].root);scene._clear_scene()
	check(restored.get_ref()==null,"epoch reset removes model/effects")
	print("SNIPER_MODEL failures=",failures," triangles=",triangles)
	quit(0 if failures.is_empty() else 1)
