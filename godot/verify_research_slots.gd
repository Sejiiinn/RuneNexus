extends SceneTree
## Production active slots exercise actual stop/resume rules and live cost/time.
const Fixture = preload("res://verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")
const ProgressVisual = preload("res://ui/research_progress.gd")
const Progression = preload("res://content/stage_progression.gd")
var captures := OS.get_environment("RESEARCH_SLOTS_CAPTURE_DIR")
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(10): await process_frame
func fills(lobby: Control) -> Array:
	return lobby.body.find_children("ResearchSlotProgress","Control",true,false)
func button(node: Node, caption: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == caption: return child
		var result := button(child,caption)
		if result != null: return result
	return null
func card(fill: Control) -> Control:
	var node: Node=fill
	while node!=null and not str(node.name).begins_with("ResearchSlot_"): node=node.get_parent()
	return node as Control
func clock(fill: Control) -> Label:
	return card(fill).find_child("ResearchSlotClock",true,false)
func timer(fill: Control) -> Timer:
	return card(fill).find_child("ResearchSlotTimer",true,false)
func cost(fill: Control) -> Label:
	return card(fill).find_child("ResearchSlotCost",true,false)
func capture(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(name+".png"))
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; root.push_input(event,true)
	await settle()
func layout(lobby: Control) -> void:
	assert(lobby.body.get_combined_minimum_size().x <= lobby._page_scroll.size.x,"Slots fit the narrow scroll width")
	for fill in fills(lobby):
		var panel := card(fill) as Control
		assert(panel.get_global_rect().encloses(fill.get_global_rect()),"Progress stays inside the existing metal row")
		var stop := panel.find_child("ResearchSlotStop",true,false) as Button
		var instant := panel.find_child("ResearchSlotInstant",true,false) as Button
		for action in [stop,instant]:
			var text_width: float=action.get_theme_font("font").get_string_size(action.text,HORIZONTAL_ALIGNMENT_LEFT,-1,action.get_theme_font_size("font_size")).x
			var padding: float=action.get_theme_stylebox("normal").get_minimum_size().x
			assert(action.size.x >= text_width+padding,"Slot action text stays visible on one line: "+action.text)
			assert(panel.get_global_rect().encloses(action.get_global_rect()),"Slot action stays inside its row")
		assert(stop.text=="중단" and stop.tooltip_text=="연구 중단" and stop.size.x>=54,"A stop is a readable bronze action")
		assert(fill.slot_bar and fill.size.y<=10,"A progress stays a thin horizontal bar")
		for part in ["ResearchSlotIcon","ResearchSlotTitle","ResearchSlotLevel","ResearchSlotPercent","ResearchSlotClock","ResearchSlotCost"]:
			var control := panel.find_child(part,true,false) as Control
			assert(control!=null and panel.get_global_rect().encloses(control.get_global_rect()),"A information stays inside card: "+part)
func run() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size=Vector2i(440,900); root.content_scale_size=root.size
	var app := Fixture.FakeApp.new(); app.catalog.load_catalog(); app.run_domain.growth.load_catalog()
	app.progression_inputs=app.run_domain.growth.data.defaultProgression.duplicate(true)
	app.progression_inputs.runes=100000; app.progression_inputs.freeDiamonds=1280; app.progression_inputs.clearedStageNumbers=Progression.ordered_ids()
	var now := int(Time.get_unix_time_from_system()*1000)
	var quote: Dictionary=app.run_domain.growth.research_quote(app.progression_inputs,"researchCostEfficiency")
	assert(app.apply_growth_command({"kind":"startResearch","id":"researchCostEfficiency","nowMillis":now-int(quote.durationMillis)/2}))
	var lobby := Lobby.new(); lobby.app=app; root.add_child(lobby); await settle(); lobby.open_page("연구"); await settle()
	assert(fills(lobby).size()==1 and fills(lobby)[0].progress>0.49,"Existing progress is visible immediately on entry")
	layout(lobby); await capture("one-slot-440")
	# Use the actual slot control to preserve the existing stop confirmation.
	await click(card(fills(lobby)[0]).find_child("ResearchSlotStop",true,false))
	assert(button(lobby.modal_frame,"계속 연구")!=null or lobby.modal_frame.find_child("KeepResearch",true,false)!=null)
	lobby.modal_frame.find_child("KeepResearch",true,false).pressed.emit(); await settle()
	assert(lobby.modal==null and app.progression_inputs.activeResearches.size()==1)
	await click(card(fills(lobby)[0]).find_child("ResearchSlotStop",true,false))
	lobby.modal_frame.find_child("StopResearch",true,false).pressed.emit(); await settle()
	assert(app.progression_inputs.activeResearches.is_empty() and int(app.progression_inputs.researchElapsedMillis.researchCostEfficiency)>int(quote.durationMillis)*0.49)
	assert(app.apply_growth_command({"kind":"startResearch","id":"researchCostEfficiency","nowMillis":int(Time.get_unix_time_from_system()*1000)}))
	lobby.refresh(); await settle()
	assert(fills(lobby)[0].progress>0.49 and fills(lobby)[0].progress<0.55,"Resume keeps previously elapsed progress instead of restarting its fill")
	app.progression_inputs.researchSlotTwoUnlocked=true
	quote=app.run_domain.growth.research_quote(app.progression_inputs,"towerDamageLimitExpansion")
	assert(app.apply_growth_command({"kind":"startResearch","id":"towerDamageLimitExpansion","nowMillis":int(Time.get_unix_time_from_system()*1000)-int(quote.durationMillis)/4}))
	lobby.refresh(); await settle()
	for width in [440,320]:
		root.size=Vector2i(width,900); root.content_scale_size=root.size; await settle(); layout(lobby)
		assert(fills(lobby).size()==2 and fills(lobby)[1].progress>0.24 and fills(lobby)[1].progress<0.3)
		await capture("two-slots-%d"%width)
	# Cost/clock and the animated fill respond to a live timer across a minute boundary.
	var active: Dictionary=app.progression_inputs.activeResearches[0]
	active.startedAtMillis=int(Time.get_unix_time_from_system()*1000)-int(active.durationMillis)+60500
	var fill: Control=fills(lobby)[0]
	timer(fill).timeout.emit(); await settle()
	assert(cost(fill).text=="2")
	var old_progress: float=fill.progress
	active.startedAtMillis-=2000; timer(fill).timeout.emit(); await create_timer(0.9).timeout
	assert(cost(fill).text=="1" and clock(fill).text.begins_with("0분"))
	assert(fill.progress>old_progress,"Timer advances the visible fill")
	app.progression_inputs.freeDiamonds=0; timer(fill).timeout.emit(); await settle()
	assert((card(fill).find_child("ResearchSlotInstant",true,false) as Button).disabled)
	app.progression_inputs.freeDiamonds=1280
	active.startedAtMillis=int(Time.get_unix_time_from_system()*1000)-int(active.durationMillis)-1000
	timer(fill).timeout.emit(); await create_timer(0.9).timeout
	assert(clock(fill).text=="연구 완료" and fill.progress>0.999,"Expired clock/fill reach completion: %s / %.6f"%[clock(fill).text,fill.progress])
	await capture("dynamic-complete-320")
	# The actual instant control retains its confirmation and real completion command.
	await click(card(fill).find_child("ResearchSlotInstant",true,false))
	assert(lobby.modal!=null)
	lobby.close_modal(true)
	assert(app.apply_growth_command({"kind":"completeFinishedResearches","nowMillis":int(Time.get_unix_time_from_system()*1000)}))
	lobby.refresh(); await settle()
	assert(fills(lobby).size()==1 and int(app.progression_inputs.researchLevels.researchCostEfficiency)==1)
	# Narrow/short views retain long identity text and three-digit live costs.
	var remaining: Dictionary=app.progression_inputs.activeResearches[0]
	remaining.startedAtMillis=int(Time.get_unix_time_from_system()*1000)
	remaining.durationMillis=123*60000
	lobby.refresh(); await settle()
	fill=fills(lobby)[0]
	(card(fill).find_child("ResearchSlotTitle",true,false) as Label).text="포탑 화력 최대 레벨 확장 연구"
	(card(fill).find_child("ResearchSlotLevel",true,false) as Label).text="Lv.99/100"
	root.size=Vector2i(320,640); root.content_scale_size=root.size; await settle(); layout(lobby)
	assert(cost(fill).text=="123" and clock(fill).text.begins_with("2시간"))
	assert((card(fill).find_child("ResearchSlotTitle",true,false) as Label).get_line_count()>1,"Long identity wraps instead of clipping")
	await capture("long-title-cost-320x640")
	# Expired instant confirmation uses the existing domain path; an empty slot is retained.
	remaining.startedAtMillis-=remaining.durationMillis+1000
	assert(app.apply_growth_command({"kind":"completeFinishedResearches","nowMillis":int(Time.get_unix_time_from_system()*1000)}))
	lobby.refresh(); await settle(); layout(lobby)
	assert(fills(lobby).is_empty() and button(lobby.body,"중단")==null)
	await capture("empty-slots-320x640")
	lobby.free(); print("PASS research slots: visible stop/instant text 440/320, initial/resumed progress, real stop keep/resume, two slots, timer minute/cost/balance/completion and instant confirmation"); quit()
