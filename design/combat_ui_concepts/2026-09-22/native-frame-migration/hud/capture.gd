extends SceneTree
var app
var hud
var prefix := "before"
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/native-frame-migration/hud/"
func _initialize(): call_deferred("run")
func capture(label: String):
 hud.refresh()
 await create_timer(0.3).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+prefix+"-"+label+".png")
 print("CAPTURE ",prefix," ",label," dock=",hud.dock.get_global_rect()," start=",hud.start.get_global_rect())
func run():
 assert(OS.get_user_data_dir().contains("RuneNexus-Frame-HUD-review"))
 root.gui_embed_subwindows=true
 for arg in OS.get_cmdline_user_args():
  if arg=="--after":prefix="after"
 var scene=load("res://main.tscn").instantiate();root.add_child(scene)
 await create_timer(2).timeout
 app=scene._standalone_session
 app.start_stage(0);hud=app.hud
 app.run_domain.state.gold=3000
 for width in [320,440]:
  root.content_scale_size=Vector2i(width,760 if width==320 else 900);root.size=root.content_scale_size
  app.board_tap(Vector2i(-1,-1));hud.main_tab="turrets";hud.body_key=""
  await capture("picker-"+str(width))
  hud.auto_start.pressed.emit()
  await capture("popup-"+str(width))
  assert(hud.auto_start_popup.visible)
  hud.auto_start_popup.hide()
 # Existing start/pause/resume actions, while the same frame is live.
 hud.start.pressed.emit();await create_timer(0.5).timeout
 if not app.scene._native_combat.session.paused:hud.pause_button.pressed.emit()
 await capture("resume-440")
 quit()
