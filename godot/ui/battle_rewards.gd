extends RefCounted
const HudNumber = preload("res://ui/hud_number.gd")
const Progression = preload("res://content/stage_progression.gd")
## Reward preview is presentation state. Settlement and equip are one domain transaction.
const Art = preload("res://ui/app_theme.gd")
const ResultPresenter = preload("res://ui/battle_result_presenter.gd")
const ResultEntrance = preload("res://ui/battle_result_entrance.gd")
const GemEntrance = preload("res://ui/gem_reward_entrance.gd")
const UiWidgets = preload("res://ui/ui_widgets.gd")
const GemFlip = preload("res://ui/gem_reward_flip.gd")
const GEM_COLORS := {"attackSpeed": "FFD866", "range": "69D7FF", "physicalDamage": "F4F7FA", "elementalDamage": "9FFFE8", "lightWeapon": "E7C66A", "heavyWeapon": "FF8A2A", "damageOverTime": "9DFF4A", "explosion": "FF8A2A", "chain": "B98CFF", "criticalChance": "FF5F7E", "aimSpeed": "B7F4FF", "damageAmplifier": "FFA14A", "armorPiercing": "D0D7DE", "multipleProjectiles": "79E6C4"}
const RULES := {"chain":"연쇄된 투사체는 피해 및 효과 범위가 50% 감폭됩니다.","explosion":"폭발은 직접 명중한 대상을 제외한 주변 적에게 명중 피해의 50%를 줍니다."}
# The approved compact cycle glyph is code-native, like the reward entrance rune.
class RerollGlyph extends Control:
	func _draw() -> void:
		var ink := Color("c5f0ec")
		draw_arc(Vector2(10,10),6.5,deg_to_rad(212),deg_to_rad(370),20,ink,1.8,true)
		draw_arc(Vector2(10,10),6.5,deg_to_rad(32),deg_to_rad(190),20,ink,1.8,true)
		draw_colored_polygon(PackedVector2Array([Vector2(16.4,12.0),Vector2(12.7,9.0),Vector2(18.5,8.7)]),ink)
		draw_colored_polygon(PackedVector2Array([Vector2(3.6,8.0),Vector2(7.3,11.0),Vector2(1.5,11.3)]),ink)

var hud
var pending_gem := ""
var replacement_id := -1
var replacement_slot := -1
var shard_selected := false
var key: Variant = ""
var _fit_key: Array = []
var _layout_revision := 0
var _layout_pending := false
var _was_visible := false
var _panel_style_mode := ""
var _panel_styles: Dictionary = {}
var shade: ColorRect
var target_layer: Control
var heading: PanelContainer
var target_actions: HBoxContainer
var target_hint := ""
var result_entrance
var gem_entrance
var gem_flip
var _displayed_offer: Dictionary = {}
var _hold_reroll_offer := false
var _confirmed_flip_waiting := false
var _last_reroll_locked := false
var _flip_state: Dictionary = {}
var _flip_viewport := Vector2.ZERO
var _reroll_pending := false
var _reroll_generation := 0
var _reroll_identity := ""

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
	result_entrance = ResultEntrance.new()
	result_entrance.setup(hud,shade)
	hud.add_child(result_entrance)
	gem_entrance = GemEntrance.new()
	gem_entrance.setup(hud,shade)
	hud.add_child(gem_entrance)
	gem_flip = GemFlip.new()
	gem_flip.setup(hud)
	gem_flip.finished.connect(_finish_reroll_flip)
	hud.add_child(gem_flip)
	hud.tree_exiting.connect(_exit_reward_view)
	var services = hud.app.get("services")
	if services is Object and services.has_signal("changed") and not services.changed.is_connected(hud.refresh):
		services.changed.connect(hud.refresh)

func targeting() -> bool:
	return not pending_gem.is_empty() and hud.app.run_domain.state.get("phase") == "reward"

func replacing() -> bool:
	return targeting() and replacement_id >= 0

func close_back() -> bool:
	if _reroll_locked(): return true
	if replacing(): replacement_id = -1; replacement_slot = -1
	elif targeting(): pending_gem = ""
	elif shard_selected: shard_selected = false
	else: return false
	key = ""
	hud.refresh()
	hud.app.refresh_selection()
	return true

func refresh(state: Dictionary) -> void:
	if not hud.is_inside_tree(): return
	var phase := str(state.get("phase",""))
	var reward_identity := _reward_identity(state) if phase == "reward" else ""
	if reward_identity != _reroll_identity:
		_reroll_identity = reward_identity
		_reroll_generation += 1
		_reroll_pending = false
		gem_flip.cancel()
		_displayed_offer.clear()
		_flip_state.clear()
		_hold_reroll_offer = false
		_confirmed_flip_waiting = false
		_last_reroll_locked = false
	if phase not in ["success","failure"]: result_entrance.cancel()
	if phase != "reward":
		gem_entrance.cancel()
		pending_gem = ""
		replacement_id = -1
		replacement_slot = -1
		shard_selected = false
	var visible: bool = phase in ["reward","success","failure"]
	shade.visible = visible and (not targeting() or replacing())
	target_layer.visible = targeting() and not replacing()
	hud.overlay.visible = visible and (not targeting() or replacing())
	var style_mode := ("replacement" if replacing() else "reward") if phase == "reward" else "result"
	if style_mode != _panel_style_mode:
		if not _panel_styles.has(style_mode):
			match style_mode:
				"replacement": _panel_styles[style_mode] = hud.Components.surface("modal",Vector2(14,14))
				"reward": _panel_styles[style_mode] = preload("res://ui/battle_theme.gd").box()
				"result": _panel_styles[style_mode] = ResultPresenter.frame()
				_: _panel_styles[style_mode] = StyleBoxEmpty.new()
		hud.overlay.add_theme_stylebox_override("panel",_panel_styles[style_mode])
		_panel_style_mode = style_mode
	if phase in ["success","failure"] and hud.is_visible_in_tree():
		result_entrance.consider(JSON.stringify([str(state.get("economyRunId","")),hud.app.stage,phase]),phase == "success")
	if phase == "reward" and hud.is_visible_in_tree():
		var round_number := int(state.get("completedRounds",0))
		gem_entrance.consider(JSON.stringify([str(state.get("economyRunId","")),hud.app.stage,round_number]),
			not state.get("isPurchasedGemReward",false) and round_number > 0 and round_number % 5 == 0 and not targeting())
	elif phase == "reward": gem_entrance.cancel()
	if not visible:
		if _was_visible:
			UiWidgets.clear(hud.overlay_body)
			UiWidgets.clear(target_layer)
			key = ""
			_fit_key.clear()
		_was_visible = false
		return
	_was_visible = true
	if phase == "reward" and not targeting():
		state = _present_reward(state)
		if gem_flip.active:
			# Refresh signals must not replace the old face or move surrounding UI.
			if hud.get_viewport_rect().size != _flip_viewport:
				_flip_viewport = hud.get_viewport_rect().size
				_fit_modal()
			return
	var viewport: Vector2 = hud.get_viewport_rect().size
	var safe: Vector4 = hud.safe_insets()
	var width := minf(viewport.x-safe.x-safe.z-24,420)
	hud.overlay.size.x = width
	var next_key := [phase,state.get("rewardOptions"),state.get("isPurchasedGemReward"),state.get("gemInventory"),state.get("gemShards"),hud.configuration_cache.revision,pending_gem,replacement_id,replacement_slot,state.get("gold"),shard_selected,target_hint,viewport,safe]
	if phase == "reward": next_key.append_array([state.get("economyRunId"),hud.app.stage,state.get("completedRounds"),_reroll_state(),_reroll_pending])
	if phase in ["success","failure"]:
		var p: Dictionary = state.get("progression",{})
		next_key.append_array([hud.app.stage,state.get("completedRounds"),state.get("lastRunWasNewBestRound"),state.get("lastRunPreviousBestRound"),state.get("lastRunFirstClear"),p.get("lastRunRuneReward"),p.get("lastRunCorePointReward"),p.get("lastRunTurretModuleTicketReward"),p.get("runes"),p.get("bestRoundsByStage",{}).get(str(hud.app.stage+1)),p.get("clearedStageNumbers",[]),_settlement_note(),_settlement_state()])
	if key is Array and next_key == key:
		_fit_modal()
		if not _layout_pending and result_entrance.active and result_entrance.started_usec == 0:
			result_entrance.bind_body()
		if not _layout_pending and gem_entrance.active and gem_entrance.started_usec == 0:
			gem_entrance.bind_body()
		return
	key = next_key.duplicate(true)
	_layout_revision += 1
	_layout_pending = true
	_fit_key.clear()
	result_entrance.detach_body()
	gem_entrance.detach_body()
	UiWidgets.clear(hud.overlay_body)
	UiWidgets.clear(target_layer)
	if not visible: return
	if phase == "reward":
		if targeting():
			if replacing(): _replacement(state)
			else: _target(state,viewport)
		else: _cards(state,width)
	else: _result(state)
	_fit_after_layout(_layout_revision)

func _text(parent: Node, value: String, size: int = 12, center: bool = false) -> Label:
	var label: Label = UiWidgets.label(parent,value,size)
	if center: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func reward_icon(parent: Node, path: String, extent: float) -> TextureRect:
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

func _reward_identity(state: Dictionary) -> String:
	return JSON.stringify([state.get("economyRunId",""),hud.app.stage,state.get("completedRounds",0),state.get("isPurchasedGemReward",false),state.get("gemOfferId", "") if state.get("isPurchasedGemReward",false) else ""])

func _reroll_state() -> Dictionary:
	if hud.app is Object and hud.app.has_method("gem_reroll_state"):
		return hud.app.gem_reroll_state()
	return {"status":"unsupported","remaining":3,"free":true,"available":false,"locked":false,"note":"젬 다시 뽑기를 사용할 수 없습니다"}

func _reroll_locked() -> bool:
	return _reroll_pending or gem_flip.active or _hold_reroll_offer or bool(_reroll_state().get("locked",false))

func _reroll(revision: int) -> void:
	if revision != _layout_revision or gem_entrance.active or targeting() or _reroll_pending or gem_flip.active or _confirmed_flip_waiting: return
	var state: Dictionary = hud.app.run_domain.state
	if state.get("phase") != "reward" or state.get("isPurchasedGemReward",false): return
	if not bool(_reroll_state().get("available",false)): return
	# Keep an already expanded shard confirmation in place during the reroll.
	_reroll_pending = true
	_hold_reroll_offer = true
	_reroll_generation += 1
	var generation := _reroll_generation
	var identity := _reward_identity(state)
	key = ""; hud.refresh()
	var result: Dictionary = await hud.app.reroll_reward_gems()
	# An old response must not refresh or unlock a new reward/run's controls.
	if not is_instance_valid(hud) or generation != _reroll_generation: return
	if identity != _reward_identity(hud.app.run_domain.state): return
	_reroll_pending = false
	if not hud.is_inside_tree():
		if result.get("ok",false):
			_displayed_offer.clear()
			_hold_reroll_offer = false
		key = ""
		return
	if result.get("ok",false):
		_hold_reroll_offer = false
		if not result.get("initialOffer", false): _start_reroll_flip(hud.app.run_domain.state)
	elif not bool(_reroll_state().get("locked",false)) and not _offer_changed(hud.app.run_domain.state):
		_hold_reroll_offer = false
	key = ""; hud.refresh()

func _exit_reward_view() -> void:
	if not _flip_state.is_empty() or _confirmed_flip_waiting:
		gem_flip.cancel()
		# A confirmed transition leaving the scene is consumed, not replayed.
		_displayed_offer.clear()
		_flip_state.clear()
		_hold_reroll_offer = false
		_confirmed_flip_waiting = false
		key = ""

func _offer_changed(state: Dictionary) -> bool:
	return not _displayed_offer.is_empty() and _displayed_offer.get("rewardOptions", []).size() == 3 and state.get("rewardOptions",[]).size() == 3 and int(state.get("gemRerollsUsed",0)) > int(_displayed_offer.gemRerollsUsed) and state.get("rewardOptions",[]) != _displayed_offer.rewardOptions

func _present_reward(state: Dictionary) -> Dictionary:
	var locked := bool(_reroll_state().get("locked",false))
	if not _reroll_pending and not locked and not _offer_changed(state):
		_hold_reroll_offer = false
		_confirmed_flip_waiting = false
	if not gem_flip.active and _offer_changed(state):
		# An in-flight snapshot may be durable before the command/outbox finishes.
		# The local await result is the confirmation boundary, not that signal.
		# A later background recovery can confirm by leaving its locked state.
		if not _reroll_pending and not locked and (_confirmed_flip_waiting or not _hold_reroll_offer or _last_reroll_locked):
			_start_reroll_flip(state)
		else:
			_hold_reroll_offer = true
	_last_reroll_locked = locked
	if (_reroll_pending or _hold_reroll_offer or gem_flip.active) and not _displayed_offer.is_empty():
		var display := state.duplicate()
		display.merge(_displayed_offer,true)
		return display
	return state

func _start_reroll_flip(state: Dictionary) -> void:
	if gem_flip.active or not _offer_changed(state): return
	if not hud.is_visible_in_tree() or not hud.overlay.visible:
		_displayed_offer.clear()
		_hold_reroll_offer = false
		_confirmed_flip_waiting = false
		return
	if gem_entrance.active:
		# Background recovery may finish during the first wave entrance. Serialize
		# the presentations so two helpers never own the same card transforms.
		_confirmed_flip_waiting = true
		_hold_reroll_offer = true
		return
	var row: HBoxContainer = hud.overlay_body.find_child("GemRewardCards",true,false)
	if row == null or row.get_child_count() != 3: return
	_flip_state = state.duplicate(true)
	_flip_viewport = hud.get_viewport_rect().size
	_hold_reroll_offer = false
	_confirmed_flip_waiting = false
	gem_flip.begin(row,_swap_reroll_faces)
	if not _layout_pending: gem_flip.bind_body()

func _swap_reroll_faces() -> void:
	if _flip_state.is_empty(): return
	var row: HBoxContainer = hud.overlay_body.find_child("GemRewardCards",true,false)
	if row == null: return
	var collection := _owned(_flip_state)
	for index in mini(row.get_child_count(),3):
		_paint_card(row.get_child(index),str(_flip_state.rewardOptions[index]),collection)

func _finish_reroll_flip() -> void:
	# Completion and hiding both consume this presentation once. Reopening or
	# duplicate refreshes must not replay it; a rebuild gets current rules too.
	if not _flip_state.is_empty():
		_displayed_offer = {"rewardOptions":_flip_state.rewardOptions.duplicate(),"gemRerollsUsed":int(_flip_state.get("gemRerollsUsed",0))}
	_flip_state.clear()
	_hold_reroll_offer = false
	_confirmed_flip_waiting = false
	key = ""
	if is_instance_valid(hud) and hud.is_inside_tree(): hud.refresh()

func _reward_header(body: VBoxContainer, state: Dictionary) -> void:
	if state.get("isPurchasedGemReward",false):
		_text(body,"젬 구매 선택",20,true)
		return
	var info := _reroll_state()
	var header := Control.new(); header.name = "GemRewardHeader"
	header.custom_minimum_size.y = 48; body.add_child(header)
	var title := _text(header,"젬 보상 선택",20,true)
	title.name = "GemRewardTitle"
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 44; title.offset_right = -44; title.offset_top = 4; title.offset_bottom = 34
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var revision := _layout_revision
	var hit := Button.new(); hit.name = "GemRewardReroll"; header.add_child(hit)
	hit.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hit.offset_left = -44; hit.offset_top = 0; hit.offset_right = 0; hit.offset_bottom = 52
	hit.custom_minimum_size = Vector2(44,52)
	hit.disabled = not bool(info.get("available",false)) or _reroll_pending
	hit.tooltip_text = str(info.get("note",""))
	if hit.tooltip_text.is_empty(): hit.tooltip_text = "젬 다시 뽑기 · 무료" if info.get("free",false) else "젬 다시 뽑기 · 젬 리셋권 1장"
	hit.pressed.connect(func(): _reroll(revision))
	for style_name in ["normal","hover","pressed","disabled"]: hit.add_theme_stylebox_override(style_name,StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new(); focus.bg_color = Color.TRANSPARENT; focus.border_color = Color("c5f0ec")
	focus.set_border_width_all(1); focus.set_corner_radius_all(4)
	hit.add_theme_stylebox_override("focus",focus)
	var box := Panel.new(); box.name = "RerollSquare"; hit.add_child(box)
	box.position = Vector2(5,4); box.size = Vector2(32,32); box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new(); skin.bg_color = Color("0b2e3c"); skin.border_color = Color("4b8797")
	skin.set_border_width_all(1); skin.set_corner_radius_all(4); box.add_theme_stylebox_override("panel",skin)
	var arrow := RerollGlyph.new(); box.add_child(arrow); arrow.position = Vector2(6,6); arrow.size = Vector2(20,20)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := PanelContainer.new(); badge.name = "RerollRemaining"; hit.add_child(badge)
	badge.position = Vector2(28,0); badge.custom_minimum_size = Vector2(16,16); badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new(); badge_style.bg_color = Color("153d48"); badge_style.border_color = Color("83ced3")
	badge_style.set_border_width_all(1); badge_style.set_corner_radius_all(8); badge_style.set_content_margin_all(0)
	badge.add_theme_stylebox_override("panel",badge_style)
	var count := _text(badge,str(info.get("remaining",0)),9,true); count.name = "Count"; count.autowrap_mode = TextServer.AUTOWRAP_OFF
	var status := str(info.get("status",""))
	if info.get("free",false) or status == "exhausted" or _reroll_locked():
		var caption := "무료" if info.get("free",false) else "소진"
		if _reroll_locked(): caption = "재시도" if status in ["recovering","save_failed"] and not _reroll_pending else "확인 중"
		var label := _text(hit,caption,8,true); label.name = "RerollCost"
		label.position = Vector2(0,36); label.size = Vector2(42,13); label.modulate = Color("98c4cb")
	else:
		var cost := HBoxContainer.new(); cost.name = "RerollCost"; hit.add_child(cost)
		cost.position = Vector2(5,36); cost.add_theme_constant_override("separation",1); cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ticket := reward_icon(cost,"ui/hud/icons/gem_reset_ticket.png",16); ticket.name = "GemResetTicket"
		var quantity := _text(cost,"×1",9); quantity.autowrap_mode = TextServer.AUTOWRAP_OFF
	if hit.disabled:
		box.modulate = Color("7d929b"); badge.modulate = Color("7d929b")

func _cards(state: Dictionary, width: float) -> void:
	_displayed_offer = {"rewardOptions":state.get("rewardOptions",[]).duplicate(),"gemRerollsUsed":int(state.get("gemRerollsUsed",0))}
	var body: VBoxContainer = hud.overlay_body
	_reward_header(body,state)
	var revision := _layout_revision
	var locked := _reroll_locked()
	if not state.get("isPurchasedGemReward",false): _text(body,"%d웨이브 클리어 보상" % int(state.get("completedRounds",0)),12,true)
	var row := HBoxContainer.new()
	row.name = "GemRewardCards"
	row.custom_minimum_size.y = 220 # Keep the established frame while initial candidates are pending.
	row.add_theme_constant_override("separation",8)
	body.add_child(row)
	var collection := _owned(state)
	for type in state.get("rewardOptions",[]):
		var card := Button.new()
		card.disabled = locked
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0,220)
		row.add_child(card)
		_paint_card(card,str(type),collection)
		card.pressed.connect(func():
			if revision != _layout_revision or gem_entrance.active or _reroll_locked(): return
			pending_gem = type; target_hint = ""; shard_selected = false; key = ""; hud.refresh(); hud.app.refresh_selection())
	if state.get("isPurchasedGemReward",false):
		for type in state.get("rewardOptions",[]):
			if RULES.has(type): _text(body,RULES[type],10).modulate = Color("939aa4")
		if locked:
			var info := _reroll_state()
			_text(body,str(info.get("note", "서버 보상 확인 중…")),11,true)
			if info.get("status") in ["recovering", "save_failed"]:
				var retry := UiWidgets.button(body,"처리 결과 다시 확인",_recover_reward)
				retry.name = "GemPurchaseRetry"
	else:
		_reward_details(body,state,width)
	if not state.get("isPurchasedGemReward",false):
		var amount := int(hud.app.run_domain.growth.data.constants.gemShardRewardFallbackAmount)
		var shard: Button = UiWidgets.button(body,"젬 대신 파편 획득\n파편 +%s · 현재 보유 %s" % [HudNumber.compact_integer(amount),HudNumber.compact_integer(int(state.gemShards))],func():
			if revision != _layout_revision or gem_entrance.active or _reroll_locked(): return
			shard_selected = true; key = ""; hud.refresh())
		shard.name = "GemRewardShards"
		shard.disabled = locked
		shard.tooltip_text = "파편 +%d · 현재 보유 %d" % [amount,state.gemShards]
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
		shard.add_theme_stylebox_override("disabled",bar)
		if shard_selected:
			var confirm: Button = UiWidgets.button(body,"파편 받기",func():
				if revision == _layout_revision: _settle({"kind":"chooseRewardShards"}))
			confirm.disabled = locked
	if not collection.is_empty():
		_text(body,"획득 젬",10).name = "GemRewardInventoryHeading"
		var chips := HFlowContainer.new()
		chips.name = "GemRewardInventory"
		body.add_child(chips)
		for type in collection:
			var chip := HBoxContainer.new()
			chips.add_child(chip)
			reward_icon(chip,"gems/"+str(type)+".png",16)
			# Flow wraps whole entries; the label must retain its natural text width.
			var label := _text(chip,"%s ×%d" % [hud.gem_name(type),collection[type]],10)
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
	gem_entrance.conceal_body()

func _reward_details(body: VBoxContainer, state: Dictionary, width: float) -> void:
	# Reserve the largest possible rule/status block for this width, independent
	# of the offered candidates or request phase. No post-flip modal/row jump.
	var area := Control.new()
	area.name = "GemRewardDetails"
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(area)
	var lines: PackedStringArray = []
	for type in state.get("rewardOptions",[]):
		if RULES.has(type): lines.append(RULES[type])
	var locked := _reroll_locked()
	var message := "\n".join(lines)
	if locked:
		message = str(_reroll_state().get("note",""))
		if message.is_empty(): message = "젬 다시 뽑기 결과를 확인하고 있습니다"
	var detail := _text(area,message,10,locked)
	detail.name = "GemRerollStatus" if locked else "GemRewardRules"
	detail.modulate = Color("98c4cb") if locked else Color("939aa4")
	detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style: StyleBox = hud.overlay.get_theme_stylebox("panel")
	var inner_width := maxf(1,width-style.get_content_margin(SIDE_LEFT)-style.get_content_margin(SIDE_RIGHT))
	var font: Font = detail.get_theme_font("font")
	var font_size := detail.get_theme_font_size("font_size")
	var reserved := 0.0
	for text in ["\n".join(RULES.values()),"처리 결과를 확인해야 합니다. 다시 눌러 확인하세요.","저장에 실패했습니다. 다시 눌러 저장을 재시도하세요."]:
		var measured := font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,inner_width,font_size,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE).y
		var line_count := maxi(1,ceili(measured/font.get_height(font_size)))
		reserved = maxf(reserved,measured+(line_count-1)*detail.get_theme_constant("line_spacing"))
	area.custom_minimum_size.y = ceilf(reserved)+4

func _paint_card(card: Button, type: String, collection: Dictionary) -> void:
	card.set_meta("gem_type",type)
	UiWidgets.clear(card)
	var accent := Color(str(GEM_COLORS.get(type,"69D7FF")))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("07111d").lerp(accent,0.19)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("normal",style)
	card.add_theme_stylebox_override("disabled",style)
	var pressed: StyleBoxFlat = style.duplicate()
	pressed.bg_color = Color("07111d").lerp(accent,0.30)
	card.add_theme_stylebox_override("pressed",pressed)
	card.add_theme_stylebox_override("hover",pressed)
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
	reward_icon(socket,"gems/"+str(type)+".png",30)
	var name_label := _text(content,hud.gem_name(type),12,true)
	name_label.custom_minimum_size.y = 32
	var effect := _text(content,_effect(type),10,true)
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text(content,{"lightWeapon":"경량화기 전용","heavyWeapon":"중화기 전용"}.get(type,""),9,true).modulate = Color("9ca3ab")
	var count := int(collection.get(type,0))
	var pill := _tinted_panel(content,Color("171b20dd"),Color("33d8ff55") if count > 0 else Color("6f778055"),12)
	pill.custom_minimum_size.y = 22
	_text(pill,"보유 %d" % count if count > 0 else "미보유",11,true).modulate = Color("b9d6e4") if count > 0 else Color("9ca3ab")

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
	reward_icon(title,"gems/"+pending_gem+".png",40)
	_text(title,hud.gem_name(pending_gem)+"\n"+_effect(pending_gem),13)
	if RULES.has(pending_gem): _text(body,RULES[pending_gem],10)
	var compatible := HFlowContainer.new()
	body.add_child(compatible)
	for type in hud.app.run_domain.service.derived(state).get("availableTurretTypes",[]):
		var allowed: bool = pending_gem in hud.app.run_domain.growth.data.turretRules[type].compatibleGems
		var label := _text(compatible,str(hud.TOWERS.get(type,type))+(" ✓" if allowed else " ×"),11)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.modulate = Color("a6e9bc") if allowed else Color("77838d")
	_text(body,target_hint if not target_hint.is_empty() else "장착할 타워를 선택하세요 · 전장을 드래그할 수 있습니다",12,true)
	target_actions = HBoxContainer.new()
	target_layer.add_child(target_actions)
	target_actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	target_actions.offset_left = safe.x+8; target_actions.offset_right = -safe.z-8; target_actions.offset_top = -safe.w-60; target_actions.offset_bottom = -safe.w-16
	for spec in [["젬 다시 선택",func(): close_back()],["보관",func(): _settle({"kind":"chooseRewardGem","type":pending_gem})]]:
		UiWidgets.button(target_actions,spec[0],spec[1]).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func board_tap(tile: Vector2i) -> bool:
	if _reroll_locked(): return true
	if not targeting(): return false
	if replacing(): return true
	var state: Dictionary = hud.app.run_domain.state
	for turret in state.get("turrets",[]):
		if int(turret.x) != tile.x or int(turret.y) != tile.y: continue
		if pending_gem not in hud.app.run_domain.growth.data.turretRules[turret.type].compatibleGems:
			target_hint = "경량화기 포탑에만 장착할 수 있습니다" if pending_gem == "lightWeapon" else "이 포탑에는 장착할 수 없습니다"
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
	body.add_theme_constant_override("separation",8)
	var safe: Vector4 = hud.safe_insets()
	var modal_width := minf(hud.get_viewport_rect().size.x-safe.x-safe.z-24,420)
	var narrow: bool = modal_width < 340
	var maximum := int(hud.app.run_domain.service.derived(state).get("maxTurretLinkSlots",3))
	var opened := int(turret.slotLimit)
	var cost := int(hud.app.run_domain.service.quotes(state,replacement_id).get("link",0))
	var buying := replacement_slot == opened
	var header := HBoxContainer.new(); body.add_child(header)
	_text(header,"젬 장착",20)
	var close: Button = UiWidgets.button(header,"×",func(): close_back())
	close.name = "ReplacementClose"; close.tooltip_text = "포탑 다시 선택"; close.custom_minimum_size = Vector2(30,30)
	UiWidgets.style_hud_button(close,"quiet",false,Vector2(3,0))
	var tower := HBoxContainer.new(); tower.add_theme_constant_override("separation",6); body.add_child(tower)
	reward_icon(tower,"ui/hud/turrets_3d/"+str(turret.type)+".png",28)
	_text(tower,"%s · Lv.%d" % [hud.TOWERS.get(turret.type,turret.type),turret.level],11 if narrow else 13)
	var capacity := _text(tower,"장착 %d개 · 최대 %d개" % [opened,maximum],10 if narrow else 12)
	capacity.name = "ReplacementCapacity"; capacity.size_flags_horizontal = Control.SIZE_SHRINK_END
	capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; capacity.autowrap_mode = TextServer.AUTOWRAP_OFF
	_replacement_rule(body)
	var incoming_row := HBoxContainer.new(); incoming_row.add_theme_constant_override("separation",10); body.add_child(incoming_row)
	reward_icon(incoming_row,"gems/"+pending_gem+".png",40)
	var incoming_text := VBoxContainer.new(); incoming_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; incoming_row.add_child(incoming_text)
	_text(incoming_text,"새 젬 · "+hud.gem_name(pending_gem),15).modulate = Color("8ee6ff")
	_text(incoming_text,hud.gem_effect(pending_gem,turret),12)
	var center := CenterContainer.new(); body.add_child(center)
	var rows := VBoxContainer.new(); rows.name = "ReplacementSockets"; rows.add_theme_constant_override("separation",10); center.add_child(rows)
	var column_width := clampf((modal_width-28-32)/3.0,68,96)
	var extent := minf(82,column_width)
	var sockets: HBoxContainer
	for slot in opened:
		if slot % 3 == 0:
			sockets = HBoxContainer.new(); sockets.alignment = BoxContainer.ALIGNMENT_CENTER
			sockets.add_theme_constant_override("separation",0); rows.add_child(sockets)
		else:
			var link_area := Control.new(); link_area.custom_minimum_size = Vector2(16,extent)
			link_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; sockets.add_child(link_area)
			var link := reward_icon(link_area,"ui/components/gem_link_locked.png",0)
			link.position = Vector2(-3,(extent-8)/2); link.size = Vector2(22,8)
		var column := VBoxContainer.new(); column.custom_minimum_size.x = column_width
		column.add_theme_constant_override("separation",3); sockets.add_child(column)
		var socket: Button = UiWidgets.button(column,"",func(): _select_replacement_slot(slot))
		socket.name = "Slot%d" % slot; socket.custom_minimum_size = Vector2(extent,extent)
		socket.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for style in ["normal","hover","pressed","disabled","focus"]: socket.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		var art := reward_icon(socket,"ui/components/"+("gem_socket_selected.png" if replacement_slot == slot else "gem_socket_empty.png"),0)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var gem := str(turret.equippedGemSlots[slot])
		var icon := reward_icon(socket,"gems/"+gem+".png",0)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = extent*0.22; icon.offset_right = -extent*0.22; icon.offset_top = extent*0.22; icon.offset_bottom = -extent*0.22
		if replacement_slot == slot:
			var check := _text(socket,"✓",14,true)
			check.name = "SelectedSocketCheck"; check.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			check.offset_left = -22; check.offset_right = -2; check.offset_top = -23; check.offset_bottom = -2
			check.add_theme_color_override("font_color",Color("8ee6ff"))
		var gem_label := _text(column,hud.gem_name(gem),11 if narrow else 12,true)
		gem_label.name = "SlotName%d" % slot; gem_label.custom_minimum_size.x = column_width
		gem_label.add_theme_color_override("font_color",Color("e8f8ff"))
		var effect := _text(column,_replacement_effect(gem,turret),10 if narrow else 11,true)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD
		effect.name = "SlotEffect%d" % slot; effect.custom_minimum_size.x = column_width
		socket.tooltip_text = hud.gem_name(gem)+" · "+hud.gem_effect(gem,turret)
	_replacement_rule(body)
	var guide := _text(body,"선택한 젬은 보관함으로 돌아갑니다." if replacement_slot >= 0 and not buying else "장착 방법을 선택하세요.",11,true)
	guide.name = "ReplacementGuide"; guide.custom_minimum_size.y = 34; guide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if opened < maximum:
		var display_cost: int = cost if cost > 0 else hud.gem_panel._slot_price(state,replacement_id,opened)
		var buy: Button = UiWidgets.button(body,"",func(): _select_replacement_slot(opened))
		buy.name = "ReplacementAddSlot"; buy.custom_minimum_size.y = 84 if narrow else 68
		hud.Components.apply(buy,"primary" if buying else "secondary")
		buy.disabled = cost <= 0 or int(state.gold) < cost
		var content := _replacement_button_body(buy,Vector2(8,6))
		content.add_theme_constant_override("separation",5)
		var mark := _text(content,"✓" if buying else "○",18,true)
		mark.name = "AddSlotSelection"; mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; mark.custom_minimum_size.x = 18
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_color_override("font_color",Color("8ee6ff") if buying else Color("90a9b6"))
		var plus_area := Control.new(); plus_area.custom_minimum_size = Vector2(32,32)
		plus_area.size_flags_vertical = Control.SIZE_SHRINK_CENTER; content.add_child(plus_area)
		var plus_socket := reward_icon(plus_area,"ui/components/gem_socket_empty.png",0); plus_socket.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var plus := _text(plus_area,"+",22,true); plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var detail := VBoxContainer.new(); detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER; detail.add_theme_constant_override("separation",2); content.add_child(detail)
		if narrow:
			_text(detail,"새 슬롯 추가",12)
			_replacement_money(detail,"",display_cost,"SlotPrice",11)
		else:
			_replacement_money(detail,"새 슬롯 추가 ·",display_cost,"SlotPrice",14)
		var reason := "기존 젬 유지 · 새 슬롯에 장착"
		if cost <= 0: reason = "포탑 Lv.5부터 추가 가능"
		elif int(state.gold) < cost: reason = "골드 %s 부족" % HudNumber.compact_integer(cost-int(state.gold))
		var description := _text(detail,reason,10 if narrow else 11)
		description.name = "AddSlotDescription"
		var owned := _replacement_money(content,"보유",int(state.gold),"OwnedGold",10 if narrow else 11)
		owned.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.tooltip_text = reason
		if buy.disabled: content.modulate = Color("889ba7")
	var confirm: Button = UiWidgets.button(body,"",_confirm_replacement)
	confirm.name = "ReplacementConfirm"; confirm.custom_minimum_size.y = 44
	hud.Components.apply(confirm,"primary")
	confirm.disabled = replacement_slot < 0 or (buying and (opened >= maximum or cost <= 0 or int(state.gold) < cost))
	var confirm_content := _replacement_button_body(confirm,Vector2(6,4)); confirm_content.alignment = BoxContainer.ALIGNMENT_CENTER
	var caption := "장착 방법을 선택하세요" if replacement_slot < 0 else ("슬롯 추가 후 장착 ·" if buying else "선택한 젬과 교체")
	var confirm_label := _text(confirm_content,caption,14 if not narrow else 12,true)
	confirm_label.name = "ConfirmCaption"; confirm_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if buying: _replacement_money(confirm_content,"",cost,"ConfirmPrice",14 if not narrow else 12)
	confirm.tooltip_text = caption
	if confirm.disabled: confirm_content.modulate = Color("788b98")
	var back: Button = UiWidgets.button(body,"포탑 다시 선택",func(): close_back())
	back.name = "ReplacementBack"; back.custom_minimum_size.y = 34
	UiWidgets.style_hud_button(back,"quiet",false,Vector2(8,6))

func _replacement_effect(gem: String, turret: Dictionary) -> String:
	# Keep Korean words and the value/unit together at compact socket widths.
	var split := RegEx.new(); split.compile("\\s(?=[+−-]?\\d)")
	return split.sub(hud.gem_effect(gem,turret),"\n",true).replace(", ",",\n").replace(" (","\n(")

func _replacement_rule(parent: Node) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new(); style.color = Color("347c9066"); style.thickness = 1
	line.add_theme_stylebox_override("separator",style); parent.add_child(line)

func _replacement_button_body(button: Button, padding: Vector2) -> HBoxContainer:
	var content := HBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = padding.x; content.offset_right = -padding.x
	content.offset_top = padding.y; content.offset_bottom = -padding.y
	return content

func _replacement_money(parent: Node, prefix: String, amount: int, node_name: String, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new(); row.name = node_name; row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",3); parent.add_child(row)
	if parent is HBoxContainer: row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not prefix.is_empty():
		var label := _text(row,prefix,font_size)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF; label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon := reward_icon(row,"ui/hud/icons/gold.png",14); icon.name = "GoldIcon"
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := _text(row,HudNumber.compact_integer(amount),font_size); value.name = "Amount"
	value.tooltip_text = str(amount)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF; value.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return row

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

func _recover_reward() -> void:
	if not hud.app.has_method("recover_reward_command"): return
	await hud.app.recover_reward_command()
	if is_instance_valid(hud) and hud.is_inside_tree():
		key = ""
		hud.refresh()

func _settle(command: Dictionary) -> void:
	if _reroll_locked() or hud.app.run_domain.state.get("phase") != "reward": return
	if hud.app.has_method("choose_reward"): await hud.app.choose_reward(command)
	else: hud.app.apply_run_command(command)
	if not is_instance_valid(hud): return
	# Persistence can fail after a successful domain mutation; never replay settlement.
	if hud.app.run_domain.state.get("phase") != "reward":
		pending_gem = ""
		replacement_id = -1
		replacement_slot = -1
	key = ""
	hud.refresh()
	hud.app.refresh_selection()

func _result(state: Dictionary) -> void:
	ResultPresenter.new(self).build(state)
	result_entrance.conceal_body()

func _record_text(state: Dictionary,progression: Dictionary,best: int) -> String:
	if state.get("lastRunWasNewBestRound",false):
		var previous := int(state.get("lastRunPreviousBestRound",0))
		return "%dR → %dR" % [previous,state.get("completedRounds",0)] if previous>0 else "%dR 첫 기록" % int(state.get("completedRounds",0))
	if hud.app.stage+1 in progression.get("clearedStageNumbers",[]): return "클리어"
	return "최고 %dR" % best

func _effect(type: String) -> String:
	# battle_labels is exported from the Flutter gem catalog; only layout changes here.
	var description: String = hud.gem_description(type)
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

func _settlement_state() -> Dictionary:
	if hud.app.get("save_failed") == true: return {"status":"save_failed","code":"CHECKPOINT_SAVE_FAILED"}
	var services = hud.app.get("services")
	if services is Object and services.has_method("run_settlement_state"):
		return services.run_settlement_state(str(hud.app.run_domain.state.get("economyRunId","")))
	return {"status":"queued" if _server_reward_pending() else "completed","code":""}

func _settlement_note() -> String:
	match str(_settlement_state().get("status","")):
		"requesting": return "전투 기록 저장됨 · 서버 보상 정산 중"
		"completed": return "전투 기록 저장됨 · 서버 보상 정산 완료"
		"retry": return "전투 기록 저장됨 · 서버 보상 정산 실패"
		"offline": return "전투 기록 저장됨 · 연결 후 서버 보상 정산"
		"guest": return "전투 기록 저장됨 · 게스트 보상은 서버 정산되지 않음"
		"save_failed": return "전투 기록 저장 실패 · 다시 저장해 주세요"
		"rejected": return "전투 기록 저장됨 · 서버 보상 정산 거절"
		"queued": return "전투 기록 저장됨 · 서버 보상 정산 준비 중"
	return "전투 기록 저장됨"

func _server_reward_pending() -> bool:
	if not hud.app.checkpoint is Object or not hud.app.checkpoint.has_method("rewards"): return false
	var queue = hud.app.checkpoint.rewards()
	if queue == null: return false
	var run_id := str(hud.app.run_domain.state.get("economyRunId",""))
	for reward in queue.state.get("pendingRewards",[]):
		if str(reward.get("runId","")) == run_id: return true
	return false

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

func _fit_after_layout(revision: int) -> void:
	# Rebuilt flow rows first measure at their unset width. Keep the existing
	# frame until native containers have assigned widths and wrapped entries.
	var tree: SceneTree = hud.get_tree()
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(hud) or not hud.is_inside_tree() or revision != _layout_revision: return
	_layout_pending = false
	_fit_modal()
	result_entrance.bind_body()
	gem_entrance.bind_body()
	gem_flip.bind_body()

func _fit_modal() -> void:
	if not is_instance_valid(hud) or not hud.overlay.visible or _layout_pending: return
	var viewport: Vector2 = hud.get_viewport_rect().size
	var safe: Vector4 = hud.safe_insets()
	# The removed body may have constrained the eager width to its old minimum.
	# Apply the requested width again after the replacement body has laid out.
	hud.overlay.size.x = minf(viewport.x-safe.x-safe.z-24,420)
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
