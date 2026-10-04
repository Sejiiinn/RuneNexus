extends SceneTree
## Accepted build origin, real-time impact and lifecycle without renderer assets.
const Placement = preload("res://presentation/turret_placement.gd")
const Fixture = preload("res://verify_run_transition.gd")
const App = preload("res://app/app_lifecycle.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
class Host extends Fixture.Host:
	var placement = Placement.new()
	var accepted: Array = []
	func confirm_turret_placement(id: int, type: String, x: int, y: int) -> void:
		accepted.append([id,type,x,y])
		placement.queue_build(id,type,x,y)
	func cancel_turret_placement(id: int) -> void: placement.remove(id)
	func _apply_frame(frame: Dictionary) -> void:
		if frame.get("reset",false): placement.clear()
		super._apply_frame(frame)
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func run() -> void:
	var app = App.new()
	var host := Host.new()
	app.scene = host
	app.checkpoint = Checkpoint.new(OS.get_cache_dir().path_join("turret-placement-"+str(Time.get_ticks_usec())))
	app.checkpoint.allow_progression_only = true
	check(app.catalog.load_catalog() and app.run_domain.growth.load_catalog() and app.retry_load(),"actual domain/save startup")
	app.progression_inputs.clearedStageNumbers = range(1,61)
	check(app.start_stage(0) and host.accepted.is_empty(),"initial session never creates placement cue")
	var state: Dictionary = app.run_domain.state
	state.gold = 100000
	var map: Dictionary = app.catalog.stage_map(0)
	var tiles: Array[Vector2i] = []
	for index in map.tiles.size():
		if map.tiles[index] == "build": tiles.append(Vector2i(index%int(map.columns),index/int(map.columns)))
	var kinds := ["arrow","cannon","magic","frost","sniper","lightning"]
	var models := {}
	var entries := {}
	for index in kinds.size():
		var tile := tiles[index]
		var before_count: int = host.accepted.size()
		var before_gold: int = app.run_domain.state.gold
		check(app.apply_run_command({"kind":"build","x":tile.x,"y":tile.y,"type":kinds[index]}),kinds[index]+" build accepted")
		var id: int = app.run_domain.state.turrets.back().id
		var angle := 0.0 if kinds[index] == "frost" else 3.0*PI/4.0
		check(is_equal_approx(app.run_domain.state.turrets.back().aimAngle,angle) and is_equal_approx(host._native_combat.turrets[str(id)].aimAngle,angle),kinds[index]+" accepted build initializes domain/native facing")
		check(host.accepted.size() == before_count+1 and app.run_domain.state.gold < before_gold,kinds[index]+" exactly one successful build cue and charge")
		var model := Node3D.new()
		model.position = Vector3(tile.x+0.5-int(map.columns)/2.0,0,tile.y+0.5-int(map.rows)/2.0)
		model.scale = Vector3(1.1,1.2,1.3)
		models[id] = model
		entries[id] = {"root":model,"type":kinds[index]}
		host.placement.apply_entry(id,entries[id],map.columns,map.rows)
		check(model.position.y == 0.0 and model.scale == Vector3(1.1,1.2,1.3),kinds[index]+" immediately uses native zero pose without deformation")
		var started: int = host.placement.placements[id].started_usec
		host.placement.queue_build(id,kinds[index],tile.x,tile.y)
		model.position.y = 0
		host.placement.apply_entry(id,entries[id],map.columns,map.rows)
		check(host.placement.placements[id].started_usec == started,kinds[index]+" duplicate submission retains clock")
	check(host.placement.shake_pixels().length() <= 2.0,"rapid placement impact stays within two actual pixels")
	var cues: int = host.accepted.size()
	check(not app.apply_run_command({"kind":"build","x":tiles[0].x,"y":tiles[0].y,"type":"arrow"}) and host.accepted.size() == cues,"occupied failure does not animate")
	app.run_domain.state.gold = 0
	check(not app.apply_run_command({"kind":"build","x":tiles[6].x,"y":tiles[6].y,"type":"arrow"}) and host.accepted.size() == cues,"unaffordable failure does not animate")
	app.board_tap(tiles[6])
	check(host.accepted.size() == cues,"selection alone does not animate")
	app.start_wave()
	app.set_speed(4)
	app.toggle_pause()
	var native_time: float = host._native_combat.clock
	Engine.time_scale = 0.05
	paused = true
	var deadline := Time.get_ticks_usec()+180000
	while Time.get_ticks_usec() < deadline: await process_frame
	check(host.placement.shake_pixels() == Vector2.ZERO and not host.placement.placements.is_empty(),"0.15 second impact ends while dust continues")
	deadline = Time.get_ticks_usec()+500000
	while Time.get_ticks_usec() < deadline: await process_frame
	host.placement.update(entries,map.columns,map.rows)
	check(host.placement.shake_pixels() == Vector2.ZERO,"impact returns to exact zero without drift")
	check(host.placement.placements.is_empty() and host._native_combat.clock == native_time and host._native_combat.session.speed == 4,"impact/dust finish in real time without advancing paused 4x battle")
	paused = false
	Engine.time_scale = 1
	for model in models.values(): check(model.position.y == 0.0 and model.scale == Vector3(1.1,1.2,1.3),"exact final zero and original shape")
	var id: int = entries.keys()[0]
	var turret: Dictionary = app.run_domain.service.turret(app.run_domain.state,id)
	host.placement.queue_build(id,str(turret.type),int(turret.x),int(turret.y))
	check(app.apply_run_command({"kind":"sell","id":id}) and not host.placement.placements.has(id),"sale cancels even an unrendered cue")
	id = entries.keys()[1]
	turret = app.run_domain.service.turret(app.run_domain.state,id)
	host.placement.queue_build(id,str(turret.type),int(turret.x),int(turret.y))
	entries[id].type = "replacement"
	host.placement.apply_entry(id,entries[id],map.columns,map.rows)
	check(not host.placement.placements.has(id),"type replacement cancels instead of replaying")
	check(app.start_stage(0) and host.placement.placements.is_empty() and host.accepted.size() == cues,"new session clears placement state without restoration cue")
	for model in models.values(): model.free()
	host.free()
	app.free()
	print("TURRET_PLACEMENT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
