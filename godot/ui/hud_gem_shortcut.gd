extends RefCounted
## Left battlefield shortcut shown while gem shards cover one gem purchase.
## Confirmation hands off to the same app purchase as the gem tab; prices and
## grants stay owned by the app and server.
const Frame = preload("res://ui/lobby_frame.gd")
const HudNumber = preload("res://ui/hud_number.gd")
const UiWidgets = preload("res://ui/ui_widgets.gd")
const SOCKET := 52.0
const TAG := Vector2(48,20)
var hud: Control
var button: Button
var cost_label: Label
var _requesting := false

func _init(owner: Control) -> void:
	hud = owner

func build() -> void:
	button = Button.new(); button.name = "GemPurchaseShortcut"
	button.tooltip_text = "젬 구매"; button.focus_mode = Control.FOCUS_NONE; button.visible = false
	for style in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	button.custom_minimum_size = Vector2(SOCKET,SOCKET+TAG.y-4); button.size = button.custom_minimum_size
	button.pressed.connect(open_confirm)
	button.button_down.connect(func(): button.modulate = Color(0.82,0.88,0.92))
	button.button_up.connect(func(): button.modulate = Color.WHITE)
	hud.add_child(button)
	var socket := _art(button,"ui/hud/gem_purchase_socket.png",Rect2(0,0,SOCKET,SOCKET))
	socket.name = "GemPurchaseSocket"
	_art(button,"ui/hud/icons/gem_purchase_trio.png",Rect2(10,8,SOCKET-20,SOCKET-17)).name = "GemPurchaseGems"
	var tag := PanelContainer.new(); tag.name = "GemPurchasePrice"; tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Frame.new("ui/hud/gem_purchase_tag.png",0)
	frame.source_center = Rect2(6,5,48,5)
	frame.content_margin_left = 6; frame.content_margin_right = 6
	tag.add_theme_stylebox_override("panel",frame)
	tag.position = Vector2((SOCKET-TAG.x)/2,SOCKET-4); tag.size = TAG; tag.custom_minimum_size = TAG
	button.add_child(tag)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation",3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE; tag.add_child(row)
	UiWidgets.icon(row,"ui/hud/icons/shard.png",11).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_label = UiWidgets.label(row,"",11); cost_label.name = "GemPurchaseCost"
	cost_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; cost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; cost_label.add_theme_color_override("font_color",Color("e8f8ff"))

func _art(parent: Control,path: String,rect: Rect2) -> TextureRect:
	var art := TextureRect.new(); art.texture = hud.AppTheme.texture(path); art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = rect.position; art.size = rect.size
	parent.add_child(art)
	return art

func cost() -> int:
	return int(hud.app.run_domain.growth.data.constants.gemChoicePurchaseCost)

func available(state: Dictionary) -> bool:
	return str(state.get("phase","")) in ["preparation","wave"] and int(state.get("gemShards",0)) >= cost()

func refresh(state: Dictionary) -> void:
	if not is_instance_valid(button): return
	var shown := available(state)
	button.visible = shown
	if not shown: return
	cost_label.text = HudNumber.compact_price(cost())
	button.disabled = _requesting or hud.app.get("save_failed") == true
	button.self_modulate = Color("78848a") if button.disabled else Color.WHITE
	place()

## Mirrors the camera toggle under the resource panel, inside the safe area.
func place() -> void:
	if not is_instance_valid(button): return
	var insets: Vector4 = hud.safe_insets()
	button.position = Vector2(8+insets.x,hud.top.offset_top+hud.top.size.y+6)

func open_confirm() -> void:
	var state: Dictionary = hud.app.run_domain.state
	if _requesting or not available(state): return
	var price := cost(); var shards := int(state.get("gemShards",0))
	var box: VBoxContainer = hud.open_modal("젬을 구매할까요?",390)
	var header: HBoxContainer = box.get_child(0)
	var icon := UiWidgets.icon(header,"ui/hud/icons/gem_purchase_trio.png",24); header.move_child(icon,0)
	var explanation := UiWidgets.label(box,"젬 파편을 사용해 젬 3개 중 1개를 고릅니다.",12)
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var summary := VBoxContainer.new(); summary.name = "GemPurchaseSummary"; summary.add_theme_constant_override("separation",4); box.add_child(summary)
	var cost_row := HBoxContainer.new(); cost_row.alignment = BoxContainer.ALIGNMENT_CENTER; cost_row.add_theme_constant_override("separation",8); summary.add_child(cost_row)
	UiWidgets.icon(cost_row,"ui/hud/icons/shard.png",28).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var amount := UiWidgets.label(cost_row,HudNumber.compact_price(price),26); amount.name = "GemPurchaseConfirmCost"
	amount.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.tooltip_text = "젬 파편 %d" % price
	var balance := UiWidgets.label(summary,"보유 %s → %s" % [HudNumber.compact_price(shards),HudNumber.compact_price(shards-price)],12)
	balance.name = "GemPurchaseBalance"; balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; balance.modulate = Color("aab8c2")
	var gap := Control.new(); gap.custom_minimum_size.y = 4; box.add_child(gap)
	var actions := HBoxContainer.new(); actions.name = "GemPurchaseActions"; actions.add_theme_constant_override("separation",8); box.add_child(actions)
	_action(actions,"취소",hud.close_modal,"secondary").name = "GemPurchaseCancel"
	_action(actions,"구매",_purchase,"primary").name = "GemPurchaseConfirm"

func _action(parent: Node,value: String,callback: Callable,variant: String) -> Button:
	var action: Button = hud.AppTheme.button(value,callback,variant)
	hud.Components.apply(action,variant)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(action)
	return action

func _purchase() -> void:
	if _requesting: return
	# Close first so the modal pause resumes the battle; the purchase then
	# records that running state and restores it after the gem choice.
	hud.close_modal()
	if not available(hud.app.run_domain.state) or not hud.app.has_method("purchase_reward_gems"): return
	_requesting = true; hud.refresh()
	await hud.app.purchase_reward_gems()
	_requesting = false
	if is_instance_valid(hud): hud.refresh()
