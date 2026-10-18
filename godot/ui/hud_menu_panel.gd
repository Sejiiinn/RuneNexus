extends RefCounted
const CoreHealthText = preload("res://ui/core_health_text.gd")
const HudNumber = preload("res://ui/hud_number.gd")
const Progression = preload("res://content/stage_progression.gd")
const UiWidgets = preload("res://ui/ui_widgets.gd")
const BattlefieldPath = preload("res://presentation/battlefield_path.gd")
## Stage menus and board details; modal lifetime remains HUD-owned.
## Reads the live HUD owner; no selection, snapshot or cache copies.
var hud: Control

func _init(owner: Control) -> void:
	hud = owner

func _stage_menu() -> void:
	if hud.app.run_domain.state.get("phase") == "reward": return
	var box = hud.open_modal("스테이지 메뉴",390)
	var header: HBoxContainer = box.get_child(0)
	var icon = UiWidgets.material_icon(header,0xf107,20); header.move_child(icon,0)
	var actions: BoxContainer = VBoxContainer.new() if hud.get_viewport_rect().size.x < 380 else HBoxContainer.new(); actions.add_theme_constant_override("separation",8); box.add_child(actions)
	var end = _action(actions,"스테이지 종료",_end_stage_confirm,"danger")
	end.size_flags_stretch_ratio = 5
	end.disabled = not _has_stage_progress() or hud.app.run_domain.state.phase in ["success","failure"]
	_action(actions,"저장하고 나가기",_save_to_stage,"primary").size_flags_stretch_ratio = 6
	UiWidgets.label(box,"진행 상황을 저장하고 스테이지 선택으로 돌아갑니다.",12)

func _has_stage_progress() -> bool:
	var state: Dictionary = hud.app.run_domain.state
	if int(state.get("roundIndex",0))>0 or int(state.get("completedRounds",0))>0 or not state.get("turrets",[]).is_empty() or state.get("phase") in ["wave","reward","restored"]: return true
	if not state.get("runUpgradeLevels",{}).is_empty() or int(state.get("savedTurretCountForMenu",0))>0: return true
	var runtime = hud.app.scene.combat_runtime
	var enemies = runtime.get("enemies")
	if enemies != null and not enemies.is_empty(): return true
	var wave = runtime.get("wave")
	if wave != null and not wave.is_empty(): return true
	return float(state.get("killGoldFractionWallet",0))>0 or not state.get("rewardOptions",[]).is_empty()

func _projected_failure_reward() -> int:
	var state: Dictionary = hud.app.run_domain.state
	var estimate: Dictionary = hud.app.run_domain.quests.finish(state.progression,{"stageNumber":hud.app.stage+1,"completedRounds":int(state.get("completedRounds",0)),"success":false,"runeResonanceBonusRate":float(hud.configuration_cache.derived(state,hud.app.run_domain.service).get("runeResonanceBonusRate",0.0))})
	return int(estimate.lastRunRuneReward)

func _end_stage_confirm() -> void:
	var box = hud.open_modal("전투를 종료할까요?",390,false,true,Color("ff7043"),"danger")
	var header: HBoxContainer = box.get_child(0)
	var flag = UiWidgets.material_icon(header,0xf07b,20); flag.modulate = Color("ff7043"); header.move_child(flag,0)
	var reward = _projected_failure_reward()
	var explanation = UiWidgets.label(box,"현재 전투를 종료하고 보상을 정산합니다.",12)
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var summary = VBoxContainer.new(); summary.name = "EndRewardSummary"; summary.add_theme_constant_override("separation",6); box.add_child(summary)
	var reward_title = UiWidgets.label(summary,"예상 보상",12)
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var reward_row = HBoxContainer.new(); reward_row.alignment = BoxContainer.ALIGNMENT_CENTER; reward_row.add_theme_constant_override("separation",10); summary.add_child(reward_row)
	UiWidgets.icon(reward_row,"ui/hud/icons/rune.png",32)
	var amount = UiWidgets.label(reward_row,"+%s 룬" % HudNumber.compact_integer(reward),26)
	amount.tooltip_text = "+%d 룬" % reward
	amount.name = "EndRewardAmount"; amount.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; amount.autowrap_mode = TextServer.AUTOWRAP_OFF; amount.modulate = Color("ffd166")
	var completed = UiWidgets.label(summary,"완료 %d웨이브 기준" % int(hud.app.run_domain.state.get("completedRounds",0)),12)
	completed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap = Control.new(); gap.custom_minimum_size.y = 4; box.add_child(gap)
	var actions = HBoxContainer.new(); actions.name = "EndConfirmActions"; actions.add_theme_constant_override("separation",8); box.add_child(actions)
	_action(actions,"계속 진행",hud.close_modal,"secondary")
	_action(actions,"전투 종료",_end_to_stage,"danger")

func _save_to_stage() -> void:
	if hud.app.open_stage_menu_destination():
		hud.modal_resume = false
		hud.close_modal()

func _end_to_stage() -> void:
	if await hud.app.abandon_run():
		hud.modal_resume = false
		hud.close_modal()

func _action(parent: Node,value: String,callback: Callable,variant: String) -> Button:
	var button = hud.AppTheme.button(value,callback,variant)
	hud.Components.apply(button,variant)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	var glyph: int = {"스테이지 종료":0xf07b,"전투 종료":0xf07b,"저장하고 나가기":0xf107,"계속 진행":0xe092}.get(value,0)
	if glyph != 0:
		var content = HBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.alignment = BoxContainer.ALIGNMENT_CENTER; button.add_child(content); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		UiWidgets.material_icon(content,glyph,17)
		var caption = Label.new(); caption.text = value; caption.mouse_filter = Control.MOUSE_FILTER_IGNORE; caption.add_theme_font_override("font",hud.AppTheme.font(800)); caption.add_theme_font_size_override("font_size",13); content.add_child(caption)
		for role in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]: button.add_theme_color_override(role,Color.TRANSPARENT)
		button.draw.connect(func():
			var color = Color("e8f8ff")
			content.modulate = Color(color,0.48 if button.disabled else 1.0))
	return button

func _board_detail(tile: String,state: Dictionary) -> void:
	if tile == "core":
		UiWidgets.label(hud.body,"코어 방어",16)
		var defense = hud.app.scene.combat_runtime.defense
		hud.core_label = UiWidgets.label(hud.body,"체력 "+CoreHealthText.combined_numbers(defense),13)
		var bar = preload("res://ui/core_health_bar.gd").new(); CoreHealthText.update_bar(bar,defense); bar.custom_minimum_size.y = 10; hud.body.add_child(bar); hud.core_bar = bar
		hud.core_metric = UiWidgets.label(hud.body,"",12)
		return
	var preparing: bool = state.phase == "preparation"
	var count: int = hud.app.catalog.wave_count(hud.app.stage)
	var index = int(state.get("completedRounds",0))
	if index >= count: UiWidgets.label(hud.body,"모든 웨이브를 완료했습니다.",12); return
	var wave: Dictionary = hud.app.catalog.wave_summary(hud.app.stage,index)
	var summary = UiWidgets.button(hud.body,(_portal_title() if preparing else "전투 진행 중")+"\n"+(str(wave.get("previewText",""))+" · %d/%d" % [index+1,count] if preparing else "진행 상태 확인"),func(): _portal_details(wave,index))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.disabled = not preparing

func _portal_title() -> String:
	for portal: Dictionary in hud.app.catalog.spawn_portals(hud.app.stage):
		var cell: Array = portal.cell
		if Vector2i(int(cell[0]),int(cell[1])) == hud.app.selected:
			var label := str(portal.get("label",""))
			return "포탈 " + str(portal.id) + (" · " + label if not label.is_empty() else "") if portal.id != "default" else "포탈 1"
	return "출현 경로" if hud.app.catalog.stage_map(hud.app.stage).has("spawnPortals") else "포탈 1"

func _portal_details(wave: Dictionary,index: int) -> void:
	var box = hud.open_modal("웨이브 %d/%d" % [index+1,hud.app.catalog.wave_count(hud.app.stage)],720,true,true,Color("b16dff"))
	var header: HBoxContainer = box.get_child(0)
	var icon = UiWidgets.material_icon(header,0xe283,20); icon.modulate = Color("e3b7ff"); header.move_child(icon,0)
	# Multi-entrance stages group the composition under each portal; a single
	# entrance needs no heading. Counts come from the compiled dispatch groups.
	var counts: Dictionary = wave.get("enemyCounts",{})
	var stage_portals: Array = hud.app.catalog.spawn_portals(hud.app.stage)
	var sections: Array = [{"id":"","label":"","counts":counts}]
	if stage_portals.size() > 1:
		sections = []
		for portal: Dictionary in stage_portals:
			sections.append({"id":str(portal.id),"label":str(portal.get("label","")),"counts":{}})
		for group: Dictionary in wave.get("routeGroups",[]):
			var id := str(group.get("spawnPortalId",""))
			var section: Dictionary = sections[0]
			for candidate: Dictionary in sections:
				if candidate.id == id: section = candidate
			section.counts[str(group.enemyType)] = int(section.counts.get(str(group.enemyType),0))+int(group.count)
	for section: Dictionary in sections:
		if section.counts.is_empty(): continue
		if not str(section.id).is_empty():
			if box.get_child_count() > 2:
				var gap := Control.new(); gap.custom_minimum_size.y = 8; gap.mouse_filter = Control.MOUSE_FILTER_IGNORE; box.add_child(gap)
			# Same per-portal tint as the battlefield route guides (first origin cyan).
			var primary := str(hud.app.catalog.spawn_portal(hud.app.stage).get("id",""))
			var tint: Color = BattlefieldPath.PRIMARY_COLOR if str(section.id) == primary else BattlefieldPath.SECONDARY_COLOR
			var heading := HBoxContainer.new(); heading.name = "WavePortal_"+str(section.id); heading.add_theme_constant_override("separation",5); box.add_child(heading)
			var mark: Label = UiWidgets.material_icon(heading,0xe283,16); mark.name = "PortalMark"; mark.modulate = tint
			mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var portal_name: Label = UiWidgets.label(heading,"포탈 "+(str(section.label) if not str(section.label).is_empty() else str(section.id)),12)
			portal_name.add_theme_font_override("font",hud.AppTheme.font(800)); portal_name.add_theme_color_override("font_color",tint)
		_wave_enemy_rows(box,section.counts,index,str(section.id))

func _wave_enemy_rows(box: VBoxContainer,counts: Dictionary,index: int,portal: String) -> void:
	var types: Array = counts.keys().filter(func(type): return str(type).to_lower().contains("boss"))
	types.append_array(counts.keys().filter(func(type): return not str(type).to_lower().contains("boss")))
	var names = {"physical":"물리","elemental":"원소","light":"경량화기","heavy":"중화기","damageOverTime":"지속피해","cooling":"냉각"}
	for position in types.size():
		var type: String = types[position]
		if position > 0:
			var divider := HSeparator.new(); divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var line := StyleBoxLine.new(); line.color = Color("52708088"); line.thickness = 1
			divider.add_theme_stylebox_override("separator",line); box.add_child(divider)
		var enemy: Dictionary = hud.app.catalog.enemy_template(type)
		var durability: Dictionary = hud.app.catalog.wave_durability(hud.app.stage,index,type)
		var row := VBoxContainer.new(); row.name = "WaveEnemy_"+(portal+"_" if not portal.is_empty() else "")+type
		row.add_theme_constant_override("separation",2); box.add_child(row)
		# Damage-taken modifiers sit beside the name as compact tags.
		var heading := HFlowContainer.new(); heading.name = "WaveEnemyHeading"; heading.add_theme_constant_override("h_separation",6); heading.add_theme_constant_override("v_separation",3); row.add_child(heading)
		var name_label: Label = UiWidgets.label(heading,"%s ×%d" % [enemy.get("name",type),int(counts[type])],13)
		name_label.name = "WaveEnemyName"; name_label.autowrap_mode = TextServer.AUTOWRAP_OFF; name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font",hud.AppTheme.font(800))
		if type.to_lower().contains("boss"): name_label.add_theme_color_override("font_color",Color("ff6b6b"))
		var stats: PackedStringArray = ["체력 "+HudNumber.compact_integer(roundi(float(durability.get("maxHp",enemy.get("maxHp",0)))))]
		for spec in [["방어구","maxArmor"],["보호막","maxShield"]]:
			if float(durability.get(spec[1],0))>0: stats.append(spec[0]+" "+HudNumber.compact_integer(roundi(float(durability[spec[1]]))))
		stats.append("속도 "+str(roundi(float(enemy.get("speed",0)))))
		# Resistance r scales damage by (1-r); each tag states the damage taken.
		for field in ["familyResistances","tagResistances"]:
			for kind in enemy.get(field,{}):
				var value := float(enemy[field][kind])
				if value == 0: continue
				var change := "%s%d%%" % ["-" if value>0 else "+",absi(roundi(value*100))]
				UiWidgets.stat_pill(heading,str(names.get(kind,kind)),change,Color("ff8a8a") if value>0 else Color("9fffe8"))
				var tag: Control = heading.get_child(heading.get_child_count()-1)
				tag.name = "WaveEnemyDamageTaken"; tag.tooltip_text = "%s 받는 피해 %s" % [names.get(kind,kind),change]
		UiWidgets.label(row," · ".join(stats),12).add_theme_color_override("font_color",Color("b7d5e3"))

func _refresh_core() -> void:
	if not is_instance_valid(hud.core_label): return
	var runtime = hud.app.scene.combat_runtime
	hud.core_label.text = "체력 "+CoreHealthText.combined_numbers(runtime.defense)
	hud.core_label.tooltip_text = CoreHealthText.tooltip(runtime.defense)
	CoreHealthText.update_bar(hud.core_bar,runtime.defense)
	var core = runtime.get("core")
	if core == null: hud.core_metric.text = "전투 스킬 없음"; return
	if core.skill == "guardianBeam":
		var damage: float = maxf(float(core.config.get("normalMaxHp",0))*float(core.config.get("guardianMinNormalHpRate",0.1)),hud.total_dps*float(core.config.get("guardianBeamInterval",5))*float(core.config.get("guardianDpsRate",0.08)))*core.power_for_activation(core.activation_count+1)
		hud.core_metric.text = "수호 광선 · 코어에 가까운 적에게 집중 피해\n광선 피해 %s    총 피해 %s" % [HudNumber.compact(damage),HudNumber.compact(core.direct_damage_dealt)]
		hud.core_metric.tooltip_text = "광선 피해 %.1f · 총 피해 %.1f" % [damage,core.direct_damage_dealt]
	elif core.skill == "riftMark":
		var power: float = 25.0*core.power_for_activation(core.activation_count+1)
		hud.core_metric.text = "균열 낙인 · 내구도 높은 적 4명\n다음 낙인 %.1f%% 증폭 (보스 %.1f%%)\n총 추가 피해 %s" % [power,power/2.0,HudNumber.compact(core.bonus_damage_dealt)]
		hud.core_metric.tooltip_text = "총 추가 피해 %.1f" % core.bonus_damage_dealt
	else: hud.core_metric.text = "전투 스킬 없음\n코어 전투 스킬이 장착되어 있지 않습니다."
