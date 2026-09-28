extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const OldCatalog = preload("res://benchmark-old-catalog.gd")
const Adapter = preload("res://app/content_run_save.gd")
const OldAdapter = preload("res://benchmark-old-save.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const ITERATIONS := 40
const BATCHES := 7
func _initialize() -> void:
	var catalog := Catalog.new()
	var old_catalog := OldCatalog.new()
	var growth := Growth.new()
	assert(catalog.load_catalog() and old_catalog.load_catalog() and growth.load_catalog())
	var current := Adapter.new(catalog,growth)
	var previous := OldAdapter.new(old_catalog,growth)
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
	var before := state.duplicate(true)
	var saved_before := previous.capture(state,snapshot,123)
	var saved_after := current.capture(state,snapshot,123)
	assert(not saved_before.is_empty(),previous.error)
	assert(saved_before == saved_after,current.error)
	assert(before == state)
	for index in range(10):
		previous.capture(state,snapshot,123)
		current.capture(state,snapshot,123)
	var old_batches := []
	var new_batches := []
	for batch in range(BATCHES):
		for kind in ([0,1] if batch % 2 == 0 else [1,0]):
			var adapter = previous if kind == 0 else current
			var started := Time.get_ticks_usec()
			for index in range(ITERATIONS):
				var result: Dictionary = adapter.capture(state,snapshot,123)
				assert(not result.is_empty(),adapter.error)
			var duration := float(Time.get_ticks_usec()-started)/ITERATIONS
			if kind == 0: old_batches.append(duration)
			else: new_batches.append(duration)
	var old_sorted := old_batches.duplicate(); old_sorted.sort()
	var new_sorted := new_batches.duplicate(); new_sorted.sort()
	print(JSON.stringify({"scope":"headless desktop capture CPU only; no disk write, GPU, FPS or Android measurement","stage":15,"roundIndex":round_index,"turrets":state.turrets.size(),"liveEnemies":snapshot.enemies.size(),"pendingSpawns":snapshot.wave.spawnQueue.size(),"iterationsPerBatch":ITERATIONS,"batches":BATCHES,"baseline":"717f881f content_run_save + content_catalog","beforeUsecPerCapture":old_batches,"afterUsecPerCapture":new_batches,"medianBeforeUsec":old_sorted[BATCHES/2],"medianAfterUsec":new_sorted[BATCHES/2],"ratio":new_sorted[BATCHES/2]/old_sorted[BATCHES/2],"sameEnvelope":saved_before==saved_after,"stateUnchanged":before==state}))
	quit()
