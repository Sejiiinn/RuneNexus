extends RefCounted
const CoreHealthText = preload("res://ui/core_health_text.gd")
const HudNumber = preload("res://ui/hud_number.gd")
const Progression = preload("res://content/stage_progression.gd")
const UiWidgets = preload("res://ui/ui_widgets.gd")
const BattlefieldPath = preload("res://presentation/battlefield_path.gd")
const RARITY_NAMES := {"magic": "마법", "rare": "희귀"}
## Same tier hues as the battlefield bar frame and model rim.
const RARITY_COLORS := {"magic": Color("6f95ff"), "rare": Color("ffcc47")}
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
	var count: int = hud.app.catalog.wave_count(hud.app.stage)
	var index = int(state.get("completedRounds",0))
	if index >= count: UiWidgets.label(hud.body,"모든 웨이브를 완료했습니다.",12); return
	var wave: Dictionary = hud.app.catalog.wave_summary(hud.app.stage,index)
	# Same total-and-boss summary as the top enemy strip, scoped to this portal
	# on multi-entrance stages; the composition lives in the wave modal.
	var counts: Dictionary = wave.get("enemyCounts",{})
	var elites: Dictionary = wave.get("eliteCounts",{})
	var selected := _selected_portal_id()
	for section: Dictionary in _portal_sections(wave):
		if not selected.is_empty() and section.id == selected: counts = section.counts; elites = section.elites
	var total := 0
	var boss := false
	for type in counts:
		total += int(counts[type]); boss = boss or str(type).to_lower().contains("boss")
	# Read-only info like the core tile; only the composition link is a control.
	var title := UiWidgets.label(hud.body,_portal_title(),16); title.name = "PortalTitle"
	var row := HBoxContainer.new(); row.name = "PortalWaveRow"; row.add_theme_constant_override("separation",0); hud.body.add_child(row)
	var info := UiWidgets.label(row,"웨이브 %d/%d · %s" % [index+1,count,"%s기" % HudNumber.compact_integer(total) if total > 0 else "출현 없음"],13)
	info.name = "PortalWaveSummary"; info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; info.add_theme_color_override("font_color",Color("b7d5e3"))
	if boss:
		var boss_label := UiWidgets.label(row," · 보스",13); boss_label.name = "PortalWaveBoss"
		boss_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; boss_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; boss_label.add_theme_color_override("font_color",Color("ff6b6b"))
	var tier := top_rarity(elites)
	if not tier.is_empty():
		var tier_label := UiWidgets.label(row," · "+RARITY_NAMES[tier],13); tier_label.name = "PortalWaveRarity"
		tier_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; tier_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; tier_label.add_theme_color_override("font_color",RARITY_COLORS[tier])
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(spacer)
	var details := UiWidgets.button(row,"구성 보기 ›",func(): _portal_details(wave,index))
	details.name = "PortalWaveDetails"; details.custom_minimum_size.y = 28
	UiWidgets.style_hud_button(details,"quiet",false,Vector2(8,2))
	details.disabled = not str(state.phase) in ["preparation","wave"]

func _selected_portal_id() -> String:
	var portals: Array = hud.app.catalog.spawn_portals(hud.app.stage)
	if portals.size() < 2: return ""
	for portal: Dictionary in portals:
		var cell: Array = portal.cell
		if Vector2i(int(cell[0]),int(cell[1])) == hud.app.selected: return str(portal.id)
	return ""

func _portal_title() -> String:
	for portal: Dictionary in hud.app.catalog.spawn_portals(hud.app.stage):
		var cell: Array = portal.cell
		if Vector2i(int(cell[0]),int(cell[1])) == hud.app.selected:
			var label := str(portal.get("label",""))
			# Authored labels already lead with the portal id ("A·서쪽"), as in the wave modal.
			return "포탈 " + (label if not label.is_empty() else str(portal.id)) if portal.id != "default" else "포탈 1"
	return "출현 경로" if hud.app.catalog.stage_map(hud.app.stage).has("spawnPortals") else "포탈 1"

# Multi-entrance stages split the composition per portal; a single entrance is
# one unnamed section. Counts come from the compiled dispatch groups.
func _portal_sections(wave: Dictionary) -> Array:
	var stage_portals: Array = hud.app.catalog.spawn_portals(hud.app.stage)
	var single := stage_portals.size() < 2
	var sections: Array = []
	if single: sections.append({"id":"","label":"","counts":wave.get("enemyCounts",{}).duplicate(),"elites":{},"variants":{}})
	else:
		for portal: Dictionary in stage_portals:
			sections.append({"id":str(portal.id),"label":str(portal.get("label","")),"counts":{},"elites":{},"variants":{}})
	# Magic/rare members and their authored affixes follow the owning group's portal.
	var elite_spawns: Dictionary = wave.get("eliteSpawns",{})
	for group: Dictionary in wave.get("routeGroups",[]):
		var section: Dictionary = sections[0]
		for candidate: Dictionary in sections:
			if candidate.id == str(group.get("spawnPortalId","")): section = candidate
		var type := str(group.enemyType)
		if not single: section.counts[type] = int(section.counts.get(type,0))+int(group.count)
		for spawn_index in group.spawnIndices:
			if not elite_spawns.has(int(spawn_index)): continue
			var elite: Dictionary = elite_spawns[int(spawn_index)]
			if not section.elites.has(type): section.elites[type] = {}
			section.elites[type][elite.rarity] = int(section.elites[type].get(elite.rarity,0))+1
			if not section.variants.has(type): section.variants[type] = []
			var merged := false
			for variant: Dictionary in section.variants[type]:
				if variant.rarity == elite.rarity and variant.affixes == elite.affixes: variant.count += 1; merged = true
			if not merged: section.variants[type].append({"rarity":elite.rarity,"affixes":elite.affixes,"count":1})
	return sections

func _rarity_tooltip(rarity: String) -> String:
	var rules: Dictionary = hud.app.catalog.enemy_rarity_rules().get("rarities",{}).get(rarity,{})
	if rules.is_empty(): return RARITY_NAMES[rarity]
	var count: Array = rules.affixCount
	var options := "옵션 %d개" % int(count[0]) if int(count[0]) == int(count[1]) else "옵션 %d~%d개" % [int(count[0]),int(count[1])]
	return "%s 몬스터 · 체력 ×%s · %s · 처치 골드 ×%d" % [RARITY_NAMES[rarity],str(snappedf(float(rules.maxHpMultiplier),0.01)),options,int(rules.rewardGoldMultiplier)]

static func _rarity_pips(rarity: String) -> Control:
	var pips := Control.new(); pips.name = "RarityPips"; pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count := 2 if rarity == "rare" else 1
	pips.custom_minimum_size = Vector2(6.0 + (count - 1) * 7.0, 12.0)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var color: Color = RARITY_COLORS[rarity]
	pips.draw.connect(func():
		for pip in range(count):
			var c := Vector2(3.0 + pip * 7.0, 6.0)
			pips.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(3, 0), c + Vector2(0, 4), c + Vector2(-3, 0)]), color))
	return pips

## Highest magic/rare tier in a {type: {rarity: count}} map, or "".
static func top_rarity(elites: Dictionary) -> String:
	var result := ""
	for type in elites:
		if elites[type].has("rare"): return "rare"
		if elites[type].has("magic"): result = "magic"
	return result

func _portal_details(wave: Dictionary,index: int) -> void:
	var box = hud.open_modal("웨이브 %d/%d" % [index+1,hud.app.catalog.wave_count(hud.app.stage)],720,true,true,Color("b16dff"))
	var header: HBoxContainer = box.get_child(0)
	var icon = UiWidgets.material_icon(header,0xe283,20); icon.modulate = Color("e3b7ff"); header.move_child(icon,0)
	# A single entrance needs no portal heading.
	for section: Dictionary in _portal_sections(wave):
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
		_wave_enemy_rows(box,section.counts,index,str(section.id),section.variants)

func _wave_enemy_rows(box: VBoxContainer,counts: Dictionary,index: int,portal: String,variants: Dictionary = {}) -> void:
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
		# Magic/rare members sit below the stats, apart from the damage-taken tags,
		# with the battlefield bar's pip shape (1 magic, 2 rare) before the tier.
		var affix_rules: Dictionary = hud.app.catalog.enemy_rarity_rules().get("affixes",{})
		for variant: Dictionary in variants.get(type,[]):
			var affix_names: PackedStringArray = []
			for affix in variant.affixes: affix_names.append(str(affix_rules.get(affix,{}).get("name",affix)))
			var line := HBoxContainer.new(); line.name = "WaveEnemyRarity_"+str(variant.rarity)
			line.add_theme_constant_override("separation",5); line.tooltip_text = _rarity_tooltip(variant.rarity); row.add_child(line)
			line.add_child(_rarity_pips(variant.rarity))
			var text := "%s%s · %s" % [RARITY_NAMES[variant.rarity]," ×%d" % int(variant.count) if int(variant.count) > 1 else "","·".join(affix_names)]
			var variant_label: Label = UiWidgets.label(line,text,12)
			variant_label.name = "WaveEnemyAffixes"; variant_label.mouse_filter = Control.MOUSE_FILTER_PASS
			variant_label.add_theme_color_override("font_color",RARITY_COLORS[variant.rarity])

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
