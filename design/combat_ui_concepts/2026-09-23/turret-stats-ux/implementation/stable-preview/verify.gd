extends SceneTree
var app
var hud
var state: Dictionary
var turret: Dictionary
var failures := []
var measurements := []
var checks := 0
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-23/turret-stats-ux/implementation/stable-preview/"
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message); print("FAIL ",message)
func settle():
	await create_timer(0.3).timeout
func button(name: String) -> Button: return hud.find_child(name,true,false) as Button
func modal_button(prefix: String) -> Button:
	for b in hud.modal_body.find_children("*","Button",true,false):
		if b.text.begins_with(prefix): return b
	return null
func click(b: Button, edge := false):
	check(b != null,"button exists")
	if b == null: return
	var rect := b.get_global_rect()
	var p := rect.position+Vector2(2,rect.size.y/2) if edge else rect.get_center()
	check(root.get_visible_rect().has_point(p),"hit point visible "+str(b.name))
	var motion := InputEventMouseMotion.new(); motion.position = p; motion.global_position = p
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = p; event.global_position = p
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle()
	state = app.run_domain.state
	if not state.turrets.is_empty(): turret = state.turrets[0]
func capture(label: String):
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image(); img.save_png(out+label+".png")
	var panel = button("TurretLevelAction")
	if panel != null:
		var bounds: Rect2 = hud.body.find_child("TurretActionPanel",true,false).get_global_rect()
		img.get_region(Rect2i(bounds.position,Vector2i(bounds.size.ceil()))).save_png(out+"panel-"+label+".png")
func layout(label: String):
	var panel = hud.body.find_child("TurretActionPanel",true,false)
	check(panel != null,label+" panel present")
	if panel == null: return
	for c in [panel]+panel.find_children("*","Control",true,false): check(c.scale == Vector2.ONE,label+" scale "+str(c.name))
	var a = button("TurretLevelAction"); var b = button("TurretTraitAction"); var c = button("TurretSellAction")
	check(absf(a.global_position.y-b.global_position.y)<1,label+" same row")
	check(b.get_global_rect().end.x<=a.global_position.x,label+" no action overlap")
	check(a.get_global_rect().end.x<=c.global_position.x,label+" no sell overlap")
	check(c.get_global_rect().end.x<=root.size.x,label+" right bound")
	check(absf(a.size.x/b.size.x-570.0/585.0)<0.06,label+" reference width ratio")
	for n in [a,b,c]:
		check(n.get_theme_stylebox("normal") is StyleBoxTexture,label+" nine-slice")
		print("HIT ",label," ",n.name," ",n.get_global_rect())
	var grid = hud.body.find_child("TurretStatsGrid",true,false)
	var stat_scroll = hud.body.find_child("TurretStatsScroll",true,false)
	var total = hud.body.find_child("TurretTotalDamage",true,false)
	if grid != null:
		check(grid.columns==2,label+" two stat columns")
		check(stat_scroll.size.y<=grid.size.y+3,label+" no empty stat scroll space")
		check(total!=null,label+" separate damage total")
		check(hud.scroll.get_global_rect().encloses(total.get_global_rect()),label+" damage total visible")
		for cell in grid.get_children():
			check(stat_scroll.get_global_rect().encloses(cell.get_global_rect()),label+" stat visible "+str(cell.name))
			for value in cell.find_children("*","Label",true,false):
				var text_width = value.get_theme_font("font").get_string_size(value.text,HORIZONTAL_ALIGNMENT_LEFT,-1,value.get_theme_font_size("font_size")).x
				check(text_width<=value.size.x+0.2,label+" stat width "+value.text)
		var category = hud.body.find_child("TurretCategoryAndTarget",true,false)
		var colors = {"physical":"F4F7FA","elemental":"9FFFE8","light":"E7C66A","heavy":"FF8A2A","cooling":"7FD8FF","damageOverTime":"9DFF4A","explosion":"FF8A2A","chain":"B98CFF"}
		for chip in category.get_children():
			if str(chip.name).begins_with("Category_"):
				var key = str(chip.name).trim_prefix("Category_")
				if colors.has(key): check(chip.get_child(0).get_theme_color("font_color").is_equal_approx(Color(colors[key])),label+" gem color "+key)
				check(chip.size.y<category.size.y,label+" small tag "+key)
		for control in category.get_children(): check(control.get_global_rect().end.x<=root.size.x,label+" category bounds")
		measurements.append({"state":label,"body_height":hud.body.size.y,"stats_height":stat_scroll.size.y,"stat_count":grid.get_child_count(),"total_visible":hud.scroll.get_global_rect().encloses(total.get_global_rect())})
	for l in panel.find_children("*","Label",true,false):
		var font_size: int = l.get_theme_font_size("font_size")
		var width: float = l.get_theme_font("font").get_string_size(l.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		check(width <= l.size.x+0.2,label+" label width "+l.text)
		check(l.get_global_rect().end.y<=panel.get_global_rect().end.y+1,label+" label height "+l.text)
		print("TEXT ",label," ",l.text," font=",font_size," size=",l.size)
func find_button_text(text: String) -> Button:
	for b in hud.body.find_children("*","Button",true,false):
		if b.text.contains(text): return b
	return null
func refresh():
	hud.body_key = ""; hud.refresh(); await settle()
var series := []
var phase := "before"
func measure(label: String):
	var items := {}
	for c in [hud.body]+hud.body.find_children("*","Control",true,false):
		var path: String = str(hud.body.get_path_to(c))
		# Generated node names change across rebuilds; sibling indexes are stable.
		var indices := []; var n: Node = c
		while n != hud.body:
			indices.push_front(n.get_index(true)); n = n.get_parent()
		path = str(indices)
		var item := {"name":str(c.name),"rect":[c.global_position.x,c.global_position.y,c.size.x,c.size.y]}
		if c is Label or c is Button:
			item.text = c.text; item.font = c.get_theme_font_size("font_size")
		items[path] = item
	series.append({"draw_frame":Engine.get_frames_drawn(),"state":label,"preview":app.selection_view.level_preview,"items":items})
func transition(label: String):
	var b = button("TurretLevelAction")
	var p = b.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = p; motion.global_position = p; root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position=p; event.global_position=p; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; root.push_input(event,true)
	for frame in range(8):
		await RenderingServer.frame_post_draw
		measure(label+"-frame-"+str(frame))
	await settle(); measure(label+"-settled"); await capture(phase+"-"+label+"-settled")
func run():
	var args=OS.get_cmdline_user_args()
	if "--after" in args: phase="after"
	var scene = load("res://main.tscn").instantiate(); root.add_child(scene)
	await create_timer(2).timeout
	app=scene._standalone_session; hud=app.hud
	assert(OS.get_user_data_dir().contains("RuneNexus-TurretStats-Review"))
	app.start_stage(0); hud=app.hud
	app.run_domain.state.progression=app.run_domain.growth.data.defaultProgression.duplicate(true)
	app.run_domain.state.progression.researchLevels.turretTargetPriority=1
	var map: Dictionary=app.catalog.stage(0).map; var tile: int=map.tiles.find("build")
	app.board_tap(Vector2i(tile % int(map.columns),tile / int(map.columns))); app.build_selected()
	state=app.run_domain.state; state.gold=999999; state.gemShards=1000
	turret=state.turrets[0]; hud.tab="stats"; hud.main_tab="turrets"
	for width in [440,320]:
		root.content_scale_size=Vector2i(width,900 if width==440 else 760); root.size=root.content_scale_size
		state=app.run_domain.state; turret=state.turrets[0]; turret.level=7; app.selection_view.level_preview=false
		await refresh(); measure(str(width)+"-base"); await capture(phase+"-"+str(width)+"-base")
		await transition(str(width)+"-preview")
		await transition(str(width)+"-confirmed")
		state=app.run_domain.state; turret=state.turrets[0]; turret.level=9; app.selection_view.level_preview=false
		await refresh(); measure(str(width)+"-level9-base")
		await transition(str(width)+"-level9-preview")
		await transition(str(width)+"-level10-confirmed")
	var file=FileAccess.open(out+phase+"-measurements.json",FileAccess.WRITE); file.store_string(JSON.stringify(series,"  ")); file.close()
	print("MEASURED ",phase," states=",series.size()); quit()
