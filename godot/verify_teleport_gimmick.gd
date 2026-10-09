extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Teleports = preload("res://combat/teleport_pairs.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Codec = preload("res://app/save_codec.gd")
var checks := 0
var failures: Array = []
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _path() -> Array:
	var path := []
	for i in range(8): path.append({"x":float(i*48),"y":0.0})
	return path
func _pairs() -> Array:
	return [{"color":"blue","entranceIndex":1,"exitIndex":3},{"color":"orange","entranceIndex":4,"exitIndex":6}]
func _enemy(extra: Dictionary = {}) -> Dictionary:
	var raw := {"id":42,"maxHp":1000.0,"hp":800.0,"speed":48.0,"path":_path(),"teleportPairs":_pairs(),"maxShield":100.0,"shield":70.0,"maxArmor":60.0,"armor":45.0,"diamondReward":1,"laneOffsetRatio":0.2,"visualPhase":0.7}
	raw.merge(extra,true)
	return Enemy.create(raw)
func _initialize() -> void:
	_validation()
	_movement()
	_runtime()
	_save()
	_disconnected()
	_save(true)
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func _validation() -> void:
	var map := {"columns":8,"rows":1,"tiles":["spawn","path","path","path","path","path","path","core"],"path":[[0,0],[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0]]}
	check(Teleports.validate_map(map).is_empty(),"missing feature allowed")
	map.teleportPairs = [{"color":"blue","entrance":[1,0],"exit":[3,0]},{"color":"orange","entrance":[4,0],"exit":[6,0]}]
	check(Teleports.validate_map(map).is_empty() and Teleports.compile_map(map) == _pairs(),"two colors compile by original path")
	for pairs in [null,{},[{"color":"red","entrance":[1,0],"exit":[3,0]}],[{"color":"blue","entrance":[3,0],"exit":[1,0]}],[{"color":"blue","entrance":[1.0,0],"exit":[3,0]}],[{"color":"blue","entrance":[1,1],"exit":[3,0]}],[{"color":"blue","entrance":[1,0],"exit":[1,0]}],[{"color":"blue","entrance":[1,0],"exit":[3,0]},{"color":"blue","entrance":[4,0],"exit":[6,0]}],[{"color":"blue","entrance":[1,0],"exit":[3,0]},{"color":"orange","entrance":[3,0],"exit":[6,0]}]]:
		map.teleportPairs = pairs
		check(not Teleports.validate_map(map).is_empty(),"invalid map rejected: " + str(pairs))
	for pair in [{"color":"blue","entrance":[0,0],"exit":[3,0]},{"color":"blue","entrance":[1,0],"exit":[7,0]}]:
		map.teleportPairs = [pair]
		check(Teleports.validate_map(map) == "Teleport endpoint must be a path tile","spawn/core tile endpoints rejected")
	map.teleportPairs = [{"color":"blue","entrance":[1,0],"exit":[3,0]}]
	for tile in ["build","blocked"]:
		map.tiles[1] = tile
		check(Teleports.validate_map(map) == "Teleport endpoint must be a path tile","non-path endpoint rejected " + tile)
	var catalog = Catalog.new()
	check(catalog.load_catalog() and catalog.stage_count() == 25,"real catalog retains existing stages plus expansion")
	for i in range(15): check(not catalog.stage(i).map.has("teleportPairs") and not catalog.bootstrap(i).has("teleportPairs"),"real stage unchanged " + str(i))
	var invalid: Dictionary = catalog.domain_snapshot()
	invalid.stages[0].map.teleportPairs = [{"color":"red"}]
	check(not catalog.load_fixture_content(invalid) and not catalog.is_loaded() and not catalog.error.is_empty(),"invalid metadata rejected at catalog boundary")
func _movement() -> void:
	var e := _enemy()
	Enemy.add_slow(e,0.5,20.0)
	Enemy.add_burn(e,{"damagePerSecond":2.0,"duration":20.0})
	Enemy.add_poison(e,3.0,20.0,2)
	Enemy.add_vulnerability(e,"physical",0.2,20.0)
	Enemy.add_rift_mark(e,0.1,20.0)
	var events := Enemy.step(e,2.0)
	check(events.filter(func(v): return v.type == "teleport" and v.color == "blue").size() == 1,"blue entrance teleports once")
	check(e.x == 144.0 and e.targetIndex == 4 and e.distanceTravelled == 144.0,"exit exact original-path progress")
	check(e.id == 42 and e.hp == 800.0 and e.armor == 45.0 and e.shield < 70.0 and e.diamondReward == 1,"identity and layered health retained with normal DOT")
	check(e.slowInstances.size() == 1 and e.burnInstances.size() == 1 and e.poisonStacks == 1 and e.physicalVulnerabilityRemaining == 18.0 and e.riftMarkRemaining == 18.0,"statuses retained and ticked once")
	check(e.visualPhase == 0.7 and e.laneOffsetRatio == 0.2,"visual identity retained")
	events = Enemy.step(e,0.0)
	check(events.filter(func(v): return v.type == "teleport").is_empty() and e.x == 144.0,"zero dt no teleport")
	events = Enemy.step(e,0.5)
	check(events.filter(func(v): return v.type == "teleport").is_empty() and e.x == 156.0,"exit never retransmits")
	e = _enemy()
	Enemy.step(e,100.0)
	check(e.x == 144.0 and not e.arrived,"large dt discards waypoint overshoot at exit")
	Enemy.step(e,100.0)
	check(e.x == 288.0 and e.teleportSerial == 2 and not e.arrived,"second color independently routes")
	events = Enemy.step(e,100.0)
	check(e.arrived and events.filter(func(v): return v.type == "coreArrival").size() == 1,"arrival once after both teleports")
	check(Enemy.step(e,100.0).is_empty(),"arrival cannot repeat")
	e = _enemy({"teleportPairs":[{"color":"blue","entranceIndex":1,"exitIndex":7}]})
	events = Enemy.step(e,1.0)
	check(e.arrived and events.size() == 2 and events[0].type == "teleport" and events[1].type == "coreArrival","last waypoint exit arrives atomically")
	e = _enemy({"teleportPairs":[{"color":"blue","entranceIndex":0,"exitIndex":3}]})
	check(Enemy.step(e,0.0).is_empty() and e.x == 0.0,"spawn entrance waits positive simulation step")
	Enemy.step(e,0.1)
	check(e.x == 144.0,"spawn entrance supported")
	e = _enemy({"hp":1.0,"shield":0.0,"armor":0.0})
	Enemy.add_burn(e,{"damagePerSecond":10.0,"duration":2.0})
	events = Enemy.step(e,1.0)
	check(e.hp == 0.0 and e.x == 0.0 and not e.has("teleportSerial"),"DOT death prevents teleport")
	var plain := _enemy({"teleportPairs":[]})
	Enemy.step(plain,100.0)
	check(plain.x == 48.0 and plain.targetIndex == 2,"legacy large dt movement unchanged")
func _runtime() -> void:
	var runtime = Runtime.new()
	var bootstrap := {"path":_path(),"teleportPairs":_pairs(),"tileSize":48.0,"boardDistanceScale":1.0,"enemies":[_enemy()]}
	var answer: Dictionary = runtime.process_command({"epoch":1,"sequence":0,"bootstrap":bootstrap,"session":{"clock":"godot","phase":"wave","paused":true,"speed":4.0}})
	check(answer.accepted,"runtime accepts compiled metadata")
	check(not runtime.advance_session(1.0) and runtime.enemies["42"].x == 0.0,"paused session blocks teleport")
	runtime.process_command({"epoch":1,"sequence":1,"session":{"paused":false}})
	# Preserve existing 60 Hz movement rounding: the entrance is reached on tick 61.
	runtime.advance_session(61.0 * Runtime.FIXED_STEP / 4.0)
	check(runtime.enemies["42"].x == 144.0 and runtime.events.size() == 1 and runtime.events[0].kind == "teleport","4x simulation teleports with existing clock")
	check(runtime.events[0].fromX == 48.0 and runtime.events[0].x == 144.0,"event coordinates use logical board pixels")
	var frame: Dictionary = runtime.decorate_frame({"enemies":[]})
	check(frame.enemies[0].size() == 15 and frame.enemies[0][14].teleportSerial == 1,"presentation optional teleport serial")
	# Ballistic projectiles only sweep their own trajectory against final enemy
	# centers; the skipped enemy segment must never act as a collision surface.
	runtime.turrets["1"] = {"id":1}
	var projectile := {"id":1,"owner":"1","attack":{"projectileSpeed":1.0,"definition":{"type":"arrow"}},"position":Vector2(96,-10),"origin":Vector2(96,-10),"direction":Vector2.DOWN,"remaining":100.0,"excluded":[],"chains":0,"chained":false,"shot":0}
	runtime._move_projectile(projectile,20.0)
	check(runtime.projectiles.size() == 1 and runtime.enemies["42"].hp == 800.0,"no projectile swept hit across teleport gap")
	runtime.turrets.clear()
	runtime.projectiles.clear()
	check(runtime._target(Vector2(144,0),1000.0,"first").id == 42,"target selection retains enemy identity at exit")
	var scaled := []
	for point in _path(): scaled.append({"x":point.x*2.0+10.0,"y":point.y*2.0+20.0})
	runtime.process_command({"epoch":1,"sequence":2,"commands":[{"kind":"layout","path":scaled,"tileSize":96.0,"boardDistanceScale":2.0,"origin":[10.0,20.0]}]})
	check(runtime.enemies["42"].x == 298.0 and runtime.enemies["42"].y == 20.0 and runtime.enemies["42"].targetIndex == 4,"layout scaling preserves exit and next waypoint")
	answer = runtime.process_command({"epoch":1,"sequence":3,"commands":[{"kind":"layout","path":[[0,0],[1,0]]}]})
	check(not answer.accepted and runtime.sequence == 2,"incompatible path rejected before layout mutation")
	var bad := bootstrap.duplicate(true)
	bad.teleportPairs[0].exitIndex = 100
	answer = runtime.process_command({"epoch":2,"sequence":0,"bootstrap":bad})
	check(not answer.accepted and answer.reason == "invalidTeleportPairs" and runtime.epoch == 1,"invalid runtime config rejected before reset")
func _gap_map() -> Dictionary:
	return {"columns":4,"rows":3,"tileTheme":"chapterOne", "tiles":["spawn","path","blocked","blocked","blocked","blocked","blocked","blocked","blocked","core","path","path"],"path":[[0,0],[1,0],[3,2],[2,2],[1,2]],"teleportPairs":[{"color":"blue","entrance":[1,0],"exit":[3,2]}]}
func _disconnected() -> void:
	var presentation := {"columns":1,"rows":1,"tiles":["build"]}
	check(Teleports.validate_map(presentation).is_empty(),"legacy presentation-only map without route allowed")
	presentation.teleportPairs = []
	check(Teleports.validate_map(presentation).is_empty(),"empty pairs preserve presentation-only map")
	presentation.teleportPairs = [{"color":"blue","entrance":[0,0],"exit":[0,0]}]
	check(Teleports.validate_map(presentation) == "Missing teleport path","teleport metadata still requires route")
	var map := _gap_map()
	check(Teleports.validate_map(map).is_empty(),"nonadjacent registered IN-to-OUT edge allowed")
	var missing := map.duplicate(true)
	missing.erase("teleportPairs")
	check(not Teleports.validate_map(missing).is_empty(),"unregistered disconnected path rejected")
	missing.teleportPairs = []
	check(not Teleports.validate_map(missing).is_empty(),"empty pairs cannot bridge a path gap")
	missing.teleportPairs = [{"color":"blue","entrance":[1,0],"exit":[2,2]}]
	check(not Teleports.validate_map(missing).is_empty(),"jump must land at registered OUT")
	var catalog := Catalog.new()
	check(catalog.load_catalog(),"gap fixture catalog")
	var fixture: Dictionary = catalog.domain_snapshot()
	fixture.stages[0].map = map
	check(catalog.load_fixture_content(fixture),"gap fixture map loaded")
	var path := catalog.world_path(0,{"tileSize":48.0})
	var e := _enemy({"path":path,"teleportPairs":Teleports.compile_map(map)})
	var events := Enemy.step(e,1.0)
	check(events.size() == 1 and events[0].type == "teleport" and e.x == 168.0 and e.y == 120.0 and e.targetIndex == 3,"gap crossing is instantaneous to OUT")
	check(events[0].fromX == 72.0 and events[0].fromY == 24.0,"jump starts at actual IN center")
	check(is_equal_approx(e.facingAngle,PI),"OUT immediately faces next walk tile")
	Enemy.step(e,0.5)
	check(e.x == 144.0 and e.y == 120.0 and e.teleportSerial == 1,"walking resumes only after OUT")
func _save(disconnected: bool = false) -> void:
	var catalog = Catalog.new()
	var growth = Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(),"save catalogs")
	# Only this owned fixture has portals; checked-in stages remain untouched.
	var fixture: Dictionary = catalog.domain_snapshot()
	if disconnected:
		fixture.stages[0].map = _gap_map()
	else:
		var path: Array = fixture.stages[0].map.path
		fixture.stages[0].map.teleportPairs = [{"color":"blue","entrance":path[1].duplicate(),"exit":path[3].duplicate()}]
	check(catalog.load_fixture_content(fixture),"owned teleport fixture loaded")
	var service = Commands.new(catalog,growth)
	var adapter = Adapter.new(catalog,growth)
	var state: Dictionary = service.initial_state({"growthVersion":1,"coreCombatSkill":null},0)
	state.phase = "wave"
	var bootstrap: Dictionary = catalog.bootstrap(0,{"defenseConfig":service.derived(state).defenseConfig})
	bootstrap.wave = catalog.wave(0,0,200000)
	var raw: Dictionary = catalog.enemy(0,0,"normal",100000)
	raw.speed = 48.0
	bootstrap.enemies = [raw]
	var runtime = Runtime.new()
	runtime.process_command({"epoch":1,"sequence":0,"bootstrap":bootstrap,"session":{"clock":"godot","phase":"wave","paused":false}})
	runtime.advance_session(61.0 * Runtime.FIXED_STEP)
	runtime.process_command({"epoch":1,"sequence":1,"ackEvent":runtime.event_id,"session":{"paused":true}})
	var before: Dictionary = runtime.enemies["100000"].duplicate(true)
	check(int(before.get("teleportSerial",0)) == 1,"save fixture actually teleported")
	var saved: Dictionary = adapter.capture(state,runtime.snapshot(),123)
	check(not saved.is_empty(),"v2 capture succeeds: " + adapter.error)
	if saved.is_empty(): return
	check(Codec.is_normalized_v2(saved) and not saved.activeRun.enemies[0].has("teleportPairs") and not saved.activeRun.enemies[0].has("teleportSerial"),"v2 schema has no new enemy fields")
	var prepared: Dictionary = adapter.prepare(saved)
	check(not prepared.is_empty(),"v2 prepare succeeds: " + adapter.error)
	if prepared.is_empty(): return
	var restored = Runtime.new()
	restored.process_command({"epoch":2,"sequence":0,"bootstrap":prepared.bootstrap,"session":prepared.session})
	var after: Dictionary = restored.enemies["100000"]
	check(after.x == before.x and after.y == before.y and after.targetIndex == before.targetIndex and after.distanceTravelled == before.distanceTravelled,"exit position and next waypoint restored from v2 distance")
	check(prepared.session.paused and not restored.advance_session(1.0),"restored combat stays paused")
	var events := Enemy.step(after,0.1)
	check(events.filter(func(v): return v.type == "teleport").is_empty(),"restored exit never retransmits")
