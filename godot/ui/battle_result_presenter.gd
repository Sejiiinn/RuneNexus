extends RefCounted
## Result presentation reads the finished run; reward ownership stays in services.
const Art = preload("res://ui/app_theme.gd")
const Progression = preload("res://content/stage_progression.gd")
const CYAN := Color("96eff4")
const PALE := Color("e7f6ff")
const MUTED := Color("a4c4d4")
const WARN := Color("f2c561")
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
	var crystal: TextureRect = rewards._icon(header,"results/result_success_v2.png" if success else "results/result_failure_v2.png",150)
	crystal.name = "ResultCrystal"
	crystal.custom_minimum_size.y = 158
	var title := text(header,"Nexus 방어 성공" if success else "Nexus 붕괴",28,CYAN if success else Color("f8b5b3"),true)
	title.name = "ResultTitle"
	text(header,"스테이지 %s %s" % [Progression.stage_label(hud.app.stage+1),"클리어" if success else "종료"],16,CYAN if success else PALE,true).name = "ResultStage"
	_rule(body)
	body.get_child(body.get_child_count()-1).name = "ResultDivider"
	text(body,"획득 보상",15,CYAN).name = "ResultRewardsHeading"
	var row := HBoxContainer.new(); row.name = "ResultRewards"
	row.add_theme_constant_override("separation",0)
	_section(body,row,"reward_summary_frame")
	var specs: Array = [["lastRunRuneReward","룬","stage_details/stats/rune_reward.png"]]
	for spec in [["lastRunCorePointReward","코어 포인트","stage_rewards/reward_core.png"],["lastRunTurretModuleTicketReward","모듈 티켓","stage_rewards/reward_module_ticket.png"]]:
		if int(p.get(spec[0],0)) > 0: specs.append(spec)
	for i in specs.size():
		if i > 0: _vertical_rule(row)
		var spec: Array = specs[i]
		var column := VBoxContainer.new(); column.name = str(spec[0])
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",1); row.add_child(column)
		var icon: TextureRect = rewards._icon(column,spec[2],36); icon.name = "RewardIcon"
		text(column,"+%d" % int(p.get(spec[0],0)),24,PALE,true).name = "RewardAmount"
		text(column,spec[1],13,MUTED,true).name = "RewardCaption"
		if spec[0] == "lastRunTurretModuleTicketReward":
			var kind := str(rewards._settlement_state().get("status",""))
			var caption := str({"requesting":"정산 중","completed":"정산 완료","retry":"정산 실패","queued":"정산 준비 중","offline":"연결 필요","guest":"게스트 정산 제외","save_failed":"저장 실패","rejected":"정산 거절"}.get(kind,""))
			text(column,caption.replace("게스트 정산 제외","게스트\n정산 제외"),11,MUTED if kind == "completed" else WARN,true).name = "TicketSettlementStatus"
	text(body,"전투 기록",15,CYAN).name = "ResultRecordsHeading"
	var records := VBoxContainer.new(); records.name = "ResultRecords"
	records.add_theme_constant_override("separation",0); _section(body,records,"section_frame")
	var best := int(p.get("bestRoundsByStage",{}).get(str(hud.app.stage+1),0))
	var greatest := _highest_damage(state)
	var record_specs := [["도달 라운드","%dR" % int(state.get("completedRounds",0))],["기록",rewards._record_text(state,p,best)],["최고 피해",greatest],["현재 룬",str(p.get("runes",0))]]
	for i in record_specs.size():
		if i > 0: _rule(records,Color("23505c88"))
		var line := HBoxContainer.new(); line.name = "Record%d" % i
		line.custom_minimum_size.y = 25; line.add_theme_constant_override("separation",8); records.add_child(line)
		var label := text(line,record_specs[i][0],13,MUTED)
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var value := text(line,record_specs[i][1],13,PALE)
		value.name = "Value"; value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if state.get("lastRunFirstClear",false): _unlocks(body,hud.app.stage+1)
	# Preserve generous terminal-result space even when rewards/unlocks are absent.
	var spacer := Control.new(); spacer.name = "ResultBreathingSpace"
	spacer.custom_minimum_size.y = 12 if state.get("lastRunFirstClear",false) else 64; body.add_child(spacer)
	_settlement(body)
	var actions := HBoxContainer.new(); actions.name = "ResultActions"
	actions.add_theme_constant_override("separation",10); body.add_child(actions)
	_action(actions,"다시 시작","restart_button_frame","ResultRestart",func(): await hud.app.retry_stage(); hud.refresh(),false)
	_action(actions,"스테이지 선택","confirm_button_frame","ResultStageSelect",func(): hud.app.open_stage_menu_destination(),true)

func text(parent: Node, value: String, font_size: int, color: Color, centered := false) -> Label:
	var label: Label = rewards._text(parent,value,font_size,centered)
	label.add_theme_color_override("font_color",color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

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

func _highest_damage(state: Dictionary) -> String:
	var damage := 0.0
	var tower_name := ""
	var runtime_turrets = hud.app.scene._native_combat.get("turrets")
	for turret in state.get("turrets",[]):
		var dealt := float(turret.get("damageDealt",0))
		if runtime_turrets is Dictionary and runtime_turrets.has(str(turret.id)):
			dealt = 0.0
			for field in ["directDamageDealt","splashDamageDealt","chainDamageDealt","burnDamageDealt"]:
				dealt += float(runtime_turrets[str(turret.id)].get(field,0))
		if dealt > damage: damage = dealt; tower_name = str(hud.TOWERS.get(turret.type,turret.type))
	return "%s %s" % [tower_name,String.num(damage,1)] if damage > 0 else "기록 없음"

func _unlocks(body: Node, stage: int) -> void:
	var items: Array = Progression.unlock_items(stage)
	if items.is_empty(): return
	text(body,"첫 클리어 해금",15,CYAN).name = "ResultUnlockHeading"
	var rows := VBoxContainer.new(); rows.name = "ResultUnlocks"
	rows.add_theme_constant_override("separation",4); _section(body,rows,"section_frame")
	for i in items.size():
		if i > 0: _rule(rows,Color("23505c88"))
		var item: Array = items[i]
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",12); rows.add_child(row)
		if str(item[1]).begins_with("material:"):
			var symbol := text(row,char(str(item[1]).trim_prefix("material:").hex_to_int()),24,CYAN,true)
			symbol.custom_minimum_size = Vector2(28,28); symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			symbol.add_theme_font_override("font",load("res://assets/ui/MaterialIcons-Regular.otf"))
		else: rewards._icon(row,item[1],28)
		text(row,"%s · %s" % [item[2],item[0]],13,PALE)

func _settlement(body: Node) -> void:
	var status: Dictionary = rewards._settlement_state()
	var kind := str(status.get("status",""))
	var note: String = rewards._settlement_note()
	if kind == "guest": note = note.replace(" · ","\n")
	var label := text(body,note,12,WARN if kind in ["retry","offline","guest","save_failed","rejected"] else MUTED,true)
	label.name = "ResultSettlementStatus"; label.custom_minimum_size.y = 30
	label.tooltip_text = str(status.get("code",""))
	if kind in ["retry","offline","save_failed"]:
		var button: Button = Art.button("저장 다시 시도" if kind == "save_failed" else "정산 다시 시도",func(): _retry_settlement(kind),"secondary",true)
		button.name = "ResultSettlementRetry"; body.add_child(button)

func _retry_settlement(kind: String) -> void:
	if kind == "save_failed": hud.app.persist_progression()
	var services = hud.app.get("services")
	if services is Object:
		if kind == "offline" and services.has_method("retry"): await services.retry()
		if services.has_method("request_run_settlement"): services.request_run_settlement(true)
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
	var symbol := text(content,"›" if primary else "↻",28,foreground,true)
	symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; symbol.autowrap_mode = TextServer.AUTOWRAP_OFF
	var label := text(content,caption,14,foreground,true)
	label.add_theme_font_override("font",Art.font(900))
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; label.autowrap_mode = TextServer.AUTOWRAP_OFF
