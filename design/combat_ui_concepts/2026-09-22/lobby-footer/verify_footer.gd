extends SceneTree
const Harness=preload("res://verify_lobby_header.gd")
const Lobby=preload("res://ui/lobby.gd")
const OUT="/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/lobby-footer/"
func _initialize() -> void: call_deferred("run")
func click(control: Control) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=control.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)
func run() -> void:
	var app=Harness.FakeApp.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.growth.load_catalog())
	var lobby=Lobby.new();lobby.app=app;root.add_child(lobby)
	var names=["Stage","Core","Upgrade","Research","Turret"]
	var pages=["스테이지","코어","강화","연구","포탑"]
	for width in [320,440]:
		root.size=Vector2i(width,900);root.content_scale_size=Vector2i(width,900)
		lobby.open_page("스테이지")
		await create_timer(0.3).timeout
		for i in range(5):
			click(lobby.find_child("Tab"+names[i],true,false))
			await create_timer(0.15).timeout
			assert(lobby.page==pages[i],"Actual tab click: "+pages[i])
			var footer=lobby.find_child("MenuTabs",true,false)
			assert(Rect2(Vector2.ZERO,Vector2(width,900)).encloses(footer.get_global_rect()))
			assert(footer.size.y==64)
			for name in names:
				var button=lobby.find_child("Tab"+name,true,false)
				assert(button.size.x>=56 and button.size.y==56)
				for child in button.get_child(0).get_children():
					assert(button.get_global_rect().encloses(child.get_global_rect()),"Overflow "+name)
			if i in [0,3]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUT+"%d-%s.png"%[width,"stage" if i==0 else "research"])
		print("PASS footer width=",width," five actual tab clicks, 64px dock, labels/icons within touch bounds")
	quit()
