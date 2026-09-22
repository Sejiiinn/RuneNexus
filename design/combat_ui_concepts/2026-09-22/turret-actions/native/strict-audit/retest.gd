extends SceneTree
var app
var hud
var state: Dictionary
var turret: Dictionary
var failures := []
var checks := 0
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/turret-actions/native/strict-audit/fixed/"
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
	check(a.get_global_rect().end.x<=b.global_position.x,label+" no action overlap")
	check(b.get_global_rect().end.x<=c.global_position.x,label+" no sell overlap")
	check(c.get_global_rect().end.x<=root.size.x,label+" right bound")
	check(absf(a.size.x/b.size.x-570.0/585.0)<0.06,label+" reference width ratio")
	for n in [a,b,c]:
		check(n.get_theme_stylebox("normal") is StyleBoxTexture,label+" nine-slice")
		print("HIT ",label," ",n.name," ",n.get_global_rect())
	for l in panel.find_children("*","Label",true,false):
		var font_size: int = l.get_theme_font_size("font_size")
		var width: float = l.get_theme_font("font").get_string_size(l.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		check(width <= l.size.x+0.2,label+" label width "+l.text)
		check(l.get_global_rect().end.y<=panel.get_global_rect().end.y+1,label+" label height "+l.text)
		print("TEXT ",label," ",l.text," font=",font_size," size=",l.size)
func refresh():
	hud.body_key = ""; hud.refresh(); await settle()
func run():
	var scene = load("res://main.tscn").instantiate(); root.add_child(scene)
	await create_timer(2).timeout
	app = scene._standalone_session; hud = app.hud
	assert(OS.get_user_data_dir().contains("RuneNexus-HUD-review-v4"))
	print("ISOLATED ",OS.get_user_data_dir())
	root.content_scale_size = Vector2i(440,900); root.size = Vector2i(440,900)
	app.start_stage(0); hud = app.hud
	var map: Dictionary = app.catalog.stage(0).map
	var tile: int = map.tiles.find("build")
	app.board_tap(Vector2i(tile % int(map.columns),tile / int(map.columns))); app.build_selected()
	state = app.run_domain.state
	state.gold = 3000; state.gemShards = 1000
	turret = state.turrets[0]; turret.level = 7
	hud.tab = "stats"; hud.main_tab = "turrets"; await refresh()
	layout("440"); await capture("base-440")
	var old_gold: int = state.gold
	await click(button("TurretLevelAction"),true)
	check(app.selection_view.level_preview and state.turrets[0].level==7 and state.gold==old_gold,"edge mouse upgrade preview preserves level/gold")
	await capture("preview-440")
	await click(button("TurretLevelAction"))
	check(not app.selection_view.level_preview and state.turrets[0].level==8 and state.gold<old_gold,"mouse upgrade confirm changes level/gold")
	turret = state.turrets[0]

	for width in [320,440,280,320]:
		root.content_scale_size=Vector2i(width,760 if width<440 else 900); root.size=root.content_scale_size
		turret.level=7; await refresh(); layout(str(width)); await capture("base-"+str(width))
		var p=button("TurretLevelAction").find_child("TurretUpgradePrice",true,false)
		check(p.text=="204 G" if width>=320 else p.text.trim_suffix(" G")=="204","exact standard price "+str(width))
		check(p.get_theme_font_size("font_size")>=8,"readable standard price "+str(width))
		check(button("TurretLevelAction").tooltip_text.contains("204 G"),"full price tooltip")
		await click(button("TurretLevelAction")); check(app.selection_view.level_preview,"preview after resize")
		await capture("preview-"+str(width)); await click(button("TurretLevelAction"))
		check(state.turrets[0].level==8 and not app.selection_view.level_preview,"confirm after resize")
	state.gold=0; await refresh(); check(button("TurretLevelAction").disabled,"poor still disabled")
	await capture("poor-320")
	state.gold=3000; turret.level=10; await refresh(); check(button("TurretLevelAction").disabled,"max still disabled")
	await capture("max-320")
	var result={"checks":checks,"failures":failures}; var f=FileAccess.open(out+"result.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("FIXED AUDIT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
