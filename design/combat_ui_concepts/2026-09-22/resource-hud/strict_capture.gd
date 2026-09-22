extends SceneTree
var app
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/resource-hud/"
func _initialize(): call_deferred("run")
func click(button: Button):
 var pos=button.get_global_rect().get_center()
 var m=InputEventMouseMotion.new();m.position=pos;root.push_input(m,true)
 for pressed in [true,false]:
  var e=InputEventMouseButton.new();e.position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;root.push_input(e,true);await process_frame
 await create_timer(0.25).timeout
func run():
 assert(OS.get_user_data_dir().contains("RuneNexus-HUD-review-v4"))
 var scene=load("res://main.tscn").instantiate();root.add_child(scene)
 await create_timer(2).timeout
 app=scene._standalone_session;app.start_stage(0)
 app.run_domain.state.gold=3000;app.run_domain.state.gemShards=100
 for width in [320,440]:
  root.content_scale_size=Vector2i(width,760 if width==320 else 900);root.size=root.content_scale_size
  app.hud.refresh();await create_timer(0.35).timeout
  var frame=app.hud.top.get_node("ResourceHUD");var rect: Rect2=frame.get_global_rect()
  assert(rect==Rect2(8,8,width-16,94))
  assert(frame.get_theme_stylebox("panel") is StyleBoxTexture)
  var style=frame.get_theme_stylebox("panel")
  assert(style.texture.resource_path.ends_with("resource_panel.png"))
  assert(style.texture_margin_left==14 and style.texture_margin_right==14 and style.texture_margin_top==14 and style.texture_margin_bottom==14)
  assert(style.content_margin_left==8 and style.content_margin_top==8)
  for control in [frame]+frame.find_children("*","Control",true,false):
   assert(control.scale==Vector2.ONE)
   if control is Label:
    var c:Rect2=control.get_global_rect()
    assert(rect.encloses(c))
    var w=control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x
    assert(w<=control.size.x+0.1,"label clipped: "+control.text)
    print(width," TEXT ",control.text," rect=",c)
  assert(app.hud.gold_label.text=="3000" and app.hud.shard_label.text=="100")
  assert(app.hud.resources.text=="전투력 0.0")
  await RenderingServer.frame_post_draw
  var img=root.get_texture().get_image();img.save_png(out+"strict-"+str(width)+".png")
  img.get_region(Rect2i(rect)).save_png(out+"strict-top-"+str(width)+".png")
  await click(app.hud.home)
  assert(app.hud.modal_active(),"mouse home did not open menu")
  var close:Button
  for b in app.hud.modal_body.find_children("*","Button",true,false):
   if b.text=="×":close=b;break
  assert(close!=null);await click(close);assert(not app.hud.modal_active())
  print("PASS ",width," bounds, native frame, label widths, exact wallet, mouse home open/close")
 print("PASS strict ResourceHUD local audit")
 quit()
