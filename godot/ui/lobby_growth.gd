extends RefCounted
const Progression = preload("res://content/stage_progression.gd")
## Flutter main_menu_permanent_upgrades / main_menu_research native counterpart.
const Frame = preload("res://ui/lobby_frame.gd")
const ProgressVisual = preload("res://ui/research_progress.gd")
const T = preload("res://ui/app_theme.gd")
const TITLES := {"startingGold": "시작 골드", "nexusHp": "넥서스 체력", "supply": "정비 보급", "fireTraining": "기초 화력 훈련", "physicalDamageTraining": "물리 화력 훈련", "elementalDamageTraining": "원소 화력 훈련", "criticalDamage": "치명 충격", "killGold": "처치 보상", "bossBounty": "토벌 보상", "linkCostOptimization": "연결 공정", "turretLevelUpOptimization": "강화 공정", "researchEfficiency": "연구 효율", "researchCostEfficiency": "연구 비용 효율", "turretTargetPriority": "전술 명령", "linkExpansionOne": "링크 확장 I", "gemAttunement": "젬 감응", "criticalChance": "치명 집중", "emergencySale": "긴급 매각", "linkMaintenance": "기초 연결 공학", "crystalRecovery": "결정 회수", "runeResonance": "룬 공명", "runUpgradeCostOptimization": "전투 투자 최적화", "towerDamageLimitExpansion": "포탑 화력 확장", "killGoldLimitExpansion": "처치 보너스 확장", "waveGoldLimitExpansion": "정비 보급 확장"}
const DESCRIPTIONS := {"startingGold": "새 런을 시작할 때 보유하는 골드가 영구적으로 증가합니다.", "nexusHp": "모든 런의 넥서스 최대 체력이 영구적으로 증가합니다.", "supply": "웨이브를 클리어할 때마다 추가 골드를 받습니다.", "fireTraining": "모든 런에서 모든 포탑의 피해량이 증가합니다.", "physicalDamageTraining": "물리 포탑의 피해량이 증가합니다.", "elementalDamageTraining": "원소 포탑의 피해량이 증가합니다.", "criticalDamage": "모든 포탑의 치명타 추가 피해율이 증가합니다.", "killGold": "적을 처치할 때 획득하는 골드가 증가합니다.", "bossBounty": "레벨마다 보스 처치 골드가 2.5% 증가합니다.", "linkCostOptimization": "모든 포탑의 링크 확장 비용을 영구적으로 감폭합니다.", "turretLevelUpOptimization": "모든 포탑의 레벨업 비용을 영구적으로 감폭합니다."}
## Korean researchDescription from lib/l10n/rune_nexus_localizations.dart.
const RESEARCH_DESCRIPTIONS := {"linkExpansionOne": "포탑의 추가 링크 홈을 열 수 있게 합니다.", "gemAttunement": "스테이지 시작 젬 파편을 +2 늘립니다.", "researchEfficiency": "레벨마다 연구 효율이 5% 증가합니다. 효율 100%는 이후 연구를 2배 빠르게 만듭니다.", "researchCostEfficiency": "레벨마다 연구 비용 효율이 5% 증가합니다. 효율 100%는 이후 연구 룬 비용을 절반으로 줄입니다.", "turretTargetPriority": "포탑별로 우선 공격 대상을 지정할 수 있도록 합니다.", "criticalChance": "레벨마다 모든 포탑의 치명타 확률이 2%p 증가합니다.", "emergencySale": "레벨마다 포탑 환불 비율이 1%p 증가합니다.", "crystalRecovery": "레벨마다 보스 처치 시 획득하는 젬 파편이 1 증가합니다.", "runeResonance": "레벨당 2%씩 합산한 비율로 런 종료 후 획득하는 룬을 증폭합니다.", "runUpgradeCostOptimization": "레벨마다 모든 런 업그레이드 비용이 2% 감소합니다.", "towerDamageLimitExpansion": "레벨마다 포탑 화력의 최대 레벨이 1 증가합니다.", "killGoldLimitExpansion": "레벨마다 처치 보너스의 최대 레벨이 1 증가합니다.", "waveGoldLimitExpansion": "레벨마다 정비 보급의 최대 레벨이 1 증가합니다."}
var lobby
var category := "전투"
var selected_research := ""
var strong_font: Font
const COMBAT := ["nexusHp", "fireTraining", "physicalDamageTraining", "elementalDamageTraining", "criticalDamage"]
const ECONOMY := ["startingGold", "supply", "killGold", "bossBounty", "linkCostOptimization", "turretLevelUpOptimization"]
const ICONS := {"nexusHp":"upgrades/nexus_hp.png", "fireTraining":"upgrades/tower_damage.png", "physicalDamageTraining":"upgrades/physical_damage.png", "elementalDamageTraining":"upgrades/elemental_damage.png", "criticalDamage":"upgrades/critical_damage.png", "startingGold":"upgrades/starting_gold.png", "supply":"upgrades/wave_gold.png", "killGold":"upgrades/kill_gold.png", "bossBounty":"research/boss_bounty.png", "linkCostOptimization":"upgrades/link_cost_optimization.png", "turretLevelUpOptimization":"upgrades/turret_level_up_optimization.png", "criticalChance":"upgrades/critical_chance.png", "emergencySale":"upgrades/turret_refund.png"}
const EFFECTS := {
"startingGold":["초기 골드", "startingGoldPerUpgradeLevel", "G"], "nexusHp":["코어 체력", "", ""], "supply":["라운드 보급", "supplyGoldPerUpgradeLevel", "G"],
"fireTraining":["모든 포탑 피해", "fireTrainingDamagePerUpgradeLevel", "%"], "physicalDamageTraining":["물리 포탑 피해", "familyDamageTrainingBonusPerUpgradeLevel", "%"], "elementalDamageTraining":["원소 포탑 피해", "familyDamageTrainingBonusPerUpgradeLevel", "%"], "criticalDamage":["치명타 피해", "criticalDamageBonusPerUpgradeLevel", "%p"], "killGold":["처치 골드", "killGoldBonusPerUpgradeLevel", "%"], "bossBounty":["보스 처치 골드", "bossBountyBonusPerUpgradeLevel", "%"], "linkCostOptimization":["링크 비용", "permanentCostReductionPerUpgradeLevel", "-%"], "turretLevelUpOptimization":["포탑 강화 비용", "permanentCostReductionPerUpgradeLevel", "-%"],
"researchEfficiency":["연구 속도", "researchEfficiencyPerLevel", "%"], "researchCostEfficiency":["연구 비용 효율", "researchCostEfficiencyPerLevel", "%"], "gemAttunement":["시작 젬 조각", "gemShardsPerGemAttunementLevel", ""], "criticalChance":["치명타 확률", "criticalChanceBonusPerResearchLevel", "%p"], "emergencySale":["포탑 판매 환급률", "emergencySaleRefundPercentPerLevel", "%base"], "linkMaintenance":["첫 링크 강화 비용", "linkMaintenanceDiscountPerLevel", "-%"], "crystalRecovery":["보스 처치 젬 조각", "bossGemShardsPerCrystalRecoveryLevel", ""], "runeResonance":["룬 획득량", "runeResonanceBonusPerLevel", "%"], "runUpgradeCostOptimization":["전투 강화 비용", "runUpgradeCostDiscountPerLevel", "-%"], "towerDamageLimitExpansion":["화력 강화 최대 레벨", "runUpgradeLimitExpansionMaxLevelPerLevel", ""], "killGoldLimitExpansion":["처치 보상 최대 레벨", "runUpgradeLimitExpansionMaxLevelPerLevel", ""], "waveGoldLimitExpansion":["보급 최대 레벨", "runUpgradeLimitExpansionMaxLevelPerLevel", ""]}

func setup(owner) -> void:
	lobby = owner

func _growth():
	return lobby.app.run_domain.growth

func _style(path: String, margin := 9) -> StyleBox:
	var frame := Frame.new(path,margin)
	# Upgrade-only frames use symmetric end caps; shared menu art is unchanged.
	if path == "ui/components/upgrade_levelup_frame_v2.png":
		frame.source_center = Rect2(12, 5, 127, 24)
	elif path == "ui/components/upgrade_rune_cost_frame_v2.png":
		frame.source_center = Rect2(10, 6, 60, 15)
	return frame

func _surface(parent: Node, path := "ui/components/card_frame.png", margin := 8) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(path, margin))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	return box

func _image(path: String, pixels: int) -> TextureRect:
	var image := TextureRect.new()
	image.texture = T.texture(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(pixels, pixels)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _icon(id: String, pixels := 36) -> Control:
	var socket := _image("ui/components/icon_socket.png", pixels)
	var path: String = ICONS.get(id, "research/" + id.to_snake_case() + ".png")
	var icon := _image(path, 0)
	socket.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 5
	icon.offset_top = 5
	icon.offset_right = -5
	icon.offset_bottom = -5
	return socket

func _heading(box: Node, id: String, level: int, maximum: int, cost := -1, upgrade := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	row.add_child(_icon(id, 44 if upgrade else 36))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 3)
	row.add_child(words)
	var title := T.label(str(TITLES.get(id, id)), 12)
	_strong(title)
	title.add_theme_color_override("font_color", Color("b9d6e4"))
	words.add_child(title)
	var line := HFlowContainer.new()
	line.add_theme_constant_override("h_separation", 5)
	words.add_child(line)
	line.add_child(_inline("Lv.%d/%d" % [level, maximum], 11))
	if cost >= 0: _currency(line, cost, 11)

func _strong(label: Label) -> Label:
	if strong_font == null and ResourceLoader.exists("res://assets/ui/NotoSansKR-VF.ttf"):
		var font := FontVariation.new()
		font.base_font = load("res://assets/ui/NotoSansKR-VF.ttf")
		font.variation_opentype = {2003265652:850.0}
		strong_font = font
	if strong_font != null: label.add_theme_font_override("font", strong_font)
	return label

func _inline(value: String, pixels: int) -> Label:
	var label := T.label(value, pixels)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return _strong(label)

func _currency(parent: Node, cost: int, pixels := 11) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	row.add_child(_image("ui/hud/icons/rune.png", 12))
	var value := _inline(str(cost), pixels)
	value.add_theme_color_override("font_color", Color("b9d6e4"))
	row.add_child(value)

func _glyph(code: int, pixels: int, color: Color) -> Label:
	var label := Label.new()
	label.text = String.chr(code)
	if ResourceLoader.exists("res://assets/ui/MaterialIcons-Regular.otf"):
		label.add_theme_font_override("font", load("res://assets/ui/MaterialIcons-Regular.otf"))
	else: label.text = ""
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _section(parent: Node, title: String, code: int, color: Color) -> VBoxContainer:
	var box := _surface(parent, "ui/components/panel_frame.png", 9)
	box.add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	box.add_child(row)
	row.add_child(_glyph(code, 17, color))
	row.add_child(_inline(title, 13))
	var line := ColorRect.new()
	line.color = Color(color, 0.35)
	line.custom_minimum_size.y = 1
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return box

func _grid(parent: Node) -> GridContainer:
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 2 if lobby.size.x >= 308 else 1
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid

func _button(box: Node, text: String, callback: Callable, disabled := false) -> Button:
	var b := T.button(text, callback)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size.y = 34
	b.disabled = disabled
	box.add_child(b)
	return b

func upgrade_requirement(id: String) -> int:
	return Progression.requirement("upgrade", id)

func upgrades_tabs(parent: Node) -> void:
	var center := CenterContainer.new()
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style("ui/components/segmented_control_frame.png", 5))
	center.add_child(panel)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	panel.add_child(tabs)
	for tab in ["전투", "경제"]:
		var b := _button(tabs, "", func(): category = tab; lobby.refresh())
		b.tooltip_text = tab
		b.custom_minimum_size = Vector2(64, 33)
		var selected_path := "ui/components/segment_selected_cyan.png" if tab == "전투" else "ui/components/segment_selected_gold.png"
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var style: StyleBox = StyleBoxEmpty.new()
			if state != "focus" and (tab == category or state in ["hover", "pressed", "hover_pressed"]):
				style = _style(selected_path, 0)
				if style is StyleBoxTexture:
					if state == "hover": style.modulate_color = Color(1.12,1.12,1.12)
					elif state in ["pressed", "hover_pressed"]: style.modulate_color = Color(0.82,0.9,0.94)
					elif state == "disabled": style.modulate_color = Color("71817f")
			if state == "focus":
				var focus := StyleBoxFlat.new()
				focus.bg_color = Color.TRANSPARENT
				focus.border_color = Color("b5f2ff")
				focus.set_border_width_all(1)
				style = focus
			b.add_theme_stylebox_override(state, style)
		var icon := _image("ui/icons/growth_combat_swords.png" if tab == "전투" else "ui/icons/growth_economy_scales.png", 28)
		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon_center)
		icon_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_center.add_child(icon)

func upgrades() -> void:
	var grid := _grid(lobby.body)
	for id in COMBAT if category == "전투" else ECONOMY:
		if not Progression.has_unlock(lobby._p(), "upgrade", id): continue
		var d: Dictionary = _growth().data.permanentUpgrades[id]
		if not d.get("enabled", true): continue
		var level := int(lobby._p().get(d.field, 0))
		var maximum := int(d.maxLevel)
		var cost := int(d.costs[mini(level, maximum)])
		var enabled := level < maximum and int(lobby._p().get("runes", 0)) >= cost
		var box := _surface(grid, "ui/components/card_frame.png", 12)
		box.custom_minimum_size.y = 158
		_heading(box, id, level, maximum, -1, true)
		var description := T.label(str(DESCRIPTIONS[id]), 10)
		description.add_theme_color_override("font_color", Color("9eb3bf"))
		box.add_child(description)
		_effect(box, id, level, maximum, enabled)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		var b := _button(box, "최대 레벨" if level >= maximum else "", lobby._change.bind({"kind":"upgradePermanent", "id":id}), not enabled)
		for state in ["normal", "disabled", "hover", "pressed"]: b.add_theme_stylebox_override(state, _style("ui/components/upgrade_levelup_frame_v2.png", 7))
		if level < maximum:
			b.tooltip_text = "레벨업 · 룬 %d" % cost
			var margin := MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 7)
			margin.add_theme_constant_override("margin_right", 7)
			margin.add_theme_constant_override("margin_top", 3)
			margin.add_theme_constant_override("margin_bottom", 3)
			margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(margin)
			margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var content := Control.new()
			content.mouse_filter = Control.MOUSE_FILTER_IGNORE
			margin.add_child(content)
			var label := _strong(T.label("레벨업", 10))
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_color", Color("e8fbff") if enabled else Color("6d7f8f"))
			content.add_child(label)
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var chip := PanelContainer.new()
			var chip_style := _style("ui/components/upgrade_rune_cost_frame_v2.png", 9)
			chip_style.content_margin_top = 7
			chip_style.content_margin_bottom = 7
			chip.add_theme_stylebox_override("panel", chip_style)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(chip)
			_currency(chip, cost)
			var align_cost := func():
				chip.size = chip.get_combined_minimum_size()
				# Anchored children do not contribute to the Button's minimum size.
				b.custom_minimum_size = Vector2(chip.size.x + label.get_minimum_size().x + 16, maxf(34, chip.size.y + 6))
				chip.position = Vector2(content.size.x - chip.size.x, (content.size.y - chip.size.y) * 0.5)
				# Keep the caption centered; reserve the same cost width on both sides.
				var side := chip.size.x + 2
				if content.size.x >= side * 2 + label.get_minimum_size().x:
					label.offset_left = side
					label.offset_right = -side
				else:
					label.offset_left = 0
					label.offset_right = -side
			content.resized.connect(align_cost)
			chip.minimum_size_changed.connect(align_cost)
			align_cost.call_deferred()

func effect_value(id: String, level: int) -> String:
	if id == "linkExpansionOne": return "링크 홈 4개" if level > 0 else "링크 홈 3개"
	if id == "turretTargetPriority": return "목표 우선순위 설정 가능" if level > 0 else "목표 우선순위 설정 잠김"
	var e: Array = EFFECTS.get(id, ["", "", ""])
	var v := float(_growth().data.constants.get(e[1], 1)) * level
	var unit: String = e[2]
	if unit == "%base": return "%d%%" % (int(_growth().data.constants.baseTurretRefundPercent) + int(v))
	if "%" in unit:
		var number := "%.1f" % (v * 100)
		if not id in ["fireTraining", "physicalDamageTraining", "elementalDamageTraining", "bossBounty"]: number = number.trim_suffix(".0")
		return ("−" if unit == "-%" else "+") + number + unit.trim_prefix("-")
	return "+%d%s" % [int(v), unit]

func _effect(box: Node, id: String, level: int, maximum: int, enabled := true) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 2)
	box.add_child(flow)
	flow.add_child(_inline("현재 " + effect_value(id, level), 10))
	if level < maximum:
		var next := _inline("다음 " + effect_value(id, mini(level + 1, maximum)), 10)
		next.add_theme_color_override("font_color", Color("e7c66a") if enabled else Color("6d7f8f"))
		flow.add_child(next)

func _research_effect(id: String, level: int, maximum: int) -> String:
	if id == "linkExpansionOne": return "최대 링크 증가"
	if id == "turretTargetPriority": return "포탑 공격 명령 해금"
	var names := {"researchEfficiency":"연구 효율", "researchCostEfficiency":"비용 효율", "linkMaintenance":"첫 링크 비용", "gemAttunement":"젬 파편", "criticalChance":"치명타 확률", "emergencySale":"포탑 환불", "crystalRecovery":"보스 처치 시 젬 파편", "runeResonance":"룬 보상", "runUpgradeCostOptimization":"런 업그레이드 비용"}
	var text: String = str(names.get(id, EFFECTS[id][0])) + " " + effect_value(id, level)
	if level < maximum: text += " → " + effect_value(id, level + 1)
	return text

func _duration(ms: int) -> String:
	var minutes := ceili(float(ms) / 60000)
	return "%d시간" % (minutes / 60) if minutes % 60 == 0 else "%d분" % minutes

func _active(id: String) -> Dictionary:
	for item in lobby._p().get("activeResearches", []):
		if item.type == id: return item
	return {}

func _remaining(active: Dictionary) -> int:
	return maxi(0, int(active.get("startedAtMillis", 0)) + int(active.get("durationMillis", 0)) - int(Time.get_unix_time_from_system() * 1000))

func _time(ms: int) -> String:
	var seconds := ceili(float(ms) / 1000)
	return "%d시간 %02d분" % [seconds / 3600, seconds % 3600 / 60] if seconds >= 3600 else "%d분 %02d초" % [seconds / 60, seconds % 60]

func research_status(id: String) -> String:
	var d: Dictionary = _growth().data.research[id]
	var q: Dictionary = _growth().research_quote(lobby._p(), id)
	if not _active(id).is_empty(): return "연구 중"
	if int(q.level) >= int(d.maxLevel): return "연구 완료"
	if not Progression.has_unlock(lobby._p(), "research", id): return "스테이지 %s 클리어 필요" % Progression.stage_label(Progression.requirement("research", id))
	if lobby._p().get("activeResearches", []).size() >= (2 if lobby._p().get("researchSlotTwoUnlocked", false) else 1): return "빈 연구 슬롯 필요"
	if int(lobby._p().get("runes", 0)) < int(q.cost): return "룬 부족"
	return "연구 가능"

func _slot_button(parent: Node, text: String, callback: Callable, primary := false) -> Button:
	var action := T.button(text, callback, "primary" if primary else "secondary", true)
	var skin = preload("res://ui/button_skin.gd")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxTexture
		if primary:
			style = skin.surface("primary",Vector2(9,5))
		else:
			style = StyleBoxTexture.new()
			style.texture = T.texture("ui/components/research_slot_a_stop.png")
			style.set_texture_margin_all(10)
			style.set_content_margin_all(5)
		if state == "hover": style.modulate_color = Color(1.12,1.12,1.12)
		elif state == "pressed": style.modulate_color = Color(0.8,0.9,0.94)
		elif state == "disabled": style.modulate_color = Color("607887")
		action.add_theme_stylebox_override(state,style)
	action.add_theme_color_override("font_color",Color("e8f8ff") if primary else Color("eba971"))
	action.add_theme_font_size_override("font_size",11)
	action.custom_minimum_size = Vector2(54,26)
	action.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(action)
	return action

func _research_slot(parent: Node, item: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name = "ResearchSlot_" + str(item.type)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var frame := Frame.new("ui/components/research_slot_a_frame.png",10)
	frame.source_scale = 6
	frame.source_center = Rect2(16,10,318.8,58.3)
	card.add_theme_stylebox_override("panel",frame)
	parent.add_child(card)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	card.add_child(row)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation",8)
	row.add_child(identity)
	var icon := _icon(str(item.type),48)
	icon.name = "ResearchSlotIcon"
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	identity.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",3)
	identity.add_child(info)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",5)
	info.add_child(heading)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",1)
	heading.add_child(words)
	var title := _strong(T.label(str(TITLES.get(item.type,item.type)),12))
	title.name = "ResearchSlotTitle"
	title.add_theme_color_override("font_color",Color("e8f8ff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(title)
	var level := _inline("Lv.%d/%d" % [int(item.targetLevel)-1,int(_growth().data.research[item.type].maxLevel)],11)
	level.name = "ResearchSlotLevel"
	words.add_child(level)
	var stop := _slot_button(heading,"중단",_cancel_confirm.bind(str(item.type)))
	stop.name = "ResearchSlotStop"
	stop.tooltip_text = "연구 중단"
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation",5)
	info.add_child(progress_row)
	var fill := ProgressVisual.new()
	fill.name = "ResearchSlotProgress"
	fill.slot_bar = true
	fill.custom_minimum_size = Vector2(0,9)
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_row.add_child(fill)
	var percent := _inline("",10)
	percent.name = "ResearchSlotPercent"
	percent.custom_minimum_size.x = 29
	percent.add_theme_color_override("font_color",Color("82afc7"))
	progress_row.add_child(percent)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",5)
	row.add_child(actions)
	var time_row := HBoxContainer.new()
	time_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_row.add_theme_constant_override("separation",3)
	actions.add_child(time_row)
	time_row.add_child(_glyph(0xe556,13,Color("92bed8")))
	var clock := _inline("",10)
	clock.name = "ResearchSlotClock"
	time_row.add_child(clock)
	var instant := _slot_button(actions,"",_instant_confirm.bind(str(item.type)),true)
	instant.name = "ResearchSlotInstant"
	instant.custom_minimum_size = Vector2(112,28)
	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",5)
	instant.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left=9; content.offset_right=-9; content.offset_top=4; content.offset_bottom=-4
	var caption := _inline("즉시 완료",11)
	caption.add_theme_color_override("font_color",Color("e8f8ff"))
	content.add_child(caption)
	var divider := ColorRect.new()
	divider.color=Color("35bbd4")
	divider.custom_minimum_size.x=1
	divider.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content.add_child(divider)
	var diamond := _inline("◇",15)
	diamond.add_theme_color_override("font_color",Color("31d9ed"))
	content.add_child(diamond)
	var cost_label := _inline("",11)
	cost_label.name = "ResearchSlotCost"
	cost_label.add_theme_color_override("font_color",Color("e8f8ff"))
	content.add_child(cost_label)
	var update := func(animate := true):
		var current := _active(str(item.type))
		var remain := _remaining(current) if not current.is_empty() else 0
		clock.text = "연구 완료" if remain==0 else _time(remain)+" 남음"
		var cost := ceili(float(remain)/60000)
		cost_label.text = str(cost)
		instant.tooltip_text = "즉시 완료 · 다이아 %d" % cost
		instant.disabled = lobby.diamonds()<cost or current.is_empty()
		content.modulate = Color("718a97") if instant.disabled else Color.WHITE
		instant.custom_minimum_size.x = maxf(112,content.get_combined_minimum_size().x+18)
		# A resumed research stores its remaining duration and prior elapsed separately.
		var total := int(current.get("durationMillis",0)) + int(current.get("initialElapsedMillis",0))
		var progress := clampf(1.0-float(remain)/maxf(1,float(total)),0,1)
		percent.text = "%d%%" % int(progress*100)
		fill.set_progress(progress,animate)
	update.call(false)
	var timer := Timer.new()
	timer.name="ResearchSlotTimer"; timer.wait_time=1
	row.add_child(timer); timer.timeout.connect(update); timer.start()

func research() -> void:
	var slots := _section(lobby.body, "연구 슬롯", 0xf499, Color("b9d6e4"))
	var active: Array = lobby._p().get("activeResearches", [])
	var count := 2 if lobby._p().get("researchSlotTwoUnlocked", false) else 1
	for i in range(count):
		if i < active.size():
			_research_slot(slots,active[i])

		else:
			var empty := _surface(slots, "ui/components/row_frame.png", 9)
			var row := HBoxContainer.new()
			empty.add_child(row)
			row.add_child(_glyph(0xe050, 18, Color("607587")))
			row.add_child(_inline("빈 연구 슬롯", 13))
	var slot_available := Progression.has_unlock(lobby._p(), "feature", "researchSlotTwo")
	if count == 1 and (Progression.has_unlock(lobby._p(), "feature", "researchSlotTwoPreview") or slot_available):
		var cost := int(_growth().data.constants.researchSlotTwoUnlockCost)
		_button(slots, "두 번째 슬롯 · 다이아 %d" % cost if slot_available else "두 번째 슬롯 · 스테이지 2-10 클리어 필요", _slot_confirm, not slot_available)
	var groups := {"가능한 연구":[], "잠긴 연구":[], "완료한 연구":[]}
	var ids: Array = _growth().data.research.keys()
	ids.sort_custom(func(a, b): return Progression.ordinal_for(Progression.requirement("research", a)) < Progression.ordinal_for(Progression.requirement("research", b)))
	for id in ids:
		var status := research_status(id)
		groups["완료한 연구" if status == "연구 완료" else ("잠긴 연구" if status.begins_with("스테이지") else "가능한 연구")].append(id)
	for group in groups:
		var presentation: Array = {"가능한 연구":["시작 가능 연구", 0xf33d, Color("e7c66a")], "잠긴 연구":["아직 해금되지 않음", 0xe3b1, Color("8da5b3")], "완료한 연구":["연구 완료", 0xe1f7, Color("bdefcf")]}[group]
		var section := _section(lobby.body, presentation[0], presentation[1], presentation[2])
		if groups[group].is_empty(): continue
		var grid := _grid(section)
		for id in groups[group]:
			var d: Dictionary = _growth().data.research[id]
			var q: Dictionary = _growth().research_quote(lobby._p(), id)
			var box := _surface(grid)
			box.custom_minimum_size.y = 90
			_heading(box, id, int(q.level), int(d.maxLevel), -1 if int(q.level) >= int(d.maxLevel) else int(q.cost))
			var effect := _strong(T.label(_research_effect(id, int(q.level), int(d.maxLevel)), 10))
			effect.add_theme_color_override("font_color", Color("b9d6e4"))
			box.add_child(effect)
			if int(q.level) < int(d.maxLevel):
				var duration := HBoxContainer.new()
				duration.alignment = BoxContainer.ALIGNMENT_END
				box.add_child(duration)
				duration.add_child(_glyph(0xe556, 10, Color("8da5b3")))
				duration.add_child(_inline(_duration(int(q.remainingMillis)), 9))
			var status := research_status(id)
			if status in ["룬 부족", "연구 완료"]:
				var chip := PanelContainer.new()
				chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var border := StyleBoxFlat.new()
				border.bg_color = Color(0,0,0,0)
				border.border_color = Color("485b6855")
				border.set_border_width_all(1)
				border.set_corner_radius_all(7)
				border.set_content_margin_all(6)
				chip.add_theme_stylebox_override("panel", border)
				chip.add_child(_inline(status, 10))
				box.add_child(chip)
			var panel: Control = box.get_parent()
			if not _active(id).is_empty():
				var active_visual := ProgressVisual.new()
				active_visual.catalog = true
				panel.add_child(active_visual)
				panel.move_child(active_visual,0)
			if group == "잠긴 연구": panel.self_modulate.a = 0.58
			if group != "잠긴 연구" and _active(id).is_empty():
				# BaseButton cancels its release action when the parent starts scrolling.
				var select := Button.new()
				select.name = "ResearchSelect_" + id
				select.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
				select.mouse_filter = Control.MOUSE_FILTER_PASS
				select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				for state in ["normal", "hover", "pressed", "focus"]:
					select.add_theme_stylebox_override(state, StyleBoxEmpty.new())
				panel.add_child(select)
				select.pressed.connect(_details.bind(id))
	# Card/section panels must forward touch gestures to the page ScrollContainer.
	for control in lobby.body.find_children("*", "Control", true, false):
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			control.mouse_filter = Control.MOUSE_FILTER_PASS

func _submit(kind: String, id: String) -> void:
	lobby.close_modal()
	lobby._change({"kind":kind, "id":id, "nowMillis":int(Time.get_unix_time_from_system() * 1000)})

func _details(id: String) -> void:
	selected_research = id
	var box: VBoxContainer = lobby.open_modal(str(TITLES.get(id, id)))
	lobby.modal.set_meta("refresh", _refresh_details.bind(id, weakref(lobby.modal)))
	lobby.modal.set_meta("max_width",380)
	_build_details(box, id)

func _refresh_details(id: String, modal_ref: WeakRef) -> void:
	var current: Control = modal_ref.get_ref()
	if current == null: return
	var box: VBoxContainer = lobby.refresh_modal_body(current)
	if box != null: _build_details(box, id)

func _research_detail_heading(box: VBoxContainer, id: String, level: int, maximum: int) -> void:
	var header: HBoxContainer
	if lobby.has_method("set_modal_header"):
		header = lobby.modal_frame.find_child("ResearchDetailHeader",true,false) as HBoxContainer
		if header != null:
			(header.find_child("ResearchDetailLevel",true,false) as Label).text = "Lv.%d / %d" % [level,maximum]
			return
	header = HBoxContainer.new(); header.name = "ResearchDetailHeader"; header.add_theme_constant_override("separation",10)
	header.add_child(_icon(id,44))
	var words = VBoxContainer.new(); words.size_flags_horizontal = Control.SIZE_EXPAND_FILL; words.add_theme_constant_override("separation",2); header.add_child(words)
	words.add_child(T.label(str(TITLES.get(id,id)),20))
	var level_text = T.label("Lv.%d / %d" % [level,maximum],14); level_text.name = "ResearchDetailLevel"; words.add_child(level_text)
	if lobby.has_method("set_modal_header"):
		var close: Button = lobby.modal_frame.find_child("CloseModal",true,false)
		if close != null:
			close.get_parent().remove_child(close); header.add_child(close); close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		lobby.set_modal_header(header)
	else: box.add_child(header)

func _research_detail_effect(box: VBoxContainer, id: String, level: int, maximum: int) -> void:
	# Unlock descriptions need wrapping; numeric effects fit the compact comparison.
	var comparison: BoxContainer = VBoxContainer.new() if id in ["linkExpansionOne","turretTargetPriority"] else HBoxContainer.new()
	comparison.name = "ResearchDetailEffect"; comparison.alignment = BoxContainer.ALIGNMENT_CENTER; comparison.add_theme_constant_override("separation",10); box.add_child(comparison)
	var current = T.label("현재 " + effect_value(id,level),16); current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; comparison.add_child(current)
	if comparison is HBoxContainer: current.autowrap_mode = TextServer.AUTOWRAP_OFF
	if level < maximum:
		if comparison is HBoxContainer:
			comparison.add_child(_inline("→",16))
		var next = T.label(("다음 " if comparison is HBoxContainer else "→ 다음 ") + effect_value(id,mini(level+1,maximum)),16)
		next.name = "ResearchDetailNext"; next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next.add_theme_color_override("font_color",Color("e7c66a")); comparison.add_child(next)
		if comparison is HBoxContainer: next.autowrap_mode = TextServer.AUTOWRAP_OFF

func _research_detail_quote(box: VBoxContainer, quote: Dictionary) -> void:
	var row = HBoxContainer.new(); row.name = "ResearchDetailQuote"; row.add_theme_constant_override("separation",12); box.add_child(row)
	var cost = HBoxContainer.new(); cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cost.add_theme_constant_override("separation",8); row.add_child(cost)
	cost.add_child(_image("ui/hud/icons/rune.png",28))
	var wallet = VBoxContainer.new(); wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL; wallet.add_theme_constant_override("separation",2); cost.add_child(wallet)
	wallet.add_child(T.label("필요 룬 %d" % int(quote.cost),14))
	wallet.add_child(T.label("보유 %s" % str(int(lobby._p().get("runes",0))),12))
	var separator = VSeparator.new(); row.add_child(separator)
	var time = HBoxContainer.new(); time.size_flags_horizontal = Control.SIZE_EXPAND_FILL; time.add_theme_constant_override("separation",8); row.add_child(time)
	time.add_child(_glyph(0xe556,26,Color("a1d8eb")))
	var duration = VBoxContainer.new(); duration.size_flags_horizontal = Control.SIZE_EXPAND_FILL; duration.add_theme_constant_override("separation",2); time.add_child(duration)
	duration.add_child(T.label("연구 시간",12))
	var remaining := int(quote.remainingMillis)
	duration.add_child(T.label(_duration(remaining) if remaining % 60000 == 0 else _time(remaining),14))

func _build_details(box: VBoxContainer, id: String) -> void:
	var d: Dictionary = _growth().data.research[id]
	var q: Dictionary = _growth().research_quote(lobby._p(), id)
	_research_detail_heading(box,id,int(q.level),int(d.maxLevel))
	var description := str(RESEARCH_DESCRIPTIONS.get(id,""))
	if not description.is_empty(): box.add_child(T.label(description,13))
	_research_detail_effect(box,id,int(q.level),int(d.maxLevel))
	var rule = HSeparator.new(); rule.custom_minimum_size.y = 6
	var style = StyleBoxLine.new(); style.color = Color("7493a488"); style.thickness = 1; rule.add_theme_stylebox_override("separator",style); box.add_child(rule)
	var active := _active(id)
	if not active.is_empty():
		if _remaining(active) == 0:
			_button(box, "완료 받기", _submit.bind("completeFinishedResearches", id))
		else:
			var clock := T.label("",14); box.add_child(clock)
			var instant := _button(box,"",_instant_confirm.bind(id))
			var update := func():
				var current := _active(id)
				var remain := _remaining(current) if not current.is_empty() else 0
				var cost := ceili(float(remain)/60000)
				clock.text = _time(remain)+" 남음" if remain>0 else "연구 완료"
				instant.text = "즉시 완료 · 다이아 %d" % cost
				instant.disabled = current.is_empty() or lobby.diamonds()<cost
			update.call()
			var timer := Timer.new(); timer.wait_time=1; box.add_child(timer); timer.timeout.connect(update); timer.start()
			_button(box, "연구 중단", _cancel_confirm.bind(id, true))
	else:
		var status := research_status(id)
		if int(q.level) < int(d.maxLevel):
			_research_detail_quote(box,q)
			if int(lobby._p().get("researchElapsedMillis", {}).get(id, 0)) > 0: box.add_child(T.label("이전에 진행한 연구 시간이 보존되어 있습니다.", 12))
		var action = T.button("연구 시작" if status == "연구 가능" else status,_submit.bind("startResearch",id),"primary")
		action.name = "ResearchDetailAction"; action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; action.custom_minimum_size.y = 44; action.add_theme_font_size_override("font_size",16); action.disabled = status != "연구 가능"; box.add_child(action)

func _cancel_confirm(id: String, from_details := false) -> void:
	var active := _active(id)
	if active.is_empty() or _remaining(active) == 0:
		_details(id)
		return
	var quote: Dictionary = _growth().research_quote(lobby._p(), id)
	var box: VBoxContainer = lobby.open_modal("연구를 중단할까요?")
	lobby.modal.set_meta("max_width",360)
	box.add_theme_constant_override("separation",12)
	var subject := HBoxContainer.new()
	subject.add_theme_constant_override("separation",10)
	box.add_child(subject)
	subject.add_child(_icon(id,42))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",2)
	subject.add_child(words)
	words.add_child(_strong(T.label(str(TITLES.get(id,id)),14)))
	words.add_child(T.label("Lv.%d → %d" % [int(quote.level),int(active.targetLevel)],12))
	var summary := _surface(box,"ui/components/row_frame.png",10)
	var refund := HBoxContainer.new()
	summary.add_child(refund)
	var caption := T.label("반환 룬",12)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refund.add_child(caption)
	refund.add_child(_image("ui/hud/icons/rune.png",16))
	var amount := _inline("+%d" % int(quote.cost),14)
	amount.add_theme_color_override("font_color",Color("e7c66a"))
	refund.add_child(amount)
	summary.add_child(T.label("진행 시간 보존 · 연구 슬롯 1칸 확보",12))
	box.add_child(T.label("다시 시작하면 이어서 진행합니다.",12))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	box.add_child(actions)
	var keep := T.button("계속 연구",func():
		if from_details: _details(id)
		else: lobby.close_modal()
	,"secondary")
	keep.name = "KeepResearch"
	var stop := T.button("연구 중단",_confirm_cancel.bind(id,int(active.targetLevel)),"danger")
	stop.name = "StopResearch"
	for button in [keep,stop]:
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)

func _confirm_cancel(id: String, target_level := -1) -> void:
	var before_runes := int(lobby._p().get("runes",0))
	var before_level := int(lobby._p().get("researchLevels",{}).get(id,0))
	# The lobby's timer can collect this research while its confirmation stays open.
	if target_level > 0 and before_level >= target_level:
		lobby.close_modal(true)
		lobby.message = "%s 연구가 완료되었습니다." % str(TITLES.get(id,id))
		lobby.refresh()
		return
	var success: bool = lobby.app.apply_growth_command({"kind":"cancelResearch","id":id,"nowMillis":int(Time.get_unix_time_from_system()*1000)})
	lobby.close_modal(true)
	if not success:
		lobby.message = "연구를 중단하지 못했습니다. 연구 상태와 저장 상태를 확인하세요."
	elif int(lobby._p().get("researchLevels",{}).get(id,0)) > before_level:
		# A research may finish while its confirmation is open; the domain completes it.
		lobby.message = "%s 연구가 완료되었습니다." % str(TITLES.get(id,id))
	else:
		var refunded := int(lobby._p().get("runes",0))-before_runes
		lobby.message = "연구 중단 · 룬 +%d 반환 · 진행 시간 보존" % refunded
	lobby.refresh()

func _instant_confirm(id: String) -> void:
	var active := _active(id)
	if active.is_empty(): return
	lobby._service("연구 즉시 완료",{"id":id})

func _slot_confirm() -> void:
	lobby._service("연구 슬롯 구매",{})
