extends SceneTree
const Fixture=preload("res://verify_battle_hud.gd")
func _initialize(): call_deferred("run")
func settle():
	for i in range(8): await process_frame
func run():
	root.size=Vector2i(320,480); root.content_scale_size=root.size
	var app=Fixture.App.new(); assert(app.catalog.load_catalog()); assert(app.run_domain.initialize(app.catalog,{},0,100)); root.add_child(app)
	var hud=load("res://ui/battle_hud.gd").new(); hud.app=app; app.hud=hud; root.add_child(hud); await settle()
	var map: Dictionary=app.catalog.stage(0).map; var i:int=map.tiles.find("build")
	app.selected=Vector2i(i%int(map.columns),i/int(map.columns)); app.run_domain.state.gold=999999
	assert(app.apply_run_command({"kind":"build","type":"arrow","x":app.selected.x,"y":app.selected.y}))
	hud.on_board_selection(); hud.refresh(); await settle()
	# A short viewport naturally requires outer scrolling; no forced layout override.
	hud.scroll.scroll_vertical=50; await settle(); var before:int=hud.scroll.scroll_vertical
	assert(before>0,"scroll fixture has scroll range")
	var scroll_id= hud.scroll.get_instance_id(); var grid=hud.body.find_child("TurretStatsGrid",true,false)
	assert(app.apply_run_command({"kind":"level","id":app.run_domain.state.turrets[0].id}))
	hud.refresh(); await settle()
	assert(hud.scroll.scroll_vertical==before,"numeric update preserves scroll")
	assert(hud.scroll.get_instance_id()==scroll_id and hud.body.find_child("TurretStatsGrid",true,false)==grid,"scroll and grid reused")
	print("INDEPENDENT_SCROLL PASS offset=",before," after=",hud.scroll.scroll_vertical); quit()
