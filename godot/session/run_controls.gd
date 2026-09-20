extends PanelContainer
## Compact development controls for the migrated domain, not the final game HUD.
var app
var gem: OptionButton
var slot: SpinBox
var trait_picker: OptionButton
var upgrade: OptionButton
var permanent: OptionButton
var reward: OptionButton
var description: Label
var last_selection := ""
var last_rewards: Array = []

func _ready() -> void:
	position = Vector2(12, 550)
	size.x = 856
	var box := VBoxContainer.new()
	add_child(box)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 820
	box.add_child(description)
	var row := HFlowContainer.new()
	box.add_child(row)
	_button(row, "Level up", func(): app.selected_run_command("level"))
	_button(row, "Sell", func(): app.selected_run_command("sell"))
	_button(row, "Add link", func(): app.selected_run_command("link"))
	gem = _picker(row, app.run_domain.growth.data.gems)
	slot = SpinBox.new()
	slot.min_value = 1
	slot.max_value = 6
	slot.step = 1
	slot.prefix = "Slot "
	row.add_child(slot)
	_button(row, "Equip", func(): app.selected_run_command("equipGem", {"type":_selected(gem),"slot":int(slot.value)-1}))
	_button(row, "Remove", func(): app.selected_run_command("removeGem", {"slot":int(slot.value)-1}))
	var second := HFlowContainer.new()
	box.add_child(second)
	trait_picker = _picker(second, [])
	_button(second, "Trait I", func(): app.selected_run_command("primaryTrait", {"type":_selected(trait_picker)}))
	_button(second, "Trait II", func(): app.selected_run_command("secondaryTrait", {"type":_selected(trait_picker)}))
	upgrade = _picker(second, app.run_domain.growth.data.runUpgrades.keys())
	_button(second, "Run upgrade", func(): app.apply_run_command({"kind":"runUpgrade","type":_selected(upgrade)}))
	var third := HFlowContainer.new()
	box.add_child(third)
	reward = _picker(third, [])
	_button(third, "Choose gem", func(): app.apply_run_command({"kind":"chooseRewardGem","type":_selected(reward)}))
	_button(third, "Choose shards", func(): app.apply_run_command({"kind":"chooseRewardShards"}))
	_button(third, "Buy gem choice", func(): app.apply_run_command({"kind":"purchaseGemChoice"}))
	permanent = _picker(third, app.run_domain.growth.data.permanentUpgrades.keys())
	_button(third, "Growth", func(): app.apply_growth_command({"kind":"permanentUpgrade","type":_selected(permanent)}))

func _button(row: Container, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	row.add_child(button)

func _picker(row: Container, values: Array) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size.x = 100
	for value in values: picker.add_item(str(value))
	row.add_child(picker)
	return picker

func _selected(picker: OptionButton) -> String:
	return picker.get_item_text(picker.selected) if picker.selected >= 0 else ""

func _process(_delta: float) -> void:
	if app.run_domain.state.is_empty(): return
	var state: Dictionary = app.run_domain.state
	var id: int = app.run_domain.selected_id(app.selected)
	var selected_type := ""
	var chosen: Dictionary = {}
	for turret in state.turrets:
		if turret.id == id:
			chosen = turret
			selected_type = turret.type
			break
	if selected_type != last_selection:
		last_selection = selected_type
		trait_picker.clear()
		if not selected_type.is_empty():
			var rules: Dictionary = app.run_domain.growth.data.turretRules[selected_type]
			for value in rules.primaryTraits + rules.secondaryTraits: trait_picker.add_item(str(value))
	var choices: Array = state.get("rewardOptions", [])
	if choices != last_rewards:
		last_rewards = choices.duplicate()
		reward.clear()
		for value in choices: reward.add_item(str(value))
	var message := "Select a build tile or turret. Build %s: %d gold" % [app.turret_type, app.run_domain.service.build_cost(state, app.turret_type)]
	if not chosen.is_empty():
		var quotes: Dictionary = app.run_domain.service.quotes(state, id)
		message = "%s Lv.%d | Level %dG | Link %dG | Sell %dG | Traits %d/%d shards" % [chosen.type, chosen.level, quotes.level, quotes.link, quotes.sell, quotes.primaryTrait, quotes.secondaryTrait]
	var run_quote: Dictionary = app.run_domain.service.run_upgrade_quote(state, _selected(upgrade))
	message += "\nRun upgrade %dG | %s gems: %d | Runes %d" % [int(run_quote.get("cost",0)), _selected(gem), int(state.gemInventory.get(_selected(gem),0)), int(state.progression.get("runes",0))]
	if description.text != message: description.text = message
	var viewport := get_viewport().get_visible_rect().size
	size.x = maxf(400.0, viewport.x - 24.0)
	position.y = maxf(160.0, viewport.y - size.y - 12.0)
