extends Node
## Shared content session orchestration; app and development UI own their lifecycle.
const Catalog = preload("res://content/content_catalog.gd")
var progression_inputs: Dictionary = {}
var run_domain = preload("res://session/run_session.gd").new()
var applying_events := false
var next_research_check := 0
var next_terminal_save := 0
var reward_worker
var catalog = Catalog.new()
var battle_inputs: Dictionary = {}
var turret_type := "arrow"
var next_round := 0
var next_enemy_id := 100000
var spawn_rng := RandomNumberGenerator.new()
var scene: Node3D
var stage := 0
var epoch := 1000
var selected := Vector2i(-1, -1)
var checkpoint = preload("res://session/session_checkpoint.gd").new()

func is_content_session() -> bool:
	return true

func stage_count() -> int:
	return catalog.stage_count()

func stage_source(index: int) -> Dictionary:
	return catalog.stage(index)

func prepare_run_transition() -> bool:
	if not is_content_session() or run_domain.state.is_empty(): return true
	if not scene._native_combat.active:
		checkpoint.message = "Load the saved run before replacing it"
		return false
	if not command(): return false
	var previous: Dictionary = run_domain.state.duplicate(true)
	var abandoning: bool = not run_domain.is_finished()
	if abandoning:
		run_domain.finish(false)
		run_domain.state.phase = "failure"
	var terminal: Dictionary = run_domain.state.duplicate(true)
	run_domain.state = previous
	# Both durable writes precede scene replacement. On failure the live run stays.
	if checkpoint.persist_state(self, terminal, abandoning) != OK: return false
	run_domain.state = terminal
	progression_inputs = terminal.progression.duplicate(true)
	return true

func _can_replace_run() -> bool:
	return prepare_run_transition()

func settle_pending_rewards(context: Dictionary, sync_save: Callable, transport: Callable = Callable()) -> Dictionary:
	var bound_checkpoint = checkpoint
	var queue = checkpoint.rewards()
	if not queue.loaded: return {"ok":false,"code":"OUTBOX_READ_FAILED"}
	if reward_worker == null or reward_worker.outbox != queue:
		if reward_worker != null:
			reward_worker.invalidate_binding()
			if not reward_worker.busy: reward_worker.queue_free()
		reward_worker = load("res://app/reward_settlement.gd").new(queue)
		add_child(reward_worker)
	var apply_snapshot := func(snapshot: Dictionary) -> bool:
		if checkpoint != bound_checkpoint: return false
		return bound_checkpoint.apply_economy_snapshot(self, snapshot)
	return await reward_worker.settle_next(context, sync_save, apply_snapshot, transport)

func enter_next() -> void:
	if stage_count() > 0 and _can_replace_run(): enter_stage((stage + 1) % stage_count())

func retry_stage() -> bool:
	if not _can_replace_run(): return false
	if is_content_session() and not run_domain.state.is_empty():
		progression_inputs = run_domain.state.progression.duplicate(true)
	enter_stage(stage)
	return true

func enter_stage(index: int, bootstrap: Dictionary = {}, session_state: Dictionary = {}, restored_state: Dictionary = {}) -> void:
	if index < 0 or index >= stage_count(): return
	stage = index
	next_round = 0
	next_enemy_id = 100000
	epoch += 1
	selected = Vector2i(-1, -1)
	checkpoint.message = ""
	scene._apply_frame({"reset":true,"sceneEpoch":epoch})
	var source: Dictionary = stage_source(stage)
	var frame := {"seq":0,"sceneEpoch":epoch,"mapRevision":stage,"map":source.map.duplicate(true),"time":0.0,"turrets":[],"enemies":[],"projectiles":[],"impacts":[],"presentation":{"effects":{},"labels":{}}}
	scene._apply_frame(frame)
	scene._native_combat_base_frame = frame
	var initial := {"path":source.path,"tileSize":1.0,"boardDistanceScale":1.0/48.0,"defense":{"config":{"maxHp":100.0}}}
	if is_content_session():
		if not run_domain.initialize(catalog, progression_inputs, stage, epoch):
			checkpoint.message = run_domain.error
			return
		if not restored_state.is_empty():
			run_domain.restore(restored_state)
			progression_inputs = run_domain.state.progression.duplicate(true)
		var inputs := battle_inputs.duplicate(true)
		inputs.defenseConfig = run_domain.growth.derive(run_domain.state.progression).defenseConfig
		inputs.coreConfig = run_domain.growth.core_config(run_domain.state, stage, 0, catalog)
		initial = catalog.bootstrap(stage, inputs)
		if initial.is_empty():
			checkpoint.message = catalog.error
			return
	initial.merge(bootstrap, true)
	var control := {"clock":"godot","phase":"preparation","paused":false,"speed":1.0}
	control.merge(session_state, true)
	scene._native_combat.process_command({"epoch":epoch,"sequence":0,"session":control,"bootstrap":initial})

func command(commands: Array = [], patch: Dictionary = {}) -> bool:
	var before: Array = []
	if is_content_session() and not applying_events:
		applying_events = true
		var collected: Dictionary = run_domain.collect(scene._native_combat)
		before = collected.get("commands", [])
		applying_events = false
		if not collected.get("ok", false):
			checkpoint.message = run_domain.error
			return false
	var packet := {"epoch":epoch,"sequence":scene._native_combat.sequence+1,"commands":before+commands,"session":patch}
	if is_content_session():
		packet.ackEvent = run_domain.event_ack
		if not patch.has("phase") and not run_domain.state.is_empty(): packet.session.phase = run_domain.state.phase
	else:
		packet.ackEvent = scene._native_combat.event_id
	scene._native_combat.process_command(packet, false)
	return true

func apply_run_command(request: Dictionary) -> bool:
	if not is_content_session() or not scene._native_combat.active: return false
	# Settle newly observed events before checking affordability/phase.
	if not command(): return false
	var result: Dictionary = run_domain.apply(request)
	if not result.get("ok", false):
		checkpoint.message = run_domain.error
		return false
	command(result.get("commands", []), {"phase":run_domain.state.phase})
	checkpoint.message = ""
	scene._native_combat_base_frame.buildPreview = null
	return true

func selected_run_command(kind: String, values: Dictionary = {}) -> bool:
	var request := {"kind":kind,"id":run_domain.selected_id(selected)}
	request.merge(values, true)
	return apply_run_command(request)

func apply_growth_command(request: Dictionary) -> bool:
	if not is_content_session() or run_domain.state.is_empty() or not scene._native_combat.active: return false
	if not command(): return false
	var result: Dictionary = run_domain.growth.execute(run_domain.state.progression, request)
	if not result.get("ok", false):
		checkpoint.message = str(result.get("error", "Growth rejected"))
		return false
	run_domain.state.progression = result.state
	progression_inputs = result.state.duplicate(true)
	# Refresh all placed turrets through the same domain/configuration path.
	var refresh: Dictionary = run_domain.service.refresh(run_domain.state)
	run_domain.state = refresh.state
	var effects: Dictionary = run_domain.growth.derive(run_domain.state.progression)
	var updates: Array = refresh.get("commands", [])
	updates.append({"kind":"defenseConfig","config":effects.defenseConfig})
	updates.append({"kind":"coreConfig","config":run_domain.growth.core_config(run_domain.state, stage, int(run_domain.state.roundIndex), catalog)})
	command(updates)
	checkpoint.message = ""
	return true

func board_tap(tile: Vector2i) -> void:
	selected = tile
	if tile.x < 0:
		scene._native_combat_base_frame.buildPreview = null
		return
	scene._native_combat_base_frame.buildPreview = [-1,tile.x + 0.5,tile.y + 0.5,0,0,0,turret_type]

func build_selected() -> void:
	if selected.x < 0 or not scene._native_combat.active: return
	apply_run_command({"kind":"build","x":selected.x,"y":selected.y,"type":turret_type})

func start_wave() -> void:
	if not scene._native_combat.active or scene._native_combat.defense.failed: return
	if scene._native_combat.wave.active: return
	if not command(): return
	if run_domain.state.get("phase") != "preparation": return
	if next_round >= stage_source(stage).waves.size():
		checkpoint.message = "All content waves complete"
		return
	var inputs := battle_inputs.duplicate(true)
	if not inputs.has("initialDelay"):
		inputs.initialDelay = catalog.data.defaults.initialDelay * float(scene._native_combat.session.get("speed", 1.0))
	if not inputs.has("spawnValues"):
		inputs.spawnValues = catalog.random_spawn_values(stage, next_round, spawn_rng)
	var wave: Dictionary = catalog.wave(stage, next_round, next_enemy_id, inputs)
	if wave.is_empty():
		checkpoint.message = catalog.error
		return
	wave.coreConfig = run_domain.growth.core_config(run_domain.state, stage, next_round, catalog)
	next_enemy_id += wave.spawnQueue.size()
	run_domain.state.phase = "wave"
	run_domain.state.roundIndex = next_round
	command([{"kind":"waveStart","wave":wave}], {"phase":"wave","paused":false})
	next_round += 1
	return

func toggle_pause() -> void:
	if not scene._native_combat.active: return
	command([], {"paused":not bool(scene._native_combat.session.get("paused",false))})

func toggle_speed() -> void:
	if not scene._native_combat.active: return
	command([], {"speed":4.0 if float(scene._native_combat.session.get("speed",1)) == 1 else 1.0})

func toggle_camera() -> void:
	scene.options.camera = "drone" if scene.options.camera == "angled" else "angled"
	scene._apply_options()

func save_session() -> void:
	checkpoint.save_session(self)

func load_session() -> void:
	checkpoint.load_session(self)

func exit_stage() -> void:
	if is_content_session() and scene._native_combat.active:
		if checkpoint.save_session(self) != OK: return
	epoch += 1
	scene._apply_frame({"reset":true,"sceneEpoch":epoch})

func _process(_delta: float) -> void:
	var runtime = scene._native_combat
	if is_content_session() and runtime.active and not run_domain.state.is_empty() and Time.get_ticks_msec() >= next_research_check:
		next_research_check = Time.get_ticks_msec() + 1000
		if not run_domain.state.progression.get("activeResearches", []).is_empty():
			var now := int(Time.get_unix_time_from_system() * 1000)
			for research in run_domain.state.progression.activeResearches:
				if now >= int(research.startedAtMillis) + int(research.durationMillis):
					apply_growth_command({"type":"completeFinishedResearches","nowMillis":now})
					break
	if is_content_session() and runtime.active and not run_domain.state.is_empty():
		if runtime.event_id > run_domain.event_ack or runtime.session.get("phase") != run_domain.state.phase:
			command()
		if run_domain.is_finished() and checkpoint.queued_run_id != str(run_domain.state.economyRunId) and Time.get_ticks_msec() >= next_terminal_save:
			next_terminal_save = Time.get_ticks_msec() + 1000
			checkpoint.save_session(self)
