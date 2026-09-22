extends SceneTree
const Stages = preload("res://ui/lobby_stages.gd")
class Catalog extends RefCounted:
	var data := {}
	func stage_count() -> int: return data.stages.size()
	func stage(index: int) -> Dictionary: return data.stages[index]
class App extends RefCounted:
	var catalog
	var run_domain := {"state":{}}
	var resumed := 0
	func resume_run() -> bool:
		resumed += 1
		return true
class Host extends Control:
	var body: VBoxContainer
	var app := App.new()
	var p := {"unlockedStageCount":7, "clearedStageNumbers":[1,2,3,4,5,6], "bestRoundsByStage":{"1":40}, "researchLevels":{}, "runes":42}
	var modal: VBoxContainer
	var started := -1
	func _p() -> Dictionary: return p
	func _has_run() -> bool: return not app.run_domain.state.is_empty()
	func _start(index: int) -> void: started = index
	func _failure() -> void: assert(false)
	func close_modal() -> void:
		if is_instance_valid(modal): remove_child(modal); modal.queue_free(); modal = null
	func open_modal(_title: String) -> VBoxContainer:
		close_modal()
		modal = VBoxContainer.new()
		modal.size.x = size.x - 52
		add_child(modal)
		return modal
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var host := Host.new()
	host.app.catalog = Catalog.new()
	host.app.catalog.data = JSON.parse_string(FileAccess.get_file_as_string("res://content/game_content.json"))
	root.add_child(host)
	host.theme = preload("res://ui/app_theme.gd").create()
	host.body = VBoxContainer.new()
	host.add_child(host.body)
	var ui := Stages.new()
	ui.setup(host)
	assert(ui.rune_reward(1) == 150)
	assert(ui.rune_reward(2) == 177)
	assert(host.p.runes == 42 and host.p.clearedStageNumbers.size() == 6)
	host.p.researchLevels.runeResonance = 10
	assert(ui.rune_reward(1) == 180)
	host.p.researchLevels = {}
	assert(ui.unlock_items(5).size() == 3)
	assert(ui.unlock_items(11)[0][0] == "모듈 티켓 5장")
	host.p.availableTurretTypes = ["sniper"]
	host.p.clearedStageNumbers.erase(3)
	assert(ui.reward_highlighted(3), "Stage 3 reward must follow actual sniper availability")
	host.p.availableTurretTypes = []
	assert(not ui.reward_highlighted(3))
	host.p.erase("availableTurretTypes")
	host.p.clearedStageNumbers.append(3)
	ui.details(8)
	assert(host.modal.get_child(host.modal.get_child_count()-1).disabled)
	ui.start(8)
	assert(host.started == -1)
	ui.start(7)
	assert(host.started == 6)
	host.size = Vector2(440,900)
	host.body.size = Vector2(392,660)
	ui.render()
	assert(ui.chapter == 2)
	await process_frame
	await process_frame
	ui.select_chapter(3)
	assert(ui.chapter == 3)
	host.app.run_domain.state = {"stage":3,"roundIndex":5,"gold":250,"turrets":[{},{}],"phase":"wave"}
	ui.start(4)
	assert(host.app.resumed == 1 and host.started == 6)
	for width in [320,440]:
		for in_progress in [false,true]:
			host.app.run_domain.state = {"stage":3,"roundIndex":5,"gold":250,"turrets":[],"phase":"wave"} if in_progress else {}
			for child in host.body.get_children(): host.body.remove_child(child); child.queue_free()
			host.size = Vector2(width,900)
			host.body.size = Vector2(width - 48,660)
			ui.chapter = 1
			ui.render()
			await process_frame
			await process_frame
			for child in ui.canvas.get_children():
				assert(child.position.x >= -1 and child.position.y >= -1)
				assert(child.position.x + child.size.x <= ui.canvas.size.x + 1, "%s at width %d" % [child, width])
				assert(child.position.y + child.size.y <= ui.canvas.size.y + 1)
			ui.details(5)
			await process_frame
			assert(host.modal.get_combined_minimum_size().x <= width - 52)
			assert(host.modal.find_child("StageDetailsHeader",true,false) != null)
			var chips := host.modal.find_children("UnlockChip*", "PanelContainer",true,false)
			assert(chips.size() == 3)
			for chip in chips:
				assert(chip.get_child(0) is HBoxContainer, "Unlock chip icon and label must be horizontal")
				assert(chip.custom_minimum_size.y == 52)
				assert(chip.find_child("RewardName",true,false).get_theme_color("font_color") == ui.SECONDARIES[0])
	print("PASS stage restoration: reference bounds 320/440, active/list, chapter, locked/start/continue, canonical rewards and unlock lists")
	host.free()
	quit()
