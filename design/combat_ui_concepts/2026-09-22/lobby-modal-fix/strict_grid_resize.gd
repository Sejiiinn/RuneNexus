extends SceneTree
const Fixture=preload("res://verify_lobby_modal.gd")
func _initialize():call_deferred("run")
func run():
 assert(OS.get_user_data_dir().contains("RuneNexus-lobby-modal-review"))
 var app=Fixture.FakeApp.new();app.catalog.load_catalog();app.run_domain.growth.load_catalog()
 var lobby=load("res://ui/lobby.gd").new();lobby.app=app;root.add_child(lobby)
 root.content_scale_size=Vector2i(440,760);root.size=Vector2i(440,900)
 lobby.open_page("스테이지");await create_timer(0.3).timeout;lobby.stages.details(8);await create_timer(0.4).timeout
 for w in [440,320,440]:
  root.content_scale_size=Vector2i(w,760);root.size=Vector2i(w,900);await create_timer(0.4).timeout
  var r:Rect2=lobby.modal_frame.get_global_rect()
  print("RESIZE ",w," frame=",r," viewport=",lobby.size)
  var ok=Rect2(Vector2.ZERO,lobby.size).encloses(r)
  for l in lobby.modal_frame.find_children("*","Label",true,false):
   if l.text=="전투 강화 비용 최적화":
    print("REWARD font=",l.get_theme_font_size("font_size")," width=",l.size.x," columns=",l.get_parent().get_parent().get_parent().columns)
    ok=ok and l.get_theme_font_size("font_size")==10 and l.size.x>=l.get_minimum_size().x
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/lobby-modal-fix/strict-resize-"+str(w)+".png")
  if not ok:print("FAIL same modal resize reward");quit(1);return
 print("PASS same modal 440→320→440 readable rewards and viewport bounds")
 lobby.free();quit()
