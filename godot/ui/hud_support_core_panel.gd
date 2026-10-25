extends RefCounted
## Support core construction (bag gem choice) and placed-core details.
## Reads the live HUD owner; commands route through the HUD.
const Frame = preload("res://ui/lobby_frame.gd")
const HudNumber = preload("res://ui/hud_number.gd")
const SupportCore = preload("res://app/support_core_rules.gd")
const UiWidgets = preload("res://ui/ui_widgets.gd")
const KIND := "supportCore"
const TITLE := "지원 코어"
const ICON := "ui/hud/turrets_3d/supportCore.png"
const CYAN := Color("3fe6d6")
const DESCRIPTION := "상하좌우로 맞닿은 포탑의 피해를 15% 높입니다. 직접 공격하지 않습니다."
var hud: Control
## Bag gem chosen for the next construction; cleared after building.
var gem := ""

func _init(owner: Control) -> void:
	hud = owner

func blocked_reason() -> String:
	if hud.app.has_method("support_core_blocked") and hud.app.support_core_blocked(): return "이 도전에서는 지을 수 없습니다."
	return ""

## Construction step on an empty build tile: choose which bag gem to spend.
func build_detail(state: Dictionary) -> void:
	var inventory: Dictionary = state.get("gemInventory", {})
	if not inventory.has(gem) or int(inventory[gem]) <= 0: gem = ""
	var heading := HBoxContainer.new(); heading.name = "SupportCoreHeading"; hud.body.add_child(heading)
	var title: Label = UiWidgets.label(heading, TITLE, 14); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reason := blocked_reason()
	var label := "설치 · %s 골드" % HudNumber.compact_price(SupportCore.BUILD_GOLD) if not gem.is_empty() else "소비할 젬 선택"
	var install: Button = UiWidgets.button(heading, label, func(): _install())
	install.name = "SupportCoreInstall"
	install.tooltip_text = "설치 · %d 골드 · %s 1개 소비" % [SupportCore.BUILD_GOLD, hud.gem_name(gem)] if not gem.is_empty() else "가방에서 소비할 젬을 고르세요"
	hud.track_purchase_button(install, "gold", SupportCore.BUILD_GOLD, gem.is_empty() or not reason.is_empty())
	UiWidgets.label(hud.body, DESCRIPTION, 11)
	var cost: Label = UiWidgets.label(hud.body, "골드 %d + 가방 젬 1개 · 소비한 젬은 철거해도 돌아오지 않습니다." % SupportCore.BUILD_GOLD, 10)
	cost.name = "SupportCoreCost"; cost.modulate = Color("b7d5e3")
	if not reason.is_empty():
		var note: Label = UiWidgets.label(hud.body, reason, 11); note.name = "SupportCoreBlocked"; note.modulate = Color("ffb38a")
		return
	var caption: Label = UiWidgets.label(hud.body, "소비할 젬", 11); caption.name = "SupportCoreGemCaption"; caption.modulate = CYAN
	var strip := ScrollContainer.new(); strip.name = "SupportCoreGems"
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	hud.body.add_child(strip)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 4); strip.add_child(row)
	for type in inventory:
		if int(inventory[type]) <= 0: continue
		_gem_button(row, str(type), int(inventory[type]))
	if row.get_child_count() == 0:
		var empty: Label = UiWidgets.label(hud.body, "가방에 젬이 없습니다. 장착한 젬은 소비할 수 없습니다.", 11)
		empty.name = "SupportCoreNoGems"; empty.modulate = Color("ffb38a")
	else: strip.custom_minimum_size.y = 50

func _gem_button(row: Node, type: String, count: int) -> void:
	var b: Button = UiWidgets.button(row, "", func():
		gem = "" if gem == type else type
		hud.refresh())
	b.name = "SupportCoreGem_" + type
	b.custom_minimum_size = Vector2(48, 48)
	b.toggle_mode = true; b.button_pressed = gem == type
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var frame := Frame.new("ui/components/card_frame.png", 2)
		if gem == type: frame.modulate_color = Color("ffe29a")
		elif state_name == "hover": frame.modulate_color = Color("a6f4ff")
		b.add_theme_stylebox_override(state_name, frame)
	var icon := TextureRect.new(); icon.name = "SupportCoreGemIcon"
	icon.texture = hud.AppTheme.texture("gems/" + type + ".png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	icon.offset_left = -17; icon.offset_right = 17; icon.offset_top = 3; icon.offset_bottom = 37
	var amount: Label = UiWidgets.label(b, "×%d" % count, 10)
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF; amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	amount.offset_left = 3; amount.offset_right = -4; amount.offset_top = -15; amount.offset_bottom = -1
	b.tooltip_text = "%s ×%d" % [hud.gem_name(type), count]

func _install() -> void:
	if gem.is_empty(): return
	var chosen := gem
	if hud.app.apply_run_command({"kind":"buildSupportCore", "x":hud.app.selected.x, "y":hud.app.selected.y, "gem":chosen}):
		gem = ""
	hud.refresh()

## Placed core: effect, active connections and demolition.
func detail(state: Dictionary, core: Dictionary) -> void:
	var heading := HBoxContainer.new(); heading.name = "SupportCoreDetailHeading"
	heading.add_theme_constant_override("separation", 8); hud.body.add_child(heading)
	UiWidgets.icon(heading, ICON, 40).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var names := VBoxContainer.new(); names.size_flags_horizontal = Control.SIZE_EXPAND_FILL; names.add_theme_constant_override("separation", 0); heading.add_child(names)
	UiWidgets.label(names, TITLE, 14).name = "SupportCoreTitle"
	var family: Label = UiWidgets.label(names, "피해 증가", 11); family.modulate = CYAN
	var refund := refund_of(state, core)
	var demolish: Button = UiWidgets.button(heading, "철거 · +%s G" % HudNumber.compact_price(refund), func(): _demolish_confirm(core, refund))
	demolish.name = "SupportCoreDemolish"; demolish.tooltip_text = "철거 · +%d G · 금액 확인" % refund
	demolish.disabled = state.get("phase") not in ["preparation", "wave"]
	var linked := 0
	for connection in SupportCore.connections(state):
		if connection[0] == Vector2i(int(core.x), int(core.y)): linked += 1
	var effect: Label = UiWidgets.label(hud.body, "맞닿은 포탑 피해 +%d%%" % roundi(float(SupportCore.FAMILY_BONUS.damage) * 100.0), 12)
	effect.name = "SupportCoreEffect"
	var count: Label = UiWidgets.label(hud.body, "연결된 포탑 %d기" % linked if linked > 0 else "연결된 포탑 없음 · 상하좌우에 포탑을 지으세요", 11)
	count.name = "SupportCoreLinks"; count.modulate = CYAN if linked > 0 else Color("b7d5e3")
	var spent: Label = UiWidgets.label(hud.body, "소비한 젬 · %s" % hud.gem_name(str(core.get("consumedGem", ""))), 10)
	spent.name = "SupportCoreSpentGem"; spent.modulate = Color("9ab8c8")

func refund_of(state: Dictionary, core: Dictionary) -> int:
	return hud.app.run_domain.service.support_core_refund(core, hud.configuration_cache.derived(state, hud.app.run_domain.service))

func _demolish_confirm(core: Dictionary, refund: int) -> void:
	var box = hud.open_modal("지원 코어를 철거할까요?", 390)
	var exact := "철거 환급 · %d 골드" % refund
	box.tooltip_text = exact
	var summary := VBoxContainer.new(); summary.name = "SupportCoreDemolishSummary"; summary.add_theme_constant_override("separation", 6); box.add_child(summary)
	var identity := HBoxContainer.new(); identity.alignment = BoxContainer.ALIGNMENT_CENTER; identity.add_theme_constant_override("separation", 8); summary.add_child(identity)
	UiWidgets.icon(identity, ICON, 32)
	var title: Label = UiWidgets.label(identity, TITLE, 14); title.autowrap_mode = TextServer.AUTOWRAP_OFF; title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 8); summary.add_child(row)
	UiWidgets.icon(row, "ui/hud/icons/gold.png", 28).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var amount: Label = UiWidgets.label(row, "+" + HudNumber.compact_price(refund), 26)
	amount.name = "SupportCoreRefundAmount"; amount.tooltip_text = exact; amount.modulate = Color("ffd166")
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF; amount.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var note: Label = UiWidgets.label(summary, "소비한 젬은 돌아오지 않습니다.", 12)
	note.name = "SupportCoreGemLost"; note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; note.modulate = Color("b7d5e3")
	var gap := Control.new(); gap.custom_minimum_size.y = 4; box.add_child(gap)
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); box.add_child(actions)
	hud.menu_panel._action(actions, "취소", hud.close_modal, "secondary")
	var confirm: Button = hud.menu_panel._action(actions, "철거", func(): _demolish(int(core.x), int(core.y), refund), "danger")
	confirm.name = "SupportCoreDemolishConfirm"; confirm.tooltip_text = exact

func _demolish(x: int, y: int, quoted_refund: int) -> void:
	var state: Dictionary = hud.app.run_domain.state
	var core := SupportCore.at(state, x, y)
	if core.is_empty(): hud.close_modal(); return
	if refund_of(state, core) != quoted_refund:
		_demolish_confirm(core, refund_of(state, core))
		return
	hud.run_command({"kind":"sellSupportCore", "x":x, "y":y})
	hud.close_modal()
