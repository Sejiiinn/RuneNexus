extends Node
## Terminal-result presentation only. A real-time timeline survives body rebuilds.
## Keyframes match the approved crystal-assembly preview; no battle clock is used.
class FrameDrawing extends Control:
	var frame: StyleBox
	func _draw() -> void:
		if frame != null: frame.draw(get_canvas_item(),Rect2(Vector2.ZERO,size))

var hud
var shade: ColorRect
var active := false
var identity := ""
var success := true
var started_usec := 0
var duration := 1.14
var _seen: Dictionary = {}
var _tracks: Array = []
var _native_frame: StyleBox
var _frame_host: Control
var _halves: Array[Control] = []
var _drawings: Array[Control] = []
var _pending_buttons: Array = []

func setup(owner, dimmer: ColorRect) -> void:
	hud = owner
	shade = dimmer
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func consider(run_identity: String, won: bool) -> void:
	if identity == run_identity: return
	cancel()
	identity = run_identity
	if _seen.has(identity): return
	_seen[identity] = true
	success = won
	duration = 1.14 if success else 1.22
	active = true
	started_usec = 0
	_native_frame = hud.overlay.get_theme_stylebox("panel")
	var empty := StyleBoxEmpty.new()
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		empty.set_content_margin(side,_native_frame.get_content_margin(side))
	hud.overlay.add_theme_stylebox_override("panel",empty)
	_frame_host = Control.new()
	_frame_host.name = "ResultEntranceFrame"
	_frame_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_frame_host)
	hud.move_child(_frame_host,hud.overlay.get_index())
	for index in 2:
		var clip := Control.new()
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame_host.add_child(clip)
		_halves.append(clip)
		var drawing := FrameDrawing.new()
		drawing.frame = _native_frame
		drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(drawing)
		_drawings.append(drawing)
	shade.modulate.a = 0
	hud.overlay_body.modulate.a = 0
	set_process(true)
	_update_frame(0)

func detach_body() -> void:
	_reset_tracks()
	_restore_pending_buttons()
	if active: hud.overlay_body.modulate.a = 0

func conceal_body() -> void:
	if not active: return
	for button in hud.overlay_body.find_children("*","Button",true,false):
		_pending_buttons.append({"node":button,"disabled":button.disabled})
		button.disabled = true

func bind_body() -> void:
	if not active: return
	_reset_tracks()
	_restore_pending_buttons()
	if started_usec == 0: started_usec = Time.get_ticks_usec()
	hud.overlay_body.modulate.a = 1
	var crystal: Control = hud.overlay_body.find_child("ResultCrystal",true,false)
	if success:
		_track(crystal,0.58,0.05,[
			_frame(0,0,95,0.34,0.34,-12,0),_frame(0.22,0,30,0.82,0.82,-5),
			_frame(0.61,0,-15,1.13,1.13,3),_frame(0.8,0,6,0.96,0.96,-1),_frame(1)])
	else:
		_track(crystal,0.64,0.05,[
			_frame(0,0,-108,1.08,1.08,-13,0),_frame(0.17,0,-82,1.06,1.06,-10),
			_frame(0.57,0,14,1.03,0.92,5),_frame(0.75,0,-11,0.99,1.04,-3),
			_frame(0.89,0,4,1,1,1),_frame(1)])
	_track_named("ResultTitle",0.26,0.45 if success else 0.53,[
		_frame(0,0,-12,1.42,1.42,0,0),_frame(0.55,0,2,0.93,0.93),
		_frame(0.78,0,-1,1.035,1.035),_frame(1)])
	var reveal := 0.65 if success else 0.73
	_rise("ResultStage",0.22,reveal-0.07)
	for node_name in ["ResultDivider","ResultRewardsHeading","ResultRewardsFrame"]:
		_rise(node_name,0.2,reveal)
	var rewards: Control = hud.overlay_body.find_child("ResultRewards",true,false)
	var index := 0
	if rewards != null:
		for column in rewards.get_children():
			if not column is VBoxContainer: continue
			_track(column,0.29,reveal+0.07+index*0.085,[
				_frame(0,0,25,0.7,0.7,0,0),_frame(0.65,0,-3,1.08,1.08),_frame(1)])
			index += 1
	for node_name in ["ResultRecordsHeading","ResultRecordsFrame"]:
		_rise(node_name,0.23,reveal+0.155)
	for node_name in ["ResultUnlockHeading","ResultUnlocksFrame"]:
		_rise(node_name,0.23,reveal+0.23)
	for node_name in ["ResultSettlementStatus","ResultSettlementRetry","ResultActions"]:
		_rise(node_name,0.23,reveal+0.26)
	# Three conditional reward columns can finish after the two-column preview.
	duration = maxf(duration,reveal+0.07+maxi(0,index-1)*0.085+0.29)
	_apply(elapsed())

func elapsed() -> float:
	return 0.0 if started_usec == 0 else (Time.get_ticks_usec()-started_usec)/1000000.0

func _process(_delta: float) -> void:
	if not active: return
	if not is_instance_valid(hud) or not hud.is_visible_in_tree() or not hud.overlay.visible:
		cancel()
		return
	_apply(elapsed())

func _apply(time: float) -> void:
	if time >= duration:
		cancel(false)
		return
	shade.modulate.a = clampf(time/0.18,0,1)
	_update_frame(time)
	for track in _tracks:
		var node: Control = track.node
		if not is_instance_valid(node): continue
		# Container sorting can update positions during a resize. Adopt that new
		# layout position instead of accumulating an animated offset into it.
		if not node.position.is_equal_approx(track.last_position): track.position = node.position
		var progress := clampf((time-track.delay)/track.duration,0,1)
		if track.ease: progress = _rise_ease(progress)
		var value := _sample(track.frames,progress)
		node.pivot_offset = node.size*Vector2(0.5,0.6) if track.crystal else node.size*0.5
		node.scale = track.scale*value.scale
		node.rotation = track.rotation+deg_to_rad(value.rotation)
		node.position = track.position+value.position
		track.last_position = node.position
		node.modulate = track.modulate*Color(1,1,1,value.alpha)
		for original in track.buttons:
			if is_instance_valid(original.node): original.node.disabled = original.disabled or value.alpha <= 0.01

func _update_frame(time: float) -> void:
	if not is_instance_valid(_frame_host): return
	_frame_host.position = hud.overlay.position
	_frame_host.size = hud.overlay.size
	var value := _sample([_frame(0,-65,0,1,1,0,0),_frame(0.65,5),_frame(0.82,-2),_frame(1)],clampf((time-0.19)/0.38,0,1))
	var half: float = hud.overlay.size.x*0.5
	for index in 2:
		_halves[index].position = Vector2((half if index == 1 else 0)+value.position.x*(-1 if index == 1 else 1),0)
		_halves[index].size = Vector2(half,hud.overlay.size.y)
		_halves[index].modulate.a = value.alpha
		_drawings[index].position = Vector2(-half if index == 1 else 0,0)
		_drawings[index].size = hud.overlay.size
		_drawings[index].queue_redraw()

func _track_named(node_name: String, length: float, delay: float, frames: Array, ease := false) -> void:
	_track(hud.overlay_body.find_child(node_name,true,false),length,delay,frames,ease)

func _rise(node_name: String, length: float, delay: float) -> void:
	_track_named(node_name,length,delay,[_frame(0,0,12,1,1,0,0),_frame(1)],true)

func _track(node: Control, length: float, delay: float, frames: Array, ease := false) -> void:
	if node == null: return
	var buttons: Array = []
	if node is Button: buttons.append({"node":node,"disabled":node.disabled})
	for button in node.find_children("*","Button",true,false):
		buttons.append({"node":button,"disabled":button.disabled})
	_tracks.append({"node":node,"position":node.position,"last_position":node.position,
		"scale":node.scale,"rotation":node.rotation,"pivot":node.pivot_offset,"modulate":node.modulate,
		"duration":length,"delay":delay,"frames":frames,"ease":ease,"buttons":buttons,"crystal":node.name=="ResultCrystal"})

static func _frame(offset: float, x := 0.0, y := 0.0, sx := 1.0, sy := 1.0, rotation := 0.0, alpha := 1.0) -> Dictionary:
	return {"offset":offset,"position":Vector2(x,y),"scale":Vector2(sx,sy),"rotation":rotation,"alpha":alpha}

static func _sample(frames: Array, progress: float) -> Dictionary:
	for index in range(1,frames.size()):
		var right: Dictionary = frames[index]
		if progress > float(right.offset): continue
		var left: Dictionary = frames[index-1]
		var weight := (progress-float(left.offset))/(float(right.offset)-float(left.offset))
		return {"position":left.position.lerp(right.position,weight),"scale":left.scale.lerp(right.scale,weight),
			"rotation":lerpf(left.rotation,right.rotation,weight),"alpha":lerpf(left.alpha,right.alpha,weight)}
	return frames.back()

static func _rise_ease(progress: float) -> float:
	# Invert the approved CSS cubic-bezier(.16,1,.3,1) x coordinate.
	if progress <= 0 or progress >= 1: return progress
	var low := 0.0
	var high := 1.0
	for iteration in 16:
		var t := (low+high)*0.5
		var x := 3*(1-t)*(1-t)*t*0.16+3*(1-t)*t*t*0.3+t*t*t
		if x < progress: low = t
		else: high = t
	var t := (low+high)*0.5
	return 1-pow(1-t,3)

func _reset_tracks() -> void:
	for track in _tracks:
		var node: Control = track.node
		if not is_instance_valid(node): continue
		if node.position.is_equal_approx(track.last_position): node.position = track.position
		node.scale = track.scale
		node.rotation = track.rotation
		node.pivot_offset = track.pivot
		node.modulate = track.modulate
		for original in track.buttons:
			if is_instance_valid(original.node): original.node.disabled = original.disabled
	_tracks.clear()

func _restore_pending_buttons() -> void:
	for original in _pending_buttons:
		if is_instance_valid(original.node): original.node.disabled = original.disabled
	_pending_buttons.clear()

func cancel(clear_identity := true) -> void:
	active = false
	set_process(false)
	_reset_tracks()
	_restore_pending_buttons()
	if is_instance_valid(hud) and is_instance_valid(hud.overlay):
		if _native_frame != null: hud.overlay.add_theme_stylebox_override("panel",_native_frame)
		if is_instance_valid(hud.overlay_body): hud.overlay_body.modulate.a = 1
	if is_instance_valid(shade): shade.modulate.a = 1
	if is_instance_valid(_frame_host):
		_frame_host.hide()
		_frame_host.queue_free()
	_frame_host = null
	_halves.clear()
	_drawings.clear()
	_native_frame = null
	if clear_identity: identity = ""

func _exit_tree() -> void:
	cancel()
