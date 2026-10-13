extends SceneTree
const HudFixture = preload("res://verify_battle_hud.gd")
const HealthBar = preload("res://ui/core_health_bar.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func settle() -> void:
	for i in 4: await process_frame
func capture(filename: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("RUNE_TREE_CAPTURE_DIR")
	if path.is_empty(): return
	DirAccess.make_dir_recursive_absolute(path)
	root.get_texture().get_image().save_png(path.path_join(filename))
func check_bar(bar,ordinary: float,bonus: float,where: String) -> void:
	var denominator := 100.0+bonus
	var segment: Rect2 = bar.additional_segment()
	check(is_equal_approx(bar.max_value,denominator),where+" denominator follows remaining bonus")
	check(is_equal_approx(bar.value,ordinary),where+" normal fill retains ordinary HP")
	check(is_equal_approx(bar.additional_hp,bonus),where+" bonus amount current")
	check(is_equal_approx(segment.position.x/bar.size.x,ordinary/denominator),where+" bright segment adjacent to ordinary fill")
	check(is_equal_approx(segment.size.x/bar.size.x,bonus/denominator),where+" bright segment exact current fraction")
	check(is_equal_approx((bar.size.x-segment.end.x)/bar.size.x,(100.0-ordinary)/denominator),where+" missing ordinary HP remains empty")
	check(segment.end.x<=bar.size.x+0.01 and is_equal_approx(segment.size.y,bar.size.y),where+" segment stays inside original bar")
func run() -> void:
	root.content_scale_size = Vector2i(440,760)
	root.size = Vector2i(440,900)
	var app := HudFixture.App.new()
	check(app.catalog.load_catalog(),"catalog")
	check(app.run_domain.initialize(app.catalog,{},0,100),"domain")
	var map: Dictionary = app.catalog.stage_map(0)
	var core_index: int = map.tiles.find("core")
	app.selected = Vector2i(core_index % int(map.columns),core_index / int(map.columns))
	root.add_child(app)
	var hud = load("res://ui/battle_hud.gd").new()
	hud.app = app; app.hud = hud
	root.add_child(hud)
	await settle()
	hud.set_process(false)
	hud.menu_panel._refresh_core()
	check(hud.find_child("AdditionalCoreHp",true,false)==null,"separate top HP row removed")
	check(HealthBar.ADDITIONAL_COLOR.get_luminance()>HealthBar.ORDINARY_COLOR.get_luminance(),"bonus green brighter than original green")
	for width in [440,320]:
		root.content_scale_size = Vector2i(width,760)
		root.size = Vector2i(width,900)
		app.scene.combat_runtime.defense.hp = 100.0
		app.scene.combat_runtime.defense.additional_hp = 0.0
		app.scene.combat_runtime.defense.config = {"nexusAdditionalHpRate":0.15}
		hud.refresh(); hud.menu_panel._refresh_core()
		await settle()
		var baseline_top_height: float = hud.top.size.y
		var baseline_core_height: float = hud.core_label.size.y
		check(is_equal_approx(baseline_top_height,94),"original top height94 at %d" % width)
		check(is_equal_approx(hud.hp.size.y,4) and is_equal_approx(hud.core_bar.size.y,10),"original bar heights4/10 at %d" % width)
		check(hud.top.find_child("WaveInformation",true,false).get_child_count()==3,"original three wave-information children at %d" % width)
		for sample in [[100.0,15.0,"115/115","full"],[100.0,5.0,"105/105","partial"],[100.0,0.0,"100/100","used"],[80.0,10.0,"90/110","injured"]]:
			app.scene.combat_runtime.defense.hp = sample[0]
			app.scene.combat_runtime.defense.additional_hp = sample[1]
			var before: Dictionary = app.scene.combat_runtime.defense.duplicate(true)
			hud.refresh(); hud.menu_panel._refresh_core()
			await settle()
			var context := "%d %s " % [width,sample[3]]
			check(hud.status.text=="♡ "+sample[2],context+"combined top number")
			check(hud.core_label.text=="체력 "+sample[2],context+"same combined lower number")
			check(not hud.status.text.contains("\n") and not hud.core_label.text.contains("\n"),context+"both numeric rows remain single-line")
			check(hud.status.tooltip_text.contains("회복 불가") and hud.core_label.tooltip_text.contains("회복 불가"),context+"nonrecoverable explanation only in tooltip")
			check(is_equal_approx(hud.top.size.y,baseline_top_height),context+"original no-bonus HUD height preserved")
			check(is_equal_approx(hud.core_label.size.y,baseline_core_height),context+"original lower numeric row height preserved")
			check(hud.status.get_global_rect().end.x<=hud.wave_label.get_global_rect().position.x+0.1,context+"top number does not overlap wave")
			check(hud.top.get_node("ResourceHUD").get_global_rect().end.x<=width+0.1,context+"resource HUD fits viewport")
			check(app.scene.combat_runtime.defense==before,context+"UI cannot mutate combat HP")
			check_bar(hud.hp,sample[0],sample[1],context+"top")
			check_bar(hud.core_bar,sample[0],sample[1],context+"lower")
			await capture("additional-hp-hud-%d.png" % width if sample[3]=="full" else "additional-hp-hud-%s-%d.png" % [sample[3],width])
			# Repeated refresh must not accumulate a second bar segment or child row.
			hud.refresh(); hud.menu_panel._refresh_core()
			check_bar(hud.hp,sample[0],sample[1],context+"repeat")
	print("ADDITIONAL_HP_UI failures=",failures," checks=",checks)
	hud.queue_free(); app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
