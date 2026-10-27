extends SceneTree
const Stages = preload("res://ui/lobby_stages.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Progression = preload("res://content/stage_progression.gd")
const Quests = preload("res://app/quest_progress.gd")
const Codec = preload("res://app/save_codec.gd")
const Store = preload("res://app/local_save_store.gd")
const StageMap = preload("res://ui/stage_map_view.gd")
const StageCard = preload("res://ui/lobby_stage_card.gd")
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
	func _init() -> void: name = "Host"
	func progression() -> Dictionary: return p
	func has_active_run() -> bool: return not app.run_domain.state.is_empty()
	func request_stage_start(index: int) -> void: started = index
	func show_failure() -> void: assert(false)
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
	ui.start(8)
	assert(host.started == -1)
	ui.start(7)
	assert(host.started == 6)
	ui.ensure_selection()
	assert(ui.chapter == 2 and ui.selected == 7, "Opens on the newest chapter at its first unlocked, uncleared stage")
	ui.select_chapter(3)
	assert(ui.chapter == 3 and ui.selected == Progression.ids_for_chapter(3)[0], "A locked chapter selects its first stage")
	host.app.run_domain.state = {"stage":3,"roundIndex":5,"gold":250,"turrets":[{},{}],"phase":"wave"}
	ui.ensure_selection()
	assert(ui.chapter == 1 and ui.selected == 4, "A new active run moves the map to its stage")
	ui.selected = 2
	ui.ensure_selection()
	assert(ui.selected == 2, "The player's own selection stays while the run is unchanged")
	ui.start(4)
	assert(host.app.resumed == 1 and host.started == 6)
	assert(Stages.unlock_icon(ui.unlock_items(3)[0]) == "ui/hud/turrets_3d/sniper.png" and Stages.unlock_destination(ui.unlock_items(3)[0]) == "포탑 해금")
	assert(Stages.unlock_destination(ui.unlock_items(11)[0]) == "모듈 티켓 지급" and Stages.previous_stage(8) == 7)
	host.app.run_domain.state = {}
	await verify_map_and_card(ui, host)
	print("PASS stage restoration: stage map 320/440 short/normal/tall, map tap/drag, card bar/actions/unlock bubble, active/locked/continue, 25-stage monotonic rune preview/settlement, preserved wallet/save, canonical rewards and unlock lists")
	host.free()
	quit()

func verify_map_and_card(ui, host) -> void:
	for dimensions in [Vector2(320, 520), Vector2(440, 700), Vector2(440, 940)]:
		for chapter in [1, 2, 3]:
			ui.select_chapter(chapter)
			var map = StageMap.new()
			map.stages = ui
			host.add_child(map)
			map.size = dimensions
			var gate_y := 125.0
			var base_y: float = dimensions.y - 270
			map.arrange(chapter, gate_y, base_y)
			map.refresh_nodes()
			var ids: Array = Progression.ids_for_chapter(chapter)
			for i in ids.size():
				var at: Vector2 = map._centers[ids[i]]
				assert(at.x > 0 and at.x < dimensions.x, "Stage socket inside the map width")
			# Every stage can be scrolled between the header and the card.
			for id in ids:
				map.set_scroll(map._centers[id].y - (gate_y + base_y) / 2)
				var y: float = map._centers[id].y - map.scroll
				assert(y >= gate_y - 20 and y <= base_y + 1, "Stage %s reachable at %s" % [Progression.stage_label(id), dimensions])
			assert(map.map_scale.y >= map.map_scale.x * 0.85 - 0.001 and map.map_scale.y <= map.map_scale.x + 0.001, "Map art never squeezes past 85%")
			var badges: int = 0
			var claimed: int = 0
			for id in ids:
				badges += mini(ui.unlock_items(id).size(), 3)
				if ui.reward_highlighted(id): claimed += mini(ui.unlock_items(id).size(), 3)
			var shown: Array = map.nodes.find_children("UnlockBadge*", "Panel", true, false)
			assert(shown.size() == badges, "One badge per first-clear unlock, obtained or not")
			assert(shown.filter(func(b): return b.get_meta("claimed") and b.get_child_count() == 2).size() == claimed, "Obtained unlocks keep their badge with a check")
			# Tap selects; a stage tap reports its id.
			var pressed: Array = []
			map.stage_pressed.connect(func(id): pressed.append(id))
			var target: int = ids[1]
			map._gui_input(_button(map._centers[target] - Vector2(0, map.scroll), true))
			map._gui_input(_button(map._centers[target] - Vector2(0, map.scroll), false))
			assert(pressed == [target], "Tap on a socket selects it")
			map.free()
		for stage in [1, 3, 7, 8, 11]:
			var card = StageCard.new()
			card.stages = ui
			host.add_child(card)
			card.size = Vector2(dimensions.x - 24, StageCard.HEIGHT)
			card.show_stage(stage)
			var rect := Rect2(Vector2.ZERO, card.size)
			for child in card.get_children():
				if child is Control: assert(rect.grow(1).encloses(Rect2(child.position, child.size)), "%s outside card at %s" % [child.name, dimensions])
			var action: Button = card.find_child("StageStart", false, false) if ui.unlocked(stage) else card.find_child("StageLocked", false, false)
			assert(action != null and action.disabled == not ui.unlocked(stage))
			assert(card.get_node("RoundTrack").position.x + card.get_node("RoundTrack").size.x <= action.position.x - 11, "Round bar stops before the action")
			var tiles := card.find_children("Unlock*", "Button", false, false)
			assert(tiles.size() == mini(ui.unlock_items(stage).size(), 3))
			if not tiles.is_empty():
				tiles[0].pressed.emit()
				await process_frame
				var bubble: Control = card.find_child("UnlockTooltip", false, false)
				assert(bubble != null and bubble.position.y < 0 and bubble.position.x >= 0 and bubble.position.x + bubble.size.x <= card.size.x + 0.1, "Bubble opens above the card")
				assert(card.find_child("TooltipDestination", true, false).text == Stages.unlock_destination(ui.unlock_items(stage)[0]))
				card._gui_input(_button(Vector2(40, 40), true))
				await process_frame
				assert(card.find_child("UnlockTooltip", false, false) == null, "Tap inside the card closes the bubble")
				tiles = card.find_children("Unlock*", "Button", false, false)
				tiles[0].pressed.emit()
				await process_frame
				var catcher: Control = host.get_node("TooltipCatcher")
				catcher.gui_input.emit(_button(Vector2(5, 5), true))
				await process_frame
				assert(card.find_child("UnlockTooltip", false, false) == null, "Tap outside closes the bubble")
			card.free()
			await process_frame

func _button(at: Vector2, down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = down
	return event

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
