extends RefCounted
## Adapts the native run owner to the existing selection renderer's tile units.
## Call after selection/run commands; no simulation or per-frame stat calculation.
const GemPalette = preload("res://ui/battle_rewards.gd")
const COLORS := {"arrow":0xffe7c66a,"cannon":0xffff7b2f,"magic":0xffff5e3a,"frost":0xff7fd8ff,"sniper":0xffb7f4ff,"lightning":0xffcfa7ff}
var level_preview := false
var _revision := 0
var _last_state: Dictionary = {}

func apply(app) -> void:
	_build_state(app)
	var frame: Dictionary = app.scene._native_combat_base_frame
	var selection: Dictionary = frame.get("presentation", {}).get("selection", {})
	if selection.is_empty() or selection.has("revision") or not selection.get("preserveLegacyOrnaments", false): return
	selection.preserveLegacyOrnaments = true
	selection.aimKey = "id"
	if selection != _last_state:
		_revision += 1
		_last_state = selection.duplicate(true)
	frame.presentation.selection = {"revision": _revision, "state": _last_state}

func _build_state(app) -> void:
	var frame: Dictionary = app.scene._native_combat_base_frame
	if frame.is_empty(): return
	frame.presentationVersion = 2
	frame.buildPreview = null
	if not frame.get("presentation") is Dictionary: frame.presentation = {}
	var hud = app.get("hud")
	var rewards = hud.get("rewards") if hud != null else null
	# Existing reward target presentation has priority over ordinary selection.
	if rewards == null and frame.presentation.get("selection",{}).get("state", frame.presentation.get("selection",{})).get("rewardTargeting",false): return
	var rewarding: bool = rewards != null and rewards.targeting()
	var selection := {"preserveLegacyOrnaments":true,"logicalTileSize":48.0,"visualScale":1.0,"rewardTargeting":rewarding,"turrets":[],"tiles":[],"rewardTargets":[]}
	frame.presentation.selection = selection
	var state: Dictionary = app.run_domain.state
	if state.is_empty(): return
	var chosen: Vector2i = app.selected
	var selected_id: int = app.run_domain.selected_id(chosen)
	var derived: Dictionary = app.run_domain.service.derived(state)
	for turret in state.get("turrets",[]):
		var stats := _stats(app,derived,turret)
		var selected: bool = int(turret.id) == selected_id
		var entry := {"id":int(turret.id),"position":[float(turret.x)+0.5,float(turret.y)+0.5],"range":_range(app,str(turret.type),stats),"selected":selected,"color":COLORS.get(turret.type,0xff8ee6ff),"level":int(turret.level)}
		# Separate from legacy 2D arcs; the model owner renders these in world space.
		entry.orbitGemColors = []
		for gem in turret.get("equippedGemSlots", []):
			if gem != null:
				entry.orbitGemColors.append(Color(str(GemPalette.GEM_COLORS.get(gem, "69D7FF"))))
		if selected and level_preview:
			var quote: Dictionary = app.run_domain.service.quotes(state,int(turret.id))
			if int(quote.get("level",0)) > 0 and int(state.gold) >= int(quote.level):
				var next: Dictionary = turret.duplicate(true)
				next.level += 1
				entry.previewRange = _range(app,str(turret.type),_stats(app,derived,next))
		selection.turrets.append(entry)
		if rewarding:
			var gem: String = rewards.pending_gem
			var rules: Dictionary = app.run_domain.growth.data.turretRules.get(turret.type, {})
			if gem in rules.get("compatibleGems", []) and gem not in turret.equippedGemSlots:
				selection.rewardTargets.append({"position":entry.position,"requiresReplacement":not null in turret.equippedGemSlots})
	if rewarding: return
	if selected_id >= 0: return
	var map: Dictionary = app.stage_source(app.stage).map
	if chosen.x < 0 or chosen.y < 0 or chosen.x >= int(map.columns) or chosen.y >= int(map.rows): return
	var kind := str(map.tiles[chosen.y*int(map.columns)+chosen.x])
	var tile := {"position":[chosen.x+0.5,chosen.y+0.5],"kind":kind}
	if kind in ["spawn","core"]:
		tile.kind = "portal" if kind == "spawn" else "core"
		selection.tiles.append(tile)
	elif kind == "build" and state.get("phase") in ["preparation","wave"]:
		var type := str(app.turret_type)
		if type not in derived.get("availableTurretTypes",[]): return
		var preview := {"type":type,"level":1,"primaryTrait":null,"secondaryTrait":null,"equippedGemSlots":[]}
		tile.range = _range(app,type,_stats(app,derived,preview))
		tile.color = COLORS.get(type,0xff8ee6ff)
		selection.tiles.append(tile)
		frame.buildPreview = [-1,chosen.x+0.5,chosen.y+0.5,0,tile.range,0,type]

func _stats(app, derived: Dictionary, turret: Dictionary) -> Dictionary:
	var input: Dictionary = derived.get("turretStatInputs",{}).get(turret.type,{}).duplicate(true)
	input.merge({"level":turret.level,"primaryTrait":turret.get("primaryTrait"),"secondaryTrait":turret.get("secondaryTrait"),"gems":turret.get("equippedGemSlots",[]).filter(func(g): return g != null)},true)
	# One native world unit per tile, matching the standalone bootstrap. The
	# catalog applies boardDistanceScale; the renderer accepts tile coordinates.
	return app.catalog.turret_stats(turret.type,{"tileSize":1.0,"statInput":input})

func _range(app, type: String, stats: Dictionary) -> float:
	var definition: Dictionary = app.catalog.data.turrets[type].configuration.statInput.definition
	return float(stats.get("range",0)) * (float(stats.get("effectAreaMultiplier",1)) if definition.get("centeredAreaAttack",false) else 1.0)
