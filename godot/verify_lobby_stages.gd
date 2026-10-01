extends SceneTree
const Stages = preload("res://ui/lobby_stages.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Progression = preload("res://content/stage_progression.gd")
const Quests = preload("res://app/quest_progress.gd")
const Codec = preload("res://app/save_codec.gd")
const Store = preload("res://app/local_save_store.gd")
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
	var opened_modals := 0
	func _p() -> Dictionary: return p
	func _has_run() -> bool: return not app.run_domain.state.is_empty()
	func _start(index: int) -> void: started = index
	func _failure() -> void: assert(false)
	func close_modal() -> void:
		if is_instance_valid(modal): remove_child(modal); modal.queue_free(); modal = null
	func open_modal(_title: String) -> VBoxContainer:
		opened_modals += 1
		close_modal()
		modal = VBoxContainer.new()
		modal.size.x = size.x - 52
		add_child(modal)
		return modal
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var host := Host.new()
	host.app.catalog = Catalog.new()
	assert(host.app.catalog.load_catalog())
	root.add_child(host)
	host.theme = preload("res://ui/app_theme.gd").create()
	host.body = VBoxContainer.new()
	host.add_child(host.body)
	var ui := Stages.new()
	ui.setup(host)
	verify_rune_rewards(ui, host)
	assert(ui.rune_reward(1) == 150)
	assert(ui.rune_reward(2) == 177)
	assert(host.p.runes == 42 and host.p.clearedStageNumbers.size() == 6)
	host.p.researchLevels.runeResonance = 10
	assert(ui.rune_reward(1) == 180)
	host.p.researchLevels = {}
	assert(ui.unlock_items(5).size() == 1)
	assert(ui.unlock_items(5)[0][0] == "토벌 보상")
	assert(ui.unlock_items(17).size() == 2)
	assert(ui.unlock_items(20).size() == 2)
	assert(ui.unlock_items(25)[0][0] == "연구 슬롯 II 구매 권한")
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
			assert(chips.size() == 1)
			for chip in chips:
				assert(chip.get_child(0) is HBoxContainer, "Unlock chip icon and label must be horizontal")
				assert(chip.custom_minimum_size.y == 52)
				assert(chip.find_child("RewardName",true,false).get_theme_color("font_color") == ui.SECONDARIES[0])
	host.close_modal()
	await verify_stage_scroll(ui, host)
	print("PASS stage restoration: reference bounds 320/440, active/list, chapter, locked/start/continue, 25-stage monotonic rune preview/settlement, preserved wallet/save, wheel/touch list scroll 320/440 short/normal, canonical rewards and unlock lists")
	host.free()
	quit()

func verify_rune_rewards(ui, host) -> void:
	var original: Dictionary = host.p.duplicate(true)
	var quests = Quests.new()
	var reward_rows: Array = []
	for level in [0, 5, 20]:
		host.p = original.duplicate(true)
		host.p.researchLevels.runeResonance = level
		var before: Dictionary = host.p.duplicate(true)
		var previous := 0
		var ordinal := 0
		var rewards: Array = []
		for id in Progression.ordered_ids():
			ordinal += 1
			assert(Progression.reward_ordinal(id) == ordinal)
			var preview: int = ui.rune_reward(id)
			assert(host.p == before, "Rune preview must not mutate source progression")
			var expected := int(round(150.0 * pow(1.18, ordinal - 1) * (1.0 + level * 0.02)))
			assert(preview == expected and preview > previous, "Rune rewards must grow at stage %s / resonance %d" % [Progression.stage_label(id), level])
			var settled: Dictionary = quests.finish(host.p, {"stageNumber":id, "completedRounds":40, "success":true})
			assert(settled.lastRunRuneReward == preview and int(settled.runes) - int(before.runes) == preview, "Preview must equal actual settlement wallet delta")
			assert(host.p == before, "Settlement must not mutate source progression")
			for rounds in [0, 1, 10, 20, 30]:
				var progress := (pow(1.04, rounds) - 1.0) / (pow(1.04, 40) - 1.0)
				var partial_expected := maxi(1, int(round(expected_unrounded(ordinal, level) * progress))) if rounds > 0 else 0
				var partial: Dictionary = quests.finish(host.p, {"stageNumber":id, "completedRounds":rounds, "success":false})
				assert(partial.lastRunRuneReward == partial_expected and int(partial.runes) - int(before.runes) == partial_expected, "Zero/partial rounds preserve cumulative reward formula")
				assert(partial.lastRunCorePointReward == 0 and partial.lastRunTurretModuleTicketReward == 0)
			previous = preview
			rewards.append({"stage":Progression.stage_label(id), "id":id, "runes":preview})
		reward_rows.append({"resonanceLevel":level, "rewards":rewards})
	# An old wallet/save is migration evidence, never a retroactive run reward.
	var old_save: Dictionary = Codec.decode({"version":2, "savedAtMillis":123, "progression":{"growthVersion":1, "runes":1234, "totalCorePoints":9, "clearedStageNumbers":[6,11], "claimedCorePointStageRewards":[6,11], "lastRunRuneReward":785, "researchLevels":{"runeResonance":5}}, "turretModules":{"tickets":7}, "preferences":{"selectedStageNumber":11}, "activeRun":null})
	var old_before := old_save.duplicate(true)
	var migrated: Dictionary = Progression.migrate_progression(old_save.progression)
	for field in ["runes", "totalCorePoints", "clearedStageNumbers", "claimedCorePointStageRewards", "lastRunRuneReward"]:
		assert(migrated[field] == old_before.progression[field], "Reward policy must preserve old wallet and received reward records")
	assert(old_save == old_before and Progression.migrate_progression(migrated) == migrated)
	old_save.progression = migrated
	var directory := OS.get_environment("TMPDIR").path_join("lobby-rune-reward-save-" + str(Time.get_ticks_usec()))
	var store = Store.new(directory)
	assert(store.save_save(old_save) == OK)
	var reloaded: Dictionary = store.load_save()
	assert(store.last_error == OK and reloaded == old_save, "Old wallet and claimed fixed IDs survive persistence/reload")
	assert(reloaded.preferences.selectedStageNumber == 11 and reloaded.turretModules.tickets == 7)
	var replay: Dictionary = quests.finish(reloaded.progression, {"stageNumber":11, "completedRounds":40, "success":true, "firstClearCorePointReward":2, "firstClearTurretModuleTicketReward":5})
	assert(replay.totalCorePoints == 9 and replay.claimedCorePointStageRewards == [6,11] and replay.lastRunCorePointReward == 0 and replay.lastRunTurretModuleTicketReward == 0, "Changed rune policy must not regrant first-clear core points/module tickets")
	store.clear()
	host.p = original
	print("RUNE_REWARD_MATRIX ", JSON.stringify(reward_rows))

func expected_unrounded(ordinal: int, level: int) -> float:
	return 150.0 * pow(1.18, ordinal - 1) * (1.0 + level * 0.02)

func stage_pointer(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func stage_row_buttons(scroll: ScrollContainer) -> Array:
	return scroll.get_node("StageRows").get_children().filter(func(child): return child is Button)

func verify_stage_scroll(ui, host) -> void:
	# Native touch scrolling is gated by touchscreen availability on desktop.
	var old_emulation := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	for width in [320, 440]:
		for height in [600, 900]:
			root.size = Vector2i(width, height)
			root.content_scale_size = Vector2i(width, height)
			for in_progress in [false, true]:
				for chapter in [1, 2]:
					host.app.run_domain.state = {"stage":0 if chapter == 1 else 5, "roundIndex":5, "gold":250, "turrets":[], "phase":"wave"} if in_progress else {}
					for child in host.body.get_children(): host.body.remove_child(child); child.queue_free()
					host.size = Vector2(width, height)
					host.body.size = Vector2(width - 48, height - 240)
					ui.list_scroll.clear()
					ui.chapter = chapter
					ui.render()
					await process_frame
					await process_frame
					var scroll := ui.canvas.get_node("StageRowsScroll") as ScrollContainer
					var rows := stage_row_buttons(scroll)
					assert(rows.size() == (9 if in_progress else 10))
					assert(rows[0].size.y >= 40, "Short list rows must remain readable/tappable")
					assert(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page)
					assert(not scroll.get_v_scroll_bar().visible and not scroll.get_h_scroll_bar().visible and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
					var fixed_rects: Array = []
					for child in ui.canvas.get_children():
						if child != scroll: fixed_rects.append(child.get_global_rect())
					var opened: int = host.opened_modals
					var point: Vector2 = rows[0].get_global_rect().get_center()
					var touch := InputEventScreenTouch.new()
					touch.index = 0; touch.position = point; touch.pressed = true
					stage_pointer(touch)
					await process_frame
					for i in range(1, 5):
						var drag := InputEventScreenDrag.new()
						drag.index = 0; drag.position = point - Vector2(0, i * 12); drag.relative = Vector2(0, -12)
						stage_pointer(drag)
						await process_frame
					touch = InputEventScreenTouch.new()
					touch.index = 0; touch.position = point - Vector2(0, 48); touch.pressed = false
					stage_pointer(touch)
					await process_frame
					assert(scroll.scroll_vertical > 0 and host.opened_modals == opened, "Row swipe must scroll without opening details")
					# A tap cancels native scroll momentum and still opens the stage details.
					scroll.scroll_vertical = 0
					await process_frame
					point = rows[0].get_global_rect().get_center()
					for down in [true, false]:
						var tap := InputEventScreenTouch.new()
						tap.index = 0; tap.position = point; tap.pressed = down
						stage_pointer(tap)
					assert(host.opened_modals == opened + 1, "Row tap must open details")
					host.close_modal()
					await process_frame
					for i in range(40):
						var wheel := InputEventMouseButton.new()
						wheel.position = scroll.get_global_rect().get_center(); wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true
						stage_pointer(wheel)
					await process_frame
					assert(scroll.scroll_vertical >= scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page - 1, "Wheel must reach the final stage")
					assert(rows[-1].tooltip_text == "스테이지 %d-10 상세" % chapter)
					assert(rows[-1].get_global_rect().end.y <= scroll.get_global_rect().end.y + 1)
					assert(scroll.scroll_horizontal == 0)
					var index := 0
					for child in ui.canvas.get_children():
						if child != scroll:
							assert(child.get_global_rect() == fixed_rects[index], "Scrolling must keep chapter tabs/banner/active card fixed")
							index += 1
					var remembered: int = scroll.scroll_vertical
					ui.select_chapter(3)
					await process_frame
					await process_frame
					ui.select_chapter(chapter)
					await process_frame
					await process_frame
					assert(ui.canvas.get_node("StageRowsScroll").scroll_vertical == remembered, "Each chapter retains its list position")
	Input.emulate_touch_from_mouse = old_emulation
