extends Node
const StageProgression = preload("res://content/stage_progression.gd")
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

## How the battlefield treats board touches. A controller with screens over the
## board (lobby, HUD modals) overrides this; the development session accepts all.
enum BoardInput { ACCEPT, IGNORE, CANCEL_CONTACTS }
func board_input_policy() -> BoardInput:
	return BoardInput.ACCEPT

## Viewport rect the camera fits the board into; empty uses the whole viewport.
func battlefield_rect() -> Rect2:
	return Rect2()

## Re-applies screen visibility after app gates change. Development has none.
func refresh_ui() -> void:
	pass

func stage_count() -> int:
	return catalog.stage_count()

func stage_source(index: int) -> Dictionary:
	return catalog.stage(index)

func stage_map(index: int) -> Dictionary:
	return catalog.stage_map(index) if is_content_session() else stage_source(index).map.duplicate(true)

func wave_count(index: int) -> int:
	return catalog.wave_count(index) if is_content_session() else stage_source(index).waves.size()

func prepare_run_transition() -> bool:
	if not is_content_session() or run_domain.state.is_empty(): return true
	if not scene.combat_runtime.active:
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
	# A slot-local journal commits both resources or restores the resumable run.
	if checkpoint.persist_state(self, terminal, abandoning, previous) != OK: return false
	run_domain.state = terminal
	progression_inputs = terminal.progression.duplicate(true)
	if abandoning:
		# Commit the live cancellation only after both checkpoint and outbox succeed.
		# Otherwise a later save would capture failure with the old spawn schedule.
		command([{"kind":"waveCancel"}], {"phase":terminal.phase,"paused":true})
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
	if stage_count() <= 0 or not _can_replace_run(): return
	if is_content_session():
		var ordinal := StageProgression.ordinal_for(catalog.stage_id(stage))
		if ordinal > 0 and ordinal < StageProgression.ORDER.size(): enter_stage(catalog.stage_index(int(StageProgression.ORDER[ordinal])))
	else: enter_stage((stage + 1) % stage_count())

func retry_stage() -> bool:
	if not _can_replace_run(): return false
	if is_content_session() and not run_domain.state.is_empty():
		progression_inputs = run_domain.state.progression.duplicate(true)
	return enter_stage(stage)

## Starts a combat generation for the stage. False when content cannot be
## prepared or the runtime rejects the bootstrap; checkpoint.message says why.
func enter_stage(index: int, bootstrap: Dictionary = {}, session_state: Dictionary = {}, restored_state: Dictionary = {}, authority_run_id: Variant = null) -> bool:
	if index < 0 or index >= stage_count(): return false
	stage = index
	next_round = 0
	next_enemy_id = 100000
	epoch += 1
	selected = Vector2i(-1, -1)
	checkpoint.message = ""
	scene.apply_frame({"reset":true,"sceneEpoch":epoch})
	var map: Dictionary = stage_map(stage)
	var frame := {"seq":0,"sceneEpoch":epoch,"mapRevision":stage,"map":map,"time":0.0,"turrets":[],"enemies":[],"projectiles":[],"impacts":[],"presentation":{"effects":{},"labels":{}}}
	scene.apply_frame(frame)
	scene.combat_base_frame = frame
	var path: Array = catalog.world_path(stage) if is_content_session() else stage_source(stage).path
	var initial := {"path":path,"tileSize":1.0,"boardDistanceScale":1.0/48.0,"defense":{"config":{"maxHp":100.0}}}
	if is_content_session():
		if not run_domain.initialize(catalog, progression_inputs, stage, epoch, authority_run_id):
			checkpoint.message = run_domain.error
			return false
		if not restored_state.is_empty():
			run_domain.restore(restored_state)
			progression_inputs = run_domain.state.progression.duplicate(true)
		var inputs := battle_inputs.duplicate(true)
		inputs.defenseConfig = run_domain.growth.derive(run_domain.growth.run_effect_progression(run_domain.state)).defenseConfig
		inputs.coreConfig = run_domain.growth.core_config(run_domain.state, stage, 0, catalog)
		initial = catalog.bootstrap(stage, inputs)
		if initial.is_empty():
			checkpoint.message = catalog.error
			return false
	initial.merge(bootstrap, true)
	var control := {"clock":"godot","phase":"preparation","paused":false,"speed":1.0}
	control.merge(session_state, true)
	var rejected: String = scene.combat_runtime.start(epoch, initial, control)
	if not rejected.is_empty():
		_report_rejection("전투를 시작하지 못했습니다", rejected)
		return false
	if not scene.combat_runtime.step_completed.is_connected(_on_combat_step_completed):
		scene.combat_runtime.step_completed.connect(_on_combat_step_completed)
	return true

## Runtime rejections are protocol or content faults, never player input; the
## run domain validates commands first. They are logged and shown, not ignored.
func _report_rejection(context: String, reason: String) -> void:
	checkpoint.message = "%s (%s)" % [context, reason]
	push_error("Combat runtime rejected: %s (%s)" % [context, reason])

func command(commands: Array = [], patch: Dictionary = {}) -> bool:
	var before: Array = []
	if is_content_session() and not applying_events:
		applying_events = true
		var collected: Dictionary = run_domain.collect(scene.combat_runtime)
		before = collected.get("commands", [])
		applying_events = false
		if not collected.get("ok", false):
			checkpoint.message = run_domain.error
			return false
	var ack_event: int = scene.combat_runtime.event_id
	if is_content_session():
		ack_event = run_domain.event_ack
		if not patch.has("phase") and not run_domain.state.is_empty(): patch.phase = run_domain.state.phase
	var rejected: String = scene.combat_runtime.apply_batch(epoch, before + commands, patch, ack_event)
	if not rejected.is_empty():
		_report_rejection("전투 명령을 적용하지 못했습니다", rejected)
		return false
	return true

func apply_run_command(request: Dictionary) -> bool:
	if not is_content_session() or not scene.combat_runtime.active: return false
	# Settle newly observed events before checking affordability/phase.
	if not command(): return false
	var build_id := int(run_domain.state.get("nextTurretId",-1)) if request.get("kind") == "build" else -1
	var previous: Dictionary = run_domain.state.duplicate(true)
	var result: Dictionary = run_domain.apply(request)
	if not result.get("ok", false):
		checkpoint.message = run_domain.error
		return false
	# A rejected batch leaves combat unchanged; keep the run (gold, turrets) with it.
	if not command(result.get("commands", []), {"phase":run_domain.state.phase}):
		run_domain.state = previous
		return false
	checkpoint.message = ""
	if build_id >= 0:
		var placed: Dictionary = run_domain.service.turret(run_domain.state,build_id)
		if not placed.is_empty(): scene.confirm_turret_placement(build_id,str(placed.type),int(placed.x),int(placed.y))
	if request.get("kind") == "sell":
		scene.cancel_turret_placement(int(request.get("id",-1)))
	scene.combat_base_frame.buildPreview = null
	return true

func selected_run_command(kind: String, values: Dictionary = {}) -> bool:
	var request := {"kind":kind,"id":run_domain.selected_id(selected)}
	request.merge(values, true)
	return apply_run_command(request)

func apply_growth_command(request: Dictionary) -> bool:
	if not is_content_session() or run_domain.state.is_empty() or not scene.combat_runtime.active: return false
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
	command(progression_commands(refresh))
	checkpoint.message = ""
	return true

## Growth (upgrades, research) applies to the running stage at once, whatever
## its source (purchase, research completion, server receipt or authoritative
## snapshot): refreshed turret stats plus defense and core configuration. The
## loadout (core, modules) stays as fixed at stage start. Call after
## run_domain.state holds the refreshed state.
func progression_commands(refresh: Dictionary) -> Array:
	var updates: Array = refresh.get("commands", []).duplicate()
	var effects: Dictionary = run_domain.growth.derive(run_domain.growth.run_effect_progression(run_domain.state))
	updates.append({"kind":"defenseConfig","config":effects.defenseConfig})
	updates.append({"kind":"coreConfig","config":run_domain.growth.core_config(run_domain.state, stage, int(run_domain.state.roundIndex), catalog)})
	return updates

## Saves a new progression, then applies it to the live run (see
## progression_commands). False, with live state unchanged, when the save fails;
## the caller decides whether that blocks the app. A combat rejection after the
## save is reported by command().
func commit_progression(value: Dictionary) -> bool:
	if run_domain.state.is_empty() or not scene.combat_runtime.active:
		if checkpoint.save_progression(self, value) != OK: return false
		progression_inputs = value.duplicate(true)
		return true
	var candidate: Dictionary = run_domain.state.duplicate(true)
	candidate.progression = value
	return commit_run_state(candidate)

## commit_progression for a whole candidate run state (progression plus other
## authoritative run fields) during an active run.
func commit_run_state(candidate: Dictionary) -> bool:
	var refresh: Dictionary = run_domain.service.refresh(candidate)
	# Durable save precedes live mutation; failed purchases never spend balances.
	if checkpoint.persist_state(self, refresh.state) != OK: return false
	run_domain.state = refresh.state
	progression_inputs = candidate.progression.duplicate(true)
	command(progression_commands(refresh))
	return true

func board_tap(tile: Vector2i) -> void:
	selected = tile
	if tile.x < 0:
		scene.combat_base_frame.buildPreview = null
		return
	scene.combat_base_frame.buildPreview = [-1,tile.x + 0.5,tile.y + 0.5,run_domain.Commands.initial_aim_angle(turret_type),0,0,turret_type]

func build_selected() -> void:
	if selected.x < 0 or not scene.combat_runtime.active: return
	apply_run_command({"kind":"build","x":selected.x,"y":selected.y,"type":turret_type})

func start_wave() -> void:
	if not scene.combat_runtime.active or scene.combat_runtime.defense.failed: return
	if scene.combat_runtime.wave.active: return
	if not command(): return
	if run_domain.state.get("phase") != "preparation": return
	if next_round >= catalog.wave_count(stage):
		checkpoint.message = "All content waves complete"
		return
	var inputs := battle_inputs.duplicate(true)
	if not inputs.has("initialDelay"):
		inputs.initialDelay = catalog.initial_delay()
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
	if not scene.combat_runtime.active: return
	command([], {"paused":not bool(scene.combat_runtime.session.get("paused",false))})

func toggle_speed() -> void:
	if not scene.combat_runtime.active: return
	command([], {"speed":4.0 if float(scene.combat_runtime.session.get("speed",1)) == 1 else 1.0})

func toggle_camera() -> void:
	scene.options.camera = "drone" if scene.options.camera == "angled" else "angled"
	scene.apply_options()

func save_session() -> void:
	checkpoint.save_session(self)

func load_session() -> void:
	checkpoint.load_session(self)

func exit_stage() -> void:
	if is_content_session() and scene.combat_runtime.active:
		if checkpoint.save_session(self) != OK: return
	epoch += 1
	scene.apply_frame({"reset":true,"sceneEpoch":epoch})

func _on_combat_step_completed() -> void:
	# The runtime has finished all movement/attacks/wave/core work and deducted
	# this step's debt. ACK/configuration changes therefore affect the next step,
	# regardless of how many simulation steps fit in the current render frame.
	var runtime = scene.combat_runtime
	if is_content_session() and runtime.active and not run_domain.state.is_empty():
		if runtime.event_id > run_domain.event_ack or runtime.session.get("phase") != run_domain.state.phase:
			if not command(): runtime.session.paused = true

func _process(_delta: float) -> void:
	var runtime = scene.combat_runtime
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
