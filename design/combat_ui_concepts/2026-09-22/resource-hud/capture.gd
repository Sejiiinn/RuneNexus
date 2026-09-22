extends SceneTree
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/resource-hud/"
var app
func _initialize(): call_deferred("run")
func capture(prefix: String,width: int,height: int):
 root.content_scale_size=Vector2i(width,height); root.size=Vector2i(width,height)
 app.hud.refresh()
 await create_timer(0.35).timeout
 await RenderingServer.frame_post_draw
 var screenshot := root.get_texture().get_image()
 var frame: Control = app.hud.top.get_node("ResourceHUD")
 var bounds := Rect2i(frame.get_global_rect())
 screenshot.save_png(out+prefix+"-"+str(width)+".png")
 var top := screenshot.get_region(bounds)
 top.save_png(out+prefix+"-top-"+str(width)+".png")
 for corner in [["tl",Vector2i(0,0)],["tr",Vector2i(bounds.size.x-32,0)],["bl",Vector2i(0,bounds.size.y-32)],["br",bounds.size-Vector2i(32,32)]]:
  top.get_region(Rect2i(corner[1],Vector2i(32,32))).save_png(out+prefix+"-"+corner[0]+"-"+str(width)+".png")
 print("CAPTURE ",prefix," ",width," ",bounds)
func run():
 assert(OS.get_user_data_dir().contains("RuneNexus-HUD-review-v4"))
 var scene = load("res://main.tscn").instantiate(); root.add_child(scene)
 await create_timer(2).timeout
 app=scene._standalone_session
 app.start_stage(0)
 app.run_domain.state.gold=3000; app.run_domain.state.gemShards=100
 var prefix := "before"
 for arg in OS.get_cmdline_user_args():
  if arg == "--after": prefix="after"
 await capture(prefix,320,760)
 await capture(prefix,440,900)
 if prefix == "after":
  var point: Vector2 = app.hud.home.get_global_rect().get_center()
  var move := InputEventMouseMotion.new(); move.position=point; Input.parse_input_event(move)
  await process_frame
  var down := InputEventMouseButton.new(); down.position=point; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
  Input.parse_input_event(down); await process_frame
  var up := InputEventMouseButton.new(); up.position=point; up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false
  Input.parse_input_event(up); await process_frame; await process_frame
  assert(app.hud.modal_active(),"Resource HUD home must open the stage menu through mouse input")
  await create_timer(0.35).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+"after-home-440.png")
  print("PASS resource HUD home mouse input")
 quit()
