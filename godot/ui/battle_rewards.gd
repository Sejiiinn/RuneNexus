extends RefCounted
## Reward preview is presentation state. Settlement and equip are one domain transaction.
const Art = preload("res://ui/app_theme.gd")
const GEM_COLORS := {"attackSpeed": "FFD866", "range": "69D7FF", "physicalDamage": "F4F7FA", "elementalDamage": "9FFFE8", "lightWeapon": "E7C66A", "heavyWeapon": "FF8A2A", "damageOverTime": "9DFF4A", "explosion": "FF8A2A", "chain": "B98CFF", "criticalChance": "FF5F7E", "aimSpeed": "B7F4FF", "damageAmplifier": "FFA14A", "armorPiercing": "D0D7DE", "multipleProjectiles": "79E6C4"}
const RULES := {"chain":"연쇄된 투사체는 피해 및 효과 범위가 50% 감폭됩니다.","explosion":"폭발은 직접 명중한 대상을 제외한 주변 적에게 명중 피해의 50%를 줍니다."}
var hud
var pending_gem := ""
var replacement_id := -1
var replacement_slot := -1
var shard_selected := false
var key: Variant = ""
var _fit_key: Array = []
var _was_visible := false
var _panel_style_mode := ""
var _panel_styles: Dictionary = {}
var shade: ColorRect
var target_layer: Control
var heading: PanelContainer
var target_actions: HBoxContainer
var target_hint := ""

func setup(owner) -> void:
	hud = owner
	_panel_style_mode = ""
	_panel_styles.clear()
	shade = ColorRect.new()
	shade.color = Color(0.008,0.027,0.05,0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.hide()
	hud.add_child(shade)
	target_layer = Control.new()
	target_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_layer.hide()
	hud.add_child(target_layer)
	hud.move_child(hud.overlay,-1)

func targeting() -> bool:
	return not pending_gem.is_empty() and hud.app.run_domain.state.get("phase") == "reward"

func replacing() -> bool:
	return targeting() and replacement_id >= 0

func close_back() -> bool:
	if replacing(): replacement_id = -1; replacement_slot = -1
	elif targeting(): pending_gem = ""
	elif shard_selected: shard_selected = false
	else: return false
	key = ""
	hud.refresh()
	hud.app.refresh_selection()
	return true

func refresh(state: Dictionary) -> void:
	var phase := str(state.get("phase",""))
	if phase != "reward":
		pending_gem = ""
		replacement_id = -1
		replacement_slot = -1
		shard_selected = false
	var visible: bool = phase in ["reward","success","failure"]
	shade.visible = visible and (not targeting() or replacing())
	target_layer.visible = targeting() and not replacing()
	hud.overlay.visible = visible and (not targeting() or replacing())
	var style_mode := ("replacement" if replacing() else "reward") if phase == "reward" else "empty"
	if style_mode != _panel_style_mode:
		if not _panel_styles.has(style_mode):
			match style_mode:
				"replacement": _panel_styles[style_mode] = hud.Components.surface("modal",Vector2(14,14))
				"reward": _panel_styles[style_mode] = preload("res://ui/battle_theme.gd").box()
				_: _panel_styles[style_mode] = StyleBoxEmpty.new()
		hud.overlay.add_theme_stylebox_override("panel",_panel_styles[style_mode])
		_panel_style_mode = style_mode
	if not visible:
		if _was_visible:
			hud._clear(hud.overlay_body)
			hud._clear(target_layer)
			key = ""
			_fit_key.clear()
		_was_visible = false
		return
	_was_visible = true
	var viewport: Vector2 = hud.get_viewport_rect().size
	var safe: Vector4 = hud.safe_insets()
	var width := minf(viewport.x-safe.x-safe.z-24,420)
	hud.overlay.size.x = width
	var next_key := [phase,state.get("rewardOptions"),state.get("isPurchasedGemReward"),state.get("gemInventory"),state.get("gemShards"),hud.configuration_cache.revision,pending_gem,replacement_id,replacement_slot,state.get("gold"),shard_selected,target_hint,viewport,safe]
	if phase in ["success","failure"]:
		var p: Dictionary = state.get("progression",{})
		next_key.append_array([hud.app.stage,state.get("completedRounds"),state.get("lastRunWasNewBestRound"),state.get("lastRunPreviousBestRound"),state.get("lastRunFirstClear"),p.get("lastRunRuneReward"),p.get("lastRunCorePointReward"),p.get("lastRunTurretModuleTicketReward"),p.get("runes"),p.get("bestRoundsByStage",{}).get(str(hud.app.stage+1)),p.get("clearedStageNumbers",[]),_settlement_note()])
	if key is Array and next_key == key:
		_fit_modal()
		return
	key = next_key.duplicate(true)
	_fit_key.clear()
	hud._clear(hud.overlay_body)
	hud._clear(target_layer)
	if not visible: return
	if phase == "reward":
		if targeting():
			if replacing(): _replacement(state)
			else: _target(state,viewport)
		else: _cards(state,width)
	else: _result(state)
	_fit_modal.call_deferred()

func _text(parent: Node, value: String, size: int = 12, center: bool = false) -> Label:
	var label: Label = hud._label(parent,value,size)
	if center: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _icon(parent: Node, path: String, extent: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = Art.texture("res://assets/app/"+path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(extent,extent)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _owned(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.get("gemInventory",{}).duplicate()
	for turret in state.get("turrets",[]):
		for gem in turret.get("equippedGemSlots",[]):
			if gem != null: result[gem] = int(result.get(gem,0))+1
	return result

func _cards(state: Dictionary, width: float) -> void:
	var body: VBoxContainer = hud.overlay_body
	_text(body,"젬 구매 선택" if state.get("isPurchasedGemReward",false) else "젬 보상 선택",20,true)
	if not state.get("isPurchasedGemReward",false): _text(body,"%d웨이브 클리어 보상" % int(state.get("completedRounds",0)),12,true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	body.add_child(row)
	var collection := _owned(state)
	for type in state.get("rewardOptions",[]):
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0,220)
		var accent := Color(str(GEM_COLORS.get(type,"69D7FF")))
		var style := StyleBoxFlat.new()
		style.bg_color = Color("07111d").lerp(accent,0.19)
		style.border_color = accent
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		card.add_theme_stylebox_override("normal",style)
		var pressed: StyleBoxFlat = style.duplicate()
		pressed.bg_color = Color("07111d").lerp(accent,0.30)
		card.add_theme_stylebox_override("pressed",pressed)
		card.add_theme_stylebox_override("hover",pressed)
		row.add_child(card)
		var content := VBoxContainer.new()
		card.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 5; content.offset_right = -5; content.offset_top = 10; content.offset_bottom = -8
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var socket_center := CenterContainer.new()
		socket_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(socket_center)
		var socket := _tinted_panel(socket_center,Color("07111d").lerp(accent,0.28),accent,8)
		socket.custom_minimum_size = Vector2(38,38)
		_icon(socket,"gems/"+str(type)+".png",30)
		var name_label := _text(content,hud._gem_name(type),12,true)
		name_label.custom_minimum_size.y = 32
		var effect := _text(content,_effect(type),10,true)
		effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_text(content,"중화기 전용" if type == "heavyWeapon" else "",9,true).modulate = Color("9ca3ab")
		var count := int(collection.get(type,0))
		var pill := _tinted_panel(content,Color("171b20dd"),Color("33d8ff55") if count > 0 else Color("6f778055"),12)
		pill.custom_minimum_size.y = 22
		_text(pill,"보유 %d" % count if count > 0 else "미보유",11,true).modulate = Color("b9d6e4") if count > 0 else Color("9ca3ab")
		card.pressed.connect(func(): pending_gem = type; target_hint = ""; shard_selected = false; key = ""; hud.refresh(); hud.app.refresh_selection())
	for type in state.get("rewardOptions",[]):
		if RULES.has(type): _text(body,RULES[type],10).modulate = Color("939aa4")
	if not state.get("isPurchasedGemReward",false):
		var amount := int(hud.app.run_domain.growth.data.constants.gemShardRewardFallbackAmount)
		var shard: Button = hud._button(body,"젬 대신 파편 획득\n파편 +%d · 현재 보유 %d" % [amount,state.gemShards],func(): shard_selected = true; key = ""; hud.refresh())
		shard.icon = Art.texture("res://assets/app/ui/hud/icons/shard.png")
		shard.expand_icon = true
		shard.add_theme_constant_override("icon_max_width",24)
		shard.add_theme_color_override("font_color",Color("e8f8ff"))
		hud.Components.apply(shard)
		var bar := StyleBoxFlat.new()
		bar.bg_color = Color("0e3624") if shard_selected else Color("07111d")
		bar.border_color = Color("28d66f")
		bar.set_border_width_all(1)
		bar.set_corner_radius_all(8)
		bar.set_content_margin_all(8)
		shard.add_theme_stylebox_override("normal",bar)
		if shard_selected: hud._button(body,"파편 받기",func(): _settle({"kind":"chooseRewardShards"}))
	if not collection.is_empty():
		_text(body,"획득 젬",10)
		var chips := HFlowContainer.new()
		body.add_child(chips)
		for type in collection:
			var chip := HBoxContainer.new()
			chips.add_child(chip)
			_icon(chip,"gems/"+str(type)+".png",16)
			_text(chip,"%s ×%d" % [hud._gem_name(type),collection[type]],10)

func _target(state: Dictionary, viewport: Vector2) -> void:
	heading = PanelContainer.new()
	target_layer.add_child(heading)
	var safe: Vector4 = hud.safe_insets()
	heading.position = Vector2(safe.x+8,maxf(hud.top.position.y+hud.top.size.y+8,safe.y+8))
	heading.size.x = viewport.x-safe.x-safe.z-16
	var body := VBoxContainer.new()
	heading.add_child(body)
	var title := HBoxContainer.new()
	body.add_child(title)
	_icon(title,"gems/"+pending_gem+".png",40)
	_text(title,hud._gem_name(pending_gem)+"\n"+_effect(pending_gem),13)
	if RULES.has(pending_gem): _text(body,RULES[pending_gem],10)
	var compatible := HFlowContainer.new()
	body.add_child(compatible)
	for type in hud.app.run_domain.service.derived(state).get("availableTurretTypes",[]):
		var allowed: bool = pending_gem in hud.app.run_domain.growth.data.turretRules[type].compatibleGems
		_text(compatible,str(hud.TOWERS.get(type,type))+(" ✓" if allowed else " ×"),11).modulate = Color("a6e9bc") if allowed else Color("77838d")
	_text(body,target_hint if not target_hint.is_empty() else "장착할 타워를 선택하세요 · 전장을 드래그할 수 있습니다",12,true)
	target_actions = HBoxContainer.new()
	target_layer.add_child(target_actions)
	target_actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	target_actions.offset_left = safe.x+8; target_actions.offset_right = -safe.z-8; target_actions.offset_top = -safe.w-60; target_actions.offset_bottom = -safe.w-16
	for spec in [["젬 다시 선택",func(): close_back()],["보관",func(): _settle({"kind":"chooseRewardGem","type":pending_gem})]]:
		hud._button(target_actions,spec[0],spec[1]).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func board_tap(tile: Vector2i) -> bool:
	if not targeting(): return false
	if replacing(): return true
	var state: Dictionary = hud.app.run_domain.state
	for turret in state.get("turrets",[]):
		if int(turret.x) != tile.x or int(turret.y) != tile.y: continue
		if pending_gem not in hud.app.run_domain.growth.data.turretRules[turret.type].compatibleGems:
			target_hint = "이 포탑에는 장착할 수 없습니다"
		elif pending_gem in turret.equippedGemSlots:
			target_hint = "이미 같은 젬이 장착되어 있습니다"
		else:
			var empty: int = turret.equippedGemSlots.find(null)
			if empty >= 0: _settle({"kind":"chooseRewardGemEquip","type":pending_gem,"id":turret.id,"slot":empty})
			else: replacement_id = int(turret.id); replacement_slot = -1
		key = ""
		hud.refresh()
		return true
	return true

func _replacement(state: Dictionary) -> void:
	var turret: Dictionary = hud.app.run_domain.service.turret(state,replacement_id)
	if turret.is_empty(): replacement_id = -1; replacement_slot = -1; return
	var body: VBoxContainer = hud.overlay_body
	body.add_theme_constant_override("separation",9)
	var header := HBoxContainer.new(); body.add_child(header)
	_text(header,"젬 장착",18)
	var close: Button = hud._button(header,"×",func(): close_back())
	close.tooltip_text = "포탑 다시 선택"; close.custom_minimum_size = Vector2(30,30)
	hud._style_hud_button(close,"quiet",false,Vector2(3,0))
	var tower := HBoxContainer.new(); body.add_child(tower)
	_icon(tower,"ui/hud/turrets_3d/"+str(turret.type)+".png",32)
	_text(tower,"%s · Lv.%d" % [hud.TOWERS.get(turret.type,turret.type),turret.level],13)
	var incoming := PanelContainer.new(); body.add_child(incoming)
	incoming.add_theme_stylebox_override("panel",hud.BattleTheme.box(Color("103140"),Color("4eb7d088"),10))
	var incoming_row := HBoxContainer.new(); incoming_row.add_theme_constant_override("separation",10); incoming.add_child(incoming_row)
	_icon(incoming_row,"gems/"+pending_gem+".png",34)
	var incoming_text := VBoxContainer.new(); incoming_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; incoming_row.add_child(incoming_text)
	_text(incoming_text,"새 젬 · "+hud._gem_name(pending_gem),14).modulate = Color("8ee6ff")
	_text(incoming_text,hud._gem_effect(pending_gem,turret),12)
	var q: Dictionary = hud.app.run_domain.service.quotes(state,replacement_id)
	var cost := int(q.get("link",0))
	var maximum := int(hud.app.run_domain.service.derived(state).get("maxTurretLinkSlots",3))
	_text(body,"장착할 슬롯을 선택하세요",13)
	var center := CenterContainer.new(); body.add_child(center)
	var rows := VBoxContainer.new(); rows.name = "ReplacementSockets"; rows.add_theme_constant_override("separation",8); center.add_child(rows)
	var sockets: HBoxContainer
	for slot in int(turret.slotLimit):
		if slot % 3 == 0:
			sockets = HBoxContainer.new(); sockets.alignment = BoxContainer.ALIGNMENT_CENTER
			sockets.add_theme_constant_override("separation",2); rows.add_child(sockets)
		else:
			var link_area := Control.new(); link_area.custom_minimum_size = Vector2(24,64)
			link_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; sockets.add_child(link_area)
			var link := _icon(link_area,"ui/components/gem_link_active.png",0)
			link.position = Vector2(0,26); link.size = Vector2(24,12)
		var column := VBoxContainer.new(); column.custom_minimum_size.x = 64; sockets.add_child(column)
		var socket: Button = hud._button(column,"",func(): _select_replacement_slot(slot))
		socket.name = "Slot%d" % slot; socket.custom_minimum_size = Vector2(64,64)
		socket.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for style in ["normal","hover","pressed","disabled","focus"]: socket.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		var art := _icon(socket,"ui/components/"+("gem_socket_selected.png" if replacement_slot == slot else "gem_socket_empty.png"),0)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var gem := str(turret.equippedGemSlots[slot])
		var icon := _icon(socket,"gems/"+gem+".png",0)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 14; icon.offset_right = -14; icon.offset_top = 14; icon.offset_bottom = -14
		var socket_name: String = hud._gem_name(gem)
		if socket_name.length() > 5 and socket_name.contains(" "):
			var split_at := socket_name.rfind(" ")
			socket_name = socket_name.substr(0,split_at)+"\n"+socket_name.substr(split_at+1)
		var gem_label: Label = _text(column,socket_name,11,true)
		gem_label.custom_minimum_size.x = 64
		gem_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		socket.tooltip_text = hud._gem_name(gem)+" · "+hud._gem_effect(gem,turret)
	if cost > 0:
		var buy: Button = hud._button(body,("✓ " if replacement_slot == int(turret.slotLimit) else "+ ")+"슬롯 추가 · %d G" % cost,func(): _select_replacement_slot(int(turret.slotLimit)))
		hud.Components.apply(buy,"selected" if replacement_slot == int(turret.slotLimit) else "secondary")
		buy.disabled = int(state.gold) < cost
	_text(body,"보유 %d G" % state.gold,11,true).modulate = Color("b2c5d0")
	var buying: bool = replacement_slot == int(turret.slotLimit)
	if replacement_slot >= 0 and not buying and replacement_slot < turret.equippedGemSlots.size():
		var old := str(turret.equippedGemSlots[replacement_slot])
		_text(body,"%s → %s" % [hud._gem_name(old),hud._gem_name(pending_gem)],14,true).modulate = Color("ffe19a")
		_text(body,"효과 제거 · "+hud._gem_effect(old,turret),12)
		_text(body,"기존 젬은 보관함으로 돌아갑니다.",11).modulate = Color("a6c2cb")
	elif buying:
		_text(body,"새 슬롯에 %s 장착" % hud._gem_name(pending_gem),14,true).modulate = Color("8ee6ff")
		_text(body,"기존 젬 유지 · %d G 사용 후 %d G 남음" % [cost,int(state.gold)-cost],11,true)
	elif int(turret.slotLimit) >= maximum:
		_text(body,"모든 슬롯이 사용 중입니다. 교체할 젬을 선택하세요.",11)
	elif cost <= 0:
		_text(body,"다음 슬롯은 포탑 Lv.5부터 추가할 수 있습니다.
기존 젬을 선택하면 교체할 수 있습니다.",11)
	elif int(state.gold) < cost:
		_text(body,"슬롯 추가에 %d G 부족합니다.
기존 젬을 선택하면 교체할 수 있습니다." % (cost-int(state.gold)),11)
	else:
		_text(body,"장착 젬 선택 → 교체
슬롯 추가 선택 → 기존 젬을 유지하고 장착",11)
	var caption := "장착할 슬롯을 선택하세요" if replacement_slot < 0 else ("슬롯 추가 후 장착 · %d G" % cost if buying else "선택한 젬과 교체")
	var confirm: Button = hud._button(body,caption,_confirm_replacement)
	hud.Components.apply(confirm,"primary"); confirm.custom_minimum_size.y = 44; confirm.disabled = replacement_slot < 0
	var back: Button = hud._button(body,"포탑 다시 선택",func(): close_back())
	hud._style_hud_button(back,"quiet",false,Vector2(8,6))

func _select_replacement_slot(slot: int) -> void:
	var state: Dictionary = hud.app.run_domain.state
	var turret: Dictionary = hud.app.run_domain.service.turret(state,replacement_id)
	if not replacing() or turret.is_empty() or slot < 0 or slot > int(turret.slotLimit): return
	if slot == int(turret.slotLimit):
		var cost := int(hud.app.run_domain.service.quotes(state,replacement_id).get("link",0))
		if cost <= 0 or int(state.gold) < cost: return
	replacement_slot = slot; key = ""; hud.refresh()

func _confirm_replacement() -> void:
	if not replacing() or replacement_slot < 0: return
	var turret: Dictionary = hud.app.run_domain.service.turret(hud.app.run_domain.state,replacement_id)
	if turret.is_empty(): return
	if replacement_slot == int(turret.slotLimit): _buy_replacement_slot()
	else: _settle({"kind":"chooseRewardGemEquip","type":pending_gem,"id":replacement_id,"slot":replacement_slot})

func _buy_replacement_slot() -> void:
	var turret: Dictionary = hud.app.run_domain.service.turret(hud.app.run_domain.state,replacement_id)
	if not replacing() or turret.is_empty(): return
	_settle({"kind":"chooseRewardGemEquip","type":pending_gem,"id":replacement_id,"slot":int(turret.slotLimit),"buySlot":true})

func _settle(command: Dictionary) -> void:
	hud.app.apply_run_command(command)
	# Persistence can fail after a successful domain mutation; never replay settlement.
	if hud.app.run_domain.state.get("phase") != "reward":
		pending_gem = ""
		replacement_id = -1
		replacement_slot = -1
	key = ""
	hud.refresh()
	hud.app.refresh_selection()

func _surface(parent: Node, asset: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = Art.texture("res://assets/app/results/ui/"+asset+".png")
	# Flutter _ResultAssetSurface uses Image.asset(fit: BoxFit.fill), with no centerSlice.
	# Zero texture margins intentionally stretch the same complete authored frame.
	style.set_texture_margin_all(0)
	style.set_content_margin_all(18 if asset == "result_panel_frame" else 12)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	return body

func _result(state: Dictionary) -> void:
	var success: bool = state.phase == "success"
	var body := _surface(hud.overlay_body,"result_panel_frame")
	var emblem := _icon(body,"results/ui/status_emblem_socket.png",54)
	var icon := _icon(emblem,"results/result_success.png" if success else "results/result_failure.png",0)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 7; icon.offset_right = -7; icon.offset_top = 7; icon.offset_bottom = -7
	_text(body,"Nexus 방어 성공" if success else "Nexus 붕괴",20,true)
	_text(body,"스테이지 %d %s" % [hud.app.stage+1,"클리어" if success else "종료"],12,true)
	var p: Dictionary = state.get("progression",{})
	var rewards := _surface(body,"reward_summary_frame")
	_text(rewards,"보상 획득",11,true)
	_text(rewards,"+%d 룬" % int(p.get("lastRunRuneReward",0)),28,true)
	for spec in [["lastRunCorePointReward","코어 포인트"],["lastRunTurretModuleTicketReward","포탑 모듈 티켓"+(" · 정산 대기" if _server_reward_pending() else "")]]:
		if int(p.get(spec[0],0)) > 0: _text(rewards,"+%d %s" % [p[spec[0]],spec[1]],15,true)
	_text(rewards,_settlement_note(),11,true)
	_text(body,"전투 기록",14)
	var records := _surface(body,"section_frame")
	var best := int(p.get("bestRoundsByStage",{}).get(str(hud.app.stage+1),0))
	var record := _record_text(state,p,best)
	var damage := 0.0
	var tower_name := ""
	for turret in state.get("turrets",[]):
		var dealt := float(turret.get("damageDealt",0))
		var runtime_turrets = hud.app.scene._native_combat.get("turrets")
		if runtime_turrets is Dictionary and runtime_turrets.has(str(turret.id)):
			dealt = 0.0
			for field in ["directDamageDealt","splashDamageDealt","chainDamageDealt","burnDamageDealt"]:
				dealt += float(runtime_turrets[str(turret.id)].get(field,0))
		if dealt > damage: damage = dealt; tower_name = str(hud.TOWERS.get(turret.type,turret.type))
	for spec in [["도달 라운드","%dR" % int(state.get("completedRounds",0))],["기록",record],["최고 피해",tower_name+" %.1f" % damage if damage > 0 else "기록 없음"],["현재 룬",str(p.get("runes",0))]]:
		var line := HBoxContainer.new()
		records.add_child(line)
		_text(line,spec[0],11)
		_text(line,spec[1],12).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if state.get("lastRunFirstClear",false): _unlocks(body,hud.app.stage+1)
	for spec in [["확인","confirm_button_frame" if success else "confirm_button_danger_frame",func(): hud.app.show_lobby(); hud.app.lobby.open_page("스테이지")],["다시 시작","restart_button_frame",func(): hud.app.retry_stage(); hud.refresh()]]:
		var center := CenterContainer.new(); body.add_child(center)
		var button: Button = Art.button(spec[0],spec[2],"ghost",true)
		hud.Components.apply(button)
		center.add_child(button)
		button.custom_minimum_size = Vector2(208,34)
		button.add_theme_font_override("font",Art.font(900)); button.add_theme_font_size_override("font_size",13)
		var foreground := Color("02070d") if success and spec[0] == "확인" else Color("e8f8ff")
		for role in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(role,foreground)
		if spec[0] == "다시 시작":
			button.text = ""
			var content := HBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.alignment = BoxContainer.ALIGNMENT_CENTER; button.add_child(content); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var replay := Label.new(); replay.text = char(0xe523); replay.add_theme_font_override("font",load("res://assets/ui/MaterialIcons-Regular.otf")); replay.add_theme_font_size_override("font_size",13); replay.add_theme_color_override("font_color",foreground); content.add_child(replay)
			var caption := Label.new(); caption.text = "다시 시작"; caption.add_theme_font_override("font",Art.font(900)); caption.add_theme_font_size_override("font_size",13); caption.add_theme_color_override("font_color",foreground); content.add_child(caption)
		var style := StyleBoxTexture.new()
		style.texture = Art.texture("res://assets/app/results/ui/"+spec[1]+".png")
		for state_name in ["normal","hover","pressed","disabled"]: button.add_theme_stylebox_override(state_name,style)

func _record_text(state: Dictionary,progression: Dictionary,best: int) -> String:
	if state.get("lastRunWasNewBestRound",false):
		var previous := int(state.get("lastRunPreviousBestRound",0))
		return "%dR → %dR" % [previous,state.get("completedRounds",0)] if previous>0 else "%dR 첫 기록" % int(state.get("completedRounds",0))
	if hud.app.stage+1 in progression.get("clearedStageNumbers",[]): return "클리어"
	return "최고 %dR" % best

func _unlocks(body: Node, stage: int) -> void:
	var items := {1:"강화 · 처치 보상\n연구 · 긴급 매각",2:"연구 · 전술 명령 / 젬 감응",3:"포탑 · 저격 포탑\n젬 · 조준경 젬",4:"강화 · 치명 충격\n연구 · 치명 집중",5:"연구 · 링크 확장 I / 결정 회수\n코어 · 균열 낙인",6:"포탑 · 라이트닝 포탑",7:"강화 · 물리 화력 훈련 / 원소 화력 훈련",8:"연구 · 룬 공명 / 전투 투자 최적화",9:"강화 · 연결 공정 / 강화 공정",10:"젬 · 장갑 관통 젬\n연구 · 연구 슬롯 II 구매 권한",15:"연구 · 포탑 화력 확장 / 처치 보너스 확장 / 정비 보급 확장"}
	if not items.has(stage): return
	_text(body,"해금 항목",14)
	_text(_surface(body,"unlock_chip_frame"),items[stage],12)

func _effect(type: String) -> String:
	# battle_labels is exported from the Flutter gem catalog; only layout changes here.
	var description: String = hud._gem_description(type)
	if type == "heavyWeapon": description = description.replace("\n중화기 전용","")
	var parts := PackedStringArray()
	var numeric := RegEx.new()
	numeric.compile(" ([0-9]+%)")
	for line in description.split("\n"):
		var found := numeric.search(line)
		if found != null:
			parts.append(line.substr(0,found.get_start())+"\n"+line.substr(found.get_start()+1).replace(" ","\u00a0"))
		elif type in ["heavyWeapon","explosion"] and line.rfind(" ") >= 0:
			var split := line.rfind(" ")
			parts.append(line.substr(0,split)+"\n"+line.substr(split+1))
		else: parts.append(line)
	return ("\n\n" if type in ["heavyWeapon","explosion"] else "\n").join(parts)

func _settlement_note() -> String:
	if hud.app.get("save_failed") == true: return "전투 기록 저장 대기 · 다시 저장해 주세요"
	if _server_reward_pending():
		return "전투 기록 저장됨 · 서버 보상 정산 대기"
	return "전투 기록 저장됨"

func _server_reward_pending() -> bool:
	if not hud.app.checkpoint is Object or not hud.app.checkpoint.has_method("rewards"): return false
	var queue = hud.app.checkpoint.rewards()
	return queue != null and not queue.state.get("pendingRewards",[]).is_empty()

func _tinted_panel(parent: Node, fill: Color, border: Color, radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(2)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel

func _fit_modal() -> void:
	if not is_instance_valid(hud) or not hud.overlay.visible: return
	var viewport: Vector2 = hud.get_viewport_rect().size
	var safe: Vector4 = hud.safe_insets()
	var style: StyleBox = hud.overlay.get_theme_stylebox("panel")
	var padding := style.get_content_margin(SIDE_TOP)+style.get_content_margin(SIDE_BOTTOM)
	var available := maxf(1,viewport.y-safe.y-safe.w-24)
	var content_height: float = hud.overlay_body.get_combined_minimum_size().y+padding
	var next_fit := [viewport,safe,hud.overlay.size.x,content_height]
	if next_fit == _fit_key: return
	_fit_key = next_fit
	var height := minf(available,content_height)
	hud.overlay.size.y = height
	hud.overlay.position = Vector2(safe.x+(viewport.x-safe.x-safe.z-hud.overlay.size.x)/2,safe.y+(viewport.y-safe.y-safe.w-height)/2)
