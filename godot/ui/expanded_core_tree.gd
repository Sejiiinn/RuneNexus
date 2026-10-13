extends RefCounted
## Approved v5 artwork and geometry. No inferred edges or radial relayout.
## Drawn in screen space: the background always covers the view, each rank up to 3
## grows a link toward unranked neighbours, and the point bar and sheets reuse the
## shipped frames (design/core_tree_concepts/ui-redesign-2026-10-13).
const AppTheme = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const CloseButton = preload("res://ui/close_button.gd")
const Progression = preload("res://content/stage_progression.gd")
const ROOT := "core_passive_tree/expanded/"
const DETAIL_ZOOM := 0.40
## Node bounds including frames; the overview fits these, not the 2800-unit art square.
const NODE_EXTENT := 2470.0
const GROW_SECONDS_PER_RANK := 0.33
const GOLD := Color("edc785")
const MAX_GOLD := Color("f6d891")
const MINT := Color("9bd89b")
const CREAM := Color("f3e2b3")
const SELECT := Color("e8fff6")
const MUTED := Color("8ea4ab")
const LOCKED_TINT := Color(0.46,0.49,0.53)
const HUB_GLYPH := 0xf0616
const REGIONS := [
	{"name":"집중 타격","categories":["직격","발동"],"color":Color("eda78b"),"title":Vector2(410,235)},
	{"name":"원소 공명","categories":["연소","확산"],"color":Color("96d9db"),"title":Vector2(2360,170)},
	{"name":"강화 육성","categories":["육성","지원"],"color":Color("add4a9"),"title":Vector2(410,2580)},
	{"name":"전선 제어","categories":["제어","방위"],"color":Color("a2d8f1"),"title":Vector2(2320,2580)},
]
const SKILL_TEXT := {
	"guardianBeam":"5초마다 자동 발동 · 가장 앞선 적에게 광선을 발사하며 포탑 화력에 비례해 피해가 증가합니다.",
	"riftMark":"10초마다 자동 발동 · 내구도가 높은 적 4명의 받는 모든 피해를 기본 25% 증폭합니다. 코어 스킬 위력에 비례하며 보스는 절반입니다.",
}
const SKILL_LOCKED_TEXT := "챕터 2 해금 · 스테이지 1-10을 클리어하면 균열 낙인을 장착할 수 있습니다."
var visuals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ui/core_tree_visuals.json"))
var grow := {}
var camera := {}
var shade: GradientTexture2D
var aura: GradientTexture2D
var point_bar: PanelContainer
var remaining_label: Label
var earned_label: Label
var draft_chip: Label
var menu_button: Button
var menu: PanelContainer

class NodeArt extends Control:
	var tree
	var core
	var id := ""
	func _draw() -> void:
		var side := minf(size.x,size.y)
		tree.draw_node_art(self,core,id,size/2,side/float(tree.visuals[id].diameter)*0.98,tree.is_locked(core,id))

class Dots extends Control:
	func _draw() -> void:
		for i in 3: draw_circle(size/2+Vector2((i-1)*7,0),2.2,Color("cfe0e6"))

class RankBar extends Control:
	var applied := 0
	var rank := 0
	var maximum := 1
	func _draw() -> void:
		var gap := 4.0
		var seg := (size.x-gap*(maximum-1))/maximum
		var top := size.y/2-4
		for i in maximum:
			var cell := Rect2(i*(seg+gap),top,seg,8)
			var fill := Color("1d2d37")
			var border := Color("2f4552")
			if i < applied:
				fill = GOLD; border = Color("f7e2b6")
			elif i < rank:
				fill = MINT; border = Color("b9e8b9")
			draw_rect(cell,fill)
			if i >= applied and i < rank:
				var x := cell.position.x+2
				while x < cell.end.x:
					draw_rect(Rect2(x,top,minf(3,cell.end.x-x),8),Color("6fae76"))
					x += 7
			draw_rect(cell,border,false,1)

func diameter(id: String) -> float:
	return float(visuals[id].diameter)

func hit_rect(owner, id: String) -> Rect2:
	# A 44px finger target at detailed zoom. Nearest-center resolution prevents
	# overlapping touch rectangles from selecting whichever node was iterated first.
	var width := maxf(diameter(id)*owner.zoom,44.0)
	return Rect2(owner.offset+owner.point(id)*owner.zoom-Vector2.ONE*width/2,Vector2.ONE*width)

# ---- rules shown on the map ----
func is_locked(owner, id: String) -> bool:
	return int(owner.lobby.core_draft.get(id,0)) <= 0 and not owner.accessible_nodes().has(id)

func applied_rank(owner, id: String) -> int:
	return mini(owner.rendered_rank(id),int(owner.lobby.core_draft.get(id,0)))

## A locked selection highlights the neighbours that can open it.
func openers(owner) -> Array:
	var id: String = owner.selected
	if id.is_empty() or not is_locked(owner,id): return []
	var result := []
	for neighbor in owner.data().nodes[id].neighbors:
		if not bool(owner.data().nodes[neighbor].get("terminal",false)): result.append(neighbor)
	return result

func region_of(category: String) -> Dictionary:
	for region in REGIONS:
		if category in region.categories: return region
	return REGIONS[0]

# ---- camera ----
func cover_zoom(owner) -> float:
	return maxf(owner.view.size.x,owner.view.size.y)/2800.0

func minimum_zoom(owner) -> float:
	return minf((owner.viewport_size.x-16)/NODE_EXTENT,maxf(80,owner.viewport_size.y-128)/NODE_EXTENT)

func visible_height(owner) -> float:
	if is_instance_valid(owner.inline_panel): return minf(owner.view.size.y,owner.inline_panel.position.y)
	return owner.view.size.y

## The background must always cover the view. Below cover scale the art is drawn
## larger than the world, so the limit follows the art rectangle. While a sheet is
## open only the area above it must stay covered, so edge nodes can be lifted.
func clamp_view(owner) -> void:
	if not is_instance_valid(owner.view): return
	var bz := maxf(owner.zoom,cover_zoom(owner))
	var shift: float = 1400.0*(owner.zoom-bz)
	var view_size := Vector2(owner.view.size.x,visible_height(owner))
	var offset: Vector2 = owner.offset
	for axis in range(2):
		offset[axis] = clampf(offset[axis],view_size[axis]-2800.0*bz-shift,-shift)
	owner.offset = offset

func fit(owner) -> void:
	owner.zoom = minimum_zoom(owner)
	owner.offset = owner.view.size/2-owner.center()*owner.zoom
	clamp_view(owner)

func destination(owner, change: Callable) -> Array:
	var saved := [owner.zoom,owner.offset]
	change.call()
	var result := [owner.zoom,owner.offset]
	owner.zoom = saved[0]
	owner.offset = saved[1]
	return result

## Eases zoom (log space) and the world point under the view centre.
func animate_to(owner, target: Array, seconds := 0.34) -> void:
	var half: Vector2 = owner.view.size/2
	camera = {"t":0.0,"duration":seconds,"z0":owner.zoom,"z1":float(target[0]),
		"c0":(half-owner.offset)/owner.zoom,"c1":(half-Vector2(target[1]))/float(target[0])}
	owner.view.set_process(true)

func settle_camera(owner) -> void:
	if camera.is_empty(): return
	camera.t = camera.duration
	tick(owner,0.0)

func interrupt() -> void:
	camera = {}

func tick(owner, delta: float) -> bool:
	var animating := false
	if not camera.is_empty():
		camera.t = minf(float(camera.t)+delta,float(camera.duration))
		var p := float(camera.t)/maxf(0.001,float(camera.duration))
		var e := 1.0-pow(1.0-p,3)
		owner.zoom = float(camera.z0)*pow(float(camera.z1)/float(camera.z0),e)
		var centre: Vector2 = Vector2(camera.c0).lerp(camera.c1,e)
		owner.offset = owner.view.size/2-centre*owner.zoom
		clamp_view(owner)
		if p >= 1.0: camera = {}
		else: animating = true
	var step := delta/(3.0*GROW_SECONDS_PER_RANK)
	for id in owner.node_ids():
		var target := minf(int(owner.lobby.core_draft.get(id,0)),3)/3.0
		var shown: float = grow.get(id,target)
		grow[id] = target if absf(target-shown) <= step else shown+signf(target-shown)*step
		if not is_equal_approx(float(grow[id]),target): animating = true
	owner.view.queue_redraw()
	return animating

# ---- input ----
func select_at(owner, location: Vector2) -> void:
	close_menu()
	var world: Vector2 = (location-owner.offset)/owner.zoom
	if owner.zoom < DETAIL_ZOOM:
		animate_to(owner,destination(owner,owner.scale_at.bind(DETAIL_ZOOM/owner.zoom,location)),0.38)
		return
	if world.distance_to(owner.center()) <= 150:
		owner.skills()
		return
	var closest := ""
	var distance := INF
	for id in owner.node_ids():
		if not hit_rect(owner,id).has_point(location): continue
		var d: float = location.distance_to(owner.offset+owner.point(id)*owner.zoom)
		if d < distance:
			distance = d
			closest = id
	if not closest.is_empty():
		node_details(owner,closest)
		layout(owner)
		# Centre the selection in the area above its sheet. Selecting never purchases.
		var top := point_bar.position.y+point_bar.size.y if is_instance_valid(point_bar) else 0.0
		var spot := Vector2(owner.view.size.x/2,(top+visible_height(owner))/2)
		var target: Vector2 = owner.point(closest)
		animate_to(owner,destination(owner,func():
			owner.offset = spot-target*owner.zoom
			clamp_view(owner)))
	else:
		owner.selected = ""
		owner.selecting_skill = false
		owner._close_inline()
	layout(owner)
	owner.view.queue_redraw()

# ---- overlay controls ----
func _glyph_label(code: int, pixels: int, color: Color, owner) -> Label:
	var label := Label.new()
	label.text = String.chr(code)
	if owner.material_font: label.add_theme_font_override("font",owner.material_font)
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _plain(text: String, pixels: int, color: Color, weight := 700) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",AppTheme.font(weight))
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, variant: String, callback: Callable) -> Button:
	var b := AppTheme.button(text,callback,variant)
	b.custom_minimum_size = Vector2(44,44)
	b.add_theme_font_size_override("font_size",12)
	return b

func _frame(path: String, inset: int) -> StyleBox:
	return Frame.new(path,inset)

## The upgrade screen's level-up frame; rank down and level-up share it.
func _levelup_style(disabled := false) -> StyleBox:
	var frame := Frame.new("ui/components/upgrade_levelup_frame_v2.png",7)
	frame.source_center = Rect2(12,5,127,24)
	if disabled: frame.modulate_color = Color(0.62,0.66,0.7)
	return frame

func build_overlay(owner) -> void:
	point_bar = PanelContainer.new()
	point_bar.name = "CorePointOverlay"
	var bar_style := _frame("ui/components/panel_frame.png",8)
	bar_style.content_margin_left = 14
	bar_style.content_margin_right = 8
	point_bar.add_theme_stylebox_override("panel",bar_style)
	point_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	point_bar.offset_left = 8
	point_bar.offset_right = -8
	point_bar.offset_top = 8
	point_bar.custom_minimum_size.y = 56
	owner.view.add_child(point_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	point_bar.add_child(row)
	row.add_child(_glyph_label(HUB_GLYPH,22,Color("7fd8e6"),owner))
	var numbers := VBoxContainer.new()
	numbers.add_theme_constant_override("separation",-2)
	numbers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(numbers)
	numbers.add_child(_plain("남은 코어 포인트",10,MUTED))
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation",4)
	numbers.add_child(values)
	remaining_label = _plain("",21,Color("e8f8ff"),900)
	remaining_label.name = "CoreRemainingPoints"
	values.add_child(remaining_label)
	earned_label = _plain("",12,MUTED)
	earned_label.size_flags_vertical = Control.SIZE_SHRINK_END
	values.add_child(earned_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	draft_chip = _plain("",12,MINT,800)
	draft_chip.name = "CoreDraftDelta"
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(MINT,0.08)
	chip_style.border_color = Color(MINT,0.6)
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(12)
	chip_style.content_margin_left = 9
	chip_style.content_margin_right = 9
	chip_style.content_margin_top = 2
	chip_style.content_margin_bottom = 2
	draft_chip.add_theme_stylebox_override("normal",chip_style)
	draft_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(draft_chip)
	owner.cancel_button = _button("되돌리기","secondary",owner.cancel)
	owner.cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(owner.cancel_button)
	owner.apply_button = _button("적용","primary",owner.apply)
	owner.apply_button.name = "CoreApplyDraft"
	owner.apply_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(owner.apply_button)
	menu_button = _button("","secondary",func(): menu.visible = not menu.visible; layout(owner))
	menu_button.name = "CorePointMenuButton"
	menu_button.tooltip_text = "더보기"
	menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dots := Dots.new()
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_button.add_child(dots)
	dots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(menu_button)
	menu = PanelContainer.new()
	menu.name = "CorePointMenu"
	menu.add_theme_stylebox_override("panel",_frame("ui/components/panel_frame.png",10))
	menu.visible = false
	owner.view.add_child(menu)
	owner.reset_button = _button("전체 초기화","danger",func(): close_menu(); owner.confirm_reset())
	owner.reset_button.custom_minimum_size.x = 150
	menu.add_child(owner.reset_button)
	# One grouped camera control; hidden while a sheet is open (pinch still works).
	var group := PanelContainer.new()
	group.name = "CoreZoomControls"
	group.add_theme_stylebox_override("panel",_frame("ui/components/button_frame.png",2))
	owner.view.add_child(group)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",0)
	group.add_child(buttons)
	var entries := [["−",1.0/1.4,40.0],["전체",0.0,46.0],["+",1.4,40.0]]
	for index in entries.size():
		var entry: Array = entries[index]
		if index > 0:
			var divider := ColorRect.new()
			divider.color = Color(0.63,0.75,0.78,0.22)
			divider.custom_minimum_size = Vector2(1,0)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			buttons.add_child(divider)
		var factor: float = entry[1]
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(float(entry[2]),40)
		button.add_theme_font_override("font",AppTheme.font(800))
		button.add_theme_font_size_override("font_size",12 if factor == 0 else 17)
		button.add_theme_color_override("font_color",Color("cfe0e6"))
		for state in ["normal","hover","pressed","focus","disabled"]:
			var flat := StyleBoxFlat.new()
			flat.bg_color = Color(0.72,1,0.92,0.12) if state == "pressed" else Color.TRANSPARENT
			button.add_theme_stylebox_override(state,flat)
		button.pressed.connect(func():
			if factor == 0: animate_to(owner,destination(owner,fit.bind(owner)),0.42)
			else: animate_to(owner,destination(owner,owner.scale_at.bind(factor,owner.view.size*0.5))))
		buttons.add_child(button)
	owner.zoom_controls = group

func close_menu() -> void:
	if is_instance_valid(menu): menu.visible = false

func update_overlay(owner) -> void:
	if not is_instance_valid(point_bar): return
	var drafting: bool = owner.changed()
	var delta: int = owner.spent(owner.lobby.core_draft)-owner.spent(owner.actual())
	remaining_label.text = str(owner.total()-owner.spent(owner.actual()))
	earned_label.text = "· 획득 %d" % owner.total()
	draft_chip.text = ("−%dP 예정" % delta) if delta >= 0 else ("+%dP 반환" % -delta)
	draft_chip.visible = drafting
	owner.cancel_button.visible = drafting
	owner.apply_button.visible = drafting
	menu_button.visible = not drafting
	if drafting: close_menu()
	owner.apply_button.disabled = owner.allocating or not owner.valid(owner.lobby.core_draft)
	owner.cancel_button.disabled = owner.allocating
	owner.reset_button.disabled = owner.allocating or owner.spent(owner.actual()) <= 0
	owner.view.set_process(true)

func layout(owner) -> void:
	if not is_instance_valid(owner.view): return
	var view_size: Vector2 = owner.view.size
	if view_size.x <= 0 or view_size.y <= 0: return
	if is_instance_valid(owner.inline_panel):
		var width := maxf(1,view_size.x-16)
		var frame: StyleBox = owner.inline_panel.get_theme_stylebox("panel")
		var content: float = owner.inline_body.get_combined_minimum_size().y+frame.get_minimum_size().y
		var height := clampf(content,minf(144,view_size.y),maxf(144,view_size.y*0.55))
		owner.inline_panel.custom_minimum_size = Vector2.ZERO
		owner.inline_panel.size = Vector2(width,height)
		owner.inline_panel.position = Vector2(8,view_size.y-height-8)
	if is_instance_valid(owner.zoom_controls):
		owner.zoom_controls.visible = not is_instance_valid(owner.inline_panel)
		owner.zoom_controls.size = owner.zoom_controls.get_combined_minimum_size()
		owner.zoom_controls.position = view_size-owner.zoom_controls.size-Vector2(8,8)
	if is_instance_valid(menu) and is_instance_valid(point_bar):
		menu.size = menu.get_combined_minimum_size()
		menu.position = Vector2(view_size.x-menu.size.x-12,point_bar.position.y+point_bar.size.y+4)
	# Opening or closing a sheet changes the covered height; ease back inside it.
	if camera.is_empty():
		var target := destination(owner,clamp_view.bind(owner))
		if Vector2(target[1]) != owner.offset: animate_to(owner,target,0.26)

# ---- sheets ----
func open_sheet(owner) -> VBoxContainer:
	# A replacement is one layout change. Clamping the briefly absent sheet
	# would start a camera move toward a full-view boundary and keep it running.
	owner._close_inline(false)
	var panel := PanelContainer.new()
	panel.name = "CoreInlineDetails"
	var style := _frame("ui/components/panel_frame.png",12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	panel.add_theme_stylebox_override("panel",style)
	owner.view.add_child(panel)
	owner.inline_panel = panel
	owner.inline_scroll = ScrollContainer.new()
	owner.inline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	owner.inline_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(owner.inline_scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner.inline_scroll.add_child(body)
	owner.inline_body = body
	body.minimum_size_changed.connect(func(): layout(owner),CONNECT_DEFERRED)
	return body

func _close_button(owner) -> Button:
	var close := CloseButton.new()
	close.name = "CloseCoreDetails"
	close.custom_minimum_size = Vector2(34,34)
	close.pressed.connect(func():
		owner.selected = ""
		owner.selecting_skill = false
		owner._close_inline()
		owner.view.queue_redraw())
	return close

func _foot() -> Label:
	var foot := _plain("변경은 다음 스테이지부터 적용됩니다.",10,MUTED,600)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return foot

func effect_text(d: Dictionary, rank: int) -> String:
	var by_rank: Array = d.get("displayEffectsByRank",[])
	if rank < by_rank.size(): return str(by_rank[rank])
	# Source lists are rank totals, never accumulated across earlier ranks.
	var result := PackedStringArray()
	for raw in d.get("displayEffects",[]):
		var line := str(raw)
		var split := line.split(": ",true,1)
		if split.size()==2 and split[1].contains(" / "):
			var values := split[1].split(" / ")
			line = split[0]+": "+values[clampi(rank-1,0,values.size()-1)]
		result.append(line)
	return "\n".join(result) if not result.is_empty() else str(d.get("effectSummary",""))

func _effect_rows(owner, body: VBoxContainer, d: Dictionary, id: String, rank: int) -> void:
	var maximum := int(d.maxRank)
	var first := true
	for raw in d.get("displayEffects",[]):
		var split := str(raw).split(": ",true,1)
		var values := split[1].split(" / ") if split.size() == 2 else PackedStringArray()
		var box := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1,1,1,0.035)
		style.border_color = Color("22394a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		box.add_theme_stylebox_override("panel",style)
		body.add_child(box)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",0)
		box.add_child(column)
		if values.size() != maximum or maximum == 1:
			# Sentences without per-rank values (keystones, extra HP) read whole.
			var whole := _plain(effect_text(d,maxi(1,rank)) if first else str(raw),12,Color("c7d5d8"))
			whole.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if first: whole.name = "CoreCurrentEffect"
			column.add_child(whole)
		else:
			column.add_child(_plain(split[0],12,Color("c7d5d8")))
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation",10)
			column.add_child(line)
			var applied := applied_rank(owner,id)
			var current := _plain(values[rank-1] if rank > 0 else "—",22,(Color("f3e6c4") if rank == applied else MINT) if rank > 0 else MUTED,900)
			if first: current.name = "CoreCurrentEffect"
			line.add_child(current)
			if rank < maximum:
				var arrow := _plain("→",18,MUTED,700)
				line.add_child(arrow)
				var next := _plain(values[rank],22,GOLD,900)
				if first: next.name = "CoreNextEffect"
				line.add_child(next)
		first = false

func node_details(owner, id: String) -> void:
	owner.selecting_skill = false
	owner.selected = id
	var d: Dictionary = owner.data().nodes[id]
	var rank := int(owner.lobby.core_draft.get(id,0))
	var maximum := int(d.maxRank)
	var body := open_sheet(owner)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",10)
	body.add_child(head)
	var art := NodeArt.new()
	art.tree = self
	art.core = owner
	art.id = id
	art.custom_minimum_size = Vector2(56,56)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(art)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_constant_override("separation",2)
	head.add_child(title)
	var name_label := _plain(owner.node_name(id),18,Color("f3e6c4"),900)
	name_label.name = "CoreNodeName"
	title.add_child(name_label)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation",5)
	title.add_child(tags)
	var category := _plain(str(d.get("category","")),11,Color("1c0f08"),800)
	var tag := StyleBoxFlat.new()
	tag.bg_color = Color(str(visuals[id].color))
	tag.set_corner_radius_all(4)
	tag.content_margin_left = 6
	tag.content_margin_right = 6
	category.add_theme_stylebox_override("normal",tag)
	tags.add_child(category)
	tags.add_child(_plain(str(region_of(str(d.get("category",""))).name),11,MUTED))
	head.add_child(_close_button(owner))
	var rank_row := HBoxContainer.new()
	rank_row.add_theme_constant_override("separation",8)
	body.add_child(rank_row)
	var bar := RankBar.new()
	bar.name = "CoreRankBar"
	bar.applied = applied_rank(owner,id)
	bar.rank = rank
	bar.maximum = maximum
	bar.custom_minimum_size = Vector2(0,28)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_row.add_child(bar)
	var count := _plain("%d/%d" % [rank,maximum],15,Color("e8f8ff"),900)
	count.custom_minimum_size.x = 38
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_row.add_child(count)
	_effect_rows(owner,body,d,id,rank)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation",8)
	body.add_child(acts)
	var minus := Button.new()
	minus.name = "CoreRefundRank"
	minus.text = "−"
	minus.tooltip_text = "등급 내리기"
	minus.custom_minimum_size = Vector2(64,46)
	minus.disabled = owner.allocating or rank <= 0 or not owner.valid(owner.candidate(id,-1))
	minus.pressed.connect(owner.change_rank.bind(id,-1))
	_style_levelup(minus,18)
	acts.add_child(minus)
	var plus := Button.new()
	plus.name = "CorePurchaseRank"
	plus.text = "최대 등급" if rank >= maximum else "강화"
	plus.custom_minimum_size = Vector2(0,46)
	plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plus.disabled = owner.allocating or rank >= maximum or not owner.valid(owner.candidate(id,1))
	plus.pressed.connect(owner.change_rank.bind(id,1))
	_style_levelup(plus,14)
	acts.add_child(plus)
	if rank < maximum: _cost_chip(owner,plus,int(d.rankCosts[rank]))
	body.add_child(_foot())
	layout(owner)
	owner.view.queue_redraw()

func _style_levelup(button: Button, pixels: int) -> void:
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		var style := _levelup_style(state == "disabled")
		if state == "hover": style.modulate_color = Color(1.12,1.12,1.12)
		elif state in ["pressed","hover_pressed"]: style.modulate_color = Color(0.82,0.9,0.94)
		button.add_theme_stylebox_override(state,style)
	button.add_theme_font_override("font",AppTheme.font(900))
	button.add_theme_font_size_override("font_size",pixels)
	button.add_theme_color_override("font_color",Color("e8fbff"))
	button.add_theme_color_override("font_hover_color",Color("e8fbff"))
	button.add_theme_color_override("font_pressed_color",Color("e8fbff"))
	button.add_theme_color_override("font_disabled_color",Color("6d7f8f"))

## Same rune-cost chip as the upgrade screen, carrying the core point glyph.
func _cost_chip(owner, button: Button, cost: int) -> void:
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_right = -8
	var chip := PanelContainer.new()
	chip.name = "CoreRankCost"
	var frame := Frame.new("ui/components/upgrade_rune_cost_frame_v2.png",9)
	frame.source_center = Rect2(10,6,60,15)
	frame.content_margin_top = 4
	frame.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel",frame)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if button.disabled: chip.modulate.a = 0.5
	holder.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(_glyph_label(HUB_GLYPH,15,Color("7fd8e6"),owner))
	row.add_child(_plain(str(cost),13,Color("b9d6e4"),800))

func skills(owner) -> void:
	owner.selecting_skill = true
	owner.selected = ""
	var body := open_sheet(owner)
	var head := HBoxContainer.new()
	body.add_child(head)
	var title := _plain("코어 스킬",18,Color("f3e6c4"),900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_close_button(owner))
	var current := str(owner.lobby.progression().get("coreCombatSkill",""))
	for id in ["guardianBeam","riftMark"]:
		var unlocked: bool = Progression.has_unlock(owner.lobby.progression(),"core",id)
		var row := PanelContainer.new()
		row.name = "CoreSkill_"+id
		row.add_theme_stylebox_override("panel",Frame.new("ui/components/row_frame.png" if unlocked else "ui/components/row_frame_locked.png",10))
		body.add_child(row)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",10)
		row.add_child(line)
		var socket := TextureRect.new()
		socket.texture = owner.tex("ui/components/icon_socket.png")
		socket.custom_minimum_size = Vector2(52,52)
		socket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		socket.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(socket)
		var icon := TextureRect.new()
		icon.texture = owner.tex("core_abilities/%s.png" % ("guardian_beam" if id == "guardianBeam" else "rift_mark"))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not unlocked: icon.modulate = LOCKED_TINT
		socket.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 9
		icon.offset_top = 9
		icon.offset_right = -9
		icon.offset_bottom = -9
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation",2)
		line.add_child(text)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation",6)
		text.add_child(name_row)
		name_row.add_child(_plain(owner.lobby.display_title(id),14,Color("f3e6c4"),900))
		if current == id:
			var badge := _plain("장착 중",10,Color("1c1406"),800)
			var badge_style := StyleBoxFlat.new()
			badge_style.bg_color = GOLD
			badge_style.set_corner_radius_all(4)
			badge_style.content_margin_left = 5
			badge_style.content_margin_right = 5
			badge.add_theme_stylebox_override("normal",badge_style)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			name_row.add_child(badge)
		var description := _plain(SKILL_TEXT[id] if unlocked else SKILL_LOCKED_TEXT,11,Color("b9d6e4"),600)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(description)
		var equip := _button("해제" if current == id else ("장착" if unlocked else "잠김"),"secondary" if current == id or not unlocked else "primary",func():
			owner.lobby.apply_growth_change({"kind":"unequipCoreCombatSkill" if current == id else "equipCoreCombatSkill","id":id})
			owner.skills())
		equip.custom_minimum_size.x = 72
		equip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		equip.disabled = not unlocked
		line.add_child(equip)
	body.add_child(_foot())
	layout(owner)
	owner.view.queue_redraw()

# ---- drawing ----
func _textures() -> void:
	if shade: return
	# Darkens the graph centre so nodes read above the art; the canvas-wide 0.2
	# fill plus this ramp yields 0.82 at the core, 0.6 at three quarters, 0.2 outside.
	shade = GradientTexture2D.new()
	shade.width = 256
	shade.height = 256
	shade.fill = GradientTexture2D.FILL_RADIAL
	shade.fill_from = Vector2(0.5,0.5)
	shade.fill_to = Vector2(1.0,0.5)
	shade.gradient = Gradient.new()
	shade.gradient.offsets = PackedFloat32Array([0.0,0.75,1.0])
	shade.gradient.colors = PackedColorArray([Color(0.016,0.055,0.086,0.775),Color(0.016,0.055,0.086,0.5),Color(0.016,0.055,0.086,0.0)])
	aura = GradientTexture2D.new()
	aura.width = 128
	aura.height = 128
	aura.fill = GradientTexture2D.FILL_RADIAL
	aura.fill_from = Vector2(0.5,0.5)
	aura.fill_to = Vector2(1.0,0.5)
	aura.gradient = Gradient.new()
	aura.gradient.offsets = PackedFloat32Array([0.0,0.3,1.0])
	aura.gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,1),Color(1,1,1,0)])

func screen(owner, world: Vector2) -> Vector2:
	return owner.offset+world*owner.zoom

func _text(canvas: CanvasItem, text: String, at: Vector2, font_size: int, color: Color, weight := 800) -> void:
	var font := AppTheme.font(weight)
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline := at+Vector2(-width/2,0)
	canvas.draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,maxi(3,int(font_size*0.28)),Color("061019"))
	canvas.draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _glow_line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(a,b,Color(color,0.22),width+5,true)
	canvas.draw_line(a,b,color,width,true)

func _glow_arc(canvas: CanvasItem, at: Vector2, radius: float, from: float, to: float, color: Color, width: float) -> void:
	canvas.draw_arc(at,radius,from,to,32,Color(color,0.22),width+4,true)
	canvas.draw_arc(at,radius,from,to,32,color,width,true)

func draw_node_art(canvas: CanvasItem, owner, id: String, at: Vector2, scale: float, locked: bool) -> void:
	var v: Dictionary = visuals[id]
	var radius := float(v.diameter)/2*scale
	canvas.draw_circle(at,radius*0.79,Color("07131e"))
	var tint := LOCKED_TINT if locked else Color.WHITE
	var icon_size := float(v.iconSize)*scale
	var icon: Texture2D = owner.tex(ROOT+str(v.icon)+".png")
	if icon: canvas.draw_texture_rect(icon,Rect2(at-Vector2.ONE*icon_size/2,Vector2.ONE*icon_size),false,tint)
	var frame: Texture2D = owner.tex(ROOT+str(v.frame)+".png")
	if frame: canvas.draw_texture_rect(frame,Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2),false,tint)

## Each rank up to 3 extends the link toward unranked neighbours; at rank 3 it
## reaches them and they open. Applied ranks gold, planned mint.
func _grow_line(canvas: CanvasItem, owner, from: String, a: Vector2, to: String, b: Vector2, k: float) -> void:
	if from == "CORE" or int(owner.lobby.core_draft.get(from,0)) <= 0 or int(owner.lobby.core_draft.get(to,0)) > 0: return
	if bool(owner.data().nodes[from].get("terminal",false)): return
	var length: float = grow.get(from,minf(int(owner.lobby.core_draft.get(from,0)),3)/3.0)
	var applied := minf(length,minf(applied_rank(owner,from),3)/3.0)
	if applied > 0: _glow_line(canvas,a,a.lerp(b,applied),GOLD,3*k)
	if length > applied: _glow_line(canvas,a.lerp(b,applied),a.lerp(b,length),MINT,3*k)
	if length > 0 and length < 1:
		var tip := a.lerp(b,length)
		var color := MINT if length > applied else GOLD
		canvas.draw_circle(tip,2.6*k+3,Color(color,0.25))
		canvas.draw_circle(tip,2.6*k,color)

func draw_tree(owner, canvas: Control) -> void:
	_textures()
	var view_size := canvas.size
	var zoom: float = owner.zoom
	var detailed := zoom >= DETAIL_ZOOM
	var draft: Dictionary = owner.lobby.core_draft
	canvas.draw_rect(Rect2(Vector2.ZERO,view_size),Color("04111b"))
	var core := screen(owner,owner.center())
	var bz := maxf(zoom,cover_zoom(owner))
	var background: Texture2D = owner.tex(ROOT+"background.png")
	if background: canvas.draw_texture_rect(background,Rect2(core-Vector2.ONE*1400*bz,Vector2.ONE*2800*bz),false,Color(0.62,0.62,0.64))
	canvas.draw_rect(Rect2(Vector2.ZERO,view_size),Color(0.016,0.055,0.086,0.2))
	var reach := 1300*zoom*1.15
	canvas.draw_texture_rect(shade,Rect2(core-Vector2.ONE*reach,Vector2.ONE*reach*2),false)
	var available: Array = owner.accessible_nodes()
	var hint := openers(owner)
	var k := maxf(zoom/0.46,0.5)
	for edge in owner.data().edges:
		var a: String = edge[0]; var b: String = edge[1]
		var start := screen(owner,owner.point(a)); var end := screen(owner,owner.point(b))
		var rank_a := 1 if a == "CORE" else int(draft.get(a,0))
		var rank_b := int(draft.get(b,0))
		var lit: bool = rank_a > 0 and rank_b > 0 and (a == "CORE" or owner.rendered_rank(a) > 0) and owner.rendered_rank(b) > 0
		var planned := not lit and rank_a > 0 and rank_b > 0
		canvas.draw_line(start,end,Color(0.008,0.031,0.051,0.85),(7.0 if lit or planned else 5.0)*k,true)
		if lit: _glow_line(canvas,start,end,GOLD,3.6*k)
		elif planned: canvas.draw_line(start,end,MINT,3.4*k,true)
		elif a == "CORE": canvas.draw_line(start,end,Color("b8ccd3"),2.2*k,true)
		else: canvas.draw_line(start,end,Color(0.43,0.53,0.58,0.75),1.6*k,true)
		if not lit and not planned:
			_grow_line(canvas,owner,a,start,b,end,k)
			_grow_line(canvas,owner,b,end,a,start,k)
	# Allocation feedback follows the exact same straight segments as the map.
	for step in owner.allocation_steps:
		var elapsed: float = owner.allocation_elapsed-float(step.wave)*200
		if not step.lightsConnection or elapsed<0 or elapsed>500: continue
		var from := screen(owner,owner.center() if str(step.source).is_empty() else owner.point(step.source))
		canvas.draw_line(from,from.lerp(screen(owner,owner.point(step.id)),clampf(elapsed/340,0,1)),Color("a3edee"),4*k,true)
	if detailed:
		for region in REGIONS:
			var at := screen(owner,region.title)
			_text(canvas,region.name,at,int(maxf(36*zoom,14)),Color("edd8b3"),900)
	for id in owner.node_ids():
		_draw_node(owner,canvas,id,available,hint,detailed)
	_draw_core(owner,canvas,core,detailed)
	if not detailed: _draw_overview(owner,canvas)

func _draw_node(owner, canvas: Control, id: String, available: Array, hint: Array, detailed: bool) -> void:
	var d: Dictionary = owner.data().nodes[id]
	var v: Dictionary = visuals[id]
	var at := screen(owner,owner.point(id))
	var zoom: float = owner.zoom
	var rank := int(owner.lobby.core_draft.get(id,0))
	var applied := applied_rank(owner,id)
	var maximum := int(d.maxRank)
	var unlocked := rank > 0 or available.has(id)
	var color := Color(str(v.color))
	var radius := float(v.diameter)/2*zoom
	if bool(d.get("terminal",false)):
		var halo := radius*2.1
		canvas.draw_texture_rect(aura,Rect2(at-Vector2.ONE*halo,Vector2.ONE*halo*2),false,Color(color,0.45 if unlocked else 0.3))
	draw_node_art(canvas,owner,id,at,zoom,not unlocked)
	var kk := maxf(zoom/0.46,0.45)
	var gauge := radius+5*kk+1.5
	var width := maxf(2.8,4.2*kk)
	if applied == maximum:
		_glow_arc(canvas,at,gauge,0,TAU,MAX_GOLD,width+0.6)
		canvas.draw_arc(at,gauge+width/2+2.5,0,TAU,48,Color(1,0.96,0.84,0.9),1,true)
	elif rank > 0:
		var gap := 0.22 if maximum > 1 else 0.0
		var seg := (TAU-gap*maximum)/maximum
		for i in maximum:
			var from := -PI/2+gap/2+i*(seg+gap)
			if i < applied: _glow_arc(canvas,at,gauge,from,from+seg,GOLD,width)
			elif i < rank:
				var dash := (3*kk+1)/gauge
				var pause := (2*kk+1)/gauge
				var t := from
				while t < from+seg:
					canvas.draw_arc(at,gauge,t,minf(t+dash,from+seg),6,MINT,width,true)
					t += dash+pause
			else: canvas.draw_arc(at,gauge,from,from+seg,24,Color(0.16,0.23,0.27,0.95),width,true)
	elif unlocked:
		_glow_arc(canvas,at,gauge,0,TAU,Color(CREAM,0.85),maxf(1.1,2*kk))
	if hint.has(id):
		var glow := gauge+16
		canvas.draw_texture_rect(aura,Rect2(at-Vector2.ONE*glow,Vector2.ONE*glow*2),false,Color(CREAM,0.4))
	if owner.selected == id: _glow_arc(canvas,at,gauge+9,0,TAU,SELECT,2.5)
	if detailed:
		var label := Vector2(float(v.labelPosition[0]),float(v.labelPosition[1]))
		var label_at := screen(owner,label)
		var tint := Color("f3e6c4") if rank > 0 else (color if unlocked or hint.has(id) else Color("7f8f96"))
		_text(canvas,owner.node_name(id),label_at,int(maxf(float(v.labelSize)*zoom,11.5)),tint)
		if rank > 0:
			var below := label_at.y < at.y
			_text(canvas,"%d/%d" % [rank,maximum],at+Vector2(0,gauge+15 if below else -gauge-6),12,Color("f1f5f4"))

## The equipped skill stays identifiable: a medallion in the overview, the
## nameplate with the skill icon and name once zoomed in.
func _draw_core(owner, canvas: Control, core: Vector2, detailed: bool) -> void:
	var radius: float = 150*owner.zoom
	_glow_arc(canvas,core,radius*0.92,0,TAU,Color(0.5,0.85,0.9,0.55),1.5)
	var art: Texture2D = owner.tex(ROOT+"core.png")
	if art: canvas.draw_texture_rect(art,Rect2(core-Vector2.ONE*radius,Vector2.ONE*radius*2),false)
	if owner.selecting_skill: _glow_arc(canvas,core,radius*0.98+6,0,TAU,SELECT,2.5)
	var skill := str(owner.lobby.progression().get("coreCombatSkill",""))
	var equipped := skill in ["guardianBeam","riftMark"]
	var icon: Texture2D = owner.tex("core_abilities/%s.png" % ("guardian_beam" if skill == "guardianBeam" else "rift_mark")) if equipped else null
	if not detailed:
		if not equipped: return
		var medal := core+Vector2(0,radius*0.78)
		canvas.draw_circle(medal,12,Color(0,0,0,0.5))
		canvas.draw_circle(medal,11,Color("0a1822"))
		canvas.draw_arc(medal,11,0,TAU,32,Color("d9b46c"),1.6,true)
		if icon: canvas.draw_texture_rect(icon,Rect2(medal-Vector2(8,8),Vector2(16,16)),false)
		return
	var title: String = owner.lobby.display_title(skill) if equipped else "스킬 선택"
	var font := AppTheme.font(800)
	var height := 32.0
	var icon_size := height-6 if equipped else 0.0
	var width := font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+icon_size+(34 if equipped else 32)
	var plate := Rect2(core+Vector2(-width/2,maxf(radius*0.7,18)),Vector2(width,height))
	owner._nameplate(canvas,plate)
	if icon: canvas.draw_texture_rect(icon,Rect2(plate.position+Vector2(14,3),Vector2.ONE*icon_size),false)
	var baseline := font.get_ascent(14)-font.get_height(14)/2.0
	canvas.draw_string(font,Vector2(plate.position.x+(18+icon_size if equipped else 16),plate.get_center().y+baseline+1),title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f4e6c8"))

## Overview bands: region progress, legend and gesture hint at screen-fixed sizes.
func _draw_overview(owner, canvas: Control) -> void:
	var view_size := canvas.size
	var top := point_bar.position.y+point_bar.size.y+10 if is_instance_valid(point_bar) else 10.0
	var spots := [Vector2(12,top),Vector2(-12,top),Vector2(12,view_size.y-144),Vector2(-12,view_size.y-144)]
	var actual: Dictionary = owner.actual()
	var font := AppTheme.font(800)
	for index in REGIONS.size():
		var region: Dictionary = REGIONS[index]
		var invested := 0
		var whole := 0
		for id in owner.node_ids():
			var d: Dictionary = owner.data().nodes[id]
			if not str(d.get("category","")) in region.categories: continue
			for i in int(d.maxRank): whole += int(d.rankCosts[i])
			for i in mini(int(actual.get(id,0)),int(d.maxRank)): invested += int(d.rankCosts[i])
		var amount := "%d/%d" % [invested,whole]
		var name_width := font.get_string_size(region.name,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		var amount_width := AppTheme.font(700).get_string_size(amount,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
		var width := 10+8+6+name_width+6+46+6+amount_width+10
		var spot: Vector2 = spots[index]
		var box := Rect2(Vector2(spot.x if spot.x > 0 else view_size.x+spot.x-width,spot.y),Vector2(width,28))
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(0.016,0.055,0.086,0.78)
		pill.border_color = Color(1,1,1,0.08)
		pill.set_border_width_all(1)
		pill.set_corner_radius_all(14)
		canvas.draw_style_box(pill,box)
		var x := box.position.x+10
		var mid := box.get_center().y
		canvas.draw_circle(Vector2(x+4,mid),4,region.color)
		x += 14
		canvas.draw_string(font,Vector2(x,mid+5),region.name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("edd8b3"))
		x += name_width+6
		canvas.draw_rect(Rect2(x,mid-2,46,4),Color("1d2d37"))
		if whole > 0: canvas.draw_rect(Rect2(x,mid-2,46.0*invested/whole,4),GOLD)
		x += 52
		canvas.draw_string(AppTheme.font(700),Vector2(x,mid+4),amount,HORIZONTAL_ALIGNMENT_LEFT,-1,11,GOLD if invested > 0 else MUTED)
	if is_instance_valid(owner.inline_panel): return
	var small := AppTheme.font(600)
	canvas.draw_string(small,Vector2(12,view_size.y-56),"눌러서 확대 · 끌어서 이동",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("b7cbcf"))
	var x := 12.0
	var y := view_size.y-30
	for entry in [["locked","잠김"],["open","투자 가능"],["applied","투자 중"],["max","최대"],["plan","계획"]]:
		var at := Vector2(x+7,y)
		canvas.draw_circle(at,4.5,Color("07131e"))
		match entry[0]:
			"locked": canvas.draw_arc(at,5.5,0,TAU,24,Color("55656c"),1.8,true)
			"open": canvas.draw_arc(at,6,0,TAU,24,CREAM,1.8,true)
			"max": canvas.draw_arc(at,6,0,TAU,24,MAX_GOLD,2.4,true)
			_:
				for i in 3:
					var from := -PI/2+i*2.09+0.15
					canvas.draw_arc(at,6,from,from+1.8,8,GOLD if entry[0] == "applied" else MINT,2.2,true)
		canvas.draw_string(small,Vector2(x+16,y+4),entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("b7cbcf"))
		x += 16+small.get_string_size(entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,10).x+9
