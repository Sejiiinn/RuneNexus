extends SceneTree
## Render the production Lobby/detail widgets with isolated actual growth rules.
const Fixture = preload("res://verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")
var captures := OS.get_environment("RESEARCH_DETAILS_CAPTURE_DIR")
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(10): await process_frame
func button(node: Node, caption: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == caption: return child
		var result := button(child,caption)
		if result != null: return result
	return null
func labels(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	if node is Label: result.append(node)
	for child in node.get_children(): result.append_array(labels(child))
	return result
func texts(node: Node) -> String:
	var result: String = node.text if node is Label or node is Button else ""
	for child in node.get_children(): result += "\n" + texts(child)
	return result
func capture(label: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(label+".png"))
func layout(lobby: Control, id: String) -> void:
	var bounds := Rect2(Vector2.ZERO,Vector2(root.size))
	assert(bounds.encloses(lobby.modal_frame.get_global_rect()),"Detail frame stays inside viewport")
	assert(lobby.modal_body.get_combined_minimum_size().x <= lobby.modal_scroll.size.x,"Content fits narrow scroll width")
	assert(labels(lobby.modal_frame).filter(func(label):return label.text==str(lobby.growth.TITLES.get(id,id))).size()==1,"Research title is shown once")
	assert(not texts(lobby.modal_body).contains("해금 조건"))
	assert(lobby.modal_body.find_children("*","PanelContainer",true,false).is_empty(),"Description has no nested frame")
	var quote = lobby.modal_body.find_child("ResearchDetailQuote",true,false) as HBoxContainer
	if quote != null:
		assert(quote.get_global_rect().end.x <= lobby.modal_frame.get_global_rect().end.x)
		assert(is_equal_approx(quote.get_child(0).global_position.y,quote.get_child(2).global_position.y),"Cost and time remain in two columns")
	var next = lobby.modal_body.find_child("ResearchDetailNext",true,false) as Label
	if next != null:
		assert(next.get_theme_font_size("font_size")==16 and next.get_theme_color("font_color").is_equal_approx(Color("e7c66a")),"Next effect uses readable gold text")
func click(control: Control) -> void:
	var pos := control.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=pos; event.pressed=down; root.push_input(event,true)
	await settle()
func run() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size=Vector2i(440,900); root.content_scale_size=root.size
	var app := Fixture.FakeApp.new(); app.catalog.load_catalog(); app.run_domain.growth.load_catalog()
	var baseline: Dictionary=app.run_domain.growth.data.defaultProgression.duplicate(true); baseline.runes=1000
	app.progression_inputs=baseline.duplicate(true)
	var lobby := Lobby.new(); lobby.app=app; root.add_child(lobby); await settle(); lobby.open_page("연구"); await settle()
	for width in [440,320]:
		root.size=Vector2i(width,900); root.content_scale_size=root.size; await settle()
		lobby.growth._details("researchEfficiency"); await settle(); layout(lobby,"researchEfficiency")
		var quote: Dictionary=app.run_domain.growth.research_quote(app.progression_inputs,"researchEfficiency")
		assert(texts(lobby.modal_body).contains("필요 룬 %d" % int(quote.cost)) and texts(lobby.modal_body).contains("보유 1000"))
		assert(texts(lobby.modal_body).contains(lobby.growth.effect_value("researchEfficiency",0)) and texts(lobby.modal_body).contains(lobby.growth.effect_value("researchEfficiency",1)))
		var action := button(lobby.modal_body,"연구 시작")
		assert(action!=null and not action.disabled and action.variant=="primary" and action.size.y>=44)
		assert(lobby.modal_frame.get_global_rect().encloses(action.get_global_rect()) and action.size.x==lobby.modal_body.size.x)
		await capture("research-detail-%d" % width)
	# Actual press sends the same domain command and deducts the actual quote.
	var initial_runes: int=int(app.progression_inputs.runes)
	var quote: Dictionary=app.run_domain.growth.research_quote(app.progression_inputs,"researchEfficiency")
	await click(button(lobby.modal_body,"연구 시작"))
	assert(app.commands.back().kind=="startResearch" and app.commands.back().id=="researchEfficiency")
	assert(app.progression_inputs.activeResearches.size()==1 and int(app.progression_inputs.runes)==initial_runes-int(quote.cost))
	app.progression_inputs.freeDiamonds=100
	lobby.growth._details("researchEfficiency"); await settle(); layout(lobby,"researchEfficiency")
	assert(button(lobby.modal_body,"연구 중단")!=null and texts(lobby.modal_body).contains("즉시 완료"))
	await capture("research-active-320")
	app.progression_inputs.activeResearches[0].startedAtMillis=int(Time.get_unix_time_from_system()*1000)-int(app.progression_inputs.activeResearches[0].durationMillis)+59000
	for child in lobby.modal_body.get_children():
		if child is Timer: child.timeout.emit()
	assert(button(lobby.modal_body,"즉시 완료 · 다이아 1")!=null,"Active timer still updates real instant cost")
	app.progression_inputs.freeDiamonds=0
	for child in lobby.modal_body.get_children():
		if child is Timer: child.timeout.emit()
	assert(button(lobby.modal_body,"즉시 완료 · 다이아 1").disabled)
	# Expired research retains its explicit completion action.
	app.progression_inputs.activeResearches[0].startedAtMillis=int(Time.get_unix_time_from_system()*1000)-int(app.progression_inputs.activeResearches[0].durationMillis)-1000
	lobby.growth._details("researchEfficiency"); await settle()
	assert(button(lobby.modal_body,"완료 받기")!=null)
	button(lobby.modal_body,"완료 받기").pressed.emit(); await settle()
	assert(app.progression_inputs.activeResearches.is_empty() and int(app.progression_inputs.researchLevels.researchEfficiency)==1)
	# Hiding a condition never enables unavailable research.
	app.progression_inputs=baseline.duplicate(true); lobby.growth._details("linkExpansionOne"); await settle(); layout(lobby,"linkExpansionOne")
	assert((lobby.modal_body.find_child("ResearchDetailAction",true,false) as Button).disabled and lobby.growth.research_status("linkExpansionOne").begins_with("스테이지"))
	app.progression_inputs.runes=0; lobby.growth._details("researchEfficiency"); await settle()
	assert(button(lobby.modal_body,"룬 부족").disabled)
	app.progression_inputs=baseline.duplicate(true); app.progression_inputs.activeResearches=[{"type":"researchEfficiency","targetLevel":1,"startedAtMillis":int(Time.get_unix_time_from_system()*1000),"durationMillis":300000}]
	lobby.growth._details("researchCostEfficiency"); await settle(); assert(button(lobby.modal_body,"빈 연구 슬롯 필요").disabled)
	# Long one-time unlock values wrap, and real discount cost/duration stay live.
	app.progression_inputs=baseline.duplicate(true); app.progression_inputs.clearedStageNumbers=range(1,16); app.progression_inputs.runes=123456789
	for id in ["turretTargetPriority","linkExpansionOne","linkMaintenance","researchCostEfficiency"]:
		lobby.growth._details(id); await settle(); layout(lobby,id)
		assert(texts(lobby.modal_body).contains(lobby.growth.effect_value(id,0)) and texts(lobby.modal_body).contains(lobby.growth.effect_value(id,1)))
	# Existing shell refresh updates the header level without duplicate title/entrance.
	lobby.growth._details("researchEfficiency"); await settle()
	var modal_id: int=lobby.modal.get_instance_id(); var header_id: int=lobby.modal_frame.find_child("ResearchDetailHeader",true,false).get_instance_id()
	app.progression_inputs.researchLevels={"researchEfficiency":1,"researchCostEfficiency":2}; lobby.refresh(); await settle(); layout(lobby,"researchEfficiency")
	quote=app.run_domain.growth.research_quote(app.progression_inputs,"researchEfficiency")
	assert(lobby.modal.get_instance_id()==modal_id and lobby.modal_frame.find_child("ResearchDetailHeader",true,false).get_instance_id()==header_id)
	assert((lobby.modal_frame.find_child("ResearchDetailLevel",true,false) as Label).text=="Lv.1 / 20")
	assert(texts(lobby.modal_body).contains("필요 룬 %d" % int(quote.cost)))
	# Short windows scroll content instead of shrinking its button/text.
	root.size=Vector2i(320,220); root.content_scale_size=root.size; await settle(); lobby.growth._details("researchCostEfficiency"); await settle(); layout(lobby,"researchCostEfficiency")
	assert(lobby.modal_body.get_combined_minimum_size().y>lobby.modal_scroll.size.y)
	lobby.modal_scroll.scroll_vertical=10000; await settle()
	var action := button(lobby.modal_body,"연구 시작")
	assert(action!=null and action.size.y>=44 and lobby.modal_frame.get_global_rect().encloses(action.get_global_rect()),"Start is reachable by internal scrolling")
	await capture("research-short-320")
	# Maximum research does not offer a next effect or a start command.
	root.size=Vector2i(320,900); root.content_scale_size=root.size; await settle()
	app.progression_inputs.researchLevels={"researchEfficiency":20}; lobby.growth._details("researchEfficiency"); await settle(); layout(lobby,"researchEfficiency")
	assert(button(lobby.modal_body,"연구 완료").disabled and lobby.modal_body.find_child("ResearchDetailNext",true,false)==null)
	var maximum_effect: Label=lobby.modal_body.find_child("ResearchDetailEffect",true,false).get_child(0)
	assert(maximum_effect.size.x>70 and maximum_effect.get_line_count()==1,"Maximum current effect remains readable without a next column")
	lobby.close_modal(); lobby.refresh(); await settle(); assert(lobby.modal==null,"Refresh cannot reopen a dismissed research detail")
	print("PASS research details: title/effect/quote 440/320, real start cost, active timer, expired collection, unlock/rune/slot gates, long values, refresh, max and 320x220 scrolling")
	lobby.free(); quit()
