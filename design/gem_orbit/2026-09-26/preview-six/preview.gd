extends SceneTree
var scene
var app
func _initialize(): call_deferred("run")
func sample(label):
 for i in range(8): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("GEM_OUT").path_join(label+".png"))
 print("CAPTURE ",label)
func run():
 root.size=Vector2i(440,900)
 scene=load("res://main.tscn").instantiate(); root.add_child(scene)
 for i in range(15): await process_frame
 app=scene._standalone_session
 assert(app.start_stage(0))
 for i in range(10): await process_frame
 app.run_domain.state.gold=10000
 app.run_domain.state.gemInventory={"range":2,"attackSpeed":2,"criticalChance":2}
 var map:Dictionary=app.catalog.stage(0).map
 var index:int=map.tiles.find("build")
 app.board_tap(Vector2i(index%int(map.columns),index/int(map.columns)))
 app.build_selected()
 assert(app.selected_run_command("equipGem",{"type":"range","slot":0}))
 var entry:Dictionary=scene.turrets.values()[0]
 assert(entry.has("gem_orbit"))
 # Presentation fixture only: six rendered gems, no gameplay slot/rule changes.
 scene.set_process(false); app.set_process(false)
 var palette = preload("res://ui/battle_rewards.gd").GEM_COLORS
 var colors:Array=[]
 for kind in ["range","attackSpeed","criticalChance","chain","multipleProjectiles","explosion"]:
  colors.append(Color(str(palette[kind])))
 entry.gem_orbit.configure(colors)
 entry.gem_orbit.update_time(0.6)
 assert(entry.gem_orbit._rotor.get_child_count()==6)
 await sample("six-game-scale")
 scene.camera.near=0.01;scene.camera.far=100;scene.camera.size=2.3;scene.camera.h_offset=0;scene.camera.v_offset=0
 var center:Vector3=entry.root.global_position
 scene.camera.position=center+Vector3(2.0,3.0,3.0)
 scene.camera.look_at(center)
 scene._presentation_layer.hide(); app.hud.hide(); scene.options.turret_levels=false
 print("ROOT ",entry.root.global_transform," GEM ",entry.gem_orbit.global_transform)
 await sample("six-detail")
 scene.camera.position=center+Vector3(0,4,0.01)
 scene.camera.look_at(center)
 scene._turret_level_labels.hide()
 await sample("six-top")
 print("PASS six-gem presentation fixture; gameplay slot limits unchanged")
 scene.free(); await process_frame;quit()
