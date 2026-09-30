extends SceneTree
## Maintained presentation regression: approved geometry, surface end and lifecycle.
const SniperVfx = preload("res://effects/sniper_vfx.gd")
var checks := 0
var failures: Array[String] = []
var scene
func _initialize() -> void: run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func frame(time:float,shots:int,feedback:float,aiming:=false,target:=91,ratio:=.5) -> void:
	scene.last_frame.time=time
	scene._sync_turrets([[71,2.5,3.5,0.0,shots,feedback,"sniper",1,{"aimActive":aiming,"aimTargetId":target,"aimProgress":.5 if aiming else 0.0,"aimRatio":ratio if aiming else 0.0}]])
	scene._units.sync_sniper_aim()
func triangles(node:Node) -> int:
	var total:=0
	for mesh:MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			total+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
	return total
func run() -> void:
	scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	frame(1.0,0,0.0)
	scene._sync_enemies([[91,5.0,3.5,0,0,1.0,0,"armored"]])
	frame(1.1,0,0.0,true)
	var e:Dictionary=scene.turrets[71];var fx:SniperVfx=e.sniper_effect
	check(triangles(fx.flash)==56 and triangles(fx.line)==20,"approved 56-triangle flash and 20-triangle solid line")
	check(e.flashes.is_empty() and e.smokes.is_empty(),"no duplicate shared atlas flash or smoke")
	check(fx.flash.get_parent()==e.muzzle,"approved flash follows muzzle recoil")
	check(fx.line.visible,"valid aiming target displays line")
	check(fx.line_start.is_equal_approx(e.barrel.to_global(SniperVfx.LENS_ORIGIN)),"line starts at approved cyan lens front")
	check(fx.line_end.is_finite() and fx.line_end.distance_to(fx.line_start)>1.0,"line ends at actual target surface")
	check((fx.line.global_transform*Vector3(0,-.5,0)).distance_to(fx.line_start)<.00001 and (fx.line.global_transform*Vector3(0,.5,0)).distance_to(fx.line_end)<.00001,"actual angled GLB cylinder endpoints match lens and target surface")
	check(not SniperVfx.AIM_ENERGY.code.contains("depth_test_disabled") and not SniperVfx.AIM_ENERGY.code.contains("TIME"),"local energy shader retains normal depth and supplied game clock")
	check(fx.aim_layers.size()==4 and fx.aim_materials.size()==4,"authored core and three bounded 3D radiance volumes")
	check(fx.aim_layers[2].global_position.is_equal_approx(fx.line_start) and fx.aim_layers[3].global_position.is_equal_approx(fx.line_end),"compact light points follow lens and actual surface")
	var material:ShaderMaterial=fx.line_materials[0].material
	var material_id:=material.get_instance_id()
	frame(1.1,0,0.0,true,91,0.0)
	var dim:float=material.get_shader_parameter("charge")
	frame(1.1,0,0.0,true,91,.5)
	var middle:float=material.get_shader_parameter("charge")
	frame(1.1,0,0.0,true,91,1.0)
	check(dim<middle and middle<float(material.get_shader_parameter("charge")),"actual private shader receives normalized early/middle/late charge")
	check(is_equal_approx(material.get_shader_parameter("charge"),1.0),"completed aim reaches white cyan energy stage")
	var peer:SniperVfx=scene._units._new_turret("sniper").sniper_effect
	peer.show_aim(fx.line_end,0.0,1.1)
	check(peer.line_materials[0].material!=material and float(peer.line_materials[0].material.get_shader_parameter("charge"))<float(material.get_shader_parameter("charge")),"different turret aim progress owns independent shader state")
	var source_material:StandardMaterial3D=fx.line.find_children("*","MeshInstance3D",true,false)[0].mesh.surface_get_material(0)
	check(source_material.albedo_color.is_equal_approx(fx.line_materials[0].albedo) and is_equal_approx(source_material.emission_energy_multiplier,fx.line_materials[0].energy),"shared approved line material is unchanged")
	peer.get_parent().free()
	frame(1.1,0,0.0,true,91,.5)
	check(material.get_instance_id()==material_id and is_equal_approx(material.get_shader_parameter("charge"),middle) and is_equal_approx(material.get_shader_parameter("game_time"),1.1),"pause holds shader clock/charge and reuses material without allocation")
	# A ray through armored's symmetric shared edge must stop at the outer face.
	var surface=scene.enemies[91].sniper_surface
	var center:Vector3=surface.aim_point()
	var edge:Vector3=surface.first_hit(center+Vector3(3,1.2,0),center)
	check(edge.is_finite() and edge.distance_to(scene.enemies[91].root.global_position+Vector3(.303744,.846300,0))<.00025,"shared-edge ray selects armored outer first surface")
	var held:Transform3D=fx.line.global_transform
	frame(1.1,0,0.0,true)
	check(fx.line.global_transform.is_equal_approx(held) and not fx.flash.visible,"pause holds aim without advancing flash")
	var endpoint:Vector3=fx.line_end
	scene._sync_enemies([[91,5.5,4.0,0,0,1.0,0,"armored"]])
	check(fx.line_end.distance_to(endpoint)>.1,"moving or teleporting target updates surface endpoint immediately")
	frame(2.0,1,1.0,false)
	check(fx.flash.visible and fx.aim_layers.all(func(layer):return not layer.visible),"native shot hides all aim radiance and shows single solid flash")
	frame(2.018,1,1.0,false)
	var peak:Vector3=e.muzzle.global_position
	check(is_equal_approx(e.barrel.position.z,-.045),"original recoil and peak timing unchanged")
	frame(2.018,1,1.0,false)
	check(fx.flash.visible and e.muzzle.global_position.is_equal_approx(peak),"pause holds fired flash and recoil")
	frame(2.16,1,0.0,false)
	check(not fx.flash.visible and not fx.line.visible and is_zero_approx(e.barrel.position.z),"cooldown/idle hides effects and returns original recoil")
	frame(2.3,1,0.0,true)
	scene._sync_enemies([])
	check(fx.aim_layers.all(func(layer):return not layer.visible),"dead or missing target hides all radiance despite retained metadata")
	frame(2.4,1,0.0,true,999)
	check(not fx.line.visible,"invalid target cannot retain stale endpoint")
	frame(2.5,2,1.0,false)
	check(fx.flash.visible,"new sequence fires once")
	frame(1.0,2,1.0,false)
	check(not fx.flash.visible and not fx.line.visible,"rewind does not replay old shot or retain aim")
	var old=weakref(e.root);scene._sync_turrets([])
	check(old.get_ref()==null,"sell removes both attached effects")
	frame(3.0,8,1.0,false)
	check(not scene.turrets[71].sniper_effect.flash.visible,"restored root with residual feedback does not replay history")
	frame(3.1,9,1.0,false)
	check(scene.turrets[71].sniper_effect.flash.visible,"restored root can fire next new sequence")
	var restored=weakref(scene.turrets[71].root);scene._clear_scene()
	check(restored.get_ref()==null,"reset removes all sniper model and effect nodes")
	print("SNIPER_VFX checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
