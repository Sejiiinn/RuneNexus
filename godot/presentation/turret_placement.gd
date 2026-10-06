extends RefCounted
## Explicit accepted builds drive a real-time impact, never snapshot membership.
signal began(id: int, cue: Dictionary)
signal ended(id: int)
const IMPACT_DURATION := 0.22
const DUST_DURATION := 19.0/30.0
var placements: Dictionary = {}

func queue_build(id: int, type: String, x: int, y: int) -> void:
	if id < 0 or placements.has(id): return
	placements[id] = {"type":type,"x":x,"y":y,"started_usec":0,"root_id":0}

func apply_entry(id: int, entry: Dictionary, columns: int, rows: int) -> void:
	if not placements.has(id): return
	var cue: Dictionary = placements[id]
	var model: Node3D = entry.root
	var base := Vector3(float(cue.x)+0.5-columns/2.0,0,float(cue.y)+0.5-rows/2.0)
	if entry.type != cue.type or not is_equal_approx(model.position.x,base.x) or not is_equal_approx(model.position.z,base.z):
		remove(id)
		return
	if int(cue.root_id) != 0 and int(cue.root_id) != model.get_instance_id():
		remove(id)
		return
	# Installation keeps the native pose immediately; only world/dust move.
	model.position.y = 0.0
	if int(cue.started_usec) == 0:
		cue.started_usec = Time.get_ticks_usec()
		cue.root_id = model.get_instance_id()
		began.emit(id,cue)
	if elapsed(cue) >= DUST_DURATION: remove(id)

func update(turrets: Dictionary, columns: int, rows: int) -> void:
	for id in placements.keys():
		if turrets.has(id): apply_entry(id,turrets[id],columns,rows)

func remove(id: int) -> void:
	if placements.erase(id): ended.emit(id)

func clear() -> void:
	for id in placements.keys(): remove(id)

static func elapsed(cue: Dictionary) -> float:
	return maxf(0.0,(Time.get_ticks_usec()-int(cue.started_usec))/1000000.0) if int(cue.started_usec) > 0 else 0.0

func shake_pixels() -> Vector2:
	var offset := Vector2.ZERO
	for cue: Dictionary in placements.values():
		if int(cue.started_usec) == 0: continue
		var progress := elapsed(cue)/IMPACT_DURATION
		if progress >= 1.0: continue
		var decay := pow(1.0-progress,1.5)
		# A small vertical impact followed by a weaker rebound; HUD stays still.
		offset.y += cos(progress*TAU*1.5)*2.0*decay
	return offset.limit_length(2.0)
