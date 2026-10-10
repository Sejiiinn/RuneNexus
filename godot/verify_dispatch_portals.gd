extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const SaveProjection = preload("res://app/run_save_adapter.gd")
const Hash = preload("res://services/save_payload_hash.gd")
var checks := 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	var catalog = Catalog.new()
	var growth = Growth.new()
	var loaded: bool = catalog.load_catalog() and growth.load_catalog()
	check(loaded,"load compiled metadata: " + catalog.error + " " + growth.error)
	if not failures.is_empty(): _finish(); return
	_portal_ingress()
	_shipped_boundary(catalog)
	_signature_compatibility(catalog)
	_dispatch(catalog)
	for stage_id in range(26,31): _checkpoint(catalog,growth,stage_id)
	_finish()
func _finish() -> void:
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func _portal_ingress() -> void:
	var config := {"path":[[0,0],[10,0]],"spawnPortalId":"A","routes":[{"id":"north","spawnPortalId":"A","path":[[0,0],[10,0]]}]}
	for invalid in [123,null,[],{},""]:
		for location in ["default","route"]:
			for queued in [false,true]:
				var runtime = Runtime.new()
				check(runtime.process_command({"epoch":1,"sequence":0,"bootstrap":config}).accepted,"valid portal ingress")
				var bad := config.duplicate(true)
				if location == "default": bad.spawnPortalId = invalid
				else: bad.routes[0].spawnPortalId = invalid
				var enemy := {"id":1,"routeId":"north","maxHp":10.0}
				if queued: bad.wave = {"active":true,"spawnQueue":[{"enemyType":"normal","delay":0.0,"enemy":enemy}]}
				else: bad.enemies = [enemy]
				check(not runtime.process_command({"epoch":2,"sequence":0,"bootstrap":bad}).accepted and runtime.epoch == 1,"malformed portal rejected before bootstrap reset")
				var layout := {"kind":"layout","routes":bad.routes,"spawnPortalId":bad.spawnPortalId}
				check(not runtime.process_command({"epoch":1,"sequence":1,"commands":[layout]}).accepted and runtime.sequence == 0,"malformed named layout portal rejected before mutation")

func _shipped_boundary(catalog) -> void:
	var legacy: Dictionary = catalog._data.duplicate(true)
	legacy.erase("schedulingPolicy")
	for stage in legacy.stages:
		for wave in stage.waves: wave.erase("groupDispatch")
	var path := "user://legacy-catalog-boundary.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var reader = Catalog.new()
	check(not reader.load_catalog(path),"shipped loader cannot silently omit authoritative dispatch metadata")
	DirAccess.remove_absolute(path)
	var fixture: Dictionary = catalog.domain_snapshot()
	fixture.erase("schedulingPolicy")
	for stage in fixture.stages:
		for wave in stage.waves: wave.erase("groupDispatch")
	check(reader.load_fixture_content(fixture),"explicit legacy fixture loading stays compatible: " + reader.error)

func _signature_compatibility(catalog) -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/chapter_three_map_signature_baseline.json"))
	check(baseline.stages.size() == 30,"all pre-architecture map signatures covered")
	for row in baseline.stages:
		var map: Dictionary = catalog.stage_map(catalog.stage_index(int(row.stageId)))
		check(SaveProjection.map_signature(map,map.path).sha256_text() == row.signatureSha256,"geometric save signature unchanged stage " + str(row.stageId))
		var portals: Array = catalog.spawn_portals(catalog.stage_index(int(row.stageId)))
		var original: Array = portals.duplicate(true)
		portals[0].cell[0] = -99
		check(catalog.spawn_portals(catalog.stage_index(int(row.stageId))) == original,"portal APIs own returned coordinates")

func _dispatch(catalog) -> void:
	for stage in range(catalog.stage_count()):
		var source: Dictionary = catalog.stage(stage)
		var map: Dictionary = source.map
		var legacy: bool = int(source.id) <= 25
		var bootstrap: Dictionary = catalog.bootstrap(stage)
		check(bootstrap.has("spawnPortalId") != legacy,"legacy bootstrap keeps implicit portal " + str(source.id))
		if legacy:
			check(not catalog.enemy(stage,0,"normal").has("spawnPortalId"),"legacy enemy metadata unchanged")
			check(catalog.spawn_portal(stage).id == "default" and catalog.spawn_portal(stage).cell == map.path[0],"legacy portal derived without source/save changes")
		for round_index in range(catalog.wave_count(stage)):
			var wave: Dictionary = source.waves[round_index]
			var summary: Dictionary = catalog.wave_summary(stage,round_index)
			var rows: Array = wave.groupDispatch
			check(summary.routeGroups.size() == rows.size(),"summary consumes every compiled group")
			var previous := -INF
			var seen := {}
			for index in range(rows.size()):
				var row: Dictionary = rows[index]
				var shown: Dictionary = summary.routeGroups[index]
				check(not seen.has(row.groupId),"stable unique group identity")
				seen[row.groupId] = true
				for key in row: check(shown[key] == row[key],"summary forwards compiled " + key)
				check(shown.spawnDelay == row.firstDispatch and row.firstDispatch >= previous,"compiled chronological dispatch order used directly")
				previous = row.firstDispatch
				check(row.spawnPortalId == catalog.spawn_portal(stage,row.routeId).id,"group portal derived from authored route")
				check(row.spawnIndices.size() == row.count,"compiled dispatch membership count")
				check(wave.spawnQueue[row.spawnIndices[0]].delay == row.firstDispatch and wave.spawnQueue[row.spawnIndices[-1]].delay == row.lastDispatch,"compiled first/last matches authoritative queue")
func _checkpoint(catalog,growth,stage_id: int) -> void:
	var stage: int = catalog.stage_index(stage_id)
	var map: Dictionary = catalog.stage_map(stage)
	var service = Commands.new(catalog,growth)
	var adapter = Adapter.new(catalog,growth)
	var state: Dictionary = service.initial_state({"coreCombatSkill":null},stage)
	state.phase = "wave"
	state.roundIndex = 21
	state.completedRounds = 21
	var route_id: String = map.routes[-1].id if map.has("routes") else ""
	var portal: Dictionary = catalog.spawn_portal(stage,route_id)
	var bootstrap: Dictionary = catalog.bootstrap(stage,{"defenseConfig":service.derived(state).defenseConfig})
	bootstrap.wave = catalog.wave(stage,21)
	var enemy: Dictionary = catalog.enemy(stage,21,"normal",99999,{"routeId":route_id})
	enemy.spawnPortalId = "stale-save-or-caller-value"
	enemy.distanceTravelled = 1.25
	for key in ["x","y","position","targetIndex","facingAngle"]: enemy.erase(key)
	bootstrap.enemies = [enemy]
	var runtime = Runtime.new()
	check(runtime.process_command({"epoch":1,"sequence":0,"bootstrap":bootstrap,"session":{"clock":"godot","phase":"wave","paused":true}}).accepted,"explicit portal bootstrap")
	check(runtime.enemies["99999"].spawnPortalId == portal.id,"runtime derives portal instead of trusting stale enemy copy")
	runtime.process_command({"epoch":1,"sequence":1,"ackEvent":runtime.event_id})
	var saved: Dictionary = adapter.capture(state,runtime.snapshot(),123)
	check(not saved.is_empty(),"portal save captures: " + adapter.error)
	if saved.is_empty(): return
	check(not saved.activeRun.enemies[0].has("spawnPortalId"),"live portal not duplicated in persisted schema")
	for entry in saved.activeRun.spawnQueue: check(not entry.has("spawnPortalId"),"pending portal derived, not separately persisted")
	var hash_before: String = Hash.hash_payload(saved)
	var prepared: Dictionary = adapter.prepare(saved)
	check(not prepared.is_empty(),"portal restore prepares: " + adapter.error)
	if prepared.is_empty(): return
	check(Hash.hash_payload(saved) == hash_before,"restore never mutates canonical input save")
	check(prepared.bootstrap.enemies[0].spawnPortalId == portal.id,"restored live portal derived from retained route")
	for request in prepared.bootstrap.wave.spawnQueue:
		check(request.enemy.spawnPortalId == catalog.spawn_portal(stage,request.get("routeId", "")).id,"restored pending portal derives from its route")
	var resumed = Runtime.new()
	resumed.process_command({"epoch":2,"sequence":0,"bootstrap":prepared.bootstrap,"session":prepared.session})
	var before: Dictionary = resumed.snapshot()
	check(not resumed.advance_session(1.0) and resumed.snapshot().enemies == before.enemies,"paused restored route never advances")
	resumed.process_command({"epoch":2,"sequence":1,"session":{"paused":false}})
	resumed.advance_session(0.1)
	check(resumed.enemies["100000"].spawnPortalId == portal.id and resumed.enemies["100000"].get("routeId", "") == route_id,"resume keeps route and derived portal")
	check(resumed.enemies["100000"].distanceTravelled > 1.25,"resumed enemy moves normally")
	if stage_id == 28:
		check(catalog.spawn_portal(stage,map.routes[0].id).id == portal.id,"split routes explicitly share one portal")
	if stage_id == 30:
		check(catalog.spawn_portal(stage,map.routes[0].id).id != portal.id,"dual routes explicitly use separate portals")
