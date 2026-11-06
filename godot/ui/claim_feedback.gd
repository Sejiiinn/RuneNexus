extends RefCounted
## Feedback of server commands in the lobby dialogs: the blocking spinner while
## the server answers and, for single-kind claims, the gained amount rising from
## the claimed control.
const A = preload("res://ui/app_theme.gd")
const ReconnectOverlay = preload("res://ui/reconnect_overlay.gd")

static func wallet(lobby) -> Dictionary:
	return {"diamonds":lobby.diamonds(), "tickets":int(lobby.progression().get("turretModules",{}).get("tickets",0))}

## Blocks the modal behind the spinner, reusing its overlay, and returns that overlay.
static func show_overlay(modal: Control, overlay, active_check: Callable, caption := "보상을 수령하는 중") -> Control:
	if is_instance_valid(overlay) and overlay.get_parent() == modal:
		modal.move_child(overlay, -1)
		overlay.sync()
		return overlay
	var created := ReconnectOverlay.new()
	created.caption_text = caption
	created.show_delay = 0.15
	created.active_check = active_check
	modal.add_child(created)
	created.name = "ClaimOverlay"
	return created

## The claimed amount rises from the anchor, so success needs no notice line.
static func show_gain(modal, anchor, before: Dictionary, now: Dictionary) -> void:
	var diamonds := int(now.diamonds) - int(before.diamonds)
	var tickets := int(now.tickets) - int(before.tickets)
	if (diamonds <= 0 and tickets <= 0) or not is_instance_valid(modal) or not is_instance_valid(anchor): return
	var gain := HBoxContainer.new()
	gain.name = "ClaimGain"
	gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain.add_theme_constant_override("separation", 4)
	if diamonds > 0:
		gain.add_child(_gain_label("+%d" % diamonds, Color("8ee6ff")))
		gain.add_child(_image("res://assets/ui/diamond_currency.png", Vector2(17, 17)))
	if tickets > 0:
		gain.add_child(_image("stage_rewards/reward_module_ticket.png", Vector2(16, 19)))
		gain.add_child(_gain_label("+%d" % tickets, Color("f5cb61")))
	modal.add_child(gain)
	gain.reset_size()
	var rect: Rect2 = anchor.get_global_rect()
	# Wider ticket gains stay inside the dialog by not passing the anchor's right edge.
	gain.global_position = Vector2(minf(rect.get_center().x - gain.size.x / 2, rect.end.x - gain.size.x), rect.get_center().y - gain.size.y / 2)
	gain.pivot_offset = gain.size / 2
	if ProjectSettings.get_setting("accessibility/disable_animations", false):
		gain.create_tween().tween_callback(gain.queue_free).set_delay(0.9)
		return
	gain.modulate.a = 0.0
	gain.scale = Vector2.ONE * 0.7
	# A short rise keeps the pop inside the claimed row.
	var rest := gain.position.y - 14
	var tween := gain.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(gain, "modulate:a", 1.0, 0.12)
	tween.tween_property(gain, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_property(gain, "position:y", rest, 0.9)
	tween.chain().tween_property(gain, "modulate:a", 0.0, 0.3).set_delay(0.25)
	tween.chain().tween_callback(gain.queue_free)

static func _gain_label(value: String, color: Color) -> Label:
	var label := A.label(value, 16)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_override("font", A.font(800))
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color("02070d"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func _image(path: String, extent: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = A.texture(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = extent
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image
