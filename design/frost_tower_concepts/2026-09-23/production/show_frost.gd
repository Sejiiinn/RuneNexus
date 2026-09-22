extends SceneTree
func _initialize() -> void: call_deferred("launch")
func launch() -> void:
 var scene=load("res://main.tscn").instantiate()
 root.add_child(scene)
 await create_timer(1.5).timeout
 var app=scene._standalone_session
 if app.startup_blocked:
  print("LOCAL_PLAY_STARTUP_BLOCKED")
  return
 app.lobby.collection.turret = "frost"
 app.lobby.open_page("포탑")
 await create_timer(0.5).timeout
 await create_timer(0.6).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/Users/sejin/Documents/Codex/RuneNexus/design/frost_tower_concepts/2026-09-23/production/godot/user-live-collection.png")
 print("LOCAL_PLAY_READY ",app.lobby.find_child("MenuTabs",true,false).get_global_rect()," viewport=",root.get_visible_rect())
