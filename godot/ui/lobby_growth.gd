extends RefCounted
const Progression = preload("res://content/stage_progression.gd")
## Flutter main_menu_permanent_upgrades / main_menu_research native counterpart.
const Frame = preload("res://ui/lobby_frame.gd")
const ProgressVisual = preload("res://ui/research_progress.gd")
const T = preload("res://ui/app_theme.gd")
const TITLES := {"bossDamageTraining": "대형 표적 훈련", "startingGold": "시작 골드", "nexusHp": "넥서스 체력", "supply": "정비 보급", "fireTraining": "기초 화력 훈련", "physicalDamageTraining": "물리 화력 훈련", "elementalDamageTraining": "원소 화력 훈련", "poisonDamageTraining": "독 화력 훈련", "criticalDamage": "치명 충격", "killGold": "처치 보상", "bossBounty": "토벌 보상", "linkCostOptimization": "연결 공정", "turretLevelUpOptimization": "강화 공정", "researchEfficiency": "연구 효율", "researchCostEfficiency": "연구 비용 효율", "turretTargetPriority": "전술 명령", "linkExpansionOne": "링크 확장 I", "linkExpansionTwo": "링크 확장 II", "gemAttunement": "젬 감응", "criticalChance": "치명 집중", "emergencySale": "긴급 매각", "linkMaintenance": "기초 연결 공학", "crystalRecovery": "결정 회수", "runeResonance": "룬 공명", "runUpgradeCostOptimization": "전투 투자 최적화", "towerDamageLimitExpansion": "포탑 화력 확장", "killGoldLimitExpansion": "처치 보너스 확장", "waveGoldLimitExpansion": "정비 보급 확장", "directDamageTraining": "타격 훈련", "splashDamageTraining": "범위 타격 훈련", "damageOverTimeTraining": "지속 피해 훈련"}
const DESCRIPTIONS := {"bossDamageTraining": "포탑이 보스에게 주는 피해가 증가합니다.", "startingGold": "새 런을 시작할 때 보유하는 골드가 영구적으로 증가합니다.", "nexusHp": "모든 런의 넥서스 최대 체력이 영구적으로 증가합니다.", "supply": "웨이브를 클리어할 때마다 추가 골드를 받습니다.", "fireTraining": "모든 런에서 모든 포탑의 피해량이 증가합니다.", "physicalDamageTraining": "물리 포탑의 피해량이 증가합니다.", "elementalDamageTraining": "원소 포탑의 피해량이 증가합니다.", "poisonDamageTraining": "독 포탑의 피해량이 증가합니다.", "criticalDamage": "모든 포탑의 치명타 추가 피해율이 증가합니다.", "killGold": "적을 처치할 때 획득하는 골드가 증가합니다.", "bossBounty": "레벨마다 보스 처치 골드가 2.5% 증가합니다.", "linkCostOptimization": "모든 포탑의 링크 확장 비용을 영구적으로 감폭합니다.", "turretLevelUpOptimization": "모든 포탑의 레벨업 비용을 영구적으로 감폭합니다.", "directDamageTraining": "포탑의 모든 즉시 타격 피해가 증가합니다.", "splashDamageTraining": "포탑의 폭발 주변·냉각 범위 피해가 증가합니다.", "damageOverTimeTraining": "포탑의 지속 피해가 증가합니다."}
## Korean researchDescription from lib/l10n/rune_nexus_localizations.dart.
const RESEARCH_DESCRIPTIONS := {"linkExpansionOne": "포탑의 네 번째 링크 홈을 골드로 열 수 있게 합니다.", "linkExpansionTwo": "링크 확장 I 연구를 마친 뒤, 포탑의 다섯 번째 링크 홈을 골드로 열 수 있게 합니다.", "gemAttunement": "스테이지 시작 젬 파편을 +2 늘립니다.", "researchEfficiency": "레벨마다 연구 효율이 5% 증가합니다. 효율 100%는 이후 연구를 2배 빠르게 만듭니다.", "researchCostEfficiency": "레벨마다 연구 비용 효율이 5% 증가합니다. 효율 100%는 이후 연구 룬 비용을 절반으로 줄입니다.", "turretTargetPriority": "포탑별로 우선 공격 대상을 지정할 수 있도록 합니다.", "criticalChance": "레벨마다 모든 포탑의 치명타 확률이 2%p 증가합니다.", "emergencySale": "레벨마다 포탑 환불 비율이 1%p 증가합니다.", "crystalRecovery": "레벨마다 보스 처치 시 획득하는 젬 파편이 1 증가합니다.", "runeResonance": "레벨당 2%씩 합산한 비율로 런 종료 후 획득하는 룬을 증폭합니다.", "runUpgradeCostOptimization": "레벨마다 모든 런 업그레이드 비용이 2% 감소합니다.", "towerDamageLimitExpansion": "레벨마다 포탑 화력의 최대 레벨이 1 증가합니다.", "killGoldLimitExpansion": "레벨마다 처치 보너스의 최대 레벨이 1 증가합니다.", "waveGoldLimitExpansion": "레벨마다 정비 보급의 최대 레벨이 1 증가합니다."}
var lobby
var category := "전투"
var selected_research := ""
var strong_font: Font
const COMBAT := ["nexusHp", "fireTraining", "physicalDamageTraining", "elementalDamageTraining", "poisonDamageTraining", "criticalDamage", "bossDamageTraining", "directDamageTraining", "splashDamageTraining", "damageOverTimeTraining"]
const ECONOMY := ["startingGold", "supply", "killGold", "bossBounty", "linkCostOptimization", "turretLevelUpOptimization"]
const ICONS := {"bossDamageTraining": "upgrades/boss_damage_training.png", "linkExpansionTwo": "research/link_expansion_one.png", "nexusHp": "upgrades/nexus_hp.png", "fireTraining": "upgrades/tower_damage.png", "physicalDamageTraining": "upgrades/physical_damage.png", "elementalDamageTraining": "upgrades/elemental_damage.png", "poisonDamageTraining": "upgrades/poison_damage.png", "criticalDamage": "upgrades/critical_damage.png", "startingGold": "upgrades/starting_gold.png", "supply": "upgrades/wave_gold.png", "killGold": "upgrades/kill_gold.png", "bossBounty": "research/boss_bounty.png", "linkCostOptimization": "upgrades/link_cost_optimization.png", "turretLevelUpOptimization": "upgrades/turret_level_up_optimization.png", "criticalChance": "upgrades/critical_chance.png", "emergencySale": "upgrades/turret_refund.png", "directDamageTraining": "upgrades/direct_damage_training.png", "splashDamageTraining": "upgrades/splash_damage_training.png", "damageOverTimeTraining": "upgrades/damage_over_time_training.png"}
const EFFECTS := {
"directDamageTraining":["타격 피해", "directDamageTrainingBonusPerUpgradeLevel", "%"],
"splashDamageTraining":["범위 타격 피해", "splashDamageTrainingBonusPerUpgradeLevel", "%"],
"damageOverTimeTraining":["지속 피해", "damageOverTimeTrainingBonusPerUpgradeLevel", "%"],
"bossDamageTraining":["보스 피해", "bossDamageTrainingBonusPerUpgradeLevel", "%"],
"startingGold":["초기 골드", "startingGoldPerUpgradeLevel", "G"], "nexusHp":["코어 체력", "", ""], "supply":["라운드 보급", "supplyGoldPerUpgradeLevel", "G"],
"fireTraining":["모든 포탑 피해", "fireTrainingDamagePerUpgradeLevel", "%"], "physicalDamageTraining":["물리 포탑 피해", "familyDamageTrainingBonusPerUpgradeLevel", "%"], "elementalDamageTraining":["원소 포탑 피해", "familyDamageTrainingBonusPerUpgradeLevel", "%"], "poisonDamageTraining":["독 포탑 피해", "familyDamageTrainingBonusPerUpgradeLevel", "%"], "criticalDamage":["치명타 피해", "criticalDamageBonusPerUpgradeLevel", "%p"], "killGold":["처치 골드", "killGoldBonusPerUpgradeLevel", "%"], "bossBounty":["보스 처치 골드", "bossBountyBonusPerUpgradeLevel", "%"], "linkCostOptimization":["링크 비용", "permanentCostReductionPerUpgradeLevel", "-%"], "turretLevelUpOptimization":["포탑 강화 비용", "permanentCostReductionPerUpgradeLevel", "-%"],
"researchEfficiency":["연구 속도", "researchEfficiencyPerLevel", "%"], "researchCostEfficiency":["연구 비용 효율", "researchCostEfficiencyPerLevel", "%"], "gemAttunement":["시작 젬 파편", "gemShardsPerGemAttunementLevel", ""], "criticalChance":["치명타 확률", "criticalChanceBonusPerResearchLevel", "%p"], "emergencySale":["포탑 판매 환급률", "emergencySaleRefundPercentPerLevel", "%base"], "linkMaintenance":["첫 링크 강화 비용", "linkMaintenanceDiscountPerLevel", "-%"], "crystalRecovery":["보스 처치 젬 파편", "bossGemShardsPerCrystalRecoveryLevel", ""], "runeResonance":["룬 획득량", "runeResonanceBonusPerLevel", "%"], "runUpgradeCostOptimization":["전투 강화 비용", "runUpgradeCostDiscountPerLevel", "-%"], "towerDamageLimitExpansion":["화력 강화 최대 레벨", "runUpgradeLimitExpansionMaxLevelPerLevel", ""], "killGoldLimitExpansion":["처치 보상 최대 레벨", "runUpgradeLimitExpansionMaxLevelPerLevel", ""], "waveGoldLimitExpansion":["보급 최대 레벨", "runUpgradeLimitExpansionMaxLevelPerLevel", ""]}

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

const UPGRADE_ART := "ui/components/upgrade/"
## Forge-row nine-patch art: masters are 3x logical; centers are logical pixels between the rivets/end caps.
const UPGRADE_FRAMES := {"row_normal":Rect2(16,15,135,24), "row_locked":Rect2(16,15,135,24), "row_max":Rect2(16,15,135,24), "button_normal":Rect2(11,7,74,15), "button_disabled":Rect2(11,7,70,15), "button_max":Rect2(12,8,79,30), "locked_plate":Rect2(12,8,79,30), "gauge_track":Rect2(5,3,137,4), "tab_bar":Rect2(20,8,260,16), "tab_selected":Rect2(10,7,102,13), "divider":Rect2(0,12,3,66)}
## Level-up button, locked condition and max seal share one action slot.
const ACTION_SIZE := Vector2(96, 58)
## Logical rows of the level-up art: dark price band height and the rim below it (measured at ACTION_SIZE).
const BUTTON_BAND := 19.0
const BUTTON_RIM := 7.0
const UPGRADE_STATUSES := ["해금", "잠김", "완료"]
## Lock codepoint in the bundled Flutter MaterialIcons font.
const LOCK_GLYPH := 0xe3ae
const UPGRADE_EMPTY := {"해금":"레벨업할 수 있는 강화가 없습니다.", "잠김":"잠긴 강화가 없습니다.", "완료":"아직 최대 레벨에 도달한 강화가 없습니다."}
var status := "해금"
## The level-up being applied ({id, before}); rows rebuilt meanwhile replay its forge strike.
var _strike := {}

## Segmented forge gauge redrawn for its width, so ticks never stretch.
class ForgeGauge extends Control:
	var ratio := 0.0
	var finished := false
	var track: StyleBox
	## Cells lit by the latest level-up glow white-hot while flash fades from 1 to 0.
	var flash_from := -1
	var flash := 0.0:
		set(value):
			flash = value
			queue_redraw()
	func lit_cells(value: float) -> int:
		var cells := maxi(8, int((size.x - 6) / 11.0))
		return ceili(value * cells) if value > 0 else 0
	func _init() -> void:
		custom_minimum_size.y = 13
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: queue_redraw()
	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, size)
		if track: draw_style_box(track, area)
		var inner := area.grow_individual(-3, -3, -3, -3)
		if inner.size.x <= 0 or inner.size.y <= 0: return
		var cells := maxi(8, int(inner.size.x / 11.0))
		var step := inner.size.x / cells
		var lit := ceili(ratio * cells) if ratio > 0 else 0
		for i in cells:
			var cell := Rect2(inner.position.x + i * step + 1.0, inner.position.y, step - 2.0, inner.size.y)
			if i < lit:
				var heat := float(i) / maxf(1, cells - 1)
				var color := Color("ffd76e") if finished else Color("ef7a1f").lerp(Color("ffc040"), heat)
				if flash > 0 and i >= mini(flash_from, lit - 1): color = color.lerp(Color("fffbea"), flash)
				draw_rect(cell, color)
				draw_rect(Rect2(cell.position, Vector2(cell.size.x, maxf(1, cell.size.y * 0.35))), Color(1, 0.93, 0.7, 0.45))
			else:
				draw_rect(cell, Color("15110e"))

func _forge(name: String, inset := 0) -> StyleBox:
	var frame := Frame.new(UPGRADE_ART + name + ".png", inset)
	frame.source_scale = 3.0
	frame.source_center = UPGRADE_FRAMES[name]
	return frame

func upgrade_groups() -> Dictionary:
	var ids: Array = COMBAT if category == "전투" else ECONOMY
	var groups := {"해금":[], "잠김":[], "완료":[]}
	for id in ids:
		var d: Dictionary = _growth().data.permanentUpgrades[id]
		if not d.get("enabled", true): continue
		if not Progression.has_unlock(lobby.progression(), "upgrade", id): groups["잠김"].append(id)
		elif int(lobby.progression().get(d.field, 0)) >= int(d.maxLevel): groups["완료"].append(id)
		else: groups["해금"].append(id)
	# Locked rows follow the stage that opens them; ties keep the catalog order.
	groups["잠김"].sort_custom(func(a, b):
		var left := Progression.ordinal_for(upgrade_requirement(a))
		var right := Progression.ordinal_for(upgrade_requirement(b))
		return left < right or (left == right and ids.find(a) < ids.find(b)))
	return groups

func upgrade_status_tabs(parent: Node) -> void:
	var groups := upgrade_groups()
	var bar := PanelContainer.new()
	bar.name = "UpgradeStatusTabs"
	bar.add_theme_stylebox_override("panel", _forge("tab_bar", 4))
	parent.add_child(bar)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	bar.add_child(tabs)
	for key in UPGRADE_STATUSES:
		var b := Button.new()
		b.name = "UpgradeStatus_" + key
		b.text = "%s  %d" % [key, groups[key].size()]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 28
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", T.font(900))
		b.add_theme_font_size_override("font_size", 12)
		var selected: bool = key == status
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(state, Color("fff0d2") if selected else Color("9a9488"))
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var style: StyleBox = StyleBoxEmpty.new()
			if selected and state != "focus": style = _forge("tab_selected")
			elif state in ["hover", "pressed", "hover_pressed"]:
				style = _forge("tab_selected")
				style.modulate_color = Color(1, 1, 1, 0.3)
			b.add_theme_stylebox_override(state, style)
		if key == "완료" and _strike_finished(): _flash.call_deferred(b, Color(1.9, 1.6, 1.1), 0.7)
		b.pressed.connect(func():
			if status == key: return
			status = key
			var scroll = lobby.get("_page_scroll")
			if is_instance_valid(scroll): scroll.scroll_vertical = 0
			lobby.refresh())
		tabs.add_child(b)

func upgrades() -> void:
	var list := VBoxContainer.new()
	list.name = "UpgradeList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	lobby.body.add_child(list)
	var ids: Array = upgrade_groups()[status]
	if ids.is_empty():
		var empty := PanelContainer.new()
		empty.name = "UpgradeEmpty"
		empty.add_theme_stylebox_override("panel", _forge("row_locked", 14))
		list.add_child(empty)
		var text := T.label(str(UPGRADE_EMPTY[status]), 11)
		text.add_theme_color_override("font_color", Color("8e949a"))
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(text)
		return
	for id in ids: _upgrade_row(list, id)

func _upgrade_row(parent: Node, id: String) -> void:
	var d: Dictionary = _growth().data.permanentUpgrades[id]
	var level := int(lobby.progression().get(d.field, 0))
	var maximum := int(d.maxLevel)
	var locked := not Progression.has_unlock(lobby.progression(), "upgrade", id)
	var finished := not locked and level >= maximum
	var cost := int(d.costs[mini(level, maximum)])
	var enabled := not locked and not finished and int(lobby.progression().get("runes", 0)) >= cost
	var panel := PanelContainer.new()
	panel.name = "UpgradeRow_" + id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("upgrade_id", id)
	panel.set_meta("level_text", "Lv.%d/%d" % [level, maximum])
	var frame := _forge("row_locked" if locked else ("row_max" if finished else "row_normal"))
	frame.content_margin_left = 14
	frame.content_margin_right = 14
	frame.content_margin_top = 12
	frame.content_margin_bottom = 11
	panel.add_theme_stylebox_override("panel", frame)
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	row.add_child(_forge_icon(id, locked))
	var levels := VBoxContainer.new()
	levels.custom_minimum_size.x = 32
	levels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	levels.add_theme_constant_override("separation", -3)
	row.add_child(levels)
	var number_color := Color("7d848a") if locked else (Color("ffd76e") if finished else Color("f0b75a"))
	var number: Label
	for part in [["Lv.", 10], [str(level), 23], ["/%d" % maximum, 10]]:
		var label := _inline(part[0], part[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", number_color if part[1] > 10 else Color("8a8f93") if locked else Color("c9b48d"))
		levels.add_child(label)
		if part[1] > 10: number = label
	row.add_child(_forge_divider(locked))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 3)
	row.add_child(words)
	var title := _strong(T.label(str(TITLES.get(id, id)), 14))
	title.add_theme_color_override("font_color", Color("a3a8ac") if locked else Color("f4e6c8"))
	words.add_child(title)
	var description := T.label(str(DESCRIPTIONS[id]), 10)
	description.add_theme_color_override("font_color", Color("787f86") if locked else Color("a99f90"))
	words.add_child(description)
	var effect := HFlowContainer.new()
	effect.add_theme_constant_override("h_separation", 4)
	effect.add_theme_constant_override("v_separation", 1)
	words.add_child(effect)
	var current := _inline("현재 " + effect_value(id, level), 11)
	current.add_theme_color_override("font_color", Color("9aa0a5") if locked else Color("e9dcc2"))
	effect.add_child(current)
	if not finished:
		var arrow := _inline("→", 11)
		arrow.add_theme_color_override("font_color", Color("8a8f93"))
		effect.add_child(arrow)
		var next := _inline("다음 " + effect_value(id, level + 1), 11)
		next.add_theme_color_override("font_color", Color("b39a62") if locked else Color("ffc54d"))
		effect.add_child(next)
	var gauge := ForgeGauge.new()
	gauge.ratio = float(level) / maxf(1, maximum)
	gauge.finished = finished
	gauge.track = _forge("gauge_track")
	words.add_child(gauge)
	if _strike.get("id") == id and level > int(_strike.before):
		_play_strike.call_deferred(panel, number, gauge, float(_strike.before) / maxf(1, maximum))
	var action: Control
	if locked: action = _forge_plate("locked_plate", LOCK_GLYPH, "%s 클리어" % Progression.stage_label(upgrade_requirement(id)), Color("a3a8ac"))
	elif finished: action = _forge_plate("button_max", 0, "최대 레벨", Color("4a2c08"))
	else: action = _levelup_button(id, cost, enabled, level)
	row.add_child(action)

func _forge_icon(id: String, locked: bool) -> Control:
	var socket := _image(UPGRADE_ART + "icon_socket.png", 56)
	socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := _image(ICONS.get(id, "upgrades/" + id.to_snake_case() + ".png"), 0)
	socket.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]: icon.set_offset(side, 7)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]: icon.set_offset(side, -7)
	if locked:
		# Dims the bronze socket and its icon together to match the grey iron row.
		socket.self_modulate = Color(0.62, 0.64, 0.68)
		icon.modulate = Color(0.55, 0.58, 0.62)
		var badge := _glyph(LOCK_GLYPH, 13, Color("d4d8dc"))
		badge.name = "LockBadge"
		badge.add_theme_color_override("font_outline_color", Color("0b0c0d"))
		badge.add_theme_constant_override("outline_size", 5)
		socket.add_child(badge)
		badge.position = Vector2(socket.custom_minimum_size.x - 12, -4)
	return socket

func _forge_plate(art: String, code: int, text: String, color: Color) -> Control:
	var plate := PanelContainer.new()
	plate.custom_minimum_size = ACTION_SIZE
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_theme_stylebox_override("panel", _forge(art, 4))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	plate.add_child(box)
	if code:
		var glyph := _glyph(code, 17, color)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(glyph)
	var label := _inline(text, 12 if code else 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	box.add_child(label)
	return plate

func _forge_divider(locked: bool) -> Control:
	var line := Panel.new()
	line.custom_minimum_size.x = 3
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_stylebox_override("panel", _forge("divider"))
	if locked: line.self_modulate = Color(0.7, 0.72, 0.76)
	return line

# Relights the shared lobby hall as a forge for the upgrade page: the stone
# picks up an umber tint and furnace light from below and the far arch, so
# lit edges glow while the shadows stay dark, and a few embers rise.
const FORGE_LIGHT := """
shader_type canvas_item;
uniform vec3 tint = vec3(1.0, 0.74, 0.54);
uniform vec3 ember = vec3(1.0, 0.46, 0.14);
float glow(vec2 uv, float aspect, vec2 center, float radius) {
	vec2 d = (uv - center) * vec2(1.0, aspect);
	return 1.0 - smoothstep(0.0, radius, length(d));
}
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	// Drain the hall's teal accents first; tinted teal turns lime, not firelight.
	base.rgb = mix(base.rgb, vec3(dot(base.rgb, vec3(0.3, 0.59, 0.11))), 0.85);
	float aspect = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
	float furnace = glow(SCREEN_UV, aspect, vec2(0.5, 1.02), 1.45);
	float arch = glow(SCREEN_UV, aspect, vec2(0.5, 0.1), 0.42);
	float light = pow(furnace, 1.6) * 8.0 + arch * arch * 4.0;
	vec3 lit = base.rgb * tint * (vec3(1.0) + ember * light) + ember * (pow(furnace, 2.2) * 0.16 + arch * arch * 0.04);
	COLOR = vec4(lit, base.a);
}
"""

func forge_atmosphere(parent: Node, backdrop: CanvasItem) -> void:
	var shader := Shader.new()
	shader.code = FORGE_LIGHT
	var light := ShaderMaterial.new()
	light.shader = shader
	backdrop.material = light
	if _animations_off(): return
	var layer := Control.new()
	layer.name = "ForgeEmbers"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(layer)
	var embers := CPUParticles2D.new()
	embers.amount = 30
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.direction = Vector2.UP
	embers.spread = 20.0
	embers.gravity = Vector2(0, -4)
	embers.initial_velocity_min = 22.0
	embers.initial_velocity_max = 50.0
	embers.scale_amount_min = 0.1
	embers.scale_amount_max = 0.24
	embers.texture = _ember_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	embers.material = additive
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.12, 0.65, 1.0])
	fade.colors = PackedColorArray([Color(1, 0.9, 0.6, 0), Color(1, 0.92, 0.65, 1), Color(1, 0.62, 0.25, 0.85), Color(1, 0.35, 0.08, 0)])
	embers.color_ramp = fade
	layer.add_child(embers)
	var place := func():
		embers.position = Vector2(layer.size.x * 0.5, layer.size.y)
		embers.emission_rect_extents = Vector2(layer.size.x * 0.5, 8)
	layer.resized.connect(place)
	place.call()

func _ember_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture

func _strike_finished() -> bool:
	if _strike.is_empty(): return false
	var d: Dictionary = _growth().data.permanentUpgrades[_strike.id]
	return int(lobby.progression().get(d.field, 0)) >= int(d.maxLevel) and int(_strike.before) < int(d.maxLevel)

func _animations_off() -> bool:
	return ProjectSettings.get_setting("accessibility/disable_animations", false)

## Brightens a control and lets it cool back to its own colors.
func _flash(control: Control, peak: Color, seconds: float, own := false) -> void:
	if _animations_off() or not is_instance_valid(control) or not control.is_inside_tree(): return
	var property := "self_modulate" if own else "modulate"
	control.set(property, peak)
	control.create_tween().tween_property(control, property, Color.WHITE, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## Forge strike after a level-up: row edge flares, the level number pops, new gauge cells cool from white.
func _play_strike(panel: Control, number: Label, gauge: ForgeGauge, before: float) -> void:
	if _animations_off() or not is_instance_valid(panel) or not panel.is_inside_tree(): return
	_flash(panel, Color(1.55, 1.3, 1.05), 0.45, true)
	if is_instance_valid(number):
		number.pivot_offset = number.size / 2
		number.scale = Vector2.ONE * 1.3
		_flash(number, Color(1.7, 1.5, 1.1), 0.35)
		number.create_tween().tween_property(number, "scale", Vector2.ONE, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if is_instance_valid(gauge):
		gauge.flash_from = gauge.lit_cells(before)
		gauge.flash = 1.0
		gauge.create_tween().tween_property(gauge, "flash", 0.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _levelup_button(id: String, cost: int, enabled: bool, level := 0) -> Button:
	var b := Button.new()
	b.name = "UpgradeLevelUp_" + id
	b.tooltip_text = "레벨업 · 룬 %d" % cost
	b.disabled = not enabled
	b.custom_minimum_size = ACTION_SIZE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := _forge("button_normal" if enabled else "button_disabled")
		if state == "hover": style.modulate_color = Color(1.12, 1.08, 1.0)
		elif state in ["pressed", "hover_pressed"]: style.modulate_color = Color(0.82, 0.78, 0.72)
		elif state == "focus": style = StyleBoxEmpty.new()
		b.add_theme_stylebox_override(state, style)
	b.pressed.connect(func():
		# Rows rebuilt by this command (including reentrant refreshes) replay the strike.
		_strike = {"id":id, "before":level}
		lobby.apply_growth_change({"kind":"upgradePermanent", "id":id})
		_strike = {})
	# The art has a bronze caption face over a dark price band; content follows that split.
	var caption_area := CenterContainer.new()
	caption_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(caption_area)
	caption_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption_area.offset_top = 4
	caption_area.offset_bottom = -(BUTTON_BAND + BUTTON_RIM + 2)
	var price_area := CenterContainer.new()
	price_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(price_area)
	price_area.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	price_area.offset_top = -(BUTTON_BAND + BUTTON_RIM)
	price_area.offset_bottom = -BUTTON_RIM
	var ink := Color("2b1606") if enabled else Color("4a4e52")
	var caption := HBoxContainer.new()
	caption.alignment = BoxContainer.ALIGNMENT_CENTER
	caption.add_theme_constant_override("separation", 3)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_area.add_child(caption)
	var hammer := _image(UPGRADE_ART + "hammer.png", 22)
	hammer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not enabled: hammer.modulate = Color(0.55, 0.57, 0.6)
	caption.add_child(hammer)
	var label := _inline("레벨업", 13)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ink)
	caption.add_child(label)
	var price := HBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", 6)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_area.add_child(price)
	var rune := _image("ui/hud/icons/rune.png", 15)
	rune.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not enabled: rune.modulate = Color(0.6, 0.62, 0.65)
	price.add_child(rune)
	var value := _inline(str(cost), 13)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color", Color("fff6e4") if enabled else Color("8b9095"))
	price.add_child(value)
	return b

func effect_value(id: String, level: int) -> String:
	if id == "linkExpansionOne": return "링크 홈 4개" if level > 0 else "링크 홈 3개"
	if id == "linkExpansionTwo": return "링크 홈 5개" if level > 0 else "링크 홈 4개"
	if id == "turretTargetPriority": return "목표 우선순위 설정 가능" if level > 0 else "목표 우선순위 설정 잠김"
	var e: Array = EFFECTS.get(id, ["", "", ""])
	var v := float(_growth().data.constants.get(e[1], 1)) * level
	var unit: String = e[2]
	if unit == "%base": return "%d%%" % (int(_growth().data.constants.baseTurretRefundPercent) + int(v))
	if "%" in unit:
		var number := "%.1f" % (v * 100)
		if not id in ["fireTraining", "physicalDamageTraining", "elementalDamageTraining", "poisonDamageTraining", "bossBounty"]: number = number.trim_suffix(".0")
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
	if id in ["linkExpansionOne","linkExpansionTwo"]: return "최대 링크 증가"
	if id == "turretTargetPriority": return "포탑 공격 명령 해금"
	var names := {"researchEfficiency":"연구 효율", "researchCostEfficiency":"비용 효율", "linkMaintenance":"첫 링크 비용", "gemAttunement":"젬 파편", "criticalChance":"치명타 확률", "emergencySale":"포탑 환불", "crystalRecovery":"보스 처치 시 젬 파편", "runeResonance":"룬 보상", "runUpgradeCostOptimization":"런 업그레이드 비용"}
	var text: String = str(names.get(id, EFFECTS[id][0])) + " " + effect_value(id, level)
	if level < maximum: text += " → " + effect_value(id, level + 1)
	return text

func _duration(ms: int) -> String:
	var minutes := ceili(float(ms) / 60000)
	return "%d시간" % (minutes / 60) if minutes % 60 == 0 else "%d분" % minutes

func _active(id: String) -> Dictionary:
	for item in lobby.progression().get("activeResearches", []):
		if item.type == id: return item
	return {}

func _remaining(active: Dictionary) -> int:
	return maxi(0, int(active.get("startedAtMillis", 0)) + int(active.get("durationMillis", 0)) - int(Time.get_unix_time_from_system() * 1000))

func _time(ms: int) -> String:
	var seconds := ceili(float(ms) / 1000)
	return "%d시간 %02d분" % [seconds / 3600, seconds % 3600 / 60] if seconds >= 3600 else "%d분 %02d초" % [seconds / 60, seconds % 60]

func research_status(id: String) -> String:
	var d: Dictionary = _growth().data.research[id]
	var q: Dictionary = _growth().research_quote(lobby.progression(), id)
	if not _active(id).is_empty(): return "연구 중"
	if int(q.level) >= int(d.maxLevel): return "연구 완료"
	if not Progression.has_unlock(lobby.progression(), "research", id): return "스테이지 %s 클리어 필요" % Progression.stage_label(Progression.requirement("research", id))
	var missing: Array = _growth().missing_research_prerequisites(lobby.progression(), id)
	if not missing.is_empty(): return "%s 연구 완료 필요" % TITLES.get(missing[0], missing[0])
	if lobby.progression().get("activeResearches", []).size() >= (2 if lobby.progression().get("researchSlotTwoUnlocked", false) else 1): return "빈 연구 슬롯 필요"
	if int(lobby.progression().get("runes", 0)) < int(q.cost): return "룬 부족"
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
	var active: Array = lobby.progression().get("activeResearches", [])
	var count := 2 if lobby.progression().get("researchSlotTwoUnlocked", false) else 1
	for i in range(count):
		if i < active.size():
			_research_slot(slots,active[i])

		else:
			var empty := _surface(slots, "ui/components/row_frame.png", 9)
			var row := HBoxContainer.new()
			empty.add_child(row)
			row.add_child(_glyph(0xe050, 18, Color("607587")))
			row.add_child(_inline("빈 연구 슬롯", 13))
	var slot_available := Progression.has_unlock(lobby.progression(), "feature", "researchSlotTwo")
	if count == 1:
		var cost := int(_growth().data.constants.researchSlotTwoUnlockCost)
		_button(slots, "두 번째 슬롯 · 다이아 %d" % cost if slot_available else "두 번째 슬롯 · 스테이지 2-10 클리어 필요", _slot_confirm, not slot_available)
	var groups := {"가능한 연구":[], "잠긴 연구":[], "완료한 연구":[]}
	var ids: Array = _growth().data.research.keys()
	ids.sort_custom(func(a, b): return Progression.ordinal_for(Progression.requirement("research", a)) < Progression.ordinal_for(Progression.requirement("research", b)))
	for id in ids:
		var status := research_status(id)
		groups["완료한 연구" if status == "연구 완료" else ("잠긴 연구" if status.begins_with("스테이지") or status.ends_with("연구 완료 필요") else "가능한 연구")].append(id)
	for group in groups:
		var presentation: Array = {"가능한 연구":["해금된 연구", 0xf33d, Color("e7c66a")], "잠긴 연구":["아직 해금되지 않음", 0xe3b1, Color("8da5b3")], "완료한 연구":["연구 완료", 0xe1f7, Color("bdefcf")]}[group]
		var section := _section(lobby.body, presentation[0], presentation[1], presentation[2])
		if groups[group].is_empty(): continue
		var grid := _grid(section)
		for id in groups[group]:
			var d: Dictionary = _growth().data.research[id]
			var q: Dictionary = _growth().research_quote(lobby.progression(), id)
			var status := research_status(id)
			var ready := status == "연구 가능"
			var box := _surface(grid)
			box.custom_minimum_size.y = 116
			var panel: Control = box.get_parent()
			panel.name = "ResearchCard_" + id
			panel.set_meta("research_id",id)
			panel.set_meta("research_status",status)
			if ready:
				# Tint the existing metallic image, keeping its bevels and corners.
				var ready_frame := _style("ui/components/card_frame.png",8)
				ready_frame.modulate_color = Color(0.35,1.55,1.65)
				panel.add_theme_stylebox_override("panel",ready_frame)
			else:
				# Inherited modulation includes the icon, labels, rune and time.
				panel.modulate = Color(0.48,0.58,0.68)
			_heading(box, id, int(q.level), int(d.maxLevel), -1 if int(q.level) >= int(d.maxLevel) else int(q.cost))
			var effect := _strong(T.label(_research_effect(id, int(q.level), int(d.maxLevel)), 10))
			effect.add_theme_color_override("font_color", Color("b9d6e4"))
			box.add_child(effect)
			var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE; box.add_child(spacer)
			var footer := HBoxContainer.new(); footer.add_theme_constant_override("separation",4); box.add_child(footer)
			var state_text := _inline(status if status in ["연구 중","연구 완료"] else "",11)
			state_text.name = "ResearchAvailability"
			state_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			footer.add_child(state_text)
			if int(q.level) < int(d.maxLevel):
				var duration := HBoxContainer.new(); duration.add_theme_constant_override("separation",3); footer.add_child(duration)
				duration.add_child(_glyph(0xe556, 10, Color("8da5b3")))
				duration.add_child(_inline(_duration(int(q.remainingMillis)), 9))

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
	lobby.apply_growth_change({"kind":kind, "id":id, "nowMillis":int(Time.get_unix_time_from_system() * 1000)})

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
	var comparison: BoxContainer = VBoxContainer.new() if id in ["linkExpansionOne","linkExpansionTwo","turretTargetPriority"] else HBoxContainer.new()
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
	wallet.add_child(T.label("보유 %s" % str(int(lobby.progression().get("runes",0))),12))
	var separator = VSeparator.new(); row.add_child(separator)
	var time = HBoxContainer.new(); time.size_flags_horizontal = Control.SIZE_EXPAND_FILL; time.add_theme_constant_override("separation",8); row.add_child(time)
	time.add_child(_glyph(0xe556,26,Color("a1d8eb")))
	var duration = VBoxContainer.new(); duration.size_flags_horizontal = Control.SIZE_EXPAND_FILL; duration.add_theme_constant_override("separation",2); time.add_child(duration)
	duration.add_child(T.label("연구 시간",12))
	var remaining := int(quote.remainingMillis)
	duration.add_child(T.label(_duration(remaining) if remaining % 60000 == 0 else _time(remaining),14))

func _build_details(box: VBoxContainer, id: String) -> void:
	var d: Dictionary = _growth().data.research[id]
	var q: Dictionary = _growth().research_quote(lobby.progression(), id)
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
			if int(lobby.progression().get("researchElapsedMillis", {}).get(id, 0)) > 0: box.add_child(T.label("이전에 진행한 연구 시간이 보존되어 있습니다.", 12))
		var action = T.button("연구 시작" if status == "연구 가능" else status,_submit.bind("startResearch",id),"primary")
		action.name = "ResearchDetailAction"; action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; action.custom_minimum_size.y = 44; action.add_theme_font_size_override("font_size",16); action.disabled = status != "연구 가능"; box.add_child(action)

func _cancel_confirm(id: String, from_details := false) -> void:
	var active := _active(id)
	if active.is_empty() or _remaining(active) == 0:
		_details(id)
		return
	var quote: Dictionary = _growth().research_quote(lobby.progression(), id)
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
	var before_runes := int(lobby.progression().get("runes",0))
	var before_level := int(lobby.progression().get("researchLevels",{}).get(id,0))
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
	elif int(lobby.progression().get("researchLevels",{}).get(id,0)) > before_level:
		# A research may finish while its confirmation is open; the domain completes it.
		lobby.message = "%s 연구가 완료되었습니다." % str(TITLES.get(id,id))
	else:
		var refunded := int(lobby.progression().get("runes",0))-before_runes
		lobby.message = "연구 중단 · 룬 +%d 반환 · 진행 시간 보존" % refunded
	lobby.refresh()

func _instant_confirm(id: String) -> void:
	var active := _active(id)
	if active.is_empty(): return
	lobby.open_service("연구 즉시 완료",{"id":id})

func _slot_confirm() -> void:
	lobby.open_service("연구 슬롯 구매",{})
