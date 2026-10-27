extends "res://ui/expanded_core_tree_state.gd"
## Screen-space drawing of the tree, its growth links and the apply wave.

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
	if length > applied: _glow_line(canvas,a.lerp(b,applied),a.lerp(b,length),PLANNED,3*k)
	if length > 0 and length < 1:
		var tip := a.lerp(b,length)
		var color := PLANNED if length > applied else GOLD
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
		elif planned: _glow_line(canvas,start,end,PLANNED,3.2*k)
		elif a == "CORE": canvas.draw_line(start,end,Color("b8ccd3"),2.2*k,true)
		else: canvas.draw_line(start,end,Color(0.43,0.53,0.58,0.75),1.6*k,true)
		if not lit and not planned:
			_grow_line(canvas,owner,a,start,b,end,k)
			_grow_line(canvas,owner,b,end,a,start,k)
	if owner.allocating and not wave.is_empty(): _draw_wave_links(owner,canvas,k)
	if detailed:
		for region in REGIONS:
			var at := screen(owner,region.title)
			_text(canvas,region.name,at,int(maxf(36*zoom,14)),Color("edd8b3"),900)
	for id in owner.node_ids():
		_draw_node(owner,canvas,id,available,hint,detailed)
	_draw_core(owner,canvas,core,detailed)
	if owner.allocating and not wave.is_empty(): _draw_wave_bursts(owner,canvas,core,k)
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
					canvas.draw_arc(at,gauge,t,minf(t+dash,from+seg),6,PLANNED,width,true)
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
					canvas.draw_arc(at,6,from,from+1.8,8,GOLD if entry[0] == "applied" else PLANNED,2.2,true)
		canvas.draw_string(small,Vector2(x+16,y+4),entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("b7cbcf"))
		x += 16+small.get_string_size(entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,10).x+9

# ---- apply feedback ----
## Path of Exile style: light runs along real links (shortest world distance) from
## where the tree is already lit — the core and every kept allocation — out to the
## new ranks. Returns the animation length in ms.
func begin_wave(owner, base: Dictionary, target: Dictionary) -> float:
	wave = {}
	var distance := {"CORE":0.0}
	for id in base:
		if int(base[id]) > 0 and int(target.get(id,0)) > 0: distance[id] = 0.0
	var adjacency := {}
	var links := []
	var origins := []
	for edge in owner.data().edges:
		var a: String = edge[0]
		var b: String = edge[1]
		if not (a == "CORE" or int(target.get(a,0)) > 0) or int(target.get(b,0)) <= 0: continue
		var length: float = owner.point(a).distance_to(owner.point(b))
		if not adjacency.has(a): adjacency[a] = []
		if not adjacency.has(b): adjacency[b] = []
		adjacency[a].append([b,length])
		adjacency[b].append([a,length])
		# Links between two already-lit ends stay as they are; light only leaves them.
		if distance.has(a) and distance.has(b): continue
		links.append([a,b,length])
		for end in [a,b]:
			if distance.has(end) and not end in origins: origins.append(end)
	var settled := {}
	while true:
		var nearest := ""
		var best := INF
		for id in distance:
			if not settled.has(id) and float(distance[id]) < best:
				nearest = id
				best = distance[id]
		if nearest.is_empty(): break
		settled[nearest] = true
		for pair in adjacency.get(nearest,[]):
			if best+float(pair[1]) < float(distance.get(pair[0],INF)): distance[pair[0]] = best+float(pair[1])
	var raised := []
	var farthest := 0.0
	for id in target:
		if not distance.has(id) or int(target[id]) <= int(base.get(id,0)): continue
		raised.append(id)
		farthest = maxf(farthest,float(distance[id]))
	if raised.is_empty(): return 0.0
	# Raising only kept nodes travels nowhere: they flash in place.
	var seconds := clampf(farthest/WAVE_SPEED,WAVE_MIN_SECONDS,WAVE_MAX_SECONDS) if farthest > 0 else 0.0
	wave = {"distance":distance,"links":links,"origins":origins,"raised":raised,"speed":farthest/seconds if seconds > 0 else 1.0,"base":base.duplicate(),"target":target.duplicate()}
	return seconds*1000.0+WAVE_BURST_MS

func wave_front(owner) -> float:
	return float(owner.allocation_elapsed)/1000.0*float(wave.get("speed",0.0))

## Lowered ranks change at once; raised ranks wait for the light to arrive.
func wave_rank(owner, id: String) -> int:
	var target := int(wave.target.get(id,0))
	var before := int(wave.base.get(id,0))
	if target <= before: return target
	return target if float(wave.distance.get(id,INF)) <= wave_front(owner) else before

func _draw_wave_links(owner, canvas: Control, k: float) -> void:
	var front := wave_front(owner)
	var distance: Dictionary = wave.distance
	for link in wave.links:
		var a: String = link[0]
		var b: String = link[1]
		var length: float = link[2]
		var near := a if float(distance.get(a,INF)) <= float(distance.get(b,INF)) else b
		var far := b if near == a else a
		var progress := (front-float(distance[near]))/length
		if progress <= 0: continue
		var from := screen(owner,owner.point(near))
		var to := screen(owner,owner.point(far))
		var reach := minf(progress,1.0)
		_glow_line(canvas,from,from.lerp(to,reach),GOLD,3.6*k)
		# A bright streak rides the front and fades once it leaves the link.
		var tail := WAVE_TAIL/length
		if progress > 1.0+tail: continue
		var fade := 1.0 if progress <= 1.0 else 1.0-(progress-1.0)/tail
		for i in 3:
			var t0 := maxf(0.0,reach-tail*(3-i)/3.0)
			var color := Color(1,0.97,0.86,fade*(0.25+0.25*i))
			canvas.draw_line(from.lerp(to,t0),from.lerp(to,reach),color,(2.0+i)*k,true)
		if progress < 1.0:
			var head := from.lerp(to,reach)
			canvas.draw_circle(head,6*k,Color(1,0.95,0.8,0.25))
			canvas.draw_circle(head,3*k,Color(1,0.98,0.92))

func _draw_wave_bursts(owner, canvas: Control, core: Vector2, k: float) -> void:
	var elapsed: float = owner.allocation_elapsed
	if elapsed < WAVE_BURST_MS:
		# The light departs from each lit end it leaves: the core or kept nodes.
		var e := elapsed/WAVE_BURST_MS
		for origin in wave.origins:
			if origin == "CORE":
				canvas.draw_arc(core,150*owner.zoom*(0.95+0.35*e),0,TAU,48,Color(0.75,0.95,1,1-e),3*k,true)
				continue
			var at := screen(owner,owner.point(origin))
			var radius: float = diameter(origin)/2*owner.zoom+5*maxf(owner.zoom/0.46,0.45)+1.5
			canvas.draw_arc(at,radius*(1.0+0.35*e),0,TAU,40,Color(1,0.96,0.84,1-e),2.5*k,true)
	var front := wave_front(owner)
	for id in wave.raised:
		var age := (front-float(wave.distance[id]))/float(wave.speed)*1000.0
		if age < 0 or age > WAVE_BURST_MS: continue
		var e := age/WAVE_BURST_MS
		var at := screen(owner,owner.point(id))
		var radius: float = diameter(id)/2*owner.zoom+5*maxf(owner.zoom/0.46,0.45)+1.5
		var flash: float = radius*(1.4+0.6*e)
		canvas.draw_texture_rect(aura,Rect2(at-Vector2.ONE*flash,Vector2.ONE*flash*2),false,Color(1,0.95,0.78,0.55*(1-e)))
		canvas.draw_arc(at,radius+28*k*e,0,TAU,40,Color(GOLD,1-e),3*k*(1-e)+1,true)
