extends RefCounted
## Approved v5 artwork and geometry. No inferred edges or radial relayout.
const AppTheme = preload("res://ui/app_theme.gd")
const ROOT := "core_passive_tree/expanded/"
const DETAIL_ZOOM := 0.40
var visuals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ui/core_tree_visuals.json"))

func diameter(id: String) -> float:
	return float(visuals[id].diameter)

func hit_rect(owner, id: String) -> Rect2:
	# A 44px finger target at detailed zoom. Nearest-center resolution prevents
	# overlapping touch rectangles from selecting whichever node was iterated first.
	var width := maxf(diameter(id)*owner.zoom,44.0)
	return Rect2(owner.offset+owner.point(id)*owner.zoom-Vector2.ONE*width/2,Vector2.ONE*width)

func select_at(owner, location: Vector2) -> void:
	var world: Vector2 = (location-owner.offset)/owner.zoom
	if owner.zoom < DETAIL_ZOOM:
		owner.scale_at(DETAIL_ZOOM/owner.zoom,location)
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
		# Keep the selected node visible above its bottom sheet, including outer
		# keystones and small portrait screens. Selecting never purchases a rank.
		owner.offset = Vector2(owner.view.size.x/2,maxf(115,owner.view.size.y*0.28))-owner.point(closest)*owner.zoom
		owner._clamp()
	else:
		owner.selected = ""
		owner.selecting_skill = false
		owner._close_inline()
	layout(owner)
	owner.view.queue_redraw()

func layout(owner) -> void:
	var bottom: float = owner.view.size.y-54
	if is_instance_valid(owner.inline_panel):
		var width := maxf(1,owner.view.size.x-16)
		var height := minf(300,maxf(144,owner.view.size.y*0.48))
		owner.inline_panel.custom_minimum_size = Vector2.ZERO
		owner.inline_panel.size = Vector2(width,height)
		owner.inline_panel.position = Vector2(8,owner.view.size.y-height-8)
		bottom = owner.inline_panel.position.y-50
	if is_instance_valid(owner.zoom_controls):
		owner.zoom_controls.position = Vector2(8,maxf(92,bottom))

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

func node_details(owner, id: String) -> void:
	owner.selecting_skill = false
	owner.selected = id
	var d: Dictionary = owner.data().nodes[id]
	var rank := int(owner.lobby.core_draft.get(id,0))
	var current := int(owner.actual().get(id,0))
	var maximum := int(d.maxRank)
	var box: VBoxContainer = owner._open_inline(owner.node_name(id))
	var kind := "종착 핵심" if bool(d.get("terminal",false)) else ("주요 노드" if maximum==3 else "일반 노드")
	box.add_child(AppTheme.label("%s · %s · %s" % [d.get("category",""),id,kind],10))
	box.add_child(AppTheme.label("현재 %d/%d · 계획 %d/%d · 투자 %dP" % [current,maximum,rank,maximum,_node_spent(d,rank)],12))
	var current_effect := AppTheme.label(("현재 효과\n" if rank>0 else "1등급 효과\n")+effect_text(d,maxi(1,rank)),13)
	current_effect.name = "CoreCurrentEffect"
	box.add_child(current_effect)
	if rank>0 and rank<maximum:
		var next_effect := AppTheme.label("다음 등급\n"+effect_text(d,rank+1),11)
		next_effect.name = "CoreNextEffect"
		box.add_child(next_effect)
	var accessible: bool = owner.accessible_nodes().has(id) or rank>0
	var condition := "시작 노드 · 바로 투자할 수 있습니다." if id in owner.data().startingNodes else "연결된 노드 중 하나가 코어와 이어진 3등급이면 열립니다."
	if bool(d.get("terminal",false)): condition += " 이 핵심을 통해 다른 노드는 열리지 않습니다."
	var hint := AppTheme.label(condition,10)
	if not accessible: hint.add_theme_color_override("font_color",Color("eac783"))
	box.add_child(hint)
	var can_refund: bool = rank>0 and owner.valid(owner.candidate(id,-1))
	if rank>0 and not can_refund:
		box.add_child(AppTheme.label("연결이 끊기는 노드를 먼저 환불해야 합니다. 다른 3등급 경로가 있으면 유지할 수 있습니다.",10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	box.add_child(row)
	var minus: Button = owner.action(row,"− %dP" % (int(d.rankCosts[rank-1]) if rank>0 else 0),owner.change_rank.bind(id,-1))
	minus.name = "CoreRefundRank"
	minus.disabled = owner.allocating or not can_refund
	var plus: Button = owner.action(row,"+ %dP" % (int(d.rankCosts[rank]) if rank<maximum else 0),owner.change_rank.bind(id,1))
	plus.name = "CorePurchaseRank"
	plus.disabled = owner.allocating or rank>=maximum or not owner.valid(owner.candidate(id,1))
	if rank>=maximum: plus.text = "최대 등급"
	var difference: int = owner.spent(owner.lobby.core_draft)-owner.spent(owner.actual())
	var apply_text := "계획 적용" if difference==0 else ("%dP 적용" % difference if difference>0 else "%dP 반환" % -difference)
	var apply: Button = owner.action(row,apply_text,owner.apply)
	apply.name = "CoreApplyDraft"
	apply.disabled = owner.allocating or not owner.changed() or not owner.valid(owner.lobby.core_draft)
	box.add_child(AppTheme.label("변경은 다음 스테이지부터 적용됩니다.",10))
	layout(owner)
	owner.view.queue_redraw()

func _node_spent(d: Dictionary,rank: int) -> int:
	var result := 0
	for n in rank: result += int(d.rankCosts[n])
	return result

func _text(owner, canvas: Control,text: String,at: Vector2,font_size: int,color: Color) -> void:
	var font := AppTheme.font(800)
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline := at+Vector2(-width/2,0)
	canvas.draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color("061019"))
	canvas.draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func draw_tree(owner, canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("04111b"))
	canvas.draw_set_transform(owner.offset,0,Vector2.ONE*owner.zoom)
	owner._image(canvas,ROOT+"background.png",Rect2(Vector2.ZERO,Vector2(2800,2800)))
	var detailed: bool = owner.zoom>=DETAIL_ZOOM
	var available: Array = owner.accessible_nodes()
	for edge in owner.data().edges:
		var a: String = edge[0]; var b: String = edge[1]
		var start: Vector2 = owner.point(a); var end: Vector2 = owner.point(b)
		var planned: bool = int(owner.lobby.core_draft.get(b,0))>0 and (a=="CORE" or int(owner.lobby.core_draft.get(a,0))>0)
		var lit: bool = owner.rendered_rank(b)>0 and (a=="CORE" or owner.rendered_rank(a)>0)
		canvas.draw_line(start,end,Color("031018"),12,true)
		canvas.draw_line(start,end,Color("edc785") if lit else (Color("9bd89b") if planned else Color("647c88")),5 if lit or planned else 2.8,true)
	# Allocation feedback follows the exact same straight segments as the map.
	for step in owner.allocation_steps:
		var elapsed: float = owner.allocation_elapsed-float(step.wave)*200
		if not step.lightsConnection or elapsed<0 or elapsed>500: continue
		var start: Vector2 = owner.center() if str(step.source).is_empty() else owner.point(step.source)
		canvas.draw_line(start,start.lerp(owner.point(step.id),clampf(elapsed/340,0,1)),Color("a3edee"),7,true)
	for title in [["집중 타격",Vector2(410,235)],["원소 공명",Vector2(2360,170)],["강화 육성",Vector2(410,2580)],["전선 제어",Vector2(2320,2580)]]:
		_text(owner,canvas,title[0],title[1],36,Color("edd8b3"))
	for id in owner.node_ids():
		var d: Dictionary = owner.data().nodes[id]
		var v: Dictionary = visuals[id]
		var pos: Vector2 = owner.point(id)
		var size: float = v.diameter
		var rank := int(owner.lobby.core_draft.get(id,0))
		var current: int = owner.rendered_rank(id)
		var unlocked: bool = available.has(id) or rank>0
		var color := Color(str(v.color))
		canvas.draw_circle(pos,size*0.395,Color("07131e"))
		canvas.draw_arc(pos,size*0.395,0,TAU,48,color,2,true)
		owner._image(canvas,ROOT+str(v.icon)+".png",Rect2(pos-Vector2.ONE*float(v.iconSize)/2,Vector2.ONE*float(v.iconSize)),Color(1,1,1,1 if unlocked else 0.45))
		owner._image(canvas,ROOT+str(v.frame)+".png",Rect2(pos-Vector2.ONE*size/2,Vector2.ONE*size),Color(1,1,1,1 if unlocked else 0.55))
		if rank>0 or owner.selected==id or id in owner.data().startingNodes:
			var halo_color := Color("82d9e7") if current>0 else (Color("9bd89b") if rank>0 else Color("ddc69b"))
			canvas.draw_arc(pos,size/2+8,0,TAU,64,halo_color,5 if rank>0 or owner.selected==id else 2,true)
		if owner.selected==id: canvas.draw_arc(pos,size/2+17,0,TAU,64,Color("d4f8e7"),3,true)
		if detailed:
			_text(owner,canvas,"%d/%d" % [rank,int(d.maxRank)],pos+Vector2(0,size/2+10),20,Color("dce8e9"))
			var at := Vector2(float(v.labelPosition[0]),float(v.labelPosition[1]))
			_text(owner,canvas,owner.node_name(id),at,int(v.labelSize),Color("f3d492") if bool(d.get("terminal",false)) else color)
	owner._image(canvas,ROOT+"core.png",Rect2(owner.center()-Vector2(150,150),Vector2(300,300)))
	var skill := str(owner.lobby.progression().get("coreCombatSkill",""))
	var name: String = owner.lobby.display_title(skill) if skill in ["guardianBeam","riftMark"] else "스킬 선택"
	owner._nameplate(canvas,Rect2(owner.center()+Vector2(-110,92),Vector2(220,41)))
	_text(owner,canvas,name,owner.center()+Vector2(0,121),24,Color("e5d2a5"))
	canvas.draw_set_transform(Vector2.ZERO)
	if not detailed:
		var hint := "방향을 눌러 확대 · 드래그로 이동"
		var font := AppTheme.font(700)
		canvas.draw_string(font,Vector2(10,canvas.size.y-66),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("b7cbcf"))
