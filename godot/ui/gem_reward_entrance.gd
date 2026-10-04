extends Node
## Approved center-spread presentation only; the battle clock and domain stay untouched.
const DURATION := 0.82
const FRAME_DURATION := 0.40
class RuneRing extends Control:
	func _draw() -> void:
		var center := size*0.5
		# Soft inner/outer halo around the approved 160px ring.
		for spread in range(11,0,-1):
			draw_arc(center,80,0,TAU,96,Color(0.384,0.89,0.808,0.008),spread*2.0,true)
		draw_arc(center,80,0,TAU,96,Color("74eadb"),1,true)
		for dash in 48:
			var angle := dash*TAU/48.0
			draw_arc(center,64,angle,angle+TAU/96.0,3,Color("9beddd99"),1,true)
		var extent := 54.0*sqrt(2.0)
		draw_polyline(PackedVector2Array([center+Vector2(0,-extent),center+Vector2(extent,0),center+Vector2(0,extent),center+Vector2(-extent,0),center+Vector2(0,-extent)]),Color("9bedddaa"),1,true)

var hud
var shade: ColorRect
var active := false
var identity := ""
var started_usec := 0
var _seen: Dictionary = {}
var _tracks: Array = []
var _frame_track: Dictionary = {}
var _buttons: Array = []
var _ring: Control
var _body_ready := false
var _overlay_modulate := Color.WHITE
var _body_modulate := Color.WHITE
var _shade_modulate := Color.WHITE

func setup(owner, dimmer: ColorRect) -> void:
	hud = owner
	shade = dimmer
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func consider(reward_identity: String, eligible: bool) -> void:
	if not eligible:
		cancel()
		# Entering target/replacement or purchase is not a new wave presentation.
		_seen[reward_identity] = true
		return
	if identity == reward_identity: return
	cancel()
	identity = reward_identity
	if _seen.has(identity): return
	_seen[identity] = true
	active = true
	started_usec = 0
	_body_ready = false
	_frame_track = {"position":hud.overlay.position,"last_position":hud.overlay.position,
		"scale":hud.overlay.scale,"rotation":hud.overlay.rotation,"pivot":hud.overlay.pivot_offset}
	_overlay_modulate = hud.overlay.modulate
	_body_modulate = hud.overlay_body.modulate
	_shade_modulate = shade.modulate
	hud.overlay.modulate.a = 0
	hud.overlay_body.modulate.a = 0
	shade.modulate.a = 0
	_ring = RuneRing.new()
	_ring.name = "GemEntranceRuneRing"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.size = Vector2(160,160)
	_ring.pivot_offset = _ring.size*0.5
	hud.add_child(_ring)
	hud.move_child(_ring,hud.overlay.get_index())
	_apply_ring(0)
	set_process(true)

func elapsed() -> float:
	return 0.0 if started_usec == 0 else (Time.get_ticks_usec()-started_usec)/1000000.0

func detach_body() -> void:
	if not active: return
	_reset_tracks()
	_restore_buttons()
	_body_ready = false
	hud.overlay_body.modulate.a = 0

func conceal_body() -> void:
	if not active: return
	for button in hud.overlay_body.find_children("*","Button",true,false):
		var colors: Dictionary = {}
		for pair in [["font_disabled_color","font_color"],["icon_disabled_color","icon_normal_color"]]:
			colors[pair[0]] = {"override":button.has_theme_color_override(pair[0]),"value":button.get_theme_color(pair[0])}
			button.add_theme_color_override(pair[0],button.get_theme_color(pair[1]))
		_buttons.append({"node":button,"disabled":button.disabled,"style_override":button.has_theme_stylebox_override("disabled"),
			"style":button.get_theme_stylebox("disabled"),"colors":colors})
		# Input locking must retain the approved card/shard appearance and margins.
		button.add_theme_stylebox_override("disabled",button.get_theme_stylebox("normal"))
		button.disabled = true

func bind_body() -> void:
	if not active: return
	_reset_tracks()
	if started_usec == 0: started_usec = Time.get_ticks_usec()
	_body_ready = true
	hud.overlay_body.modulate = _body_modulate
	var row: Control = hud.overlay_body.find_child("GemRewardCards",true,false)
	if row != null:
		var index := 0
		for card in row.get_children():
			if not card is Button: continue
			_track(card,0.56,0.14+index*0.035,index)
			index += 1
	for spec in [["GemRewardShards",0.16,0.62],["GemRewardInventoryHeading",0.15,0.67],["GemRewardInventory",0.15,0.67]]:
		_track(hud.overlay_body.find_child(spec[0],true,false),spec[1],spec[2])
	_apply(elapsed())

func _process(_delta: float) -> void:
	if not active: return
	if not is_instance_valid(hud) or not hud.is_visible_in_tree() or not hud.overlay.visible:
		cancel()
		return
	_apply(elapsed())

func _apply(time: float) -> void:
	if time >= DURATION:
		cancel(false)
		return
	hud.overlay.modulate = _overlay_modulate*Color(1,1,1,_ease(clampf(time/0.25,0,1)))
	shade.modulate = _shade_modulate*Color(1,1,1,_ease(clampf(time/0.24,0,1)))
	_apply_frame(time)
	_apply_ring(time)
	if not _body_ready:
		hud.overlay_body.modulate.a = 0
		return
	# Adopt native container positions before deriving the current card pitch.
	for track in _tracks:
		var node: Control = track.node
		if is_instance_valid(node) and not node.position.is_equal_approx(track.last_position): track.position = node.position
	for track in _tracks:
		var node: Control = track.node
		if not is_instance_valid(node): continue
		var progress := _ease(clampf((time-track.delay)/track.duration,0,1))
		var offset := Vector2.ZERO
		if track.index >= 0:
			var row: HBoxContainer = node.get_parent()
			var pitch: float = row.get_child(0).size.x+row.get_theme_constant("separation")
			offset = Vector2((1-track.index)*pitch,14)*(1-progress)
			node.pivot_offset = node.size*Vector2(0.5,0.65)
			node.scale = track.scale*lerpf(0.7,1,progress)
			node.rotation = track.rotation+deg_to_rad((track.index-1)*-8.0)*(1-progress)
			node.position = track.position+offset
			track.last_position = node.position
		node.modulate = track.modulate*Color(1,1,1,progress)

func _adopt_frame_position() -> void:
	# _fit_modal owns native geometry, including a resized or rebuilt body.
	if not hud.overlay.position.is_equal_approx(_frame_track.last_position):
		_frame_track.position = hud.overlay.position

func _apply_frame(time: float) -> void:
	_adopt_frame_position()
	var progress := _ease(clampf(time/FRAME_DURATION,0,1))
	hud.overlay.pivot_offset = hud.overlay.size*0.5
	hud.overlay.scale = _frame_track.scale*lerpf(0.90,1,progress)
	hud.overlay.position = _frame_track.position+Vector2(0,14)*(1-progress)
	_frame_track.last_position = hud.overlay.position

func _restore_frame() -> void:
	if is_instance_valid(hud) and is_instance_valid(hud.overlay) and not _frame_track.is_empty():
		_adopt_frame_position()
		hud.overlay.position = _frame_track.position
		hud.overlay.scale = _frame_track.scale
		hud.overlay.rotation = _frame_track.rotation
		hud.overlay.pivot_offset = _frame_track.pivot
	_frame_track.clear()

func _apply_ring(time: float) -> void:
	if not is_instance_valid(_ring): return
	# The ring is a sibling, so follow the transformed frame center explicitly.
	_ring.position = hud.overlay.get_transform()*(hud.overlay.size*0.5)-_ring.size*0.5
	var progress := _ease(clampf(time/0.62,0,1))
	var first := progress <= 0.35
	var weight := progress/0.35 if first else (progress-0.35)/0.65
	_ring.scale = Vector2.ONE*lerpf(0.3 if first else 0.85,0.85 if first else 1.5,weight)
	_ring.rotation = deg_to_rad(lerpf(-35 if first else 0,0 if first else 18,weight))
	_ring.modulate.a = lerpf(0 if first else 0.8,0.8 if first else 0,weight)

func _track(node: Control, length: float, delay: float, index := -1) -> void:
	if node == null: return
	_tracks.append({"node":node,"position":node.position,"last_position":node.position,
		"scale":node.scale,"rotation":node.rotation,"pivot":node.pivot_offset,"modulate":node.modulate,
		"duration":length,"delay":delay,"index":index})

static func _ease(progress: float) -> float:
	# Invert the x coordinate of the approved cubic-bezier(.18,.8,.25,1).
	if progress <= 0 or progress >= 1: return progress
	var low := 0.0
	var high := 1.0
	for iteration in 16:
		var t := (low+high)*0.5
		var x := 3*(1-t)*(1-t)*t*0.18+3*(1-t)*t*t*0.25+t*t*t
		if x < progress: low = t
		else: high = t
	var t := (low+high)*0.5
	return 3*(1-t)*(1-t)*t*0.8+3*(1-t)*t*t+t*t*t

func _reset_tracks() -> void:
	for track in _tracks:
		var node: Control = track.node
		if not is_instance_valid(node): continue
		if node.position.is_equal_approx(track.last_position): node.position = track.position
		node.scale = track.scale
		node.rotation = track.rotation
		node.pivot_offset = track.pivot
		node.modulate = track.modulate
	_tracks.clear()

func _restore_buttons() -> void:
	for original in _buttons:
		if not is_instance_valid(original.node): continue
		original.node.disabled = original.disabled
		if original.style_override: original.node.add_theme_stylebox_override("disabled",original.style)
		else: original.node.remove_theme_stylebox_override("disabled")
		for color_name in original.colors:
			var color: Dictionary = original.colors[color_name]
			if color.override: original.node.add_theme_color_override(color_name,color.value)
			else: original.node.remove_theme_color_override(color_name)
	_buttons.clear()

func cancel(clear_identity := true) -> void:
	# An inactive helper must not overwrite terminal-result presentation state.
	if active:
		active = false
		set_process(false)
		_reset_tracks()
		_restore_frame()
		_restore_buttons()
		if is_instance_valid(hud):
			if is_instance_valid(hud.overlay): hud.overlay.modulate = _overlay_modulate
			if is_instance_valid(hud.overlay_body): hud.overlay_body.modulate = _body_modulate
		if is_instance_valid(shade): shade.modulate = _shade_modulate
		if is_instance_valid(_ring):
			_ring.hide()
			_ring.queue_free()
		_ring = null
		_body_ready = false
	if clear_identity: identity = ""

func _exit_tree() -> void:
	cancel()
