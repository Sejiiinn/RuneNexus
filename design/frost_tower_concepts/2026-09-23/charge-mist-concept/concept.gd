extends Node3D
const OUT="/Users/sejin/Documents/Codex/RuneNexus/design/frost_tower_concepts/2026-09-23/charge-mist-concept/"
var charge_mat:ShaderMaterial
var mist_mat:ShaderMaterial
var mist:MultiMeshInstance3D
var enemy:Node3D
var lamp:OmniLight3D
var label:Label
var subtitle:Label
var frame=0
var camera:Camera3D
var capture=false
var enemy_materials=[]
var snapshots=[0,36,66,105,117,126,138,168]
var stats={}
func all_meshes(n:Node)->Array:
 var a=[]
 if n is MeshInstance3D:a.append(n)
 for c in n.get_children():a.append_array(all_meshes(c))
 return a
func surface(color:Color,metal=0.0)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=.68;return m
func _ready():
 capture=OS.get_cmdline_user_args().has("--capture")
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("091419");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("b3d4df");env.environment.ambient_light_energy=.6;env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-30,0);sun.light_color=Color("c6e0eb");sun.light_energy=2.2;sun.shadow_enabled=true;add_child(sun)
 var rim=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-20,130,0);rim.light_color=Color("56a7c6");rim.light_energy=.65;add_child(rim)
 camera=Camera3D.new();add_child(camera);camera.position=Vector3(3.3,3.3,4.8);camera.look_at(Vector3(0,.12,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.8;camera.current=true
 var tower=load("res://frost.glb").instantiate();add_child(tower)
 charge_mat=ShaderMaterial.new();charge_mat.shader=load("res://charge.gdshader")
 for o in all_meshes(tower):
  for i in o.mesh.get_surface_count():
   var m=o.get_active_material(i)
   if m and ("cold aluminum fins" in m.resource_name or "cold circulating core" in m.resource_name):o.set_surface_override_material(i,charge_mat)
 lamp=OmniLight3D.new();lamp.position=Vector3(0,.28,0);lamp.omni_range=1.15;lamp.light_color=Color("26c3e5");lamp.shadow_enabled=false;add_child(lamp)
 for x in range(-3,4):
  for z in range(-3,4):
   var tile=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.985,.09,.985);tile.mesh=box;tile.position=Vector3(x,-.067,z);tile.material_override=surface(Color(.055+.006*((x+z+6)%3),.081,.089),.12);add_child(tile)
 enemy=load("res://enemy.glb").instantiate();add_child(enemy);enemy.scale=Vector3.ONE*.7
 for o in all_meshes(enemy):
  for i in o.mesh.get_surface_count():
   var em=o.get_active_material(i).duplicate()
   if em is StandardMaterial3D:
    em.emission_enabled=false;em.albedo_color=Color("697d89");o.set_surface_override_material(i,em);enemy_materials.append(em)
 var source=load("res://mist-volume.glb").instantiate();var source_mesh=all_meshes(source)[0].mesh
 mist=MultiMeshInstance3D.new();mist.multimesh=MultiMesh.new();mist.multimesh.transform_format=MultiMesh.TRANSFORM_3D;mist.multimesh.use_custom_data=true;mist.multimesh.mesh=source_mesh;mist.multimesh.instance_count=32;mist.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mist.custom_aabb=AABB(Vector3(-2,-.2,-2),Vector3(4,1.4,4));add_child(mist)
 for i in 32:
  mist.multimesh.set_instance_transform(i,Transform3D.IDENTITY)
  mist.multimesh.set_instance_custom_data(i,Color(fposmod(i*.618,1.),fposmod(i*.381966,1.),.25+.75*fposmod(i*.719,1.),1.))
 mist_mat=ShaderMaterial.new();mist_mat.shader=load("res://mist.gdshader");var noise=NoiseTexture2D.new();noise.width=128;noise.height=128;noise.seamless=true;var fn=FastNoiseLite.new();fn.frequency=.045;fn.fractal_octaves=3;noise.noise=fn;mist_mat.set_shader_parameter("noise_tex",noise);mist.material_override=mist_mat
 source.queue_free()
 var canvas=CanvasLayer.new();add_child(canvas)
 label=Label.new();label.position=Vector2(48,37);label.add_theme_font_size_override("font_size",28);label.add_theme_color_override("font_color",Color("c5edf2"));canvas.add_child(label)
 subtitle=Label.new();subtitle.position=Vector2(48,79);subtitle.add_theme_font_size_override("font_size",16);subtitle.add_theme_color_override("font_color",Color("7ca4ad"));canvas.add_child(subtitle)
 var foot=Label.new();foot.text="FROST  /  CHARGE & RELEASE";foot.position=Vector2(48,746);foot.add_theme_font_size_override("font_size",14);foot.modulate=Color("71939e");canvas.add_child(foot)
 DirAccess.make_dir_recursive_absolute(OUT+"frames")
 apply_time(0.)
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 if capture:run_capture()
func apply_time(t:float):
 var charge=clampf(t/2.5,0.,1.) if t<4.65 else 0.0
 charge_mat.set_shader_parameter("charge",charge)
 lamp.light_energy=charge*.65
 var age=(t-4.65)/1.05
 mist.visible=age>=0.0 and age<1.0
 mist_mat.set_shader_parameter("age",clampf(age,0.,1.))
 enemy.position=Vector3(lerpf(2.9,1.3,clampf((t-3.5)/1.15,0.,1.)),0.,.2)
 if t>6.3:enemy.position.x=lerpf(1.3,2.9,clampf((t-6.3)/1.6,0.,1.))
 for em in enemy_materials:em.albedo_color=Color("a5dbe5") if t>4.95 and t<6.8 else Color("697d89")
 enemy.rotation.y=-PI/2
 label.text="CHARGING" if t<2.5 else ("READY" if t<4.65 else ("FROST RELEASE" if t<5.7 else "COOLING"))
 subtitle.text="Cooling fins fill from bottom to top" if t<2.5 else ("Holding charge until an enemy enters range" if t<4.65 else ("Cold mist spreads outward  /  1.58 tile radius" if t<5.7 else "Charge spent  /  cooling fins reset"))
func run_capture():
 for f in 192:
  frame=f;apply_time(float(f)/24.)
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  var img=get_viewport().get_texture().get_image();img.save_png(OUT+"frames/%04d.png"%f)
  if f in snapshots:img.save_png(OUT+"stage-%03d.png"%f)
  if f in [66,126]:stats[str(f)]={"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
 camera.size=9.5;apply_time(5.15)
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OUT+"actual-scale.png")
 var file=FileAccess.open(OUT+"runtime-stats.json",FileAccess.WRITE);file.store_string(JSON.stringify(stats,"  "))
 print("FROST_CONCEPT_CAPTURE_COMPLETE ",stats);get_tree().quit()
func _process(delta):
 if not capture:
  var t=fmod(Time.get_ticks_msec()/1000.,8.);apply_time(t)
