extends RefCounted
## Expanded core tree shared state: node geometry, rank queries and the camera
## view model.
const AppTheme = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const CloseButton = preload("res://ui/close_button.gd")
const Progression = preload("res://content/stage_progression.gd")
const ROOT := "core_passive_tree/expanded/"
const DETAIL_ZOOM := 0.40
## Node bounds including frames; the overview fits these, not the 2800-unit art square.
const NODE_EXTENT := 2470.0
const GROW_SECONDS_PER_RANK := 0.33
## Apply feedback: light leaves the core and runs through every allocated link at
## this world speed; each raised rank takes effect as the front reaches it.
const WAVE_SPEED := 1100.0
const WAVE_MIN_SECONDS := 0.7
const WAVE_MAX_SECONDS := 1.6
const WAVE_BURST_MS := 450.0
const WAVE_TAIL := 160.0
const GOLD := Color("edc785")
const MAX_GOLD := Color("f6d891")
## Planned (not yet applied) ranks glow bright white, like a PoE path preview.
const PLANNED := Color("f4faff")
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
var wave := {}
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
				fill = PLANNED; border = Color.WHITE
			draw_rect(cell,fill)
			if i >= applied and i < rank:
				var x := cell.position.x+2
				while x < cell.end.x:
					draw_rect(Rect2(x,top,minf(3,cell.end.x-x),8),Color("b9c9d2"))
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
