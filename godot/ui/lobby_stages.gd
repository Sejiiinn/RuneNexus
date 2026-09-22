extends RefCounted
## Reference coordinates match main_menu_stage.dart (789 x 1566).
const T = preload("res://ui/app_theme.gd")
const DetailTheme = preload("res://ui/stage_detail_theme.gd")
const RewardArt = preload("res://ui/stage_reward_art.gd")
const Quests = preload("res://app/quest_progress.gd")
const REFERENCE := Vector2(789, 1566)
const STAGE := "ui/stage_reference/"
const WHITE := Color("e8f8ff")
const MUTED := Color("7f93a1")
const GOLD := Color("e7c66a")
const CHAPTERS := ["초원 초입", "균열 장막", "공명 용광로"]
const SECONDARIES := [Color("e7c66a"), Color("b68bff"), Color("5cf9e9")]
const ACCENTS := [Color("8ee6ff"), Color("5cf9e9"), Color("ff8a3d")]
# Original stage-details unlock lists, with original item artwork.
const UNLOCKS := {
1:[["처치 보상", "upgrades/kill_gold.png", "강화"], ["긴급 매각", "upgrades/turret_refund.png", "연구"]],
2:[["전술 명령", "research/turret_target_priority.png", "연구"], ["젬 감응", "research/gem_attunement.png", "연구"]],
3:[["저격 포탑", "material:ef3a", "포탑"], ["조준경 젬", "gems/aimSpeed.png", "젬"]],
4:[["치명 집중", "upgrades/critical_chance.png", "연구"], ["치명 충격", "upgrades/critical_damage.png", "강화"]],
5:[["링크 확장 I", "research/link_expansion_one.png", "연구"], ["결정 회수", "research/crystal_recovery.png", "연구"], ["균열 낙인", "core_abilities/rift_mark.png", "코어"]],
6:[["라이트닝 포탑", "material:eedd", "포탑"]],
7:[["물리 화력 훈련", "upgrades/physical_damage.png", "강화"], ["원소 화력 훈련", "upgrades/elemental_damage.png", "강화"]],
8:[["룬 공명", "research/rune_resonance.png", "연구"], ["전투 강화 비용 최적화", "research/run_upgrade_cost_optimization.png", "연구"]],
9:[["연결 공정", "upgrades/link_cost_optimization.png", "강화"], ["강화 공정", "upgrades/turret_level_up_optimization.png", "강화"]],
10:[["장갑 관통 젬", "gems/armorPiercing.png", "젬"], ["연구 슬롯 II 구매 권한", "material:f499", "연구"]],
15:[["화력 한계 확장", "research/tower_damage_limit_expansion.png", "연구"], ["처치 보상 한계 확장", "research/kill_gold_limit_expansion.png", "연구"], ["보급 한계 확장", "research/wave_gold_limit_expansion.png", "연구"]]}
var lobby
var chapter := 0
var active_stage_seen := 0
var canvas: Control
var scale_factor := Vector2.ONE

func setup(owner) -> void:
	lobby = owner

func _state() -> Dictionary:
	return lobby.app.run_domain.state

func _stage_number() -> int:
	return int(_state().get("stage", 0)) + 1

func unlocked(stage: int) -> bool:
	return stage <= int(lobby._p().get("unlockedStageCount", 1)) and stage <= lobby.app.catalog.stage_count()

func active(stage: int) -> bool:
	return lobby._has_run() and stage == _stage_number()

func rune_reward(stage: int) -> int:
	# Pure preview of the existing settlement calculation; returned state is discarded.
	var preview: Dictionary = Quests.new().finish(lobby._p(), {"stageNumber":stage, "completedRounds":lobby.app.catalog.stage(stage - 1).waves.size(), "success":true, "grantEconomyRewardsLocally":false})
	return int(preview.lastRunRuneReward)

func record(stage: int) -> String:
	var best := int(lobby._p().get("bestRoundsByStage", {}).get(str(stage), 0))
	if best > 0: return "최고 %d라운드" % best
	return "클리어" if stage in lobby._p().get("clearedStageNumbers", []) else "기록 없음"

func status(stage: int) -> String:
	if not unlocked(stage): return "잠김"
	if active(stage):
		return "전투 중" if _state().get("phase") == "wave" else ("보상 선택 대기" if _state().get("phase") == "reward" else "진행 중")
	if stage in lobby._p().get("clearedStageNumbers", []): return "클리어"
	return record(stage)

func reset_navigation() -> void:
	chapter = 0
	active_stage_seen = 0

func render() -> void:
	if chapter == 0:
		chapter = (clampi(_stage_number() if not _state().is_empty() else int(lobby._p().get("unlockedStageCount", 1)), 1, 15) - 1) / 5 + 1
	if lobby._has_run() and _stage_number() != active_stage_seen:
		active_stage_seen = _stage_number()
		chapter = (active_stage_seen - 1) / 5 + 1
	canvas = Control.new()
	canvas.name = "StageReferenceBoard"
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size.y = 200
	canvas.clip_contents = true
	lobby.body.add_child(canvas)
	canvas.resized.connect(_layout)
	_layout.call_deferred()

func _rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position * scale_factor, rect.size * scale_factor)

func _place(control: Control, rect: Rect2) -> void:
	canvas.add_child(control)
	var scaled := _rect(rect)
	control.position = scaled.position
	control.size = scaled.size

func _image(path: String, rect: Rect2, color := Color.WHITE) -> TextureRect:
	var image := TextureRect.new()
	image.texture = T.texture(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.modulate = color
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(image, rect)
	return image

func _asset(file: String, rect: Rect2, color := Color.WHITE) -> void:
	_image(STAGE + file + ".png", rect, color)

func _text(value: String, rect: Rect2, font_size: float, color := WHITE, centered := false, weight := 900) -> Label:
	var label := Label.new()
	label.text = value
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", T.font(weight))
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", maxi(8, roundi(font_size * minf(scale_factor.x, scale_factor.y))))
	_place(label, rect)
	# FittedBox.scaleDown equivalent for one-line labels.
	var font: Font = label.get_theme_font("font")
	var measured := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	if measured > label.size.x:
		label.add_theme_font_size_override("font_size", maxi(7, floori(label.get_theme_font_size("font_size") * label.size.x / measured)))
	return label

func _hit(rect: Rect2, callback: Callable, hint: String) -> Button:
	var button := Button.new()
	button.tooltip_text = hint
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(callback)
	_place(button, rect)
	return button

func select_chapter(value: int) -> void:
	chapter = clampi(value, 1, 3)
	_layout()

func _layout() -> void:
	if not is_instance_valid(canvas) or canvas.size.x <= 0: return
	for child in canvas.get_children(): canvas.remove_child(child); child.queue_free()
	scale_factor = canvas.size / REFERENCE
	_asset("stage_shell_fill", Rect2(Vector2.ZERO, REFERENCE))
	_asset("stage_shell_frame", Rect2(Vector2.ZERO, REFERENCE))
	var rects := [Rect2(31,28,247,91), Rect2(288,28,237,91), Rect2(531,28,233,91)]
	for i in range(3):
		_asset("chapter_tab_selected" if chapter == i + 1 else "chapter_tab_idle", rects[i], ACCENTS[i] if chapter == i + 1 else Color.WHITE)
		_text("챕터 %d" % (i + 1), rects[i], 25, WHITE, true)
		_hit(rects[i], select_chapter.bind(i + 1), "챕터 %d" % (i + 1))
	_image("chapter_%d_banner.png" % chapter, Rect2(35,135,724,134))
	_asset("chapter_banner_frame", Rect2(35,135,724,134))
	_text(CHAPTERS[chapter - 1], Rect2(62,164,360,52), 42)
	var first := (chapter - 1) * 5 + 1
	_text("스테이지 %d–%d" % [first, first + 4], Rect2(62,211,280,35), 24, Color("b9d6e4"), false, 700)
	var active_here: bool = lobby._has_run() and _stage_number() >= first and _stage_number() < first + 5
	if active_here: _active_card(_stage_number())
	else: _asset("chapter_bridge", Rect2(338,280,114,36))
	var i := 0
	for stage in range(first, mini(first + 5, lobby.app.catalog.stage_count() + 1)):
		if active_here and stage == _stage_number(): continue
		_row(stage, (658 if active_here else 289) + i * 131)
		i += 1

func _active_card(stage: int) -> void:
	_asset("active_stage_panel", Rect2(24,282,740,366))
	_asset("stage_number_socket", Rect2(24,296,145,150))
	_asset("stage_stat_strip", Rect2(56,431,682,81))
	_asset("continue_button_idle", Rect2(57,527,678,84))
	_text("%02d" % stage, Rect2(61,340,72,65), 34, WHITE, true)
	_badge(Rect2(157,326,80,34), Color("087f78cc"), Color.TRANSPARENT, 5)
	_text("진행 중", Rect2(157,326,80,34), 20, Color("68fff0"), true)
	_text("스테이지 %d" % stage, Rect2(157,370,330,53), 34)
	_badge(Rect2(595,346,145,48), Color("28261fb9"), Color.TRANSPARENT, 7)
	_text("룬 +%d" % rune_reward(stage), Rect2(595,346,145,48), 24, GOLD, true)
	var state := _state()
	var gold := int(state.get("gold", 0))
	var values := ["%d/%d" % [int(state.get("roundIndex", 0)) + 1, lobby.app.catalog.stage(stage - 1).waves.size()], str(state.get("turrets", []).size()), "%.1fK" % (float(gold)/1000) if gold >= 1000 else str(gold)]
	for i in range(3):
		_text(values[i], Rect2(57 + i * 227,436,226,39), 30, GOLD if i == 2 else WHITE, true)
		_text(["라운드", "포탑", "골드"][i], Rect2(57 + i * 227,475,226,29), 22, Color("b9d6e4"), true, 700)
	_glyph("f00a0", Rect2(275,553,31,31), 31, Color("06141e"))
	_text("이어서 진행", Rect2(315,528,250,82), 30, Color("06141e"))
	_hit(Rect2(57,528,678,82), _continue, "이어서 진행")
	_hit(Rect2(52,309,500,113), details.bind(stage), "스테이지 상세")

func _row(stage: int, top: float) -> void:
	var enabled := unlocked(stage)
	var tint := Color.WHITE if enabled else Color(1,1,1,0.76)
	_asset("locked_stage_row", Rect2(24,top,740,123), tint)
	_asset("stage_number_plate", Rect2(42,top + 18,114,90), tint)
	_text("%02d" % stage, Rect2(57.5,top+26,74,70), 38, Color("b9d6e4") if enabled else MUTED, true)
	_text("스테이지 %d" % stage, Rect2(169,top+17,270,48), 34, WHITE if enabled else MUTED)
	if not enabled: _glyph("f888", Rect2(169,top+68,22,22), 22, Color("667987"))
	_text(status(stage), Rect2(169 if enabled else 198,top+61,180 if enabled else 151,36), 23, ACCENTS[chapter-1] if enabled else Color("667987"), false, 700)
	_text("룬 +%d" % rune_reward(stage), Rect2(409,top+35,180,52), 24, SECONDARIES[chapter-1] if enabled else Color("667987"), true)
	var icons := _reward_icons(stage)
	# Flutter's 52x32 reward row is scaled into its 94x72 reference slot.
	var badge_scale := 94.0 / 52.0
	for i in range(icons.size()):
		var left := 614.0 + (28 if icons.size() == 1 else i * 28) * badge_scale
		var rect := Rect2(left, top + 39.46, 24 * badge_scale, 24 * badge_scale)
		var color := WHITE if enabled else MUTED
		_badge(rect, Color("e8f8ff14"), Color(color, 0.34), 7 * badge_scale)
		if icons[i].begins_with("turret:"):
			var shape := RewardTurretIcon.new()
			shape.kind = icons[i].trim_prefix("turret:")
			_place(shape, Rect2(rect.position + Vector2(3,4 if shape.kind == "sniper" else 3) * badge_scale, Vector2(18,16 if shape.kind == "sniper" else 18) * badge_scale))
		else: _image(icons[i], Rect2(rect.position + Vector2.ONE * 4 * badge_scale, Vector2.ONE * 16 * badge_scale))
	_glyph("f63b", Rect2(714,top+32,44,60), 36, Color(ACCENTS[chapter-1],0.84) if enabled else Color("536675"))
	_hit(Rect2(24,top,740,123), details.bind(stage), "스테이지 %d 상세" % stage)

func _reward_icons(stage: int) -> Array:
	match stage:
		1,4,7,9: return ["stage_rewards/reward_upgrade.png"]
		2,8,15: return ["stage_rewards/reward_research.png"]
		3: return ["turret:sniper", "stage_rewards/reward_gem.png"]
		5: return ["stage_rewards/reward_research.png", "stage_rewards/reward_core.png"]
		6: return ["turret:lightning"]
		10: return ["stage_rewards/reward_gem.png", "stage_rewards/reward_research.png"]
		11: return ["stage_rewards/reward_module_ticket.png"]
	return []

func _continue() -> void:
	lobby.close_modal()
	if not lobby.app.resume_run(): lobby._failure()

func start(stage: int) -> void:
	if not unlocked(stage): return
	lobby.close_modal()
	if active(stage): _continue()
	else: lobby._start(stage - 1)

func _surface(parent: Node, image: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBox = T.panel()
	var texture := T.texture("stage_details/ui/" + image + ".png")
	if texture:
		var texture_style := StyleBoxTexture.new()
		texture_style.texture = texture
		texture_style.set_texture_margin_all(0)
		texture_style.set_content_margin_all(10 if image == "unlock_panel_frame" else 9)
		if image == "quick_stat_frame":
			texture_style.content_margin_left = 8
			texture_style.content_margin_right = 8
		style = texture_style
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	return box

func unlock_items(stage: int) -> Array:
	if stage == 11: return [["모듈 티켓 %d장" % int(lobby.app.catalog.stage(stage - 1).get("firstClearTurretModuleTicketReward", 0)), "stage_rewards/reward_module_ticket.png", "티켓"]]
	return UNLOCKS.get(stage, [])

func _small_icon(path: String, pixels: int = 18) -> Control:
	if path.begins_with("material:"):
		var glyph := Label.new()
		glyph.text = String.chr(path.trim_prefix("material:").hex_to_int())
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", pixels)
		if ResourceLoader.exists("res://assets/ui/MaterialIcons-Regular.otf"):
			glyph.add_theme_font_override("font", load("res://assets/ui/MaterialIcons-Regular.otf"))
		else: glyph.text = ""
		return glyph
	var image := TextureRect.new()
	image.texture = T.texture(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(pixels,pixels)
	return image

func _badge(rect: Rect2, fill: Color, edge: Color, radius: float) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1 if edge.a > 0 else 0)
	style.set_corner_radius_all(roundi(radius * minf(scale_factor.x, scale_factor.y)))
	panel.add_theme_stylebox_override("panel",style)
	_place(panel,rect)

func _glyph(code: String, rect: Rect2, pixels: int, color: Color) -> void:
	var icon := _small_icon("material:" + code, maxi(1,roundi(pixels * minf(scale_factor.x, scale_factor.y))))
	icon.modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(icon,rect)

func reward_highlighted(stage: int) -> bool:
	if stage == 3:
		var inputs: Dictionary = lobby._p()
		if inputs.has("availableTurretTypes"): return "sniper" in inputs.availableTurretTypes
		if lobby.app.run_domain is Object and lobby.app.run_domain.get("growth") != null:
			return "sniper" in lobby.app.run_domain.growth.derive(inputs).get("availableTurretTypes", [])
	return stage in lobby._p().get("clearedStageNumbers", [])

func _detail_label(value: String, pixels := 12, color := WHITE, weight := 700) -> Label:
	var label := T.label(value,pixels)
	# These are compact captions; wrapping gives shrink-to-fit chips zero width.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_override("font",T.font(weight))
	label.add_theme_color_override("font_color",color)
	return label

func _texture_panel(image: String, padding: Vector4 = Vector4(8,6,8,6)) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = T.texture("stage_details/ui/" + image + ".png")
	style.set_texture_margin_all(0)
	style.content_margin_left = padding.x
	style.content_margin_top = padding.y
	style.content_margin_right = padding.z
	style.content_margin_bottom = padding.w
	panel.add_theme_stylebox_override("panel",style)
	return panel

func _detail_divider() -> Control:
	var divider := PanelContainer.new()
	divider.custom_minimum_size.y = 10
	divider.add_theme_stylebox_override("panel",DetailTheme.box("divider"))
	return divider

func _detail_header(stage: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "StageDetailsHeader"
	panel.custom_minimum_size.y = 64
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	panel.add_child(row)
	var balance := Control.new()
	balance.custom_minimum_size.x = 42
	row.add_child(balance)
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation",4)
	row.add_child(titles)
	var title := _detail_label("스테이지 %d" % stage,DetailTheme.FONT_TITLE,WHITE if unlocked(stage) else Color("899faa"),900)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(title)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel",DetailTheme.status())
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var state := _detail_label(status(stage),DetailTheme.FONT_SECONDARY,GOLD if active(stage) else Color("bee9f0"),800)
	chip.add_child(state)
	titles.add_child(chip)
	var close := Button.new()
	close.name = "CloseStageDetails"
	close.tooltip_text = "닫기"
	close.custom_minimum_size = Vector2(42,41)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for key in ["normal","hover","pressed","focus"]:
		close.add_theme_stylebox_override(key,DetailTheme.box("close_button"))
	close.pressed.connect(lobby.close_modal)
	row.add_child(close)
	return panel

func details(stage: int) -> void:
	var box: VBoxContainer = lobby.open_modal("스테이지 %d" % stage)
	box.add_theme_constant_override("separation",0)
	if is_instance_valid(lobby.modal): lobby.modal.set_meta("max_width",390)
	if lobby.has_method("set_modal_stylebox"): lobby.set_modal_stylebox(DetailTheme.box("dialog_frame",16))
	var header := _detail_header(stage)
	if lobby.has_method("set_modal_header"): lobby.set_modal_header(header)
	else: box.add_child(header)
	box.add_child(_detail_divider())
	var stat_row := HBoxContainer.new()
	stat_row.name = "StageQuickStats"
	stat_row.custom_minimum_size.y = 74
	stat_row.add_theme_constant_override("separation",8)
	box.add_child(stat_row)
	var stat_data := [["최고 기록", record(stage), "best_record"], ["총 라운드", "%d라운드" % lobby.app.catalog.stage(stage - 1).waves.size(), "total_rounds"], ["룬 보상", "+%d" % rune_reward(stage), "rune_reward"]]
	for i in range(stat_data.size()):
		if i > 0:
			var separator := VSeparator.new()
			separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			separator.custom_minimum_size.y = 48
			var line := StyleBoxLine.new()
			line.color = Color("397785")
			line.vertical = true
			line.thickness = 1
			separator.add_theme_stylebox_override("separator",line)
			stat_row.add_child(separator)
		var entry: Array = stat_data[i]
		var stat := VBoxContainer.new()
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat.alignment = BoxContainer.ALIGNMENT_CENTER
		stat.add_theme_constant_override("separation",3)
		stat_row.add_child(stat)
		var icon := _small_icon("stage_details/stats/" + entry[2] + ".png",22)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stat.add_child(icon)
		var caption := _detail_label(entry[0],DetailTheme.FONT_SECONDARY,Color("b9d6e4"))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat.add_child(caption)
		var value := _detail_label(entry[1],DetailTheme.FONT_PRIMARY,WHITE,900)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat.add_child(value)
	box.add_child(_detail_divider())
	if not unlocked(stage):
		var label := _detail_label("스테이지 %d 클리어 후 입장할 수 있습니다." % (stage-1),DetailTheme.FONT_SECONDARY,Color("b9d6e4"))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	var items := unlock_items(stage)
	var highlighted := reward_highlighted(stage)
	if not items.is_empty():
		var heading := PanelContainer.new()
		heading.custom_minimum_size.y = 33
		heading.add_theme_stylebox_override("panel",DetailTheme.box("reward_heading",6))
		box.add_child(heading)
		var caption := HBoxContainer.new()
		caption.add_theme_constant_override("separation",7)
		heading.add_child(caption)
		var icon := _small_icon("material:eea9",16)
		icon.modulate = Color("ede0bc")
		caption.add_child(icon)
		caption.add_child(_detail_label(("수령 완료" if highlighted else "최초 클리어 보상") if stage == 11 else ("해금됨" if highlighted else "클리어 보상"),DetailTheme.FONT_PRIMARY,WHITE,900))
		var rewards := VBoxContainer.new()
		rewards.add_theme_constant_override("separation",2)
		box.add_child(rewards)
		for i in range(items.size()):
			var item: Array = items[i]
			var reward := PanelContainer.new()
			reward.name = "UnlockChip_%d" % i
			reward.custom_minimum_size.y = 52
			var reward_style := DetailTheme.box("reward_row",8)
			reward_style.content_margin_top = 5
			reward_style.content_margin_bottom = 5
			reward.add_theme_stylebox_override("panel",reward_style)
			rewards.add_child(reward)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",10)
			reward.add_child(row)
			var item_icon := _small_icon(RewardArt.for_reward(item[1]),38)
			if item[1] == "material:f499":
				var plus := _detail_label("+",20,Color("f4cf70"),900)
				plus.name = "ResearchSlotPlus"
				plus.position = Vector2(24,-3)
				plus.add_theme_color_override("font_outline_color",Color("07151e"))
				plus.add_theme_constant_override("outline_size",3)
				plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
				item_icon.add_child(plus)
			item_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(item_icon)
			var text := VBoxContainer.new()
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.alignment = BoxContainer.ALIGNMENT_CENTER
			text.add_theme_constant_override("separation",1)
			row.add_child(text)
			text.add_child(_detail_label(item[2],DetailTheme.FONT_SECONDARY,DetailTheme.CYAN,800))
			var name := _detail_label(item[0],DetailTheme.FONT_PRIMARY,SECONDARIES[(stage-1)/5] if highlighted else WHITE,900)
			name.name = "RewardName"
			name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.add_child(name)
			var arrow := _detail_label("›",23,Color("b9d6e4"),600)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(arrow)
	var button := T.button("이어서 진행" if active(stage) else ("시작하기" if unlocked(stage) else "시작 불가"), start.bind(stage))
	button.name = "StageAction"
	button.disabled = not unlocked(stage)
	button.custom_minimum_size.y = 53
	button.add_theme_font_override("font",T.font(900))
	button.add_theme_font_size_override("font_size",DetailTheme.FONT_ACTION)
	DetailTheme.apply_action(button)
	var action_label := button.text
	button.text = ""
	button.tooltip_text = action_label
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_row.add_theme_constant_override("separation",6)
	button.add_child(action_row)
	action_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var action_icon := _small_icon("material:f00a0" if unlocked(stage) else "material:e3b1",18)
	action_icon.modulate = WHITE if unlocked(stage) else Color("667987")
	action_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_row.add_child(action_icon)
	action_row.add_child(_detail_label(action_label,DetailTheme.FONT_ACTION,WHITE if unlocked(stage) else Color("667987"),900))
	box.add_child(button)

# Static reward icon port of lib/game/rendering/turret_shape_renderer.dart.
# Keep the original 112-unit geometry; HUD sprites are a different asset.
class RewardTurretIcon extends Control:
	var kind := "sniper"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _polygon(points: Array, fill: Color, edge: Color, width: float) -> void:
		var polygon := PackedVector2Array()
		var unit := minf(size.x,size.y) / 112.0
		for point in points: polygon.append(size/2 + point * unit)
		draw_colored_polygon(polygon,fill)
		polygon.append(polygon[0])
		draw_polyline(polygon,edge,width,true)
	func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		var unit := minf(size.x,size.y) / 112.0
		draw_line(size/2+a*unit,size/2+b*unit,color,width,true)
	func _draw() -> void:
		if kind == "sniper": _sniper()
		else: _lightning()
	func _sniper() -> void:
		var span := minf(size.x,size.y)
		draw_circle(size/2,span*0.38,Color("0d1721"))
		draw_arc(size/2,span*0.38,0,TAU,64,Color("050a12"),span/16*1.1,true)
		draw_circle(size/2,span*0.3,Color("274451"))
		draw_arc(size/2,span*0.3,0,TAU,64,Color("050a12"),span/16*1.1*0.52,true)
		_polygon([Vector2(-40,5),Vector2(-29,21),Vector2(-17,35),Vector2(-30,31),Vector2(-43,17)],Color("91a2a9"),Color("050a12"),span/16*1.1 * 0.52)
		_polygon([Vector2(40,5),Vector2(29,21),Vector2(17,35),Vector2(30,31),Vector2(43,17)],Color("91a2a9"),Color("050a12"),span/16*1.1 * 0.52)
		_line(Vector2(-35,10),Vector2(-23,26),Color("ddf8ffc2"),span * 0.011)
		_line(Vector2(35,10),Vector2(23,26),Color("ddf8ffc2"),span * 0.011)
		_polygon([Vector2(-15,10),Vector2(-18,37),Vector2(-9,48),Vector2(0,38),Vector2(9,48),Vector2(18,37),Vector2(15,10),Vector2(8,4),Vector2(-8,4)],Color("2b3944"),Color("050a12"),span/16*1.1 * 0.52)
		_polygon([Vector2(-10,14),Vector2(-12,34),Vector2(-6,40),Vector2(0,32),Vector2(6,40),Vector2(12,34),Vector2(10,14)],Color("152630"),Color("050a12e6"),span/16*1.1 * 0.38)
		_polygon([Vector2(-17,-2),Vector2(-29,11),Vector2(-22,22),Vector2(-10,12)],Color("91a2a9"),Color("050a12e6"),span/16*1.1 * 0.38)
		_polygon([Vector2(17,-2),Vector2(29,11),Vector2(22,22),Vector2(10,12)],Color("91a2a9"),Color("050a12e6"),span/16*1.1 * 0.38)
		_polygon([Vector2(-17,10),Vector2(-14,-18),Vector2(-8,-25),Vector2(8,-25),Vector2(14,-18),Vector2(17,10),Vector2(9,20),Vector2(-9,20)],Color("506a78"),Color("050a12"),span/16*1.1 * 0.52)
		_polygon([Vector2(-10,7),Vector2(-8,-15),Vector2(-4,-20),Vector2(4,-20),Vector2(8,-15),Vector2(10,7),Vector2(5,13),Vector2(-5,13)],Color("152630"),Color("050a12e6"),span/16*1.1 * 0.38)
		_polygon([Vector2(-7,-18),Vector2(-6,-48),Vector2(-3,-55),Vector2(3,-55),Vector2(6,-48),Vector2(7,-18)],Color("b7f4fff5"),Color("050a12e6"),span/16*1.1 * 0.38)
		_polygon([Vector2(-11,-48),Vector2(-9,-58),Vector2(9,-58),Vector2(11,-48),Vector2(6,-43),Vector2(-6,-43)],Color("e8fbff"),Color("050a12e6"),span/16*1.1 * 0.38)
		_line(Vector2(-7,-53),Vector2(7,-53),Color("10212c"),span * 0.025)
		_line(Vector2(0,-43),Vector2(0,-22),Color("ddf8ffc2"),span * 0.011)
		_polygon([Vector2(13,-17),Vector2(21,-24),Vector2(30,-20),Vector2(31,-6),Vector2(23,-1),Vector2(14,-7)],Color("274451"),Color("050a12e6"),span/16*1.1 * 0.38)
		draw_circle(size/2+Vector2(23,-13)*span/112,5.5*span/112,Color.WHITE)
		draw_arc(size/2+Vector2(23,-13)*span/112,5.5*span/112,0,TAU,32,Color("050a12e6"),span/16*1.1*0.38,true)
		_line(Vector2(20,-16),Vector2(26,-10),Color("ddf8ffc2"),span * 0.011)
		draw_circle(size/2,span*0.075,Color("b7f4fff5"))
		draw_arc(size/2,span*0.075,0,TAU,32,Color("050a12e6"),span/16*1.1*0.38,true)
	func _lightning() -> void:
		var span := minf(size.x,size.y)
		_polygon([Vector2(-46,28),Vector2(-34,-34),Vector2(-16,-50),Vector2(16,-50),Vector2(34,-34),Vector2(46,28),Vector2(26,51),Vector2(-26,51)],Color("cfa7ff1f"),Color("cfa7ff52"),span * 0.012)
		_polygon([Vector2(-42,25),Vector2(-31,-27),Vector2(-13,-43),Vector2(13,-43),Vector2(31,-27),Vector2(42,25),Vector2(22,46),Vector2(-22,46)],Color("111f2b"),Color("050a12"),span/18)
		_polygon([Vector2(-31,18),Vector2(-23,-18),Vector2(0,-31),Vector2(23,-18),Vector2(31,18),Vector2(16,34),Vector2(-16,34)],Color("1c303c"),Color("050a12"),span/18)
		_line(Vector2(-31,18),Vector2(31,18),Color("83a4b48c"),span * 0.011)
		_line(Vector2(-23,-18),Vector2(23,-18),Color("83a4b48c"),span * 0.011)
		_line(Vector2(0,-31),Vector2(0,34),Color("83a4b48c"),span * 0.011)
		_polygon([Vector2(-31,23),Vector2(-25,-49),Vector2(-8,-49),Vector2(-8,23)],Color("465b69"),Color("050a12"),span/18)
		_polygon([Vector2(8,23),Vector2(8,-49),Vector2(25,-49),Vector2(31,23)],Color("465b69"),Color("050a12"),span/18)
		_polygon([Vector2(-26,17),Vector2(-21,-42),Vector2(-12,-42),Vector2(-12,17)],Color("14232e"),Color("050a12"),span/18)
		_polygon([Vector2(12,17),Vector2(12,-42),Vector2(21,-42),Vector2(26,17)],Color("14232e"),Color("050a12"),span/18)
		_polygon([Vector2(-29,-47),Vector2(-25,-60),Vector2(-8,-60),Vector2(-5,-47)],Color("6f8792"),Color("050a12"),span/18)
		_polygon([Vector2(5,-47),Vector2(8,-60),Vector2(25,-60),Vector2(29,-47)],Color("6f8792"),Color("050a12"),span/18)
		_polygon([Vector2(-34,26),Vector2(-26,15),Vector2(26,15),Vector2(34,26),Vector2(21,39),Vector2(-21,39)],Color("1c303c"),Color("050a12"),span/18)
		for pair in [[Vector2(-30,-31),Vector2(-7,-31)],[Vector2(-31,-16),Vector2(-8,-16)],[Vector2(-32,-1),Vector2(-8,-1)],[Vector2(7,-31),Vector2(30,-31)],[Vector2(8,-16),Vector2(31,-16)],[Vector2(8,-1),Vector2(32,-1)]]:
			_line(pair[0],pair[1],Color("030812"),span*0.048)
			_line(pair[0],pair[1],Color("cfa7ffeb"),span*0.029)
		var core := StyleBoxFlat.new()
		core.bg_color = Color("cfa7ff")
		core.border_color = Color("050a12")
		core.set_border_width_all(1)
		core.set_corner_radius_all(roundi(span*0.012))
		draw_style_box(core,Rect2(size/2-Vector2.ONE*span*0.11,Vector2.ONE*span*0.22))
		draw_circle(size/2,span*0.04,Color(1,1,1,0.9))
