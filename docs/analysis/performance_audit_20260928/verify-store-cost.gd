extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const ITERATIONS := 20
const BATCHES := 5
const Store = preload("res://app/local_save_store.gd")
class TimedStore extends Store:
	var read_us := 0
	var write_us := 0
	var writes := 0
	func _read_valid(path: String, legacy_only: bool = false) -> Dictionary:
		var started := Time.get_ticks_usec()
		var result := super._read_valid(path,legacy_only)
		read_us += Time.get_ticks_usec()-started
		return result
	func _write_atomic(path: String, contents: String) -> Error:
		var started := Time.get_ticks_usec()
		var result := super._write_atomic(path,contents)
		write_us += Time.get_ticks_usec()-started
		writes += 1
		return result
func _initialize() -> void:
	var catalog := Catalog.new()
	var growth := Growth.new()
	assert(catalog.load_catalog() and growth.load_catalog())
	var current := Adapter.new(catalog,growth)
	var commands := Commands.new(catalog,growth)
	var state: Dictionary = commands.initial_state({"unlockedStageCount":15},14)
	state.gold = 1000000
	var source: Dictionary = catalog.stage(14)
	for cell in range(source.map.tiles.size()):
		if source.map.tiles[cell] != "build": continue
		var result: Dictionary = commands.apply(state,{"kind":"build","type":"arrow" if state.turrets.is_empty() else "cannon","x":cell % int(source.map.columns),"y":cell / int(source.map.columns)})
		assert(result.ok)
		state = result.state
		if state.turrets.size() == 2: break
	var round_index := 0
	for index in range(source.waves.size()):
		if source.waves[index].spawnQueue.size() > source.waves[round_index].spawnQueue.size(): round_index = index
	state.roundIndex = round_index
	state.completedRounds = round_index
	state.phase = "wave"
	var inputs: Dictionary = {"defenseConfig":commands.derived(state).defenseConfig,"coreConfig":growth.core_config(state,14,round_index,catalog)}
	var bootstrap := catalog.bootstrap(14,inputs)
	bootstrap.turrets = []
	for command in commands.runtime_commands(state): bootstrap.turrets.append(command.turret)
	bootstrap.wave = catalog.wave(14,round_index)
	bootstrap.enemies = []
	for index in range(12): bootstrap.enemies.append(catalog.enemy(14,round_index,"normal",90000+index))
	var runtime := Runtime.new()
	runtime.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","paused":true},"bootstrap":bootstrap})
	runtime.process_command({"epoch":1,"sequence":1,"ackEvent":runtime.event_id})
	var snapshot := runtime.snapshot()
	var saved := current.capture(state,snapshot,123)
	assert(not saved.is_empty())
	var store := TimedStore.new("user://performance-audit-"+str(Time.get_ticks_usec()))
	assert(store.save_save(saved) == OK)
	var batches := []
	for batch in range(BATCHES):
		store.read_us = 0; store.write_us = 0; store.writes = 0
		var started := Time.get_ticks_usec()
		for index in range(ITERATIONS):
			saved.savedAtMillis += 1
			assert(store.save_save(saved) == OK,store.last_error_message)
		var total := Time.get_ticks_usec()-started
		batches.append({"totalMs":total/float(ITERATIONS)/1000.0,"readValidateMs":store.read_us/float(ITERATIONS)/1000.0,"atomicWriteMs":store.write_us/float(ITERATIONS)/1000.0,"otherMs":(total-store.read_us-store.write_us)/float(ITERATIONS)/1000.0,"writesPerSave":store.writes/float(ITERATIONS)})
	var result := {"stage":15,"turrets":2,"enemies":12,"pending":snapshot.wave.spawnQueue.size(),"bytes":JSON.stringify(saved,"",false,true).length(),"iterationsPerBatch":ITERATIONS,"batches":batches,"scope":"isolated desktop headless synchronous store only; capture excluded; wall timing includes OS filesystem cache"}
	print(JSON.stringify(result))
	FileAccess.open("/Users/sejin/Documents/Codex/RuneNexus/docs/analysis/performance_audit_20260928/store-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	assert(store.clear() == OK)
	quit()
