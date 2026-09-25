extends SceneTree
const LobbyFixture = preload("res://verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")
const RESEARCH := "researchEfficiency"

func _initialize() -> void:
	call_deferred("_verify")

func _settle() -> void:
	for i in range(4): await process_frame

func _label(node: Node, value: String) -> Label:
	if node is Label and node.text == value: return node
	for child in node.get_children():
		var found := _label(child,value)
		if found != null: return found
	return null

func _button(node: Node, name: String) -> Button:
	return node.find_child(name,true,false) as Button

func _confirm_layout(lobby: Control) -> void:
	assert(_label(lobby.modal_frame,"연구를 중단할까요?") != null,"Stop confirmation title")
	assert(Rect2(Vector2.ZERO,lobby.size).encloses(lobby.modal_frame.get_global_rect()),"Stop confirmation fits 320 viewport")
	for name in ["StopResearch","KeepResearch"]:
		var action := _button(lobby.modal_frame,name)
		assert(action != null and action.visible,"Missing stop action: "+name)
		assert(action.get_global_rect().size.y >= 44,"Stop action touch height: "+name)
		assert(Rect2(Vector2.ZERO,lobby.size).encloses(action.get_global_rect()),"Stop action outside viewport: "+name)

func _verify() -> void:
	# Measure the settled touch targets; modal entrance animation is covered by
	# the separate visual UI check.
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	root.size = Vector2i(320,568)
	root.content_scale_size = Vector2i(320,568)
	var app := LobbyFixture.FakeApp.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.growth.load_catalog())
	app.progression_inputs = app.run_domain.growth.data.defaultProgression.duplicate(true)
	app.progression_inputs.runes = 100000
	var initial_runes := int(app.progression_inputs.runes)
	var quote: Dictionary = app.run_domain.growth.research_quote(app.progression_inputs,RESEARCH)
	var lobby := Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	lobby.open_page("연구")
	await _settle()
	var start_time := int(Time.get_unix_time_from_system()*1000) - 5000
	assert(app.apply_growth_command({"kind":"startResearch","id":RESEARCH,"nowMillis":start_time}))
	assert(int(app.progression_inputs.runes) == initial_runes-int(quote.cost),"Start deducts the real research cost")
	lobby.refresh()

	# Keep from details must restore details; keep from the slot list closes.
	lobby.growth._details(RESEARCH)
	lobby.growth._cancel_confirm(RESEARCH,true)
	await _settle()
	_confirm_layout(lobby)
	_button(lobby.modal_frame,"KeepResearch").pressed.emit()
	await _settle()
	assert(is_instance_valid(lobby.modal) and _label(lobby.modal_frame,"연구를 중단할까요?") == null,"Detail keep restores research details")
	assert(_label(lobby.modal_frame,str(lobby.growth.TITLES.get(RESEARCH,RESEARCH))) != null,"Original detail title restored")
	assert(app.progression_inputs.activeResearches.size() == 1,"Keep preserves active research")
	lobby.growth._cancel_confirm(RESEARCH,false)
	await _settle()
	_confirm_layout(lobby)
	_button(lobby.modal_frame,"KeepResearch").pressed.emit()
	await _settle()
	assert(not is_instance_valid(lobby.modal),"List keep closes confirmation")
	assert(app.progression_inputs.activeResearches.size() == 1,"List keep preserves active research")

	# Stop refunds the exact rule cost and preserves elapsed work for resumption.
	var before_stop := int(app.progression_inputs.runes)
	lobby.growth._cancel_confirm(RESEARCH,true)
	await _settle()
	_confirm_layout(lobby)
	_button(lobby.modal_frame,"StopResearch").pressed.emit()
	await _settle()
	assert(app.progression_inputs.activeResearches.is_empty(),"Stop clears the active research")
	assert(int(app.progression_inputs.runes)-before_stop == int(quote.cost),"Stop message must follow actual rune refund")
	assert(int(app.progression_inputs.researchElapsedMillis.get(RESEARCH,0)) >= 5000,"Stop preserves elapsed research time")
	assert(lobby.message.contains(str(quote.cost)) and lobby.message.contains("룬"),"Stop reports the actual rune refund")
	assert(lobby.message.contains("보존"),"Stop reports saved research time")

	# The rules complete an expired research even if the user confirms a stale stop dialog.
	var restart_time := int(Time.get_unix_time_from_system()*1000)
	assert(app.apply_growth_command({"kind":"startResearch","id":RESEARCH,"nowMillis":restart_time}))
	lobby.refresh()
	lobby.growth._cancel_confirm(RESEARCH,false)
	await _settle()
	var spent_runes := int(app.progression_inputs.runes)
	app.progression_inputs.activeResearches[0].startedAtMillis = restart_time-int(app.progression_inputs.activeResearches[0].durationMillis)-1000
	_button(lobby.modal_frame,"StopResearch").pressed.emit()
	await _settle()
	assert(app.progression_inputs.activeResearches.is_empty(),"Expired stop completes active research")
	assert(int(app.progression_inputs.researchLevels.get(RESEARCH,0)) == 1,"Expired stop grants the researched level")
	assert(int(app.progression_inputs.runes) == spent_runes,"Expired stop does not claim or grant a rune refund")
	assert(lobby.message.contains("완료") and not lobby.message.contains("환불"),"Expired stop explains completion without a false refund")
	lobby.growth._cancel_confirm(RESEARCH,true)
	await _settle()
	assert(_label(lobby.modal_frame,str(lobby.growth.TITLES.get(RESEARCH,RESEARCH))) != null,"Absent active research opens details")

	# Lifecycle completion may refresh the page while the old confirmation survives.
	lobby.close_modal(true)
	var next_start := int(Time.get_unix_time_from_system()*1000)
	assert(app.apply_growth_command({"kind":"startResearch","id":RESEARCH,"nowMillis":next_start}))
	lobby.refresh()
	lobby.growth._cancel_confirm(RESEARCH,false)
	await _settle()
	var pending_confirmation := lobby.modal
	app.progression_inputs.activeResearches[0].startedAtMillis = next_start-int(app.progression_inputs.activeResearches[0].durationMillis)-1000
	assert(app.apply_growth_command({"kind":"completeFinishedResearches","nowMillis":next_start}))
	var completed_runes := int(app.progression_inputs.runes)
	var command_count := app.commands.size()
	lobby.refresh()
	await _settle()
	assert(lobby.modal == pending_confirmation and _button(lobby.modal_frame,"StopResearch") != null,"Lifecycle refresh preserves pending confirmation")
	_button(lobby.modal_frame,"StopResearch").pressed.emit()
	await _settle()
	assert(app.commands.size() == command_count,"Completed confirmation sends no redundant cancel command")
	assert(app.progression_inputs.activeResearches.is_empty() and int(app.progression_inputs.researchLevels.get(RESEARCH,0)) == 2,"Lifecycle completion stays committed")
	assert(int(app.progression_inputs.runes) == completed_runes,"Completed confirmation does not change runes")
	assert(lobby.message.contains("완료") and not lobby.message.contains("반환"),"Completed confirmation explains completion without a false refund")

	# A stale confirmation must report a rejected command as a failure.
	assert(app.apply_growth_command({"kind":"startResearch","id":RESEARCH,"nowMillis":int(Time.get_unix_time_from_system()*1000)}))
	lobby.close_modal(true)
	lobby.refresh()
	lobby.growth._cancel_confirm(RESEARCH,false)
	await _settle()
	app.progression_inputs.activeResearches.clear()
	_button(lobby.modal_frame,"StopResearch").pressed.emit()
	await _settle()
	assert(lobby.message.contains("못했습니다"),"Rejected stale stop reports failure")

	print("PASS research stop: detail/list keep, 320 bounds and touch, actual refund and elapsed time, expired completion, lifecycle completion, missing active, rejected stale stop")
	lobby.free()
	quit()
