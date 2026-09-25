extends RefCounted
## Flutter's 720-unit core tree, with persistent viewport and uncommitted ranks.
const AppTheme = preload("res://ui/app_theme.gd")
const ROOT := "core_passive_tree/"
const CENTER := Vector2(360, 360)
const POLAR := {"attackHaste":[110,300],"attackOutput":[110,0],"efficiencySaving":[110,60],"efficiencyDiversity":[110,120],"controlSelfRepair":[110,180],"controlThreatSense":[110,240],"attackPrecompute":[180,310],"attackFocus":[180,350],"attackGuardianBeam":[245,300],"attackRiftMark":[245,0],"attackOverclock":[300,330],"efficiencySupplyRecovery":[180,70],"efficiencyGemSpectrum":[180,110],"efficiencyFirstDeploy":[245,60],"efficiencyFirstLink":[245,120],"efficiencyCombinedFront":[300,90],"controlRetarget":[180,190],"controlRearLock":[180,230],"controlBufferShell":[245,180],"controlEmergencyCharge":[245,240],"controlFinalLine":[300,210]}
const GLYPHS := {"attackOutput":0xe0ee,"attackPrecompute":0xe660,"attackFocus":0xe14b,"attackGuardianBeam":0xe0c1,"attackRiftMark":0xe272,"attackOverclock":0xf079c,"controlThreatSense":0xe0ea,"controlSelfRepair":0xf379,"controlRetarget":0xe304,"controlRearLock":0xf0c8,"controlEmergencyCharge":0xe0d1,"controlBufferShell":0xe582,"controlFinalLine":0xe569,"efficiencyDiversity":0xf0616,"efficiencyFirstDeploy":0xe683,"efficiencyFirstLink":0xe1c8,"efficiencyGemSpectrum":0xe0b7,"efficiencySupplyRecovery":0xf336,"efficiencyCombinedFront":0xee36}
var lobby
var view: Control
var summary: Label
var used_summary: Label
var planned_summary: Label
var remaining_summary: Label
var apply_button: Button
var cancel_button: Button
var reset_button: Button
var zoom := 1.0
var offset := Vector2.ZERO
var viewport_size := Vector2.ZERO
var selected := ""
var material_font: Font
var textures := {}
var touches := {}
var pointer_origin := Vector2.ZERO
var dragging := false
var moved := false
var inline_panel: PanelContainer
var inline_body: VBoxContainer
var selecting_skill := false
var allocating := false
var allocation_elapsed := 0.0
var allocation_duration := 0.0
var allocation_base := {}
var allocation_target := {}
var allocation_steps: Array[Dictionary] = []
var allocation_tween: Tween

class TreeCanvas extends Control:
	var owner_helper
	func _draw() -> void: owner_helper.draw_tree(self)
	func _gui_input(event: InputEvent) -> void: owner_helper.input_tree(event)

func setup(owner) -> void:
	lobby = owner
	if ResourceLoader.exists("res://assets/ui/MaterialIcons-Regular.otf"):
		material_font = load("res://assets/ui/MaterialIcons-Regular.otf")

func data() -> Dictionary: return lobby.app.run_domain.growth.data.core
func actual() -> Dictionary: return lobby._p().get("corePassiveNodeRanks", {})
func total() -> int: return int(lobby._p().get("totalCorePoints", 0))
func valid(ranks: Dictionary) -> bool: return lobby.app.run_domain.growth._valid_core(ranks, total())
func spent(ranks: Dictionary) -> int:
	var count := 0
	for id in ranks:
		for rank in range(int(ranks[id])): count += int(data().nodes[id].rankCosts[rank])
	return count
func changed() -> bool: return lobby.core_draft != actual()
func point(id: String) -> Vector2:
	var polar: Array = POLAR[id]
	return CENTER + Vector2.from_angle(deg_to_rad(float(polar[1]))) * float(polar[0])
func tex(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = AppTheme.texture(path)
	return textures[path]

func render() -> void:
	view = TreeCanvas.new()
	view.owner_helper = self
	view.name = "CoreTreeViewport"
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.clip_contents = true
	lobby.body.add_child(view)
	view.resized.connect(_resize)
	var panel := PanelContainer.new()
	panel.name = "CorePointOverlay"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = 12
	var style := StyleBoxFlat.new()
	style.bg_color = Color("07131eeb")
	style.border_color = Color("7b927f99")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	view.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",7)
	outer.add_child(row)
	var icon := Label.new()
	icon.text = String.chr(0xf0616)
	if material_font: icon.add_theme_font_override("font",material_font)
	icon.add_theme_font_size_override("font_size",19)
	icon.add_theme_color_override("font_color",Color("8ee6ff"))
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)
	var values := HFlowContainer.new()
	values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	values.add_theme_constant_override("h_separation",8)
	values.add_theme_constant_override("v_separation",2)
	row.add_child(values)
	summary = AppTheme.label("",13)
	used_summary = AppTheme.label("",11)
	planned_summary = AppTheme.label("",11)
	remaining_summary = AppTheme.label("",11)
	used_summary.add_theme_color_override("font_color",Color("ffc66a"))
	planned_summary.add_theme_color_override("font_color",Color("8ee6ff"))
	remaining_summary.add_theme_color_override("font_color",Color("72e0a2"))
	for label in [summary,used_summary,planned_summary,remaining_summary]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		values.add_child(label)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation",0)
	row.add_child(actions)
	cancel_button = action(actions, "변경 취소", cancel)
	reset_button = action(actions, "전체 초기화", confirm_reset)
	for button in [cancel_button,reset_button]:
		button.custom_minimum_size.y = 36
		button.add_theme_font_size_override("font_size",11)
		for state in ["normal","hover","pressed","disabled","focus"]:
			var transparent := StyleBoxEmpty.new()
			transparent.content_margin_left = 7
			transparent.content_margin_right = 7
			button.add_theme_stylebox_override(state,transparent)
	apply_button = action(outer, "포인트 적용", apply)
	update_state()
	if selecting_skill: skills()
	elif not selected.is_empty(): node_details(selected)
	_resize.call_deferred()

func action(parent: Node, title: String, callback: Callable) -> Button:
	var b := AppTheme.button(title, callback)
	b.custom_minimum_size.y = 32
	b.add_theme_font_size_override("font_size", 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b

func update_state() -> void:
	if not is_instance_valid(view): return
	summary.text = "코어 포인트 %d" % total()
	used_summary.text = "사용 %d" % spent(actual())
	planned_summary.text = "예정 %d" % spent(lobby.core_draft)
	remaining_summary.text = "확정 후 %d" % (total()-spent(lobby.core_draft))
	apply_button.visible = changed()
	apply_button.disabled = allocating or not changed() or not valid(lobby.core_draft)
	cancel_button.disabled = allocating or not changed()
	reset_button.disabled = allocating or spent(actual()) <= 0
	view.queue_redraw()

func _resize() -> void:
	if not is_instance_valid(view) or view.size.x <= 0 or view.size.y <= 0: return
	if viewport_size != view.size:
		viewport_size = view.size
		zoom = minimum_zoom()
		offset = (viewport_size - Vector2.ONE * 720 * zoom) / 2
	_clamp()
	_layout_inline()
	view.queue_redraw()
func minimum_zoom() -> float: return minf(viewport_size.x, viewport_size.y) / 720.0 * 0.92
func _clamp() -> void:
	var extent := 720.0 * zoom
	for axis in range(2):
		offset[axis] = (viewport_size[axis] - extent) / 2 if extent <= viewport_size[axis] else clampf(offset[axis], viewport_size[axis]-extent, 0)
func scale_at(factor: float, focus: Vector2) -> void:
	var next := clampf(zoom * factor, minimum_zoom(), minimum_zoom()*2.2)
	offset = focus - (focus-offset) * next / zoom
	zoom = next
	_clamp()
	view.queue_redraw()

func input_tree(event: InputEvent) -> void:
	if allocating: return
	if event is InputEventMagnifyGesture: scale_at(event.factor, event.position)
	elif event is InputEventPanGesture:
		offset -= event.delta * 16
		_clamp()
		view.queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			pointer_origin = event.position
			moved = touches.size() > 1
		else:
			if touches.size() == 1 and not moved: select_at(event.position)
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if not touches.has(event.index): return
		var old: Vector2 = touches[event.index]
		if touches.size() >= 2:
			for key in touches:
				if key == event.index: continue
				var other: Vector2 = touches[key]
				var distance := old.distance_to(other)
				if distance > 1: scale_at(event.position.distance_to(other)/distance, (other+event.position)/2)
				break
		else:
			offset += event.position-old
			_clamp()
		moved = moved or event.position.distance_to(pointer_origin) > 12
		touches[event.index] = event.position
		view.queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			scale_at(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				moved = false
				pointer_origin = event.position
			else:
				if dragging and not moved: select_at(event.position)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		offset += event.relative
		moved = moved or event.position.distance_to(pointer_origin) > 12
		_clamp()
		view.queue_redraw()
	view.accept_event()

func select_at(location: Vector2) -> void:
	if allocating: return
	var pos := (location-offset)/zoom
	if pos.distance_to(CENTER) < 64: skills(); return
	# Match Flutter's per-node SizedBox hit region; no oversized overlapping circles.
	for id in POLAR:
		var maximum := int(data().nodes[id].maxRank)
		var diameter := 48.0 if maximum == 5 else (68.0 if maximum == 3 else 96.0)
		if Rect2(point(id)-Vector2.ONE*diameter/2,Vector2.ONE*diameter).has_point(pos):
			node_details(id)
			return
	selected = ""
	selecting_skill = false
	_close_inline()
	view.queue_redraw()

func _close_inline() -> void:
	if is_instance_valid(inline_panel):
		inline_panel.get_parent().remove_child(inline_panel)
		inline_panel.queue_free()
	inline_panel = null
	inline_body = null

func _open_inline(title: String) -> VBoxContainer:
	_close_inline()
	inline_panel = PanelContainer.new()
	inline_panel.name = "CoreInlineDetails"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("07131ef5")
	style.border_color = Color("5d718299")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(12)
	inline_panel.add_theme_stylebox_override("panel",style)
	view.add_child(inline_panel)
	inline_body = VBoxContainer.new()
	inline_body.add_theme_constant_override("separation",8)
	inline_panel.add_child(inline_body)
	var header := HBoxContainer.new()
	inline_body.add_child(header)
	var title_label := AppTheme.label(title,14)
	title_label.add_theme_font_override("font",AppTheme.font(900))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close := preload("res://ui/close_button.gd").new()
	close.name = "CloseCoreDetails"
	close.pressed.connect(func(): selected = ""; selecting_skill = false; _close_inline(); view.queue_redraw())
	header.add_child(close)
	inline_body.minimum_size_changed.connect(_layout_inline.call_deferred)
	_layout_inline.call_deferred()
	return inline_body

func _layout_inline() -> void:
	if not is_instance_valid(inline_panel) or not is_instance_valid(view): return
	var width := minf(430, maxf(1,view.size.x-24))
	inline_panel.size.x = width
	var height := inline_panel.get_combined_minimum_size().y
	inline_panel.size.y = height
	var top := not selecting_skill and not selected.is_empty() and point(selected).y > CENTER.y
	inline_panel.position = Vector2((view.size.x-width)/2, (view.size.y-height)/2 if selecting_skill else (12.0 if top else maxf(12,view.size.y-height-12)))

func candidate(id: String, delta: int) -> Dictionary:
	var ranks: Dictionary = lobby.core_draft.duplicate()
	var rank := int(ranks.get(id,0))+delta
	if rank == 0: ranks.erase(id)
	else: ranks[id] = rank
	return ranks
func change_rank(id: String, delta: int) -> void:
	if allocating: return
	var ranks := candidate(id,delta)
	if not valid(ranks): return
	lobby.core_draft = ranks
	update_state()
	node_details(id)
func cancel() -> void:
	if allocating: return
	lobby.core_draft = actual().duplicate()
	update_state()
func apply() -> void:
	if allocating or not changed() or not valid(lobby.core_draft): return
	allocation_base = actual().duplicate()
	allocation_target = lobby.core_draft.duplicate()
	allocation_steps = build_allocation_steps(allocation_base,allocation_target)
	allocation_elapsed = 0
	allocation_duration = 0 if allocation_steps.is_empty() else float(allocation_steps.back().wave)*200+700
	allocating = true
	lobby._change({"kind":"setCorePassiveRanks","ranks":allocation_target.duplicate()})
	if actual() != allocation_target:
		_finish_allocation()
		return
	update_state()
	if not selected.is_empty(): node_details(selected)
	if allocation_duration <= 0:
		_finish_allocation()
		return
	allocation_tween = lobby.create_tween()
	allocation_tween.tween_method(_advance_allocation,0.0,allocation_duration,allocation_duration/1000.0)
	allocation_tween.tween_callback(_finish_allocation)

func build_allocation_steps(base: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var traversal := {}; var activation := {}; var sources := {}; var queue := []
	for id in POLAR:
		var before := int(base.get(id,0)); var after := int(target.get(id,0))
		if before > 0:
			traversal[id] = -1 if before >= 3 else 0
			queue.append(id)
			if after > before: activation[id] = 0
		elif after > 0 and id in data().startingNodes:
			traversal[id] = 0; activation[id] = 0; sources[id] = ""; queue.append(id)
	var cursor := 0
	while cursor < queue.size():
		var source: String = queue[cursor]; cursor += 1
		if int(target.get(source,0)) < 3: continue
		var wave := int(traversal[source])+1
		for id in data().nodes[source].neighbors:
			if int(target.get(id,0)) <= 0 or int(base.get(id,0)) > 0: continue
			if traversal.has(id) and int(traversal[id]) <= wave: continue
			traversal[id] = wave; activation[id] = wave; sources[id] = source; queue.append(id)
	var result: Array[Dictionary] = []
	var waves: Array = activation.values(); waves.sort()
	var compact := {}; var next := 0
	for wave in waves:
		if not compact.has(wave): compact[wave] = next; next += 1
	for id in POLAR:
		if activation.has(id) and int(target.get(id,0)) > int(base.get(id,0)):
			result.append({"id":id,"source":sources.get(id,""),"wave":compact[activation[id]],"lightsConnection":int(base.get(id,0))==0})
	result.sort_custom(func(a,b): return int(a.wave)<int(b.wave))
	return result

func _advance_allocation(ms: float) -> void:
	allocation_elapsed = ms
	if is_instance_valid(view): view.queue_redraw()

func _finish_allocation() -> void:
	allocating = false
	allocation_steps.clear()
	update_state()
	if not selected.is_empty() and is_instance_valid(view): node_details(selected)

func rendered_rank(id: String) -> int:
	if not allocating: return int(actual().get(id,0))
	for step in allocation_steps:
		if step.id == id and allocation_elapsed >= int(step.wave)*200+280:
			return int(allocation_target.get(id,0))
	return int(allocation_base.get(id,0))

func activation_glow(id: String) -> float:
	if not allocating: return -1.0
	for step in allocation_steps:
		if step.id != id: continue
		var t := (allocation_elapsed-int(step.wave)*200-280)/420.0
		if t < 0 or t > 1: return -1.0
		return 1.0-pow(1.0-t/0.45,3) if t < 0.45 else 1.0-pow((t-0.45)/0.55,3)
	return -1.0

func confirm_reset() -> void:
	if allocating: return
	var box: VBoxContainer = lobby.open_modal("코어 패시브 전체 초기화")
	box.add_child(AppTheme.label("투자한 %dP를 모두 돌려받습니다. 변경 중인 계획도 취소됩니다." % spent(actual()),14))
	action(box,"취소",lobby.close_modal)
	action(box,"전체 초기화",func():
		lobby.close_modal()
		lobby._change({"kind":"resetCorePassiveTree"})
		if actual().is_empty(): lobby.core_draft = {}
		update_state())

func node_details(id: String) -> void:
	selecting_skill = false
	selected = id
	view.queue_redraw()
	var d: Dictionary = data().nodes[id]
	var rank := int(lobby.core_draft.get(id,0))
	var box := _open_inline(lobby._title(id))
	inline_panel.custom_minimum_size.y = 182
	var current := int(actual().get(id,0))
	box.add_child(AppTheme.label(("%d / %d" % [rank,int(d.maxRank)]) if current == rank else ("계획 %d → %d / %d" % [current,rank,int(d.maxRank)]),11))
	var accessible: bool = id in data().startingNodes or rank > 0
	for neighbor in d.neighbors:
		if int(lobby.core_draft.get(neighbor,0)) >= 3: accessible = true
	if not accessible and current == 0:
		var hint := AppTheme.label("연결된 노드에 3등급 이상 투자하면 다음 노드가 열립니다.",10)
		hint.add_theme_color_override("font_color",Color("ffc66a"))
		box.add_child(hint)
	var effect := AppTheme.label(lobby._core_effect_text(d,maxi(1,rank)).replace("다음 등급 효과","효과"),13)
	if rank == 0: effect.modulate.a = 0.64
	box.add_child(effect)
	box.add_child(AppTheme.label("필요 포인트  " + (str(int(d.rankCosts[rank])) if rank < int(d.maxRank) else "최대 등급"),11))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",5)
	box.add_child(row)
	var minus := action(row,"−",change_rank.bind(id,-1))
	minus.custom_minimum_size = Vector2(38,38)
	minus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	minus.disabled = allocating or rank <= 0 or not valid(candidate(id,-1))
	var rank_label := AppTheme.label("%d/%d" % [rank,int(d.maxRank)],11)
	rank_label.custom_minimum_size = Vector2(54,38)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(rank_label)
	var plus := action(row,"+",change_rank.bind(id,1))
	plus.custom_minimum_size = Vector2(38,38)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plus.disabled = allocating or rank >= int(d.maxRank) or not valid(candidate(id,1))
	var cost_delta := spent(lobby.core_draft)-spent(actual())
	var caption := "적용 중" if allocating else "포인트 적용"
	if cost_delta != 0: caption += "\n%s %d" % ["필요 포인트" if cost_delta>0 else "반환 포인트",absi(cost_delta)]
	action(row,caption,apply).disabled = allocating or not changed() or not valid(lobby.core_draft)

func skills() -> void:
	if allocating: return
	selecting_skill = true
	selected = ""
	var box := _open_inline("코어 스킬 선택")
	var current := str(lobby._p().get("coreCombatSkill",""))
	for id in ["guardianBeam","riftMark"]:
		var unlocked: bool = id == "guardianBeam" or int(lobby._p().get("unlockedStageCount",1)) >= 6
		var row := HBoxContainer.new()
		box.add_child(row)
		var image := TextureRect.new()
		image.texture = tex("core_abilities/%s.png" % ("guardian_beam" if id == "guardianBeam" else "rift_mark"))
		image.custom_minimum_size = Vector2(52,52)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(image)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(AppTheme.label(lobby._title(id) + (" · 장착 중" if current == id else ""),15))
		var description := "5초마다 자동 발동\n가장 앞선 적에게 광선을 발사하며 포탑 화력에 비례해 피해가 증가합니다." if id == "guardianBeam" else ("10초마다 자동 발동\n내구도가 높은 적 4명의 받는 모든 피해를 기본 25% 증폭합니다. 코어 스킬 위력에 비례하며 보스는 절반입니다." if unlocked else "챕터 2 해금\n스테이지 6에 도달하면 균열 낙인을 장착할 수 있습니다.")
		text.add_child(AppTheme.label(description,12))
		action(box,"해제" if current == id else ("장착" if unlocked else "잠김 · 챕터 2 해금"),func():
			lobby._change({"kind":"unequipCoreCombatSkill" if current == id else "equipCoreCombatSkill","id":id})
			skills()).disabled = not unlocked

func _image(canvas: Control, asset: String, rectangle: Rect2, color := Color.WHITE) -> void:
	var texture := tex(asset)
	if texture: canvas.draw_texture_rect(texture, rectangle, false, color)
func _glyph(canvas: Control, code: int, center: Vector2, height: int, color: Color) -> void:
	if not material_font: return
	var value := String.chr(code)
	var width := material_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,height).x
	canvas.draw_string(material_font,center+Vector2(-width/2,material_font.get_ascent(height)-height/2),value,HORIZONTAL_ALIGNMENT_LEFT,-1,height,color)
func _text(canvas: Control, value: String, center: Vector2, height: int, color := Color.WHITE) -> void:
	var font := canvas.get_theme_default_font()
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,height).x
	# Font size is the em size, not the line height (Noto Sans KR includes descent).
	# Center the actual line box so nameplates and rank badges share their frame axis.
	var baseline := font.get_ascent(height) - font.get_height(height) / 2.0
	canvas.draw_string(font,center+Vector2(-width/2,baseline),value,HORIZONTAL_ALIGNMENT_LEFT,-1,height,color)
func draw_tree(canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("04111b"))
	var background := tex(ROOT+"tree_circuit_background.png")
	if background:
		var scale_bg := maxf(canvas.size.x/background.get_width(),canvas.size.y/background.get_height())
		var size_bg := background.get_size()*scale_bg
		canvas.draw_texture_rect(background,Rect2((canvas.size-size_bg)/2,size_bg),false)
	canvas.draw_set_transform(offset,0,Vector2.ONE*zoom)
	var nodes: Dictionary = data().nodes
	var visited := {}
	for id in POLAR:
		if id in data().startingNodes: _connection(canvas,CENTER,point(id),int(lobby.core_draft.get(id,0))>0,rendered_rank(id)>0)
		for neighbor in nodes[id].neighbors:
			var edge := "|".join([id,neighbor] if id < neighbor else [neighbor,id])
			if visited.has(edge): continue
			visited[edge] = true
			_connection(canvas,point(id),point(neighbor),int(lobby.core_draft.get(id,0))>0 and int(lobby.core_draft.get(neighbor,0))>0,rendered_rank(id)>0 and rendered_rank(neighbor)>0)
	_draw_allocation_lines(canvas)
	_image(canvas,ROOT+"center_socket_v1.png",Rect2(CENTER-Vector2.ONE*64,Vector2.ONE*128))
	var skill := str(lobby._p().get("coreCombatSkill",""))
	var asset := "core_abilities/%s.png" % ("guardian_beam" if skill == "guardianBeam" else "rift_mark") if skill in ["guardianBeam","riftMark"] else ROOT+"nexus_core.png"
	_image(canvas,asset,Rect2(CENTER-Vector2.ONE*27,Vector2.ONE*54))
	var title: String = lobby._title(skill) if skill in ["guardianBeam","riftMark"] else "스킬 선택"
	var width := maxf(96,canvas.get_theme_default_font().get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+32)
	# Flutter ExactAssetImage(scale:2): source pixels and destination border
	# extents are distinct. Native 32px end caps must occupy 16 world units.
	_nameplate(canvas,Rect2(CENTER+Vector2(-width/2,34),Vector2(width,30)))
	_text(canvas,title,CENTER+Vector2(0,49),15,Color("f4e6c8"))
	for id in POLAR:
		var rank := int(lobby.core_draft.get(id,0))
		var original := int(allocation_base.get(id,0)) if allocating else int(actual().get(id,0))
		var maximum := int(nodes[id].maxRank)
		var frame := "small" if maximum == 5 else ("medium" if maximum == 3 else "large")
		var diameter := 48.0 if frame == "small" else (68.0 if frame == "medium" else 96.0)
		var aperture := 32.0 if frame == "small" else (46.0 if frame == "medium" else 64.0)
		var pos := point(id)
		var accessible: bool = rank > 0 or valid(candidate(id,1)) or id in data().startingNodes
		# Accessibility is a graph condition independent of the remaining point budget.
		if not accessible:
			var ranks: Dictionary = lobby.core_draft.duplicate()
			ranks[id] = 1
			accessible = lobby.app.run_domain.growth._valid_core(ranks,2147483647)
		var muted := not accessible and original == 0 and rank == original
		var color := Color("ffb84d") if id.begins_with("attack") else (Color("56d9e8") if id.begins_with("control") else Color("72e0a2"))
		if selected == id: _image(canvas,ROOT+"selection_ring_v1.png",Rect2(pos-Vector2.ONE*diameter*0.66,Vector2.ONE*diameter*1.32))
		_image(canvas,ROOT+"node_frame_%s_a_v1.png" % frame,Rect2(pos-Vector2.ONE*diameter/2,Vector2.ONE*diameter),Color(1,1,1,0.42 if muted else 1))
		var glow := activation_glow(id)
		var active_alpha := 0.6+glow*0.4 if glow >= 0 else (1.0 if rendered_rank(id)>0 else (0.5 if rank>original else 0.0))
		if active_alpha > 0: _image(canvas,ROOT+"node_frame_%s_a_active_v1.png" % frame,Rect2(pos-Vector2.ONE*diameter/2,Vector2.ONE*diameter),Color(1,1,1,active_alpha))
		var icon_color := Color("7b8991") if muted else color
		icon_color.a = 0.35 if muted else 1
		if id in ["attackHaste","efficiencySaving"]:
			_image(canvas,"core_passives/%s.png" % ("skill_acceleration" if id == "attackHaste" else "cost_saving_design"),Rect2(pos-Vector2.ONE*aperture*0.4,Vector2.ONE*aperture*0.8),icon_color)
		else: _glyph(canvas,int(GLYPHS[id]),pos,int(aperture*0.8),icon_color)
		if muted: _glyph(canvas,0xe3b1,pos,18,Color("c2ccd1"))
		var badge_text := "%d/%d" % [rank,maximum] if original == rank else "%d→%d/%d" % [original,rank,maximum]
		var badge_width := maxf(25,canvas.get_theme_default_font().get_string_size(badge_text,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x+8)
		var badge := StyleBoxFlat.new()
		badge.bg_color = Color("061019")
		badge.border_color = color
		badge.set_border_width_all(1)
		badge.set_corner_radius_all(9)
		var badge_rect := Rect2(pos+Vector2(diameter/2-badge_width+7,diameter/2-14),Vector2(badge_width,19))
		canvas.draw_style_box(badge,badge_rect)
		_text(canvas,badge_text,badge_rect.get_center(),8,Color("e8fbff"))

func _draw_allocation_lines(canvas: Control) -> void:
	if not allocating: return
	var texture := tex(ROOT+"connection_segment_v1.png")
	if not texture: return
	for step in allocation_steps:
		var elapsed := allocation_elapsed-int(step.wave)*200
		if not step.lightsConnection or elapsed <= 0 or elapsed >= 500: continue
		var t := clampf(elapsed/340.0,0,1)
		var reach := 4*t*t*t if t < 0.5 else 1-pow(-2*t+2,3)/2
		var opacity := 1-pow(1-t,3) if elapsed<=340 else 1-pow((elapsed-340)/160,3)
		var start: Vector2 = CENTER if str(step.source).is_empty() else point(step.source)
		var end := point(step.id)
		var sr := start.distance_to(CENTER); var er := end.distance_to(CENTER)
		var curved := absf(sr-er)<=24 and sr>=1
		var control := CENTER+((start+end)/2-CENTER).normalized()*maxf(sr,er)
		var previous := start
		for i in range(1,25):
			var progress := minf(float(i)/24,reach)
			var next := start.lerp(control,progress).lerp(control.lerp(end,progress),progress) if curved else start.lerp(end,progress)
			canvas.draw_set_transform(offset+previous*zoom,(next-previous).angle(),Vector2.ONE*zoom)
			canvas.draw_texture_rect_region(texture,Rect2(0,-4.5,previous.distance_to(next)+0.4,9),Rect2(55+1426*float(i-1)/24,485,1426*(progress-float(i-1)/24),54),Color(1,1,1,opacity))
			previous = next
			if progress>=reach: break
	canvas.draw_set_transform(offset,0,Vector2.ONE*zoom)

func _connection(canvas: Control, start: Vector2, end: Vector2, planned: bool, lit: bool) -> void:
	var sr := start.distance_to(CENTER)
	var er := end.distance_to(CENTER)
	var curved := absf(sr-er)<=24 and sr>=1
	var control := CENTER + ((start+end)/2-CENTER).normalized()*maxf(sr,er)
	var samples := 24 if curved else 1
	var points: Array[Vector2] = []
	for i in range(samples+1):
		var t := float(i)/samples
		points.append(start.lerp(control,t).lerp(control.lerp(end,t),t) if curved else start.lerp(end,t))
	for active in [false,true]:
		if active and not planned and not lit: continue
		var texture := tex(ROOT+("connection_segment_v1.png" if active else "connection_segment_inactive_v1.png"))
		if not texture: continue
		var source := Rect2(55,485,1426,54) if active else Rect2(28,239,2120,238)
		var h := 6.0 if active else 3.6
		for i in range(points.size()-1):
			var a := points[i]
			var b := points[i+1]
			canvas.draw_set_transform(offset+a*zoom,(b-a).angle(),Vector2.ONE*zoom)
			var crop := Rect2(source.position + Vector2(source.size.x*i/samples,0),Vector2(source.size.x/samples,source.size.y))
			canvas.draw_texture_rect_region(texture,Rect2(0,-h/2,a.distance_to(b)+0.4,h),crop,Color(1,1,1,0.42 if active and not lit else 1))
	canvas.draw_set_transform(offset,0,Vector2.ONE*zoom)
	var junction := tex(ROOT+"connection_junction_v1.png")
	var midpoint: Vector2 = points[points.size()/2] if curved else start.lerp(end,0.52)
	if junction: canvas.draw_texture_rect_region(junction,Rect2(midpoint-Vector2(4,6),Vector2(8,12)),Rect2(330,160,595,910),Color(1,1,1,1 if lit else 0.45))

func _nameplate(canvas: Control, destination: Rect2) -> void:
	var texture := tex(ROOT+"skill_nameplate_v1.png")
	if not texture: return
	var source_x := [0.0,32.0,364.0,396.0]
	var source_y := [0.0,8.0,47.0,55.0]
	var target_x := [0.0,16.0,destination.size.x-16.0,destination.size.x]
	var target_y := [0.0,4.0,destination.size.y-4.0,destination.size.y]
	for y in range(3):
		for x in range(3):
			var source := Rect2(source_x[x],source_y[y],source_x[x+1]-source_x[x],source_y[y+1]-source_y[y])
			var target := Rect2(destination.position+Vector2(target_x[x],target_y[y]),Vector2(target_x[x+1]-target_x[x],target_y[y+1]-target_y[y]))
			canvas.draw_texture_rect_region(texture,target,source)
