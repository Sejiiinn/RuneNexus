extends RefCounted
## Stage menus and board details; modal lifetime remains HUD-owned.
## Reads the live HUD owner; no selection, snapshot or cache copies.
var hud: Control

func _init(owner: Control) -> void:
	hud = owner

func _stage_menu() -> void:
	if hud.app.run_domain.state.get("phase") == "reward": return
	var box = hud.open_modal("스테이지 메뉴",390)
	var header: HBoxContainer = box.get_child(0)
	var icon = hud._material_icon(header,0xf107,20); header.move_child(icon,0)
	var actions: BoxContainer = VBoxContainer.new() if hud.get_viewport_rect().size.x < 380 else HBoxContainer.new(); actions.add_theme_constant_override("separation",8); box.add_child(actions)
	var end = _action(actions,"스테이지 종료",_end_stage_confirm,"danger")
	end.size_flags_stretch_ratio = 5
	end.disabled = not _has_stage_progress() or hud.app.run_domain.state.phase in ["success","failure"]
	_action(actions,"저장하고 나가기",_save_to_stage,"primary").size_flags_stretch_ratio = 6
	hud._label(box,"진행 상황을 저장하고 스테이지 선택으로 돌아갑니다.",12)

func _has_stage_progress() -> bool:
	var state: Dictionary = hud.app.run_domain.state
	if int(state.get("roundIndex",0))>0 or int(state.get("completedRounds",0))>0 or not state.get("turrets",[]).is_empty() or state.get("phase") in ["wave","reward","restored"]: return true
	if not state.get("runUpgradeLevels",{}).is_empty() or int(state.get("savedTurretCountForMenu",0))>0: return true
	var runtime = hud.app.scene._native_combat
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
	var box = hud.open_modal("정말 종료할까요?",340,false,false,Color("ff7043"),"danger")
	var header: HBoxContainer = box.get_child(0)
	var flag = hud._material_icon(header,0xf07b,20); flag.modulate = Color("ff7043"); header.move_child(flag,0)
	var reward = _projected_failure_reward()
	hud._label(box,"스테이지 %d 진행을 종료하고 +%d 룬을 정산합니다." % [hud.app.stage+1,reward],12)
	var panel = PanelContainer.new(); panel.add_theme_stylebox_override("panel",hud.BattleTheme.box(Color("272116"),Color("88785835"),14)); box.add_child(panel)
	var summary = VBoxContainer.new(); panel.add_child(summary)
	var reward_title = HBoxContainer.new(); summary.add_child(reward_title)
	hud._rune_icon(reward_title,24)
	hud._label(reward_title,"종료 시 보상",12)
	hud._stat_pill(reward_title,"정산 예상","",Color("e7c66a"))
	var reward_row = HBoxContainer.new(); summary.add_child(reward_row)
	hud._label(reward_row,"%d웨이브 기준" % int(hud.app.run_domain.state.get("completedRounds",0)),12)
	hud._rune_icon(reward_row,22)
	hud._label(reward_row,"+%d 룬" % reward,26).modulate = Color("ffd166")
	var actions: BoxContainer = VBoxContainer.new() if hud.get_viewport_rect().size.x < 380 else HBoxContainer.new(); box.add_child(actions)
	_action(actions,"계속 진행",hud.close_modal,"ghost")
	_action(actions,"종료",_end_to_stage,"danger")

func _save_to_stage() -> void:
	if hud.app.open_stage_menu_destination():
		hud.modal_resume = false
		hud.close_modal()

func _end_to_stage() -> void:
	if hud.app.abandon_run():
		hud.modal_resume = false
		hud.close_modal()

func _action(parent: Node,value: String,callback: Callable,variant: String) -> Button:
	var button = hud.AppTheme.button(value,callback,variant)
	hud.Components.apply(button,variant)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	var glyph: int = {"스테이지 종료":0xf07b,"종료":0xf07b,"저장하고 나가기":0xf107,"계속 진행":0xe092}.get(value,0)
	if glyph != 0:
		var content = HBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.alignment = BoxContainer.ALIGNMENT_CENTER; button.add_child(content); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud._material_icon(content,glyph,17)
		var caption = Label.new(); caption.text = value; caption.mouse_filter = Control.MOUSE_FILTER_IGNORE; caption.add_theme_font_override("font",hud.AppTheme.font(800)); caption.add_theme_font_size_override("font_size",13); content.add_child(caption)
		for role in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]: button.add_theme_color_override(role,Color.TRANSPARENT)
		button.draw.connect(func():
			var color = Color("e8f8ff")
			content.modulate = Color(color,0.48 if button.disabled else 1.0))
	return button

func _board_detail(tile: String,state: Dictionary) -> void:
	if tile == "core":
		hud._label(hud.body,"코어 방어",16)
		var defense = hud.app.scene._native_combat.defense
		hud.core_label = hud._label(hud.body,"체력 %d / %d" % [ceili(defense.hp),ceili(defense.max_hp)],13)
		var bar = ProgressBar.new(); bar.max_value = maxf(1,defense.max_hp); bar.value = defense.hp; bar.show_percentage = false; bar.custom_minimum_size.y = 10; hud.body.add_child(bar); hud.core_bar = bar
		hud.core_metric = hud._label(hud.body,"",12)
		return
	var preparing: bool = state.phase == "preparation"
	var waves: Array = hud._stage_source().waves
	var index = int(state.get("completedRounds",0))
	if index >= waves.size(): hud._label(hud.body,"모든 웨이브를 완료했습니다.",12); return
	var wave: Dictionary = waves[index]
	var summary = hud._button(hud.body,("포탈 1" if preparing else "전투 진행 중")+"\n"+(str(wave.get("previewText",""))+" · %d/%d" % [index+1,waves.size()] if preparing else "진행 상태 확인"),func(): _portal_details(wave))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.disabled = not preparing

func _portal_details(wave: Dictionary) -> void:
	var box = hud.open_modal("포탈 1 · %d/%d 웨이브" % [int(hud.app.run_domain.state.get("completedRounds",0))+1,hud._stage_source().waves.size()],720,true,true,Color("b16dff"))
	var header: HBoxContainer = box.get_child(0)
	var icon = hud._material_icon(header,0xe283,20); icon.modulate = Color("e3b7ff"); header.move_child(icon,0)
	hud._label(box,str(wave.get("previewText","")),13)
	var counts = {}
	for spawn in wave.get("spawnQueue",[]):
		var type = str(spawn.get("enemyType","")); counts[type] = int(counts.get(type,0))+1
	for type in counts:
		var enemy: Dictionary = hud.app.catalog.data.enemies.get(type,{})
		var durability: Dictionary = wave.get("enemyDurability",{}).get(type,{})
		var panel = PanelContainer.new(); box.add_child(panel)
		var content = VBoxContainer.new(); panel.add_child(content)
		var heading = HBoxContainer.new(); content.add_child(heading)
		hud._icon(heading,"ui/hud/enemies/"+type+".png",28)
		hud._label(heading,"%s x%d" % [enemy.get("name",type),counts[type]],12)
		var pills = HFlowContainer.new(); content.add_child(pills)
		hud._stat_pill(pills,"체력",str(roundi(float(durability.get("maxHp",enemy.get("maxHp",0))))))
		for spec in [["방어구","maxArmor"],["보호막","maxShield"]]:
			if float(durability.get(spec[1],0))>0: hud._stat_pill(pills,spec[0],str(roundi(float(durability[spec[1]]))))
		hud._stat_pill(pills,"속도",str(roundi(float(enemy.get("speed",0)))))
		hud._stat_pill(pills,"넥서스 피해","-%d" % int(enemy.get("coreDamage",0)))
		hud._stat_pill(pills,"보상","+%d" % int(enemy.get("rewardGold",0)))
		var resistances = HFlowContainer.new(); content.add_child(resistances)
		var names = {"physical":"물리","elemental":"원소","light":"경량화기","heavy":"중화기","damageOverTime":"지속피해","cooling":"냉각"}
		for field in ["familyResistances","tagResistances"]:
			for kind in enemy.get(field,{}):
				var value = float(enemy[field][kind])
				if value != 0: hud._stat_pill(resistances,str(names.get(kind,kind))+" 저항",("+" if value>0 else "")+str(roundi(value*100))+"%",Color("ff8a8a") if value>0 else Color("9fffe8"))

func _refresh_core() -> void:
	if not is_instance_valid(hud.core_label): return
	var runtime = hud.app.scene._native_combat
	hud.core_label.text = "체력 %d / %d" % [ceili(runtime.defense.hp),ceili(runtime.defense.max_hp)]
	hud.core_bar.max_value = maxf(1,runtime.defense.max_hp); hud.core_bar.value = runtime.defense.hp
	var core = runtime.get("core")
	if core == null: hud.core_metric.text = "전투 스킬 없음"; return
	if core.skill == "guardianBeam":
		var damage: float = maxf(float(core.config.get("normalMaxHp",0))*float(core.config.get("guardianMinNormalHpRate",0.1)),hud.total_dps*float(core.config.get("guardianBeamInterval",5))*float(core.config.get("guardianDpsRate",0.08)))*core.power_for_activation(core.activation_count+1)
		hud.core_metric.text = "수호 광선 · 코어에 가까운 적에게 집중 피해\n광선 피해 %.1f    총 피해 %.1f" % [damage,core.direct_damage_dealt]
	elif core.skill == "riftMark":
		var power: float = 25.0*core.power_for_activation(core.activation_count+1)
		hud.core_metric.text = "균열 낙인 · 내구도 높은 적 4명\n다음 낙인 %.1f%% 증폭 (보스 %.1f%%)\n총 추가 피해 %.1f" % [power,power/2.0,core.bonus_damage_dealt]
	else: hud.core_metric.text = "전투 스킬 없음\n코어 전투 스킬이 장착되어 있지 않습니다."
