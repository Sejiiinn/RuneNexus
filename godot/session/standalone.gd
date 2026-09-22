extends Node
## Migration smoke application; production account/economy remain separate.
## Actual content is the default. The old fixture is an explicit save regression mode.
const Catalog = preload("res://content/content_catalog.gd")
var content_enabled := true
var progression_inputs: Dictionary = {}
var run_domain = preload("res://session/run_session.gd").new()
var run_controls
var applying_events := false
var next_research_check := 0
var next_terminal_save := 0
var reward_worker
var catalog = Catalog.new()
var battle_inputs: Dictionary = {}
var turret_inputs: Dictionary = {}
var turret_type := "arrow"
var next_round := 0
var next_enemy_id := 100000
var spawn_rng := RandomNumberGenerator.new()
var turret_button: Button
var wave_button: Button
var scene: Node3D
var fixture: Dictionary
var stage := 0
var epoch := 1000
var selected := Vector2i(-1, -1)
var status: Label
var panel: HFlowContainer
var next_id := 1
var checkpoint = preload("res://session/session_checkpoint.gd").new()

func _ready() -> void:
	scene = get_parent()
	scene.options.presentation_groups = ["labels","effects","selection"]
	if "--session-fixture" in OS.get_cmdline_user_args(): content_enabled = false
	if not content_enabled:
		fixture = JSON.parse_string(FileAccess.get_file_as_string("res://session/standalone_fixture.json"))
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	panel = HFlowContainer.new()
	panel.size.x = get_viewport().get_visible_rect().size.x - 24.0
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	for spec in [["Stage", enter_next], ["Build", build_selected], ["Start", start_wave], ["Pause", toggle_pause], ["1x/4x", toggle_speed], ["Camera", toggle_camera], ["Save", save_session], ["Load", load_session], ["Exit", exit_stage]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		panel.add_child(button)
	if content_enabled:
		turret_button = Button.new()
		turret_button.text = "Tower: arrow"
		turret_button.pressed.connect(cycle_turret)
		panel.add_child(turret_button)
		wave_button = Button.new()
		wave_button.text = "Wave +"
		wave_button.pressed.connect(cycle_wave)
		panel.add_child(wave_button)
	status = Label.new()
	status.position = Vector2(14, 54)
	status.size.x = get_viewport().get_visible_rect().size.x - 28.0
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)
	if content_enabled and not catalog.load_catalog():
		checkpoint.message = catalog.error
		return
	enter_stage(0)
	if content_enabled:
		run_controls = load("res://session/run_controls.gd").new()
		run_controls.app = self
		layer.add_child(run_controls)

func stage_count() -> int:
	return catalog.stage_count() if content_enabled else fixture.stages.size()

func stage_source(index: int) -> Dictionary:
	return catalog.stage(index) if content_enabled else fixture.stages[index]

func prepare_run_transition() -> bool:
	if not content_enabled or run_domain.state.is_empty(): return true
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
	if content_enabled and not run_domain.state.is_empty():
		progression_inputs = run_domain.state.progression.duplicate(true)
	enter_stage(stage)
	return true

func cycle_turret() -> void:
	if catalog.stage_count() == 0: return
	var types: Array = catalog.data.turrets.keys()
	turret_type = types[(types.find(turret_type) + 1) % types.size()]
	turret_button.text = "Tower: " + turret_type
	if selected.x >= 0: board_tap(selected)

func cycle_wave() -> void:
	if not scene._native_combat.active or scene._native_combat.wave.active: return
	if run_domain.state.get("phase") != "preparation": return
	var total: int = stage_source(stage).waves.size()
	var completed: int = run_domain.state.get("completedRounds", 0)
	if completed >= total: return
	next_round = completed + (next_round - completed + 1) % (total - completed)


func enter_stage(index: int, bootstrap: Dictionary = {}, session_state: Dictionary = {}, restored_state: Dictionary = {}) -> void:
	if index < 0 or index >= stage_count(): return
	stage = index
	next_round = 0
	next_enemy_id = 100000
	epoch += 1
	next_id = 1
	selected = Vector2i(-1, -1)
	checkpoint.message = ""
	scene._apply_frame({"reset":true,"sceneEpoch":epoch})
	var source: Dictionary = stage_source(stage)
	var frame := {"seq":0,"sceneEpoch":epoch,"mapRevision":stage,"map":source.map.duplicate(true),"time":0.0,"turrets":[],"enemies":[],"projectiles":[],"impacts":[],"presentation":{"effects":{},"labels":{}}}
	scene._apply_frame(frame)
	scene._native_combat_base_frame = frame
	var initial := {"path":source.path,"tileSize":1.0,"boardDistanceScale":1.0/48.0,"defense":{"config":{"maxHp":100.0}}}
	if content_enabled:
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
	if content_enabled and not applying_events:
		applying_events = true
		var collected: Dictionary = run_domain.collect(scene._native_combat)
		before = collected.get("commands", [])
		applying_events = false
		if not collected.get("ok", false):
			checkpoint.message = run_domain.error
			return false
	var packet := {"epoch":epoch,"sequence":scene._native_combat.sequence+1,"commands":before+commands,"session":patch}
	if content_enabled:
		packet.ackEvent = run_domain.event_ack
		if not patch.has("phase") and not run_domain.state.is_empty(): packet.session.phase = run_domain.state.phase
	else:
		packet.ackEvent = scene._native_combat.event_id
	scene._native_combat.process_command(packet, false)
	return true

func apply_run_command(request: Dictionary) -> bool:
	if not content_enabled or not scene._native_combat.active: return false
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
	if not content_enabled or run_domain.state.is_empty() or not scene._native_combat.active: return false
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
	if content_enabled:
		apply_run_command({"kind":"build","x":selected.x,"y":selected.y,"type":turret_type})
		return
	var map: Dictionary = stage_source(stage).map
	if selected.x >= int(map.columns) or selected.y < 0 or selected.y >= int(map.rows): return
	if map.tiles[selected.y * int(map.columns) + selected.x] != "build": return
	var runtime = scene._native_combat
	var position := [runtime.origin.x + (selected.x + 0.5) * runtime.tile_size, runtime.origin.y + (selected.y + 0.5) * runtime.tile_size]
	for turret in scene._native_combat.turrets.values():
		if turret.position == position: return
	var stats: Dictionary
	if content_enabled:
		var inputs := turret_inputs.duplicate(true)
		inputs.tileSize = runtime.tile_size
		stats = catalog.turret(turret_type, inputs)
		if stats.is_empty():
			checkpoint.message = catalog.error
			return
	else:
		stats = fixture.turret.duplicate(true)
		stats.boardDistanceScale = 1.0 / 48.0
	command([{"kind":"turret","turret":{"id":next_id,"position":position,"statInput":stats,"state":{"x":selected.x,"y":selected.y}}}])
	next_id += 1
	scene._native_combat_base_frame.buildPreview = null

func start_wave() -> void:
	if not scene._native_combat.active or scene._native_combat.defense.failed: return
	if scene._native_combat.wave.active: return
	if content_enabled:
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
	var path: Array = fixture.stages[stage].path
	var queue: Array = []
	for index in range(12):
		queue.append({"delay":index*0.6,"enemyType":"normal","enemy":checkpoint.enemy_configuration(path,index+1)})
	if scene._native_combat.wave.active: return
	command([{"kind":"waveStart","wave":{"id":scene._native_combat.wave.id+1,"active":true,"spawnQueue":queue}}],{"phase":"wave","paused":false})

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
	if content_enabled and scene._native_combat.active:
		if checkpoint.save_session(self) != OK: return
	epoch += 1
	scene._apply_frame({"reset":true,"sceneEpoch":epoch})

func _process(_delta: float) -> void:
	var runtime = scene._native_combat
	if content_enabled and runtime.active and not run_domain.state.is_empty() and Time.get_ticks_msec() >= next_research_check:
		next_research_check = Time.get_ticks_msec() + 1000
		if not run_domain.state.progression.get("activeResearches", []).is_empty():
			var now := int(Time.get_unix_time_from_system() * 1000)
			for research in run_domain.state.progression.activeResearches:
				if now >= int(research.startedAtMillis) + int(research.durationMillis):
					apply_growth_command({"type":"completeFinishedResearches","nowMillis":now})
					break
	if content_enabled and runtime.active and not run_domain.state.is_empty():
		if runtime.event_id > run_domain.event_ack or runtime.session.get("phase") != run_domain.state.phase:
			command()
		if run_domain.is_finished() and checkpoint.queued_run_id != str(run_domain.state.economyRunId) and Time.get_ticks_msec() >= next_terminal_save:
			next_terminal_save = Time.get_ticks_msec() + 1000
			checkpoint.save_session(self)
	# The standalone diagnostic label is hidden in the app. Domain work above still runs.
	if not status.is_visible_in_tree(): return
	status.text = "Stage %d | %s | %.1fs | HP %.1f | selected %s" % [stage+1, runtime.session.get("phase","ended"),runtime.clock,runtime.defense.hp,selected] + " | " + checkpoint.message
	if content_enabled:
		var following := str(next_round + 1) if catalog.stage_count() > stage and next_round < catalog.data.stages[stage].waves.size() else "done"
		status.text = "Stage %d | Wave %d | %s | HP %.1f | next %s | %s" % [stage+1, runtime.wave.id, runtime.session.get("phase", "ended"), runtime.defense.hp, following, turret_type]
		if not run_domain.state.is_empty():
			status.text += "\nGold %d | Shards %d | run commands active; local v2 save" % [run_domain.state.gold, run_domain.state.gemShards]
		if not checkpoint.message.is_empty(): status.text += "\n" + checkpoint.message
