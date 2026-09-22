extends SceneTree
func _initialize(): call_deferred("run")
func run():
 assert(OS.get_user_data_dir().contains("RuneNexus-HUD-review-v4"))
 root.content_scale_size=Vector2i(320,150); root.size=Vector2i(320,150)
 var panel=preload("res://ui/turret_action_panel.gd").new(); root.add_child(panel); panel.position=Vector2(8,20); panel.size=Vector2(304,0)
 panel.configure({"title":"라이트닝","icon":"ui/hud/turrets_3d/lightning.png","level":"Lv.7 → 8","upgrade_title":"강화 확정","price":"123456 G","maximum":false,"trait_count":2,"active_tab":"stats","upgrade_callback":func(): pass,"trait_callback":func(): pass,"sell_callback":func(): pass,"stats_callback":func(): pass,"gems_callback":func(): pass})
 await create_timer(0.5).timeout
 for l in panel.find_children("*","Label",true,false):
  var w=l.get_theme_font("font").get_string_size(l.text,HORIZONTAL_ALIGNMENT_LEFT,-1,l.get_theme_font_size("font_size")).x
  assert(w<=l.size.x+0.2)
  print(l.text," font=",l.get_theme_font_size("font_size")," width=",w," area=",l.size.x)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/turret-actions/native/strict-audit/synthetic-dense-320.png")
 print("PASS synthetic dense label bounds")
 quit()
