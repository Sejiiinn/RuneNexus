extends SceneTree
const Fixture=preload("res://verify_lobby_header.gd")
var lobby
func _initialize():call_deferred("run")
func click(b:Button,edge:=false):
 var r=b.get_global_rect();var p=r.position+Vector2(2,r.size.y/2) if edge else r.get_center()
 var m=InputEventMouseMotion.new();m.position=p;root.push_input(m,true)
 for down in [true,false]:
  var e=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
 await create_timer(0.25).timeout
func run():
 assert(OS.get_user_data_dir().contains("RuneNexus-lobby-header-review"))
 var app=Fixture.FakeApp.new();assert(app.catalog.load_catalog());assert(app.run_domain.growth.load_catalog())
 lobby=load("res://ui/lobby.gd").new();lobby.app=app;root.add_child(lobby)
 for w in [320,440]:
  root.size=Vector2i(w,900);root.content_scale_size=root.size
  app.progression_inputs.freeDiamonds=123456789012345678 if w==320 else 1280
  app.progression_inputs.runes=987654321012345678 if w==320 else 10000
  lobby.open_page("스테이지");await create_timer(0.3).timeout
  var before=app.progression_inputs.duplicate(true)
  await click(lobby.find_child("StageQuests",true,false));assert(is_instance_valid(lobby.modal),"quest actual input")
  assert(app.progression_inputs==before,"opening quests does not mutate progression")
  assert(lobby.close_modal());await create_timer(0.2).timeout
  await click(lobby.find_child("MenuBack",true,false),true);assert(lobby.page=="로비" and is_instance_valid(lobby.home),"edge back actual input")
  lobby.open_page("강화");await create_timer(0.3).timeout
  await click(lobby.find_child("MenuBack",true,false));assert(lobby.page=="로비","normal back input")
  print("PASS ",w," viewport mouse quest, edge back, title-page back; state unchanged")
 print("PASS independent header hit audit")
 lobby.free();quit()
