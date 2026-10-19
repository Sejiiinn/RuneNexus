extends RefCounted
## Left battlefield shortcut for gem purchases, greyed while shards fall short.
## Confirmation hands off to the same app purchase as the gem tab; prices and
## grants stay owned by the app and server.
const Frame = preload("res://ui/lobby_frame.gd")
const HudNumber = preload("res://ui/hud_number.gd")
const UiWidgets = preload("res://ui/ui_widgets.gd")
const Fx = preload("res://ui/hud_gem_shortcut_fx.gd")
const SOCKET := 52.0
const TAG := Vector2(48,20)
## Greyscale lock plus an occasional diagonal light band. The band runs on
## shader TIME (0.7 s every 3.5 s) so the idle shine costs no CPU work.
const ART_SHADER := """shader_type canvas_item;
uniform float amount = 0.0;
uniform float shine = 0.0;
void fragment() {
	// COLOR already holds the sampled texture times modulate.
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(c.rgb, vec3(g) * 0.72, amount);
	float cycle = mod(TIME, 3.5);
	float sweep = cycle / 0.7 * 1.5 - 0.25;
	float band = (1.0 - smoothstep(0.0, 0.13, abs(UV.x * 0.65 + (1.0 - UV.y) * 0.35 - sweep))) * step(cycle, 0.7);
	rgb += vec3(0.85, 0.96, 1.0) * band * 0.8 * c.a * shine * (1.0 - amount);
	COLOR = vec4(rgb, c.a);
}"""
var hud: Control
var button: Button
var cost_label: Label
var grey: ShaderMaterial
var shine: ShaderMaterial
var fx: Control
var _requesting := false
var _was_active := false
var _shining := false

func _init(owner: Control) -> void:
	hud = owner

func build() -> void:
	button = Button.new(); button.name = "GemPurchaseShortcut"
	button.tooltip_text = "젬 구매"; button.focus_mode = Control.FOCUS_NONE; button.visible = false
	for style in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	button.custom_minimum_size = Vector2(SOCKET,SOCKET+TAG.y-4); button.size = button.custom_minimum_size
	button.pivot_offset = Vector2(SOCKET,SOCKET)*0.5
	button.pressed.connect(open_confirm)
	button.button_down.connect(func(): button.modulate = Color(0.82,0.88,0.92))
	button.button_up.connect(func(): button.modulate = Color.WHITE)
	hud.add_child(button)
	var shader := Shader.new(); shader.code = ART_SHADER
	grey = ShaderMaterial.new(); grey.shader = shader
	shine = ShaderMaterial.new(); shine.shader = shader
	var socket := _art(button,"ui/hud/gem_purchase_socket.png",Rect2(0,0,SOCKET,SOCKET))
	socket.name = "GemPurchaseSocket"
	var gems := _art(button,"ui/hud/icons/gem_purchase_trio.png",Rect2(10,8,SOCKET-20,SOCKET-17))
	gems.name = "GemPurchaseGems"; gems.material = shine
	fx = Fx.new(); fx.name = "GemPurchaseFlash"; fx.size = Vector2(SOCKET,SOCKET); button.add_child(fx)
	var tag := PanelContainer.new(); tag.name = "GemPurchasePrice"; tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Frame.new("ui/hud/gem_purchase_tag.png",0)
	frame.source_center = Rect2(6,5,48,5)
	frame.content_margin_left = 6; frame.content_margin_right = 6
	tag.add_theme_stylebox_override("panel",frame); tag.material = grey
	tag.position = Vector2((SOCKET-TAG.x)/2,SOCKET-4); tag.size = TAG; tag.custom_minimum_size = TAG
	button.add_child(tag)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation",3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE; tag.add_child(row)
	var shard := UiWidgets.icon(row,"ui/hud/icons/shard.png",11); shard.size_flags_vertical = Control.SIZE_SHRINK_CENTER; shard.material = grey
	cost_label = UiWidgets.label(row,"",11); cost_label.name = "GemPurchaseCost"
	cost_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; cost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; cost_label.add_theme_color_override("font_color",Color("e8f8ff"))

func _art(parent: Control,path: String,rect: Rect2) -> TextureRect:
	var art := TextureRect.new(); art.texture = hud.AppTheme.texture(path); art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = rect.position; art.size = rect.size; art.material = grey
	parent.add_child(art)
	return art

func cost() -> int:
	return int(hud.app.run_domain.growth.data.constants.gemChoicePurchaseCost)

func shown(state: Dictionary) -> bool:
	return str(state.get("phase","")) in ["preparation","wave"]

func available(state: Dictionary) -> bool:
	return shown(state) and int(state.get("gemShards",0)) >= cost()

## Always present during play; shortage, a pending purchase or a failed save
## grey out the whole socket, gems and price and block the tap.
func refresh(state: Dictionary) -> void:
	if not is_instance_valid(button): return
	button.visible = shown(state)
	if not button.visible:
		_was_active = false; fx.stop(); _set_sweep(false)
		return
	cost_label.text = HudNumber.compact_price(cost())
	var locked: bool = not available(state) or _requesting or hud.app.get("save_failed") == true
	button.disabled = locked
	if locked: button.modulate = Color.WHITE
	for art in [grey,shine]: art.set_shader_parameter("amount",1.0 if locked else 0.0)
	cost_label.add_theme_color_override("font_color",Color("8a949b") if locked else Color("e8f8ff"))
	button.tooltip_text = "젬 파편이 부족합니다" if not available(state) else "젬 구매"
	place()
	# Announce the moment a purchase becomes possible, then keep a calm,
	# occasional shine. Both stay off while greyed or under a modal.
	var lit: bool = not locked and not hud.modal_active()
	if lit and not _was_active: _celebrate()
	_was_active = not locked
	if not lit: fx.stop()
	_set_sweep(lit)

func _celebrate() -> void:
	fx.play()
	var pop := button.create_tween()
	pop.tween_property(button,"scale",Vector2.ONE*1.12,0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_property(button,"scale",Vector2.ONE,0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_sweep(on: bool) -> void:
	if on == _shining: return
	_shining = on
	shine.set_shader_parameter("shine",1.0 if on else 0.0)
	if not on: button.scale = Vector2.ONE

func sweeping() -> bool:
	return _shining

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
	fx.stop(); _set_sweep(false)
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
