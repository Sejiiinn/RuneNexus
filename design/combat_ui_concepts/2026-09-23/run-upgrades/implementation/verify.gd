extends SceneTree
var app
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-23/run-upgrades/implementation/"
var expected := {"towerDamage":"포탑 화력","killGold":"처치 보너스","waveGold":"정비 보급"}
func _initialize(): call_deferred("run")
func click(button: Button):
	var pos=button.get_global_rect().get_center()
	var m=InputEventMouseMotion.new();m.position=pos;root.push_input(m,true)
	for pressed in [true,false]:
		var e=InputEventMouseButton.new();e.position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;root.push_input(e,true);await process_frame
	await create_timer(0.2).timeout
func settle():
	app.hud.refresh()
	await create_timer(0.3).timeout
func rows(): return app.hud.body.get_node("RunUpgradeRows")
func row(type): return rows().get_node("Upgrade_"+type)
func label(type,node_name): return row(type).find_child(node_name,true,false)
func button(type): return row(type).get_node("Purchase")
func capture(file):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+file+".png")
func check_layout(width):
	assert(rows().get_child_count()==5)
	assert(app.hud.body.get_combined_minimum_size().y<=198)
	assert(app.hud.detail_panel.get_theme_stylebox("panel") is StyleBoxTexture)
	for type in expected:
		assert(label(type,"UpgradeName").text==expected[type])
		assert(button(type).get_global_rect().end.x<=width)
		assert(app.hud.scroll.get_global_rect().encloses(row(type).get_global_rect()))
		assert(not row(type) is PanelContainer)
		for c in row(type).find_children("*","Label",true,false):
			var w=c.get_theme_font("font").get_string_size(c.text,HORIZONTAL_ALIGNMENT_LEFT,-1,c.get_theme_font_size("font_size")).x
			assert(w<=c.size.x+0.1,"text clipped: "+c.text)
			assert(row(type).get_global_rect().encloses(c.get_global_rect()),"label outside row: "+c.text)
	for c in app.hud.body.find_children("*","Label",true,false):
		assert(c.text not in ["업그레이드","이번 전투에 적용"])
	print("PASS layout ",width," height=",app.hud.body.get_combined_minimum_size().y)
func run():
	assert(OS.get_user_data_dir().contains("RuneNexus-RunUpgrade-Review"))
	var scene=load("res://main.tscn").instantiate();root.add_child(scene)
	await create_timer(2).timeout
	app=scene._standalone_session;app.start_stage(0)
	app.run_domain.state.progression=app.run_domain.growth.data.defaultProgression.duplicate(true)
	app.run_domain.state.gold=3000;app.run_domain.state.gemShards=100
	await settle()
	await click(app.hud.main_buttons.upgrades)
	assert(app.hud.main_tab=="upgrades")
	for width in [440,320]:
		root.content_scale_size=Vector2i(width,760 if width==320 else 900);root.size=root.content_scale_size
		app.run_domain.state.runUpgradeLevels={};app.run_domain.state.gold=3000
		await settle();check_layout(width)
		assert(label("towerDamage","UpgradeNext").text=="+3%")
		assert(label("killGold","UpgradeNext").text=="+2%")
		assert(label("waveGold","UpgradeNext").text=="+4 G")
		await capture("normal-"+str(width))
		var unchanged=button("towerDamage")
		app.run_domain.state.gold=0;await settle()
		assert(button("towerDamage")==unchanged,"wallet must not rebuild body")
		for type in expected:
			assert(button(type).disabled)
			assert(button(type).get_meta("action_content").modulate==Color("78848a"))
		await capture("poor-"+str(width))
		app.run_domain.state.gold=3000;await settle()
		assert(button("towerDamage")==unchanged)
		assert(not unchanged.disabled)
		assert(unchanged.get_meta("action_content").modulate==Color.WHITE)
		for type in expected:
			var quote=app.run_domain.service.run_upgrade_quote(app.run_domain.state,type)
			var gold=app.run_domain.state.gold
			await click(button(type))
			assert(app.run_domain.state.runUpgradeLevels[type]==1)
			assert(app.run_domain.state.gold==gold-quote.cost)
			assert(label(type,"UpgradeLevel").text=="Lv.1/20")
		await capture("purchased-"+str(width))
		for type in expected: app.run_domain.state.runUpgradeLevels[type]=20
		await settle();check_layout(width)
		for type in expected:
			assert(button(type).disabled)
			assert(row(type).find_child("UpgradeNext",true,false)==null)
			assert(row(type).find_child("PurchaseAction",true,false).text=="최대")
		await capture("max-"+str(width))
		print("PASS wallet transitions, actual clicks, levels/effects/prices and MAX ",width)
	# Research extensions and discounts remain owned by the domain quote.
	var research={"towerDamageLimitExpansion":10,"killGoldLimitExpansion":10,"waveGoldLimitExpansion":10}
	app.run_domain.state.progression.researchLevels=research
	app.run_domain.state.gold=999999
	for type in expected: app.run_domain.state.runUpgradeLevels[type]=29
	await settle();check_layout(320)
	for type in expected:
		var quote=app.run_domain.service.run_upgrade_quote(app.run_domain.state,type)
		assert(quote.maxLevel==30)
		assert(label(type,"UpgradeLevel").text=="Lv.29/30")
		assert(row(type).find_child("PurchasePrice",true,false).text=="%d G" % quote.cost)
	await capture("research-320")
	research.runUpgradeCostOptimization=10
	await settle()
	for type in expected:
		var quote=app.run_domain.service.run_upgrade_quote(app.run_domain.state,type)
		assert(row(type).find_child("PurchasePrice",true,false).text=="%d G" % quote.cost)
		var gold=app.run_domain.state.gold
		await click(button(type))
		assert(app.run_domain.state.gold==gold-quote.cost)
		assert(app.run_domain.state.runUpgradeLevels[type]==30)
		assert(button(type).disabled)
	print("PASS research limit/discount, longest prices and purchase to extended MAX")
	print("PASS run upgrade UI")
	quit()
