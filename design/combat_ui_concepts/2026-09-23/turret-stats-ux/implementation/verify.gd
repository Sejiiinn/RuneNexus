extends SceneTree
var app
var hud
var state: Dictionary
var turret: Dictionary
var failures := []
var measurements := []
var checks := 0
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-23/turret-stats-ux/implementation/"
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
func run():
	var scene = load("res://main.tscn").instantiate(); root.add_child(scene)
	await create_timer(2).timeout
	app = scene._standalone_session; hud = app.hud
	assert(OS.get_user_data_dir().contains("RuneNexus-TurretStats-Review"))
	print("ISOLATED ",OS.get_user_data_dir())
	root.content_scale_size = Vector2i(440,900); root.size = Vector2i(440,900)
	app.start_stage(0); hud = app.hud
	app.run_domain.state.progression = app.run_domain.growth.data.defaultProgression.duplicate(true)
	app.run_domain.state.progression.researchLevels.turretTargetPriority = 1
	var map: Dictionary = app.catalog.stage(0).map
	var tile: int = map.tiles.find("build")
	app.board_tap(Vector2i(tile % int(map.columns),tile / int(map.columns))); app.build_selected()
	state = app.run_domain.state
	state.gold = 3000; state.gemShards = 1000
	turret = state.turrets[0]; turret.level = 7
	hud.tab = "stats"; hud.main_tab = "turrets"; await refresh()
	layout("440"); await capture("base-440")
	var priority = find_button_text("공격 목표")
	check(priority != null,"unlocked priority visible")
	if priority != null:
		await click(priority); check(hud.modal_active(),"priority opens")
		await click(modal_button("후미")); check(state.turrets[0].targetPriority=="last","priority choice commits")
		turret.targetPriority="first"; await refresh()
	state.progression.researchLevels.turretTargetPriority=0; await refresh()
	check(find_button_text("공격 목표")==null,"locked priority hidden")
	state.progression.researchLevels.turretTargetPriority=1; await refresh()
	var old_gold: int = state.gold
	await click(button("TurretLevelAction"),true)
	check(app.selection_view.level_preview and state.turrets[0].level==7 and state.gold==old_gold,"edge mouse upgrade preview preserves level/gold")
	await capture("preview-440")
	await click(button("TurretLevelAction"))
	check(not app.selection_view.level_preview and state.turrets[0].level==8 and state.gold<old_gold,"mouse upgrade confirm changes level/gold")
	turret = state.turrets[0]
	await click(button("TurretGemsTab"))
	check(hud.tab=="gems" and hud.body.find_child("EquippedSocketRows",true,false)!=null,"mouse gems tab")
	await click(button("TurretLevelAction")); check(app.selection_view.level_preview,"upgrade preview from gems")
	layout("gems-preview-440"); await capture("gems-preview-440")
	app.selection_view.level_preview=false; await refresh()
	await click(button("TurretStatsTab"),true)
	check(hud.tab=="stats" and hud.body.find_child("TurretStatsScroll",true,false)!=null,"edge mouse stats tab")
	await click(button("TurretTraitAction"))
	check(hud.modal_active(),"mouse trait opens")
	await click(modal_button("과열 탄창"))
	check(turret.primaryTrait==null,"trait preview preserves state")
	await click(modal_button("✓ 과열 탄창"))
	check(state.turrets[0].primaryTrait=="overheatMagazine","trait confirm state")
	turret = state.turrets[0]; await capture("traits-one-440")
	await click(button("TurretTraitAction"))
	var candidate: Button
	for b in hud.modal_body.find_children("*","Button",true,false):
		if b.text.contains("\n") and not b.disabled: candidate=b; break
	if candidate != null:
		var prefix: String = candidate.text.split("\n")[0]
		await click(candidate); await click(modal_button("✓ "+prefix))
	check(state.turrets[0].secondaryTrait!=null,"second trait actual mouse selection")
	turret = state.turrets[0]; await capture("traits-two-440")
	await click(button("TurretSellAction"),true)
	check(hud.modal_active(),"edge mouse sell opens")
	await capture("sell-confirm-440")
	await click(modal_button("취소"))
	check(not hud.modal_active() and state.turrets.size()==1,"sell cancel preserves turret")
	state.gold=0; await refresh()
	check(button("TurretLevelAction").disabled,"insufficient gold disabled")
	await click(button("TurretLevelAction")); check(not app.selection_view.level_preview,"disabled input ignored")
	await capture("poor-440")
	state.gold=999999; turret.level=10; await refresh()
	check(button("TurretLevelAction").disabled,"max level disabled")
	await capture("max-440")
	for width in [320]:
		root.content_scale_size=Vector2i(width,760); root.size=Vector2i(width,760)
		turret.level=7; turret.type="lightning"; turret.primaryTrait=null; turret.secondaryTrait=null
		await refresh(); layout(str(width)); await capture("lightning-"+str(width))
		await click(button("TurretLevelAction")); check(app.selection_view.level_preview,"narrow mouse preview "+str(width))
		layout("preview-"+str(width)); await capture("preview-"+str(width))
		app.selection_view.level_preview=false
	root.content_scale_size=Vector2i(320,760); root.size=Vector2i(320,760)
	for kind in ["arrow","cannon","frost","sniper","magic"]:
		turret.type=kind; await refresh(); layout(kind); await capture(kind+"-320")
		if kind=="arrow":
			await click(button("TurretLevelAction")); layout("arrow-preview-320"); await capture("arrow-preview-320")
			app.selection_view.level_preview=false; await refresh()
	await click(button("TurretSellAction")); old_gold=state.gold
	await click(modal_button("판매 · "))
	check(state.turrets.is_empty() and state.gold>old_gold and not hud.modal_active(),"mouse sale commits and refunds")
	var result := {"checks":checks,"failures":failures,"measurements":measurements,"renderer":RenderingServer.get_current_rendering_method(),"user_dir":OS.get_user_data_dir()}
	var file := FileAccess.open(out+"result.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close()
	print("AUDIT ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
