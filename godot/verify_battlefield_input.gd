extends SceneTree
const BoardInput = preload("res://session/battlefield_input.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")

class Rewards extends RefCounted:
	var replacement := false
	func targeting() -> bool: return true
	func replacing() -> bool: return replacement
class Hud extends Control:
	var rewards = Rewards.new()
class App extends Node:
	var save_failed := false
	var hud
	var selected := Vector2i(-1,-1)
	func board_tap(tile: Vector2i) -> void: selected = tile
class Board extends Node3D:
	var _native_combat = Runtime.new()
	var _native_combat_base_frame := {"sceneEpoch":1}
	var camera_refreshes := 0
	var _standalone_session
	var camera := Camera3D.new()
	var world := Node3D.new()
	var camera_mode := "angled"
	var columns := 10
	var rows := 10
	var last_frame := {}
	func _apply_frame(_frame: Dictionary) -> void: camera_refreshes += 1

func _initialize() -> void: call_deferred("run")

func mouse_button(input, point: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point; event.pressed = pressed; event.button_index = button
	input.handle(event)

func touch(input, point: Vector2, pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point; event.pressed = pressed; event.index = index
	input.handle(event)

func run() -> void:
	root.size = Vector2i(440,760)
	var board := Board.new()
	root.add_child(board)
	board.add_child(board.world); board.add_child(board.camera)
	board.camera.position = Vector3(0,10,8)
	board.camera.look_at(Vector3.ZERO)
	board.camera.current = true
	var app := App.new()
	board.add_child(app); board._standalone_session = app
	var hud := Hud.new()
	board.add_child(hud); app.hud = hud
	board._native_combat.active = true
	board._native_combat.session = {"clock":"godot","phase":"wave","paused":true}
	var input = BoardInput.new(board)
	await process_frame
	assert(not input.blocked(), "Paused wave permits board interaction")
	var point: Vector2 = board.camera.unproject_position(Vector3(0.5,0,0.5))
	mouse_button(input,point,true); mouse_button(input,point,false)
	assert(app.selected == Vector2i(5,5), "Paused mouse click selects the projected tile")
	app.selected = Vector2i(-1,-1)
	touch(input,point,true); touch(input,point,false)
	assert(app.selected == Vector2i(5,5), "Paused touch selects the projected tile")
	app.selected = Vector2i(-1,-1)
	mouse_button(input,point,true)
	var motion := InputEventMouseMotion.new()
	motion.position = point+Vector2(30,20); motion.relative = Vector2(30,20)
	input.handle(motion); mouse_button(input,motion.position,false)
	assert(input.pan != Vector2.ZERO and app.selected == Vector2i(-1,-1), "Paused mouse drag pans without selecting")
	assert(board.camera_refreshes == 1, "Paused drag immediately refreshes camera presentation")
	input.reset()
	touch(input,point,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0; drag.position = point+Vector2(30,20); drag.relative = Vector2(30,20)
	input.handle(drag); touch(input,drag.position,false)
	assert(input.pan != Vector2.ZERO and app.selected == Vector2i(-1,-1), "Paused touch drag pans without selecting")
	mouse_button(input,point,true,MOUSE_BUTTON_WHEEL_UP)
	assert(input.zoom > 1.0, "Paused wheel zoom remains available")
	assert(board.camera_refreshes == 3, "Touch drag and wheel refresh without simulation frames")
	input.reset()
	touch(input,point,true,0); touch(input,point+Vector2(40,0),true,1)
	drag.index = 1; drag.position = point+Vector2(80,0)
	input.handle(drag)
	touch(input,point,false,0); touch(input,drag.position,false,1)
	assert(is_equal_approx(input.zoom,2.0) and app.selected == Vector2i(-1,-1), "Paused pinch zoom does not select")
	assert(board.camera_refreshes == 4, "Pinch refreshes camera without refreshing unchanged release events")
	var elapsed: float = board._native_combat.elapsed
	for i in range(60): assert(not board._native_combat.advance_session(1.0/60.0))
	assert(board._native_combat.elapsed == elapsed and board._native_combat.session.paused, "Interaction never resumes combat")
	for flag in ["loading","backgrounded"]:
		board._native_combat.session[flag] = true
		assert(input.blocked(), flag+" blocks input")
		board._native_combat.session[flag] = false
	for phase in ["restored","coreDestruction","failure","success","ended"]:
		board._native_combat.session.phase = phase
		assert(input.blocked(), phase+" blocks input")
	board._native_combat.session.phase = "reward"
	assert(not input.blocked(), "Paused reward targeting remains available")
	hud.rewards.replacement = true
	assert(input.blocked(), "Reward replacement blocks input")
	hud.rewards.replacement = false
	app.save_failed = true
	assert(input.blocked(), "Failed save blocks input")
	app.save_failed = false
	board._native_combat.session.phase = "wave"
	mouse_button(input,point,true)
	board._native_combat_base_frame.inputBlocked = true
	input.handle(motion)
	assert(input.contacts.is_empty(), "Blocked input cancels an existing gesture")
	board._native_combat_base_frame.inputBlocked = false
	mouse_button(input,point,false)
	assert(app.selected == Vector2i(-1,-1), "Unblocking does not turn the cancelled gesture into a tap")
	board.free()
	print("PASS battlefield input: paused mouse/touch selection, drag, wheel/pinch, frozen combat and blocking guards")
	quit()
