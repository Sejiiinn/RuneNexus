extends SceneTree
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Codec = preload("res://app/save_codec.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const Wave = preload("res://combat/native_wave_state.gd")
var checks := 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	_runtime_routes()
	_request_routes()
	_route_teleports()
	_layout_route_teleports()
	_target_routes()
	_content_routes()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func _runtime_routes() -> void:
	var a := [[0,0],[10,0],[10,10]]
	var b := [[0,0],[0,10],[10,10]]
	var equal = Wave.new()
	equal.start({"active":true,"spawnQueue":[{"enemyType":"normal","delay":1.0,"routeId":"b"},{"enemyType":"normal","delay":1.0,"routeId":"a"}]})
	check(equal.snapshot().spawnQueue[0].routeId == "b" and equal.snapshot().spawnQueue[1].routeId == "a","equal-time routes retain compiled order")
	var config := {"path":a,"routes":[{"id":"a","path":a},{"id":"b","path":b}],"enemies":[{"id":1,"routeId":"a","maxHp":100.0,"speed":1.0},{"id":2,"routeId":"b","maxHp":100.0,"speed":1.0}]}
	var runtime = Runtime.new()
	check(runtime.process_command({"epoch":1,"sequence":0,"bootstrap":config}).accepted,"accept two routes")
	runtime.process_command({"epoch":1,"sequence":1,"dtSteps":[0.25,0.25]})
	check(runtime.enemies["1"].x > 0 and runtime.enemies["1"].y == 0,"route a moves east")
	check(runtime.enemies["2"].y > 0 and runtime.enemies["2"].x == 0,"route b moves south; no global overwrite")
	var child: Dictionary = runtime.enemies["2"].duplicate(true)
	child.id = 3
	runtime.process_command({"epoch":1,"sequence":2,"commands":[{"kind":"spawn","enemy":child}],"dt":0.25})
	check(runtime.enemies["3"].routeId == "b" and runtime.enemies["3"].path == runtime.enemies["2"].path and runtime.enemies["3"].x == 0,"child/copied spawn inherits route and progress")
	var distance: float = runtime.enemies["2"].distanceTravelled
	runtime.process_command({"epoch":1,"sequence":3,"commands":[{"kind":"layout","tileSize":2.0,"boardDistanceScale":2.0,"path":[[0,0],[20,0],[20,20]]}]})
	check(is_equal_approx(runtime.enemies["2"].distanceTravelled,distance*2) and runtime.enemies["2"].x == 0,"layout scales selected route without replacing it")
	var snap: Dictionary = runtime.snapshot()
	var resumed = Runtime.new()
	var restored := {"path":runtime.path,"routes":[{"id":"a","path":runtime.routes.a.path},{"id":"b","path":runtime.routes.b.path}],"enemies":snap.enemies}
	check(resumed.process_command({"epoch":2,"sequence":0,"bootstrap":restored}).accepted,"runtime restore accepted")
	check(resumed.enemies["2"].routeId == "b" and resumed.enemies["2"].y == runtime.enemies["2"].y,"runtime snapshot restores route progress")
	var bad := config.duplicate(true)
	bad.enemies[0].routeId = "missing"
	check(not runtime.process_command({"epoch":2,"sequence":0,"bootstrap":bad}).accepted and runtime.epoch == 1,"unknown route rejected before reset")
	runtime.process_command({"epoch":1,"sequence":4,"commands":[{"kind":"coreDamage","enemyId":2,"damage":1000.0}]})
	runtime.process_command({"epoch":1,"sequence":5,"ackEvent":runtime.event_id})
	var deaths: Array = runtime.take_death_presentations()
	check(deaths.size() == 1 and deaths[0].enemyPresentation.routeId == "b","ACK death presentation retains killed route")
func _request_routes() -> void:
	var a := [[0,0],[10,0]]
	var b := [[0,0],[0,10]]
	var config := {"path":a,"routes":[{"id":"a","path":a},{"id":"b","path":b}]}
	var request := {"enemyType":"normal","delay":0.0,"routeId":"b","enemy":{"id":1,"maxHp":10.0,"speed":1.0}}
	for bootstrap_wave in [true,false]:
		var runtime = Runtime.new()
		var payload := config.duplicate(true)
		var wave := {"id":1,"active":true,"spawnQueue":[request.duplicate(true)]}
		if bootstrap_wave: payload.wave = wave
		check(runtime.process_command({"epoch":1,"sequence":0,"bootstrap":payload}).accepted,"request-only bootstrap route accepted")
		if not bootstrap_wave:
			check(runtime.process_command({"epoch":1,"sequence":1,"commands":[{"kind":"waveStart","wave":wave}]}).accepted,"request-only waveStart route accepted")
		check(runtime.wave.snapshot().spawnQueue[0].routeId == "b","request-only pending identity retained")
		runtime._step(0.1)
		runtime._step(0.5)
		check(runtime.enemies["1"].routeId == "b" and runtime.enemies["1"].x == 0 and runtime.enemies["1"].y > 0,"request-only route drives actual enemy")
		check(not request.enemy.has("routeId"),"normalization owns prepared enemy copy")
	for variant in ["unknown","mismatch","nestedMismatch","invalidType"]:
		var invalid := request.duplicate(true)
		if variant == "unknown": invalid.routeId = "missing"
		elif variant == "mismatch": invalid.enemy.routeId = "a"
		elif variant == "nestedMismatch": invalid.enemy.state = {"routeId":"a"}
		else: invalid.routeId = 1
		var runtime = Runtime.new()
		runtime.process_command({"epoch":1,"sequence":0,"bootstrap":config})
		var payload := config.duplicate(true)
		payload.wave = {"id":1,"active":true,"spawnQueue":[invalid]}
		check(not runtime.process_command({"epoch":2,"sequence":0,"bootstrap":payload}).accepted and runtime.epoch == 1,"bootstrap rejects "+variant+" route before reset")
		check(not runtime.process_command({"epoch":1,"sequence":1,"commands":[{"kind":"waveStart","wave":payload.wave}]}).accepted and runtime.sequence == 0,"waveStart rejects "+variant+" route before mutation")

	for variant in ["invalidType","unknown","nestedMismatch"]:
		var invalid := {"id":8,"maxHp":10.0,"speed":1.0,"routeId":"b"}
		if variant == "invalidType": invalid.routeId = 123
		elif variant == "unknown": invalid.routeId = "missing"
		else: invalid.state = {"routeId":"a"}
		var runtime = Runtime.new()
		runtime.process_command({"epoch":1,"sequence":0,"bootstrap":config})
		var payload := config.duplicate(true)
		payload.enemies = [invalid]
		check(not runtime.process_command({"epoch":2,"sequence":0,"bootstrap":payload}).accepted and runtime.epoch == 1,"bootstrap live enemy rejects "+variant)
		check(not runtime.process_command({"epoch":1,"sequence":1,"commands":[{"kind":"spawn","enemy":invalid}]}).accepted and runtime.sequence == 0 and runtime.enemies.is_empty(),"direct spawn rejects "+variant+" without mutation")

func _target_routes() -> void:
	var runtime = Runtime.new()
	runtime.process_command({"epoch":1,"sequence":0,"bootstrap":{"path":[[0,0],[8,0]],"enemies":[{"id":1,"path":[[0,0],[8,0]],"distanceTravelled":7.0,"maxHp":100.0},{"id":2,"path":[[0,1],[11,1]],"distanceTravelled":8.0,"maxHp":100.0}]}})
	check(runtime._target(Vector2.ZERO,100,"first").id == 1,"first ranks remaining1 before remaining3 despite shorter travelled distance")
	check(runtime._target(Vector2.ZERO,100,"last").id == 2,"last ranks remaining3 after remaining1")
	check(runtime._target(Vector2.ZERO,100,"strongest").id == 1,"durability tie ranks by remaining route distance")
	runtime._core_beam_tick(1.0)
	check(runtime.enemies["1"].hp < 100 and runtime.enemies["2"].hp == 100,"guardian beam targets nearest route completion")
	runtime.enemies["1"].hp = 100.0
	runtime.core.config.riftMarkTargetCount = 1
	runtime._core_rift_mark(1.0)
	check(runtime.enemies["1"].riftMarkRemaining > 0 and runtime.enemies["2"].riftMarkRemaining == 0,"rift durability tie ranks nearest route completion")

func _route_teleports() -> void:
	var a := [[0,0],[1,0],[4,0],[5,0]]
	var b := [[0,0],[0,1],[0,4],[5,4]]
	var pairs := [{"color":"blue","entranceIndex":1,"exitIndex":2}]
	var runtime = Runtime.new()
	var config := {"path":a,"teleportPairs":pairs,"routes":[{"id":"a","path":a,"teleportPairs":pairs},{"id":"b","path":b}],"enemies":[{"id":1,"routeId":"a","maxHp":100.0,"speed":1.0},{"id":2,"routeId":"b","maxHp":100.0,"speed":1.0}]}
	runtime.process_command({"epoch":1,"sequence":0,"bootstrap":config})
	runtime.process_command({"epoch":1,"sequence":1,"dt":1.0})
	check(runtime.enemies["1"].x == 4.0 and runtime.enemies["1"].routeId == "a","selected route teleports without losing identity")
	check(runtime.enemies["2"].y == 1.0 and not runtime.enemies["2"].has("teleportPairs"),"other route does not inherit default teleport")
	var route_only := config.duplicate(true)
	route_only.erase("teleportPairs")
	var presentation = Runtime.new()
	check(presentation.process_command({"epoch":1,"sequence":0,"bootstrap":route_only}).accepted,"route-only teleport bootstrap accepted")
	presentation.process_command({"epoch":1,"sequence":1,"dt":1.0})
	var frame: Dictionary = presentation.decorate_frame({"enemies":[]})
	check(frame.enemies[0].size() == 15 and frame.enemies[0][14].teleportSerial == 1,"route-only teleport exports interpolation discontinuity serial")
	check(frame.enemies[1].size() == 14,"nonteleport route retains legacy compact presentation row")
	var one = Runtime.new()
	var many = Runtime.new()
	for rt in [one,many]: rt.process_command({"epoch":1,"sequence":0,"bootstrap":config,"session":{"clock":"godot","phase":"wave","paused":false}})
	one.advance_session(0.5)
	for index in range(30): many.advance_session(Runtime.FIXED_STEP)
	check(one.snapshot().enemies == many.snapshot().enemies,"routed fixed steps are independent of render batching")

func _layout_route_teleports() -> void:
	var path := [[0,0],[1,0],[4,0],[5,0]]
	var pairs := [{"color":"blue","entranceIndex":1,"exitIndex":2}]
	var enemy := {"id":1,"routeId":"a","path":path,"teleportPairs":pairs,"maxHp":10.0,"speed":1.0}
	var queued := enemy.duplicate(true)
	queued.id = 2
	var runtime = Runtime.new()
	check(runtime.process_command({"epoch":1,"sequence":0,"bootstrap":{"path":path,"routes":[{"id":"a","path":path,"teleportPairs":pairs}],"enemies":[enemy],"wave":{"id":1,"active":true,"spawnQueue":[{"enemyType":"normal","delay":3.0,"routeId":"a","enemy":queued}]}}}).accepted,"layout teleport fixture accepted")
	check(runtime.process_command({"epoch":1,"sequence":1,"commands":[{"kind":"layout","routes":[{"id":"a","path":[[0,0],[1,0]]}]}]}).accepted,"replace named route topology without old teleports")
	check(not runtime.enemies["1"].has("teleportPairs") and runtime.enemies["1"].path.size() == 2,"live path replacement clears stale teleport indices")
	check(not runtime.wave.queue[0].enemy.has("teleportPairs") and runtime.wave.queue[0].enemy.path.size() == 2,"pending path replacement clears stale teleport indices")
	for tick in range(4): runtime._step(1.0)
	check(runtime.enemies["1"].arrived and runtime.enemies["2"].arrived,"updated live and pending routes arrive without invalid teleport index")
	var added := {"kind":"layout","routes":[{"id":"a","path":path,"teleportPairs":pairs}]}
	check(runtime.process_command({"epoch":1,"sequence":2,"commands":[added]}).accepted,"replacement may restore matching teleport metadata")
	added.routes[0].teleportPairs[0].exitIndex = 99
	check(runtime.routes.a.teleportPairs[0].exitIndex == 2 and runtime.enemies["1"].teleportPairs[0].exitIndex == 2,"layout teleport metadata owned independently of input")

func _content_routes() -> void:
	var catalog = Catalog.new()
	var growth = Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(),"load content")
	for stage_id in [28,30]:
		var stage: int = catalog.stage_index(stage_id)
		if stage < 0:
			check(false,"missing stage " + str(stage_id))
			continue
		var map: Dictionary = catalog.stage_map(stage)
		var bootstrap: Dictionary = catalog.bootstrap(stage)
		check(bootstrap.get("routes",[]).size() == 2,"bootstrap compiles both routes " + str(stage_id))
		check(catalog.enemy(stage,21,"normal").routeId == map.routes[0].id,"default content enemy chooses primary named route")
		var wave: Dictionary = catalog.wave(stage,21)
		var seen := {}
		for request in wave.spawnQueue:
			seen[request.enemy.routeId] = true
			check(request.enemy.path == catalog.world_path(stage,{"routeId":request.routeId}),"spawn route matches deterministic schedule")
		check(seen.size() == 2,"later wave uses both routes " + str(stage_id))
		var service = Commands.new(catalog,growth)
		var state: Dictionary = service.initial_state({"coreCombatSkill":null},stage)
		state.phase = "wave"
		state.roundIndex = 21
		state.completedRounds = 21
		bootstrap.defense.config = service.derived(state).defenseConfig
		bootstrap.wave = wave
		bootstrap.enemies = [catalog.enemy(stage,21,"normal",99999,{"routeId":map.routes[1].id})]
		bootstrap.enemies[0].distanceTravelled = 1.25
		for key in ["x","y","position","targetIndex","facingAngle"]: bootstrap.enemies[0].erase(key)
		var runtime = Runtime.new()
		runtime.process_command({"epoch":1,"sequence":0,"bootstrap":bootstrap,"session":{"clock":"godot","phase":"wave","paused":true}})
		runtime.process_command({"epoch":1,"sequence":1,"ackEvent":runtime.event_id})
		var adapter = Adapter.new(catalog,growth)
		var saved: Dictionary = adapter.capture(state,runtime.snapshot(),123)
		check(not saved.is_empty(),"capture routed save: " + adapter.error)
		if saved.is_empty(): continue
		check(saved.activeRun.enemies[0].routeId == map.routes[1].id,"saved live route identity")
		check(saved.activeRun.spawnQueue[0].routeId == wave.spawnQueue[0].routeId,"saved pending route identity")
		var prepared: Dictionary = adapter.prepare(saved)
		check(not prepared.is_empty(),"prepare routed save: " + adapter.error)
		if prepared.is_empty(): continue
		var resumed = Runtime.new()
		resumed.process_command({"epoch":2,"sequence":0,"bootstrap":prepared.bootstrap,"session":prepared.session})
		check(resumed.enemies["100000"].path == runtime.enemies["99999"].path and is_equal_approx(resumed.enemies["100000"].distanceTravelled,1.25),"content save restores selected path and progress")
		check(prepared.session.paused,"restored routed wave remains paused")
		var alternate := saved.duplicate(true)
		alternate.activeRun.enemies[0].routeId = map.routes[0].id
		check(Hash.hash_payload(alternate) != Hash.hash_payload(saved),"save hash includes route identity")
		var invalid := saved.duplicate(true)
		invalid.activeRun.enemies[0].routeId = "missing"
		check(adapter.prepare(invalid).is_empty(),"unknown saved route rejected")
		invalid = saved.duplicate(true)
		invalid.activeRun.enemies[0].erase("routeId")
		check(adapter.prepare(invalid).is_empty(),"missing live route rejected on routed map")
		invalid = saved.duplicate(true)
		invalid.activeRun.spawnQueue[0].routeId = "missing"
		check(adapter.prepare(invalid).is_empty(),"pending route mismatch rejected")
