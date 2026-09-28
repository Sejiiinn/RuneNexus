extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Current = preload("res://audit-current-session.gd")
const Baseline = preload("res://audit-baseline-session.gd")
func make_session(script, catalog, module_count: int):
	var session = script.new()
	session.now_millis = func(): return 1720000000000
	if not session.initialize(catalog,{},0,7): push_error(session.error); return null
	session.state.economyRunId = "damage-copy-benchmark"
	# Synthetic retained inventory controls nested-copy load; no equipment changes.
	session.state.progression.turretModules = {"tickets":0,"items":[]}
	for index in range(module_count):
		session.state.progression.turretModules.items.append({"id":"module-"+str(index),"type":"arrow","level":1,"options":[{"type":"damage","value":0.01},{"type":"range","value":0.01}]})
	return session
func sample(script, catalog, traces: Array, module_count: int) -> Dictionary:
	var session = make_session(script,catalog,module_count)
	if session == null: return {}
	var original: Dictionary = session.state.duplicate(true)
	var duration := 0
	for cycle in range(20):
		session.state = original.duplicate(true)
		session.event_ack = 0
		session.collected_wall_time = 0
		session.quests._play_time_remainder = 0
		var started := Time.get_ticks_usec()
		for frame in traces:
			var result: Dictionary = session.collect(frame)
			if not result.ok: push_error(session.error); return {}
		duration += Time.get_ticks_usec()-started
	return {"usec":duration,"collects":20*traces.size(),"deepCopies":session.audit_deep_copies,"state":session.state,"ack":session.event_ack,"remainder":session.quests._play_time_remainder}
func _initialize() -> void:
	var catalog := Catalog.new()
	if not catalog.load_catalog(): push_error(catalog.error); quit(1); return
	var runtime := Runtime.new()
	var setup := {"enemies":[],"turrets":[]}
	for index in range(40):
		var enemy: Dictionary = catalog.enemy(0,0,"normal",1000+index)
		enemy.x = 100.0+index; enemy.y = 100.0; enemy.path=[]
		enemy.hp = 1000000.0; enemy.maxHp = 1000000.0
		enemy.burnInstances=[{"remaining":10.0,"damagePerSecond":1.0,"damageMultiplier":1.0,"sourceX":0,"sourceY":0,"ignoreArmorReduction":false}]
		setup.enemies.append(enemy)
	runtime.process_command({"epoch":7,"sequence":0,"running":true,"bootstrap":setup},false)
	var traces := []
	var counts := {}
	for frame in range(60):
		runtime._step(1.0/60.0)
		for event in runtime.events: counts[event.kind] = int(counts.get(event.kind,0))+1
		traces.append({"epoch":7,"wall_elapsed":float(frame+1)/60.0,"events":runtime.events.duplicate(true),"enemies":{},"defense":{"hp":100},"session":{"phase":"wave"}})
		runtime.events.clear()
	var reports := []
	for inventory in [0,200]:
		var old_times := []
		var new_times := []
		var before := {}
		var after := {}
		for batch in range(5):
			if batch % 2 == 0:
				before = sample(Baseline,catalog,traces,inventory)
				after = sample(Current,catalog,traces,inventory)
			else:
				after = sample(Current,catalog,traces,inventory)
				before = sample(Baseline,catalog,traces,inventory)
			if before.is_empty() or after.is_empty(): quit(1); return
			if before.state != after.state or before.ack != after.ack or before.remainder != after.remainder: push_error("baseline mismatch"); quit(1); return
			old_times.append(float(before.usec)/before.collects)
			new_times.append(float(after.usec)/after.collects)
		var old_sorted := old_times.duplicate(); old_sorted.sort()
		var new_sorted := new_times.duplicate(); new_sorted.sort()
		reports.append({"syntheticInventoryItems":inventory,"eventTrace":counts,"collectsPerBatch":before.collects,"beforeMeanUsec":old_times,"afterMeanUsec":new_times,"medianBeforeUsec":old_sorted[2],"medianAfterUsec":new_sorted[2],"deepCopiesBefore":before.deepCopies,"deepCopiesAfter":after.deepCopies,"stateAckRemainderEqual":true})
	print(JSON.stringify({"scope":"desktop headless collect CPU only, not combat/FPS/GPU/disk/Android; exact real 40-enemy burn event trace replayed","reports":reports}))
	quit()
