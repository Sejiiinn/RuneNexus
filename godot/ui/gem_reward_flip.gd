extends Node
## Temporary 2D card compositing; original controls, game clock and saves stay put.
signal finished
const DURATION := 0.36
const Perspective = preload("res://ui/gem_reward_flip.gdshader")
var hud
var active := false
var started_usec := 0
var swapped := false
var angle := 0.0
var _cards: Array = []
var _buttons: Array = []
var _swap: Callable
var _row: HBoxContainer

func setup(owner) -> void:
	hud = owner
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func begin(row: HBoxContainer, swap_faces: Callable) -> void:
	cancel()
	active = true
	started_usec = 0
	swapped = false
	angle = 0.0
	_swap = swap_faces
	_row = row
	_row.sort_children.connect(_sync_cards)
	for card in row.get_children():
		var group := CanvasGroup.new()
		group.name = "GemFlipFace"
		group.fit_margin = 0.0
		group.clear_margin = 1.0
		group.use_mipmaps = false
		var material := ShaderMaterial.new()
		material.shader = Perspective
		group.material = material
		add_child(group)
		var track := {"node":card,"modulate":card.modulate,"group":group,"material":material,"copy":null}
		_cards.append(track)
		_replace_face(track)
		card.modulate.a = 0.0
	for button in hud.overlay_body.find_children("*","Button",true,false):
		_buttons.append({"node":button,"disabled":button.disabled})
		button.disabled = true
	_sync_cards()
	set_process(true)

func _replace_face(track: Dictionary) -> void:
	if is_instance_valid(track.copy):
		track.group.remove_child(track.copy)
		track.copy.queue_free()
	# No readback, Viewport or 3D scene: CanvasGroup composites just this card.
	var face: Button = track.node.duplicate(0)
	face.name = "Face"
	face.theme = hud.theme
	face.modulate = track.modulate
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.focus_mode = Control.FOCUS_NONE
	track.group.add_child(face)
	face.position = Vector2.ZERO
	face.size = track.node.size
	face.scale = Vector2.ONE
	face.pivot_offset = Vector2.ZERO
	track.copy = face

func bind_body() -> void:
	if not active or started_usec != 0: return
	started_usec = Time.get_ticks_usec()
	_apply(0.0)

func elapsed() -> float:
	return 0.0 if started_usec == 0 else (Time.get_ticks_usec()-started_usec)/1000000.0

func _process(_delta: float) -> void:
	if not active: return
	if not is_instance_valid(hud) or not hud.is_visible_in_tree() or not hud.overlay.visible:
		cancel()
		finished.emit()
		return
	if started_usec != 0: _apply(elapsed())

func _apply(time: float) -> void:
	if not active: return
	var progress := clampf(time/DURATION,0,1)
	angle = PI*progress
	if progress >= 0.5 and not swapped:
		# Swap at the single edge-on crossing; the new face unfolds upright.
		swapped = true
		_swap.call()
		for track in _cards:
			if is_instance_valid(track.node): _replace_face(track)
	if progress >= 1.0:
		cancel()
		finished.emit()
		return
	_sync_cards()

func _sync_cards() -> void:
	if not active or not is_instance_valid(hud): return
	var viewport: Vector2 = hud.get_viewport_rect().size
	for track in _cards:
		if not is_instance_valid(track.node): continue
		var rect: Rect2 = track.node.get_global_rect()
		track.group.global_position = rect.position
		track.copy.size = track.node.size
		track.material.set_shader_parameter("angle",angle)
		track.material.set_shader_parameter("card_rect",Vector4(rect.position.x/viewport.x,rect.position.y/viewport.y,rect.size.x/viewport.x,rect.size.y/viewport.y))
		track.material.set_shader_parameter("card_size",rect.size)
		# The temporary sibling must obey the original scroll/safe-area clips.
		var clip := Rect2(Vector2.ZERO,viewport)
		var ancestor: Node = track.node.get_parent()
		while ancestor != null:
			if ancestor is Control and ancestor.clip_contents:
				clip = clip.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		track.material.set_shader_parameter("clip_rect",Vector4(clip.position.x/viewport.x,clip.position.y/viewport.y,clip.size.x/viewport.x,clip.size.y/viewport.y))

func cancel() -> void:
	active = false
	set_process(false)
	for track in _cards:
		if is_instance_valid(track.node): track.node.modulate = track.modulate
		if is_instance_valid(track.group):
			track.group.hide()
			track.group.queue_free()
	for original in _buttons:
		if is_instance_valid(original.node): original.node.disabled = original.disabled
	if is_instance_valid(_row) and _row.sort_children.is_connected(_sync_cards):
		_row.sort_children.disconnect(_sync_cards)
	_row = null
	_cards.clear()
	_buttons.clear()
	_swap = Callable()
	started_usec = 0

func _exit_tree() -> void:
	cancel()
