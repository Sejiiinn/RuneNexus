extends SceneTree
## Production research cards compared against actual startResearch eligibility.
const Fixture = preload("res://verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")
const ProgressVisual = preload("res://ui/research_progress.gd")
const Progression = preload("res://content/stage_progression.gd")
var captures := OS.get_environment("RESEARCH_AVAILABILITY_CAPTURE_DIR")
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(10): await process_frame
func texts(node: Node) -> String:
	var value: String=node.text if node is Label or node is Button else ""
	for child in node.get_children(): value += "\n" + texts(child)
	return value
func cards(lobby: Control) -> Array:
	return lobby.body.find_children("ResearchCard_*","PanelContainer",true,false)
func card(lobby: Control, id: String) -> Control:
	return lobby.body.find_child("ResearchCard_"+id,true,false)
func is_ready(panel: Control) -> bool:
	var style: StyleBoxTexture=panel.get_theme_stylebox("panel")
	return panel.modulate==Color.WHITE and style.modulate_color.g>1 and style.modulate_color.b>1
func compare(lobby: Control, app: Fixture.FakeApp) -> void:
	assert(texts(lobby.body).contains("해금된 연구") and not texts(lobby.body).contains("시작 가능 연구"))
	assert(not texts(lobby.body).contains("룬 부족"),"The list has no rune shortage badge or amount")
	assert(not texts(lobby.body).contains("시작 가능") and not texts(lobby.body).contains("✓"),"Availability uses the frame without text or checkmark")
	assert(cards(lobby).size()==app.run_domain.growth.data.research.size(),"Every existing research remains in the catalog")
	assert(lobby.body.get_combined_minimum_size().x<=lobby._page_scroll.size.x,"Catalog keeps both columns inside the scroll viewport")
	for panel in cards(lobby):
		var id: String=panel.get_meta("research_id")
		var before: Dictionary=app.progression_inputs.duplicate(true)
		var start: Dictionary=app.run_domain.growth.execute(before,{"kind":"startResearch","id":id,"nowMillis":int(Time.get_unix_time_from_system()*1000)})
		var ready: bool=start.ok
		assert(app.progression_inputs==before,"Availability probe does not mutate progression")
		assert(is_ready(panel)==ready,"Card availability agrees with real startResearch rules: "+id)
		assert((panel.get_meta("research_status")=="연구 가능")==ready)
		if ready:
			assert(panel.modulate==Color.WHITE)
			var style: StyleBoxTexture=panel.get_theme_stylebox("panel")
			assert(style.texture!=null and style.modulate_color.g>1 and style.modulate_color.b>1,"Ready card keeps an image frame with cyan emphasis")
		else:
			assert(panel.modulate.r<0.7 and panel.modulate.g<0.7 and panel.modulate.b<0.75 and panel.self_modulate==Color.WHITE,"Unavailable tint inherits to all card children")
			for child in panel.find_children("*","TextureRect",true,false):
				assert(panel.is_ancestor_of(child),"Every icon/currency remains under the dimmed card")
		assert(panel.get_combined_minimum_size().x <= panel.size.x,"Card contents fit both columns")
		assert(panel.find_children("*","Control",true,false).all(func(node):return not node is ProgressVisual),"Catalog cards have no active gold animation")
		var status: String=panel.get_meta("research_status")
		var selector=panel.find_child("ResearchSelect_"+id,true,false)
		var locked: bool=status!="연구 완료" and (not Progression.has_unlock(app.progression_inputs,"research",id) or not app.run_domain.growth.research_prerequisites_met(app.progression_inputs,id))
		assert((selector==null)==(status=="연구 중" or locked),"Active, stage-locked and prerequisite-locked cards cannot select details: "+id)
		if status=="연구 완료": assert(texts(panel).contains("연구 완료"))
		if status=="연구 중": assert(texts(panel).contains("연구 중"))
	var expected_order: Array=app.run_domain.growth.data.research.keys()
	expected_order.sort_custom(func(a,b):return Progression.ordinal_for(Progression.requirement("research",a)) < Progression.ordinal_for(Progression.requirement("research",b)))
	for section in lobby.body.get_children().slice(1):
		var actual: Array=[]
		for panel in section.find_children("ResearchCard_*","PanelContainer",true,false): actual.append(panel.get_meta("research_id"))
		assert(actual==expected_order.filter(func(id):return id in actual),"Existing order within each group stays stable")
func capture(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(name+".png"))
func mouse_click(control: Control) -> void:
	var point=control.get_global_rect().get_center()
	for down in [true,false]:
		var event=InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; root.push_input(event,true)
	await settle()
func touch_drag(control: Control) -> void:
	var point=control.get_global_rect().get_center()
	var press=InputEventScreenTouch.new(); press.index=0; press.position=point; press.pressed=true; Input.parse_input_event(press); await process_frame
	for i in range(1,7):
		var drag=InputEventScreenDrag.new(); drag.index=0; drag.position=point-Vector2(0,i*15); drag.relative=Vector2(0,-15); Input.parse_input_event(drag); await process_frame
	var release=InputEventScreenTouch.new(); release.index=0; release.position=point-Vector2(0,90); release.pressed=false; Input.parse_input_event(release); await settle()
func run() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	Input.set_emulate_touch_from_mouse(true)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size=Vector2i(440,900); root.content_scale_size=root.size
	var app=Fixture.FakeApp.new(); app.catalog.load_catalog(); app.run_domain.growth.load_catalog()
	var baseline: Dictionary=app.run_domain.growth.data.defaultProgression.duplicate(true)
	baseline.runes=80; baseline.freeDiamonds=1280; baseline.clearedStageNumbers=Progression.ordered_ids()
	app.progression_inputs=baseline.duplicate(true)
	var lobby=Lobby.new(); lobby.app=app; root.add_child(lobby); await settle(); lobby.open_page("연구"); await settle()
	for width in [440,320]:
		root.size=Vector2i(width,900); root.content_scale_size=root.size; await settle(); compare(lobby,app)
		assert(lobby.body.find_children("*","GridContainer",true,false).all(func(grid):return grid.columns==2),"320/440 keep two columns")
		await capture("research-availability-%d" % width)
	# Clearing 3-10 alone leaves link II locked until link I is completed.
	assert(card(lobby,"linkExpansionTwo").get_meta("research_status")=="링크 확장 I 연구 완료 필요")
	assert(card(lobby,"linkExpansionTwo").find_child("ResearchSelect_linkExpansionTwo",true,false)==null)
	app.progression_inputs.researchLevels={"linkExpansionOne":1}; lobby.refresh(); await settle(); compare(lobby,app)
	assert(card(lobby,"linkExpansionTwo").find_child("ResearchSelect_linkExpansionTwo",true,false)!=null,"Completing the prerequisite allows detail selection even with insufficient runes")
	app.progression_inputs=baseline.duplicate(true); lobby.refresh(); await settle()
	# Cards show eligibility at exactly the actual cost boundary, including discounts.
	for levels in [{},{"researchCostEfficiency":5}]:
		app.progression_inputs.researchLevels=levels
		var quote: Dictionary=app.run_domain.growth.research_quote(app.progression_inputs,"criticalChance")
		for wallet in [int(quote.cost)-1,int(quote.cost),int(quote.cost)+1]:
			app.progression_inputs.runes=wallet; lobby.refresh(); await settle(); compare(lobby,app)
			assert(is_ready(card(lobby,"criticalChance"))== (wallet>=int(quote.cost)))
	# Wallet updates through the existing refresh preserve selection/detail behavior.
	app.progression_inputs=baseline.duplicate(true); app.progression_inputs.runes=0; lobby.refresh(); await settle(); compare(lobby,app)
	await capture("research-all-dim-320")
	var commands=app.commands.size()
	await mouse_click(lobby.body.find_child("ResearchSelect_researchEfficiency",true,false))
	assert(lobby.modal!=null and app.commands.size()==commands,"Dim cards still open details without starting research")
	assert(texts(lobby.modal_body).contains("룬 부족"),"The detail retains the truthful start restriction")
	lobby.close_modal(true); await settle()
	app.progression_inputs=baseline.duplicate(true); lobby.refresh(); await settle()
	await mouse_click(lobby.body.find_child("ResearchSelect_researchEfficiency",true,false))
	assert(lobby.modal!=null and app.commands.size()==commands,"Ready cards also only select details")
	lobby.close_modal(true); await settle()
	# Touch dragging a card scrolls and cancels its release selection.
	await touch_drag(lobby.body.find_child("ResearchSelect_researchEfficiency",true,false))
	assert(lobby._page_scroll.scroll_vertical>0 and lobby.modal==null,"Card touch drag scrolls without opening a detail")
	lobby._page_scroll.scroll_vertical=0; await settle()
	# A real active research fills the only slot; no catalog card remains start-ready.
	app.progression_inputs=baseline.duplicate(true); app.progression_inputs.runes=10000
	assert(app.apply_growth_command({"kind":"startResearch","id":"researchEfficiency","nowMillis":int(Time.get_unix_time_from_system()*1000)}))
	lobby.refresh(); await settle(); compare(lobby,app)
	assert(not cards(lobby).any(is_ready) and card(lobby,"researchEfficiency").find_child("ResearchSelect_researchEfficiency",true,false)==null)
	assert(texts(lobby.body).contains("즉시 완료") and texts(card(lobby,"researchEfficiency")).contains("연구 중"))
	root.size=Vector2i(440,900); root.content_scale_size=root.size; await settle(); await capture("research-full-slot-440")
	# Unlocking the second slot enables all otherwise valid research again.
	app.progression_inputs.researchSlotTwoUnlocked=true; lobby.refresh(); await settle(); compare(lobby,app)
	assert(cards(lobby).any(is_ready) and not is_ready(card(lobby,"researchEfficiency")))
	assert(app.apply_growth_command({"kind":"cancelResearch","id":"researchEfficiency","nowMillis":int(Time.get_unix_time_from_system()*1000)}))
	lobby.refresh(); await settle(); compare(lobby,app); assert(is_ready(card(lobby,"researchEfficiency")))
	assert(app.apply_growth_command({"kind":"startResearch","id":"researchCostEfficiency","nowMillis":int(Time.get_unix_time_from_system()*1000)}))
	app.progression_inputs.activeResearches[0].startedAtMillis=int(Time.get_unix_time_from_system()*1000)-int(app.progression_inputs.activeResearches[0].durationMillis)-1000
	assert(app.apply_growth_command({"kind":"completeFinishedResearches","nowMillis":int(Time.get_unix_time_from_system()*1000)}))
	lobby.refresh(); await settle(); compare(lobby,app)
	assert(app.progression_inputs.activeResearches.is_empty() and int(app.progression_inputs.researchLevels.researchCostEfficiency)==1)
	# Completed/locked cards remain dim with their previous status/selection boundary.
	app.progression_inputs.researchLevels={"researchEfficiency":20}; lobby.refresh(); await settle(); compare(lobby,app)
	assert(card(lobby,"researchEfficiency").find_child("ResearchSelect_researchEfficiency",true,false)!=null)
	app.progression_inputs=baseline.duplicate(true); app.progression_inputs.clearedStageNumbers=[]; lobby.refresh(); await settle(); compare(lobby,app)
	assert(card(lobby,"criticalChance").find_child("ResearchSelect_criticalChance",true,false)==null)
	# Receiving new synchronized progression reuses the same full refresh path.
	app.progression_inputs=baseline.duplicate(true); app.progression_inputs.runes=10000; lobby.refresh(); await settle(); compare(lobby,app)
	assert(is_ready(card(lobby,"criticalChance")))
	print("PASS research availability: real domain eligibility, two columns, full-card tint, no shortage badges, cost/discount refresh, full/second slot, active/max/locked, detail click and touch scroll")
	lobby.free(); quit()
