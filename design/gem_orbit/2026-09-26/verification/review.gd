extends SceneTree
var scene
var app
var output := OS.get_environment("GEM_OUT")
func _initialize(): call_deferred("run")
func settle():
 for i in range(5): await process_frame
func capture(label):
 await settle()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label+".png"))
 print("CAPTURE ",label)
func command(kind, params={}):
 assert(app.selected_run_command(kind, params),kind)
 await settle()
func run():
 root.size=Vector2i(440,900)
 scene=load("res://main.tscn").instantiate();root.add_child(scene)
 for i in range(15):await process_frame
 app=scene._standalone_session
 assert(app.start_stage(0));await settle()
 app.run_domain.state.gold=100000
 app.run_domain.state.gemInventory={"range":9,"attackSpeed":9,"criticalChance":9,"physicalDamage":9}
 var map:Dictionary=app.catalog.stage(0).map
 var build_indices=[]
 for i in range(map.tiles.size()):
  if map.tiles[i]=="build":build_indices.append(i)
 var index:int=build_indices[0]
 app.board_tap(Vector2i(index%int(map.columns),index/int(map.columns)));app.build_selected();await settle()
 await command("equipGem",{"type":"range","slot":0})
 var first_id:int=app.run_domain.selected_id(app.selected)
 var orbit=scene.turrets[first_id].gem_orbit
 assert(orbit._colors.size()==1)
 await capture("review-one")
 await command("link")
 await command("equipGem",{"type":"attackSpeed","slot":1})
 assert(orbit._colors.size()==2)
 for i in range(4):await command("level")
 await command("link")
 await command("equipGem",{"type":"criticalChance","slot":2})
 assert(orbit._colors.size()==3)
 await capture("review-three")
 scene.set_process(false);app.set_process(false)
 var old_camera:Transform3D=scene.camera.transform
 var old_size:float=scene.camera.size
 scene.camera.near=0.01;scene.camera.far=100;scene.camera.size=2.3;scene.camera.h_offset=0;scene.camera.v_offset=0
 var center:Vector3=scene.turrets[first_id].root.global_position
 scene.camera.position=center+Vector3(2,3,3);scene.camera.look_at(center)
 scene._presentation_layer.hide();app.hud.hide()
 await capture("review-detail-final")
 scene.camera.transform=old_camera;scene.camera.size=old_size
 scene._presentation_layer.show();app.hud.show()
 scene.set_process(true);app.set_process(true)
 await command("equipGem",{"type":"physicalDamage","slot":0})
 assert(orbit._colors[0]==Color("F4F7FA"))
 await capture("review-replaced")
 await command("removeGem",{"slot":1})
 assert(orbit._colors.size()==2 and orbit._colors[1]==Color("FF5F7E"))
 await command("removeGem",{"slot":2})
 await command("removeGem",{"slot":0})
 assert(not orbit.visible and orbit._rotor==null)
 await capture("review-removed")
 await command("equipGem",{"type":"range","slot":0})
 await command("sell")
 assert(not scene.turrets.has(first_id))
 var types=["arrow","cannon","magic","frost"]
 for j in range(types.size()):
  index=build_indices[j]
  app.turret_type=types[j]
  app.board_tap(Vector2i(index%int(map.columns),index/int(map.columns)));app.build_selected();await settle()
  await command("equipGem",{"type":"range","slot":0})
  var id:int=app.run_domain.selected_id(app.selected)
  assert(scene.turrets[id].gem_orbit._colors.size()==1)
 app.start_wave();await create_timer(0.35).timeout
 app.toggle_pause();await settle()
 var id:int=scene.turrets.keys()[0]
 var effect=scene.turrets[id].gem_orbit
 var frozen:Transform3D=effect._rotor.transform
 await create_timer(0.2).timeout
 assert(effect._rotor.transform.is_equal_approx(frozen))
 await capture("review-paused-types")
 app.toggle_camera();await capture("review-drone-types")
 app.set_speed(4.0);app.toggle_pause();await create_timer(0.15).timeout
 assert(not effect._rotor.transform.is_equal_approx(frozen))
 assert(is_equal_approx(effect._rotor.rotation.y,-fposmod(float(scene.last_frame.time)*effect.ANGULAR_SPEED,TAU)))
 app.toggle_pause();await settle()
 scene._clear_scene();assert(scene.turrets.is_empty())
 print("PASS independent actual app: equip1/2/3 replacement/null-slot removal/sale/rebuild four turret types/pause/4x clock/camera/scene reset")
 scene.free();await process_frame;quit()
