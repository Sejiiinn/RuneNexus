extends SceneTree
const Harness=preload("res://verify_lobby_header.gd")
const Lobby=preload("res://ui/lobby.gd")
const OUT="/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/module-icons/"
func _initialize() -> void: call_deferred("run")
func click(control: Control) -> void:
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=control.get_global_rect().get_center();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true)
func run() -> void:
	var app=Harness.FakeApp.new();assert(app.catalog.load_catalog());assert(app.run_domain.growth.load_catalog())
	app.progression_inputs.clearedStageNumbers=[1,2,3,4,5,6]
	var items=[]
	for type in ["arrow","cannon","magic","frost","sniper","lightning"]:
		for part in ["core","barrel","frame"]:
			items.append({"id":type+part,"turretType":type,"part":part,"grade":"rare","equipped":false,"options":[]})
	app.progression_inputs.turretModules={"items":items,"tickets":2}
	var lobby=Lobby.new();lobby.app=app;root.add_child(lobby)
	var baseline=OS.get_environment("BASELINE")=="1"
	for width in [320,440]:
		root.size=Vector2i(width,1000);root.content_scale_size=Vector2i(width,1000)
		lobby.open_page("포탑");await create_timer(0.3).timeout
		if baseline:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"before-%d.png"%width)
			continue
		for type in ["arrow","cannon","magic","frost","sniper","lightning"]:
			click(lobby.find_child("TurretSelect_"+type,true,false));await create_timer(0.1).timeout
			assert(lobby.collection.turret==type)
			var preview=lobby.find_child("ModuleTurretPreview",true,false)
			assert(preview.texture.resource_path.ends_with("turrets_3d/"+type+".png"))
			for kind in ["arrow","cannon","magic","frost","sniper","lightning"]:
				var button=lobby.find_child("TurretSelect_"+kind,true,false)
				var icon=lobby.find_child("TurretIcon_"+kind,true,false)
				assert(absf(button.get_global_rect().get_center().x-icon.get_global_rect().get_center().x)<0.6,"Selector icon center "+kind)
				assert(button.get_global_rect().encloses(icon.get_global_rect()),"Selector bounds")
			var grid=lobby.find_child("ModuleInventoryGrid",true,false)
			for cell in grid.get_children():
				var glyph=cell.find_child("ModulePartGlyph",true,false)
				if glyph:
					var delta=cell.get_global_rect().get_center()-glyph.get_global_rect().get_center()
					assert(absf(delta.x)<=0.51 and absf(delta.y)<=0.51,"Module glyph center delta="+str(delta))
			if type in ["arrow","lightning"]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUT+"after-%d-%s.png"%[width,type])
		print("PASS width=",width," six fixed 3D textures, actual selector input, selector and inventory alignment")
	quit()
