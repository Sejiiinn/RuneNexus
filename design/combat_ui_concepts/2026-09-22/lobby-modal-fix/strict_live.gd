extends SceneTree
var app
var lobby
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/lobby-modal-fix/"
func _initialize():call_deferred("run")
func click(c:Control):
 var p=c.get_global_rect().get_center()
 assert(Rect2(Vector2.ZERO,lobby.size).has_point(p),"input outside viewport")
 var m=InputEventMouseMotion.new();m.position=p;root.push_input(m,true)
 for down in [true,false]:
  var e=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
func check(stage:int):
 var r:Rect2=lobby.modal_frame.get_global_rect()
 assert(Rect2(Vector2.ZERO,lobby.size).encloses(r),"frame escaped viewport")
 assert(r.get_center().distance_to(lobby.size/2)<1,"frame not centered")
 assert(lobby.modal_visual.scale.is_equal_approx(Vector2.ONE))
 for l in lobby.modal_frame.find_children("*","Label",true,false):
  if l.text in ["기록 없음","잠김","클리어 보상","강화","연구","최초 클리어 보상"]:assert(l.get_line_count()==1,"vertical label "+l.text)
 var action=lobby.modal_body.find_child("StageAction",true,false)
 assert(lobby.modal_scroll.get_global_rect().encloses(action.get_global_rect()),"start not reachable")
 print("CHECK stage=",stage," physical=",root.size," logicalsetting=",root.content_scale_size," viewport=",root.get_visible_rect()," frame=",r)
 return r
func open_stage(stage:int):
 lobby.open_page("스테이지");lobby.stages.select_chapter(ceili(stage/5.0))
 await create_timer(0.7).timeout
 for c in lobby.stages.canvas.get_children():
  if c is Button and c.tooltip_text=="스테이지 %d 상세"%stage:await click(c);break
 assert(is_instance_valid(lobby.modal),"stage click missing modal")
func run():
 assert(OS.get_user_data_dir().contains("RuneNexus-lobby-modal-review"))
 assert(not ProjectSettings.get_setting("accessibility/disable_animations",false))
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 root.content_scale_size=Vector2i(440,760);root.size=Vector2i(440,900)
 var scene=load("res://main.tscn").instantiate();root.add_child(scene);await create_timer(2).timeout
 app=scene._standalone_session;lobby=app.lobby
 assert(app.get_script().resource_path.ends_with("app_lifecycle.gd"))
 assert(app.in_lobby)
 print("REAL APP ",app.get_script().resource_path," USER ",OS.get_user_data_dir())
 for stage in [8,11,1]:
  app.progression_inputs.unlockedStageCount=2 if stage!=11 else 11
  await open_stage(stage);await create_timer(0.4).timeout
  var original:Rect2=check(stage)
  await create_timer(0.6).timeout
  assert(lobby.modal_frame.get_global_rect()==original,"late animation drift")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"strict-real-stage"+str(stage)+".png")
  var action=lobby.modal_body.find_child("StageAction",true,false)
  if stage==8:
   assert(action.disabled);await click(action);assert(app.in_lobby and is_instance_valid(lobby.modal))
  await click(lobby.modal_frame.find_child("CloseStageDetails",true,false));assert(not is_instance_valid(lobby.modal));await create_timer(0.3).timeout
  await open_stage(stage);await create_timer(0.04).timeout
  root.size=Vector2i(440,1100);await create_timer(0.4).timeout;check(stage)
  root.size=Vector2i(440,900);await create_timer(0.4).timeout;check(stage)
  if stage==1:
   await click(lobby.modal_body.find_child("StageAction",true,false));await create_timer(0.5).timeout
   assert(not app.in_lobby and app.stage==0 and scene._native_combat.active,"actual app stage1 start failed")
   print("PASS actual AppLifecycle started stage1")
  else:
   await click(lobby.modal_frame.find_child("CloseStageDetails",true,false));assert(not is_instance_valid(lobby.modal));await create_timer(0.3).timeout
 print("PASS independent real AppLifecycle/Lobby modal: animations ON, stage8/11/1, stable geometry, reentry, resize, hit close/start")
 quit()
