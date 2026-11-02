extends RefCounted
## Result presentation reads the finished run; reward ownership stays in services.
const HudNumber = preload("res://ui/hud_number.gd")
const Art = preload("res://ui/app_theme.gd")
const Progression = preload("res://content/stage_progression.gd")
const StageDifficulty = preload("res://content/stage_difficulty.gd")
const StageChallenges = preload("res://content/stage_challenges.gd")
const ModuleIcon = preload("res://ui/module_icon.gd")
const CYAN := Color("96eff4")
const PALE := Color("e7f6ff")
const MUTED := Color("a4c4d4")
const WARN := Color("f2c561")
## Roomy sizes; fit() gives them up in order on short screens.
const CRYSTAL_HEIGHT := 158.0
const CRYSTAL_MIN_HEIGHT := 64.0
const RECORD_HEIGHT := 28.0
const UNLOCK_ICON := 28.0
const STATUS_HEIGHT := 30.0
var rewards
var hud

func _init(owner) -> void:
	rewards = owner
	hud = owner.hud

static func frame() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var texture := Art.texture("results/ui/result_panel_frame_v2.png")
	style.texture = texture if texture != null else Art.texture("results/ui/result_panel_frame.png")
	style.set_texture_margin_all(18 if texture != null else 38)
	style.set_content_margin_all(20)
	return style

func build(state: Dictionary) -> void:
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.overlay_body.add_child(body)
	body.name = "ResultBody"
	body.add_theme_constant_override("separation",10)
	var success: bool = state.get("phase") == "success"
	var p: Dictionary = state.get("progression",{})
	var header := VBoxContainer.new(); header.name = "ResultHeader"
	header.add_theme_constant_override("separation",6); body.add_child(header)
	var crystal: TextureRect = rewards.reward_icon(header,"results/result_success_v2.png" if success else "results/result_failure_v2.png",150)
	crystal.name = "ResultCrystal"
	crystal.custom_minimum_size.y = CRYSTAL_HEIGHT
	var title := text(header,"Nexus 방어 성공" if success else "Nexus 붕괴",28,CYAN if success else Color("f8b5b3"),true)
	title.name = "ResultTitle"
	text(header,"스테이지 %s %s" % [Progression.stage_label(hud.app.stage+1),"클리어" if success else "종료"],16,CYAN if success else PALE,true).name = "ResultStage"
	_rule(body)
	body.get_child(body.get_child_count()-1).name = "ResultDivider"
	var rewards_group := _heading(body,"획득 보상","ResultRewards")
	var row := HBoxContainer.new(); row.name = "ResultRewards"
	row.add_theme_constant_override("separation",0)
	_section(rewards_group,row,"reward_summary_frame")
	var specs: Array = [["lastRunRuneReward","룬","stage_details/stats/rune_reward.png"]]
	for spec in [["lastRunCorePointReward","코어 포인트","stage_rewards/reward_core.png"],["lastRunTurretModuleTicketReward","모듈 티켓","stage_rewards/reward_module_ticket.png"]]:
		if int(p.get(spec[0],0)) > 0: specs.append(spec)
	for i in specs.size():
		if i > 0: _vertical_rule(row)
		var spec: Array = specs[i]
		var column := VBoxContainer.new(); column.name = str(spec[0])
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",1); row.add_child(column)
		var icon: TextureRect = rewards.reward_icon(column,spec[2],36); icon.name = "RewardIcon"
		var amount := text(column,"+"+HudNumber.compact_integer(int(p.get(spec[0],0))),24,PALE,true)
		amount.name = "RewardAmount"
		amount.tooltip_text = "+%d" % int(p.get(spec[0],0))
		text(column,spec[1],13,MUTED,true).name = "RewardCaption"
	var records_group := _heading(body,"전투 기록","ResultRecords")
	var records := VBoxContainer.new(); records.name = "ResultRecords"
	records.add_theme_constant_override("separation",0); _section(records_group,records,"section_frame")
	var best := StageDifficulty.best_rounds(p,hud.app.stage+1,StageDifficulty.of(state))
	var greatest := _highest_damage(state)
	var record_specs := [["도달 라운드","%dR" % int(state.get("completedRounds",0))],["기록",rewards._record_text(state,p,best)],["최고 피해",greatest],["현재 룬",HudNumber.compact_integer(int(p.get("runes",0)))]]
	for i in record_specs.size():
		if i > 0: _rule(records,Color("23505c88"))
		var line := HBoxContainer.new(); line.name = "Record%d" % i
		line.custom_minimum_size.y = RECORD_HEIGHT; line.add_theme_constant_override("separation",8); records.add_child(line)
		var label := text(line,record_specs[i][0],14,MUTED)
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var value := text(line,record_specs[i][1],14,PALE)
		value.add_theme_font_override("font",Art.font(700))
		value.name = "Value"; value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if i == 2: value.tooltip_text = _highest_damage(state,true)
		elif i == 3: value.tooltip_text = str(p.get("runes",0))
	# Server settlement is never shown; hard loot appears once it is known.
	if success and StageDifficulty.is_hard(state) and str(rewards._settlement_state().get("status","")) == "completed": _hard_loot(body)
	if success and state.get("lastRunChallengeAchieved", false): _challenge(body, state)
	if state.get("lastRunFirstClear",false): _unlocks(body,hud.app.stage+1)
	# Preserve generous terminal-result space even when rewards/unlocks are absent.
	var spacer := Control.new(); spacer.name = "ResultBreathingSpace"
	spacer.custom_minimum_size.y = 12 if state.get("lastRunFirstClear",false) else 64; body.add_child(spacer)
	spacer.set_meta("roomy_height", spacer.custom_minimum_size.y)
	_settlement(body)
	var actions := HBoxContainer.new(); actions.name = "ResultActions"
	actions.add_theme_constant_override("separation",10); body.add_child(actions)
	_action(actions,"다시 시작","restart_button_frame","ResultRestart",func(): await hud.app.retry_stage(); hud.refresh(),false)
	_action(actions,"스테이지 선택","confirm_button_frame","ResultStageSelect",func(): hud.app.open_stage_menu_destination(),true)

## Keeps the whole result on one screen without scrolling. Roomy sizes are
## restored first; then the breathing space, the gaps, section padding, row
## heights and last the crystal give way, one step at a time, until the body
## fits. A body that still overflows (extreme font scaling) keeps the overlay's
## scroll fallback.
static func fit(body: Control, available: float) -> void:
	var parts := {
		"header": body.get_node_or_null("ResultHeader"),
		"crystal": body.find_child("ResultCrystal", true, false),
		"spacer": body.get_node_or_null("ResultBreathingSpace"),
		"status": body.find_child("ResultSettlementStatus", true, false),
		"rows": body.find_children("Record?", "HBoxContainer", true, false),
		"frames": body.find_children("Result*Frame", "PanelContainer", true, false),
		"groups": body.get_children().filter(func(node): return str(node.name).ends_with("Group")),
		"unlocks": body.find_child("ResultUnlocks", true, false),
	}
	var spacer: Control = parts.spacer
	var roomy: float = spacer.get_meta("roomy_height", spacer.custom_minimum_size.y) if spacer != null else 0.0
	for level in 4:
		_compact(body, parts, level)
		if spacer != null: spacer.custom_minimum_size.y = roomy
		var over := body.get_combined_minimum_size().y - available
		if over <= 0: return
		if spacer != null:
			spacer.custom_minimum_size.y = maxf(0, roomy - over)
			if over <= roomy: return
	var crystal: Control = parts.crystal
	if crystal == null: return
	var height := maxf(CRYSTAL_MIN_HEIGHT, CRYSTAL_HEIGHT - (body.get_combined_minimum_size().y - available))
	crystal.custom_minimum_size = Vector2(minf(150, height), height)

## Level 0 is the roomy layout; each level tightens one more group.
static func _compact(body: Control, parts: Dictionary, level: int) -> void:
	body.add_theme_constant_override("separation", 7 if level >= 1 else 12)
	for group in parts.groups: group.add_theme_constant_override("separation", 3 if level >= 1 else 4)
	if parts.header != null: parts.header.add_theme_constant_override("separation", 2 if level >= 1 else 6)
	if parts.crystal != null: parts.crystal.custom_minimum_size = Vector2(150, CRYSTAL_HEIGHT)
	var margin := 6.0 if level >= 2 else 10.0
	for frame in parts.frames:
		var style: StyleBox = frame.get_theme_stylebox("panel")
		if style == null or is_equal_approx(style.content_margin_top, margin): continue
		var next: StyleBox = style.duplicate()
		next.content_margin_top = margin
		next.content_margin_bottom = margin
		frame.add_theme_stylebox_override("panel", next)
	if parts.status != null: parts.status.custom_minimum_size.y = 22.0 if level >= 3 else STATUS_HEIGHT
	for row in parts.rows: row.custom_minimum_size.y = 24.0 if level >= 3 else RECORD_HEIGHT
	if parts.unlocks != null:
		parts.unlocks.add_theme_constant_override("separation", 2 if level >= 3 else 4)
		var icon := 20.0 if level >= 3 else UNLOCK_ICON
		for row in parts.unlocks.get_children():
			if not row is HBoxContainer or row.get_child_count() == 0: continue
			var symbol: Control = row.get_child(0)
			symbol.custom_minimum_size = Vector2(icon, icon)
			# Material glyph icons are labels; their glyph follows the icon size.
			if symbol is Label: symbol.add_theme_font_size_override("font_size", int(icon * 24.0 / UNLOCK_ICON))

func text(parent: Node, value: String, font_size: int, color: Color, centered := false) -> Label:
	var label: Label = rewards._text(parent,value,font_size,centered)
	label.add_theme_color_override("font_color",color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

## A section heading kept close to its frame: the pair is one group so the gap
## between groups reads larger than the heading-to-frame gap.
func _heading(body: Node, title: String, base: String) -> VBoxContainer:
	var group := VBoxContainer.new(); group.name = base+"Group"
	group.add_theme_constant_override("separation",4); body.add_child(group)
	var label := text(group,title,15,CYAN)
	label.name = base+"Heading"
	label.add_theme_font_override("font",Art.font(800))
	return group

func _section(parent: Node, content: Control, _asset: String) -> void:
	var panel := PanelContainer.new()
	panel.name = content.name+"Frame"
	var style := StyleBoxTexture.new(); style.texture = Art.texture("results/ui/result_section_frame_v2.png")
	style.texture_margin_left = 10; style.texture_margin_right = 10
	style.texture_margin_top = 10; style.texture_margin_bottom = 10
	style.content_margin_left = 12; style.content_margin_right = 12
	style.content_margin_top = 10; style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel); panel.add_child(content)

func _rule(parent: Node, color := Color("59b3c188")) -> void:
	var line := HSeparator.new(); line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxLine.new(); style.color = color; style.thickness = 1
	line.add_theme_stylebox_override("separator",style); parent.add_child(line)

func _vertical_rule(parent: Node) -> void:
	var line := VSeparator.new(); line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxLine.new(); style.color = Color("35607199"); style.thickness = 1; style.vertical = true
	line.add_theme_stylebox_override("separator",style); parent.add_child(line)

func _highest_damage(state: Dictionary, exact := false) -> String:
	var damage := 0.0
	var tower_name := ""
	var runtime_turrets = hud.app.scene.combat_runtime.get("turrets")
	for turret in state.get("turrets",[]):
		var dealt := float(turret.get("damageDealt",0))
		if runtime_turrets is Dictionary and runtime_turrets.has(str(turret.id)):
			dealt = 0.0
			for field in ["directDamageDealt","splashDamageDealt","chainDamageDealt","burnDamageDealt"]:
				dealt += float(runtime_turrets[str(turret.id)].get(field,0))
		if dealt > damage: damage = dealt; tower_name = str(hud.TOWERS.get(turret.type,turret.type))
	return "%s %s" % [tower_name,String.num(damage,1) if exact else HudNumber.format_number(damage,{"small_decimals":1})] if damage > 0 else "기록 없음"

func _unlocks(body: Node, stage: int) -> void:
	var items: Array = Progression.unlock_items(stage)
	if items.is_empty(): return
	var group := _heading(body,"첫 클리어 해금","ResultUnlock")
	var rows := VBoxContainer.new(); rows.name = "ResultUnlocks"
	rows.add_theme_constant_override("separation",4); _section(group,rows,"section_frame")
	for i in items.size():
		if i > 0: _rule(rows,Color("23505c88"))
		var item: Array = items[i]
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",12); rows.add_child(row)
		if str(item[1]).begins_with("material:"):
			var symbol := text(row,char(str(item[1]).trim_prefix("material:").hex_to_int()),24,CYAN,true)
			symbol.custom_minimum_size = Vector2(UNLOCK_ICON,UNLOCK_ICON); symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			symbol.autowrap_mode = TextServer.AUTOWRAP_OFF
			symbol.add_theme_font_override("font",load("res://assets/ui/MaterialIcons-Regular.otf"))
		else: rewards.reward_icon(row,item[1],UNLOCK_ICON)
		text(row,"%s · %s" % [item[2],item[0]],14,PALE)

## A newly achieved stage challenge; its reward is claimed in the lobby dialog.
func _challenge(body: Node, state: Dictionary) -> void:
	var group := _heading(body,"도전과제 달성","ResultChallenge")
	var row := HBoxContainer.new(); row.name = "ResultChallenge"
	row.add_theme_constant_override("separation",12); _section(group,row,"section_frame")
	rewards.reward_icon(row,"lobby_challenge_icon.png",28)
	var words := VBoxContainer.new(); words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",0); row.add_child(words)
	var lines: Array = StageChallenges.lines(hud.app.stage+1)
	var hard := StageDifficulty.is_hard(state)
	text(words,"%s · %s" % ["하드" if hard else "노말", lines[0] if not lines.is_empty() else ""],14,PALE).name = "ResultChallengeCondition"
	text(words,"보상은 로비 업적에서 받을 수 있습니다",12,MUTED).name = "ResultChallengeClaim"

## Server-rolled repeat rewards of a hard clear, known only after settlement.
func _hard_loot(body: Node) -> void:
	var group := _heading(body,"하드 전리품","ResultHardLoot")
	var row := HBoxContainer.new(); row.name = "ResultHardLoot"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",10); _section(group,row,"section_frame")
	var status: Dictionary = rewards._settlement_state()
	var drops: Dictionary = status.get("hardRewards",{})
	if drops.is_empty():
		text(row,"이번에는 전리품이 없습니다",13,MUTED,true).name = "HardLootNone"
		return
	# Loot lands on a random turret, so each icon names its turret.
	for item in drops.get("modules",[]):
		var column := VBoxContainer.new(); column.name = "HardLootModule"
		column.add_theme_constant_override("separation",0); row.add_child(column)
		var art := ModuleIcon.create_art(item, 40)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(art)
		text(column,str(hud.TOWERS.get(item.turretType,item.turretType)),12,MUTED,true).autowrap_mode = TextServer.AUTOWRAP_OFF
	if int(drops.get("moduleTickets",0)) > 0:
		var ticket := VBoxContainer.new(); ticket.name = "HardLootTicket"
		ticket.add_theme_constant_override("separation",0); row.add_child(ticket)
		rewards.reward_icon(ticket,"stage_rewards/reward_module_ticket.png",40).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var amount := text(ticket,"모듈 티켓 +%d" % int(drops.moduleTickets),12,MUTED,true)
		amount.autowrap_mode = TextServer.AUTOWRAP_OFF

## Server settlement retries on its own and is never shown here; only a failed
## local save, which can lose the run's progress, asks the player to act.
func _settlement(body: Node) -> void:
	var status: Dictionary = rewards._settlement_state()
	if str(status.get("status","")) != "save_failed": return
	# One row, so a failed save never pushes the actions off a short screen.
	var row := HBoxContainer.new(); row.name = "ResultSettlement"
	row.add_theme_constant_override("separation",8); body.add_child(row)
	var label := text(row,"전투 기록 저장 실패",12,WARN)
	label.name = "ResultSettlementStatus"; label.custom_minimum_size.y = STATUS_HEIGHT
	label.tooltip_text = str(status.get("code",""))
	var button: Button = Art.button("저장 다시 시도",_retry_save,"secondary",true)
	button.name = "ResultSettlementRetry"; button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)

func _retry_save() -> void:
	hud.app.persist_progression()
	var services = hud.app.get("services")
	if services is Object and services.has_method("request_run_settlement"): services.request_run_settlement(true)
	hud.refresh()

func _action(parent: Node, caption: String, asset: String, node_name: String, callback: Callable, primary: bool) -> void:
	var button: Button = Art.button(caption,callback,"ghost",true)
	button.name = node_name; button.custom_minimum_size = Vector2(0,48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font",Art.font(900)); button.add_theme_font_size_override("font_size",15)
	var foreground := Color("04101a") if primary else PALE
	for role in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(role,foreground)
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxTexture.new(); style.texture = Art.texture("results/ui/"+asset+".png")
		style.set_texture_margin_all(0); style.set_content_margin_all(5)
		if state_name in ["hover","pressed"]: style.modulate_color = Color("c5ffff")
		if state_name == "disabled": style.modulate_color = Color("6e8891")
		button.add_theme_stylebox_override(state_name,style)
	parent.add_child(button)
	button.text = ""
	var content := HBoxContainer.new(); content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation",5); content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6; content.offset_right = -6
	var symbol := text(content,"›" if primary else "↻",22,foreground,true)
	symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; symbol.autowrap_mode = TextServer.AUTOWRAP_OFF
	var label := text(content,caption,16,foreground,true)
	label.add_theme_font_override("font",Art.font(900))
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; label.autowrap_mode = TextServer.AUTOWRAP_OFF
