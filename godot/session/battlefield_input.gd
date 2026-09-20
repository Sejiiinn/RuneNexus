extends RefCounted
## Screen input and board projection stay beside the native camera.
var scene: Node3D
var contacts: Dictionary = {}
var start := Vector2.ZERO
var dragged := false
var zoom := 1.0
var pan := Vector2.ZERO

func _init(owner_scene: Node3D) -> void:
	scene = owner_scene

func reset() -> void:
	contacts.clear()
	pan = Vector2.ZERO
	zoom = 1.0
	dragged = false

func blocked() -> bool:
	var state: Dictionary = scene._native_combat.session
	return bool(scene._native_combat_base_frame.get("inputBlocked", false)) or bool(state.get("paused", false)) or bool(state.get("loading", false)) or state.get("phase", "") in ["restored", "coreDestruction", "failure", "success", "ended"]

func handle(event: InputEvent) -> void:
	# Android touch can also synthesize a mouse event; consume the native touch once.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if not scene._native_combat.native_session() or blocked():
		contacts.clear()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			contacts[event.index] = event.position
			start = event.position
			dragged = contacts.size() > 1
		else:
			if contacts.has(event.index) and not dragged: tap(event.position)
			contacts.erase(event.index)
	elif event is InputEventScreenDrag and contacts.has(event.index):
		if contacts.size() == 2:
			var other: Vector2 = contacts[contacts.keys()[0] if contacts.keys()[1] == event.index else contacts.keys()[1]]
			var old_distance: float = contacts[event.index].distance_to(other)
			if old_distance > 1: set_zoom(zoom * event.position.distance_to(other) / old_distance)
			dragged = true
		else:
			if event.position.distance_to(start) > 8: dragged = true
			if dragged: pan += event.relative / scene.get_viewport().get_visible_rect().size
		contacts[event.index] = event.position
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: set_zoom(zoom * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: set_zoom(zoom / 1.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				contacts[-1] = event.position
				start = event.position
				dragged = false
			elif contacts.has(-1):
				if not dragged: tap(event.position)
				contacts.erase(-1)
	elif event is InputEventMouseMotion and contacts.has(-1):
		if event.position.distance_to(start) > 8: dragged = true
		if dragged: pan += event.relative / scene.get_viewport().get_visible_rect().size
	pan = pan.clamp(Vector2(-0.75, -0.75), Vector2(0.75, 0.75))

func set_zoom(value: float) -> void:
	zoom = clampf(value, 1.0, 2.5)
	scene._native_combat.submit_input({"kind":"cameraChanged", "camera":scene.camera_mode, "zoom":zoom})

func board_position(point: Vector2) -> Vector2i:
	var ray: Vector3 = scene.camera.project_ray_origin(point)
	var direction: Vector3 = scene.camera.project_ray_normal(point)
	var hit = Plane(Vector3.UP, scene.world.global_position.y).intersects_ray(ray, direction)
	if hit == null: return Vector2i(-1, -1)
	var local: Vector3 = scene.world.to_local(hit)
	var tile := Vector2i(floori(local.x + float(scene.columns) / 2), floori(local.z + float(scene.rows) / 2))
	if tile.x < 0 or tile.y < 0 or tile.x >= scene.columns or tile.y >= scene.rows: return Vector2i(-1, -1)
	return tile

func tap(point: Vector2) -> void:
	var raw_reward = scene._native_combat_base_frame.get("rewardViewport")
	var reward: Array = raw_reward if raw_reward is Array else []
	if reward.size() == 4:
		var logical: Array = scene.last_frame.get("viewport", [])
		if logical.size() == 2:
			var p := point * Vector2(logical[0], logical[1]) / scene.get_viewport().get_visible_rect().size
			if not Rect2(reward[0],reward[1],reward[2],reward[3]).has_point(p): return
	var tile := board_position(point)
	scene._native_combat.submit_input({"kind":"boardTap", "column":tile.x, "row":tile.y})
	if is_instance_valid(scene._standalone_session): scene._standalone_session.board_tap(tile)
