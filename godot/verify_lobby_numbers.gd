extends SceneTree
const Numbers = preload("res://ui/hud_number.gd")
const Stages = preload("res://ui/lobby_stages.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Progression = preload("res://content/stage_progression.gd")
const Quests = preload("res://app/quest_progress.gd")

class App extends RefCounted:
	var catalog = Catalog.new()
	var run_domain := {"state":{}}
	var resumed := 0
	func resume_run() -> bool:
		resumed += 1
		return true

class Host extends Control:
	var app := App.new()
	var body: VBoxContainer
	var p := {"progressionVersion":1,"growthVersion":1,"clearedStageNumbers":[],"researchLevels":{},"runes":42}
	var modal: VBoxContainer
	func _p() -> Dictionary: return p
	func _has_run() -> bool: return not app.run_domain.state.is_empty()
	func close_modal() -> void:
		if is_instance_valid(modal): remove_child(modal); modal.queue_free(); modal = null
	func open_modal(_title: String) -> VBoxContainer:
		close_modal()
		modal = VBoxContainer.new()
		modal.size.x = size.x - 52
		add_child(modal)
		return modal
	func _failure() -> void: assert(false, "Unexpected resume failure")

var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); printerr(message)

func labels(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is Label: result.append(child)
		result.append_array(labels(child))
	return result

func settle() -> void:
	for i in range(3): await process_frame

func _initialize() -> void: call_deferred("verify")

func verify() -> void:
	for sample in [[0,"0"],[1,"1"],[999,"999"],[1000,"1,000"],[9400,"9,400"],[9999,"9,999"],[10000,"10K"],[10049,"10K"],[10050,"10.1K"],[11092,"11.1K"],[13089,"13.1K"],[15445,"15.4K"],[18225,"18.2K"],[999949,"999.9K"],[999950,"1M"],[999999,"1M"],[1000000,"1M"],[1049999,"1M"],[1050000,"1.1M"],[1200000,"1.2M"],[999999999,"1000M"],[1000000000,"1000M"],[9223372036854775807,"9223372036854.8M"]]:
		check(Numbers.compact_integer(sample[0]) == sample[1], "compact integer: " + str(sample))
		if sample[0] != 0:
			check(Numbers.compact_integer(-sample[0]) == "-" + sample[1], "negative compact integer: " + str(sample))
	for sample in [[0,"0"],[12,"12"],[999,"999"],[1000,"1,000"],[9400,"9,400"],[11092,"11,092"],[1000000,"1,000,000"],[9223372036854775807,"9,223,372,036,854,775,807"]]:
		check(Numbers.exact_integer(sample[0]) == sample[1], "exact integer: " + str(sample))
		if sample[0] != 0:
			check(Numbers.exact_integer(-sample[0]) == "-" + sample[1], "negative exact integer: " + str(sample))
	var minimum: int = -9223372036854775807 - 1
	check(Numbers.exact_integer(minimum) == "-9,223,372,036,854,775,808", "exact minimum signed integer")
	check(Numbers.compact_integer(minimum) == "-9223372036854.8M", "compact minimum signed integer")
	# Existing combat and price callers retain their separate policy.
	for sample in [[0,0,"0"],[0,1,"0.0"],[999,0,"999"],[999,1,"999.0"],[1000,1,"1K"],[1250,1,"1.25K"],[1000000,1,"1M"],[999990,1,"999.99K"],[999999,1,"1M"],[-1250,1,"-1.25K"],[-999999,1,"-1M"]]:
		check(Numbers.compact(sample[0],sample[1]) == sample[2], "legacy compact: " + str(sample))
	for sample in [[999,"999"],[1000,"1K"],[1250,"1.25K"],[12500,"12.5K"],[123456789,"123M"],[999499,"999K"],[999500,"1M"],[1000000,"1M"],[-999500,"-1M"]]:
		check(Numbers.compact_price(sample[0]) == sample[1], "legacy price: " + str(sample))
	for width in [320,440]:
		root.size = Vector2i(width,900)
		root.content_scale_size = Vector2i(width,900)
		var host := Host.new()
		host.size = Vector2(width,900)
		host.theme = preload("res://ui/app_theme.gd").create()
		check(host.app.catalog.load_catalog(), "catalog loads")
		host.p.clearedStageNumbers = Progression.ordered_ids().slice(0,25)
		root.add_child(host)
		host.body = VBoxContainer.new()
		host.body.size = Vector2(width - 48,660)
		host.add_child(host.body)
		var ui := Stages.new()
		ui.setup(host)
		ui.chapter = 3
		var before: Dictionary = host.p.duplicate(true)
		ui.render()
		await settle()
		var scroll: ScrollContainer = ui.canvas.get_node("StageRowsScroll")
		var rows := scroll.get_node("StageRows").get_children().filter(func(node): return node is Button)
		for stage in range(26,31):
			var expected: int = [9400,11092,13089,15445,18225][stage-26]
			var compact: String = ["9,400","11.1K","13.1K","15.4K","18.2K"][stage-26]
			check(ui.rune_reward(stage) == expected, "reward preview unchanged: " + str(stage))
			check(labels(ui.canvas).any(func(label): return label.text == "룬 +" + compact), "list compact label: " + compact)
			var settlement: Dictionary = Quests.new().finish(host.p,{"stageNumber":stage,"completedRounds":40,"success":true})
			check(settlement.lastRunRuneReward == expected and int(settlement.runes) - int(before.runes) == expected, "exact settlement: " + str(stage))
			rows[stage-21].pressed.emit()
			await settle()
			check(labels(host.modal).any(func(label): return label.text == "+" + compact), "row opens compact detail: " + str(stage))
			var stats: HBoxContainer = host.modal.find_child("StageQuickStats",true,false)
			var reward_label: Label = stats.get_child(stats.get_child_count()-1).get_child(2)
			check(reward_label.text == "+" + compact, "detail reward uses summary policy: " + str(stage))
			var detail_measured: float = reward_label.get_theme_font("font").get_string_size(reward_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,reward_label.get_theme_font_size("font_size")).x
			check(detail_measured <= reward_label.size.x + 1, "detail reward label fits: " + reward_label.text)
			check(host.modal.get_combined_minimum_size().x <= width - 52, "detail fits: %d at %d" % [stage,width])
			check(host.modal.get_child(host.modal.get_child_count()-1).disabled == (stage > 26), "locked detail stays readable: " + str(stage))
			host.modal.find_child("CloseStageDetails",true,false).pressed.emit()
			check(not is_instance_valid(host.modal), "detail closes")
		for label in labels(ui.canvas):
			if label.text.begins_with("룬 +"):
				var measured: float = label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
				check(measured <= label.size.x + 1, "reward label fits: " + label.text)
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await settle()
		check(rows[-1].get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, "last stage reachable")
		check(scroll.scroll_horizontal == 0, "no horizontal scroll")
		check(host.p == before, "display and detail preserve progression")
		host.app.run_domain.state = {"stage":29,"roundIndex":39,"gold":1200,"turrets":[],"phase":"wave"}
		host.p.clearedStageNumbers = Progression.ordered_ids().slice(0,29)
		for child in host.body.get_children(): host.body.remove_child(child); child.queue_free()
		ui.render()
		await settle()
		check(labels(ui.canvas).any(func(label): return label.text == "룬 +18.2K"), "active reward compact")
		check(labels(ui.canvas).any(func(label): return label.text == "1.2K"), "active gold policy unchanged")
		ui.details(30)
		await settle()
		check(labels(host.modal).any(func(label): return label.text == "+18.2K"), "active detail uses compact reward")
		ui.start(30)
		check(host.app.resumed == 1, "continue callback unchanged")
		host.free()
		await settle()
	print("LOBBY_NUMBERS checks=%d failures=%d %s" % [checks,failures.size(),JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
