extends SceneTree
const Legacy = preload("res://ui/game_button.gd")
var app
var hud
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/native-frame-migration/buttons/"
func _initialize():call_deferred("run")
func capture(name:String):
 await create_timer(0.25).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+name+".png")
func find_button(prefix:String)->Button:
 for b in hud.overlay_body.find_children("*","Button",true,false):
  if b.text.begins_with(prefix):return b
 return null
func click(b:Button):
 var p=b.get_global_rect().get_center()
 for down in [true,false]:
  var e=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
 await create_timer(0.2).timeout
func run():
 assert(OS.get_user_data_dir().contains("RuneNexus-Frame-Buttons-Review"))
 var theme=preload("res://ui/battle_theme.gd")
 assert(theme.create().get_stylebox("normal","Button") is Legacy.GradientBox)
 assert(theme.create(true).get_stylebox("normal","Button") is StyleBoxTexture)
 var scene=load("res://main.tscn").instantiate();root.add_child(scene);await create_timer(2).timeout
 app=scene._standalone_session;app.start_stage(0);hud=app.hud
 for width in [320,440]:
  root.content_scale_size=Vector2i(width,760 if width==320 else 900);root.size=root.content_scale_size
  var s:Dictionary=app.run_domain.state
  s.phase="reward";s.completedRounds=5;s.rewardOptions=["attackSpeed","range","physicalDamage"];s.isPurchasedGemReward=false;s.gemShards=100
  hud.rewards.shard_selected=false;hud.rewards.key="";hud.refresh()
  await create_timer(0.3).timeout
  var shard=find_button("젬 대신 파편 획득")
  assert(shard!=null and shard.get_theme_stylebox("normal") is StyleBoxFlat)
  for state in ["hover","pressed","disabled"]:assert(shard.get_theme_stylebox(state) is StyleBoxTexture)
  await capture("reward-normal-"+str(width))
  var motion=InputEventMouseMotion.new();motion.position=shard.get_global_rect().get_center();root.push_input(motion,true)
  await capture("reward-hover-"+str(width))
  await click(shard);assert(hud.rewards.shard_selected)
  await capture("reward-selected-"+str(width))
  var claim=find_button("파편 받기");assert(claim!=null and claim.get_theme_stylebox("normal") is StyleBoxTexture)
  await click(claim);assert(app.run_domain.state.phase!="reward" and app.run_domain.state.gemShards>100)
  hud.menu_panel._stage_menu();await capture("stage-menu-"+str(width));hud.close_modal()
  print("PASS ",width," shard unchanged green normal, native interactive states, mouse selection and settlement, stage menu")
 print("PASS native button boundary: lobby legacy, combat texture")
 quit()
