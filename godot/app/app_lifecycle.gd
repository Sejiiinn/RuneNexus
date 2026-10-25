extends "res://session/session_controller.gd"
## Formal application only. Debug --session deliberately retains its manual lifecycle.
const SaveJson = preload("res://app/save_json.gd")
const SaveCodec = preload("res://app/save_codec.gd")
const DevicePreferences = preload("res://app/device_preferences.gd")
const RuntimeProfile = preload("res://app/runtime_profile.gd")
const GemReroll = preload("res://app/gem_reroll.gd")
const GemDeck = preload("res://app/gem_deck.gd")
var startup_blocked := true
var in_lobby := true
var autosave_interval := 10.0
var autosave_elapsed := 0.0
var lobby: Control
var hud: Control
var ui_enabled := true
var saving := false
var save_failed := false
var auto_start_mode := "pauseEachRound"
var _modal_resume_allowed := false
var selection_view = preload("res://ui/app_selection.gd").new()
var services
var _stage_entry_pending := false
var _stage_entry_cancelled := false
var _run_close_pending := false
var _pause_generation := 0
var _gem_reroll_requesting := false
var _gem_reroll_note := ""
var _gem_offer_retry_at := 0
var _gem_purchase_resume: Dictionary = {}

func _ready() -> void:
	scene = get_parent()
	if ui_enabled:
		services = load("res://services/app_services.gd").new()
		add_child(services)
		services.setup(self)
	checkpoint.allow_progression_only = true
	scene.options.presentation_groups = ["labels", "effects", "selection"]
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	get_tree().root.content_scale_size = Vector2i(440, 760)
	scene.options.turret_levels = true
	DevicePreferences.apply(scene.options)
	# Optional inspection launch setting; normal app launches retain their default.
	for argument in OS.get_cmdline_user_args():
		if argument in ["--camera=angled", "--camera=drone"]:
			scene.options.camera = argument.trim_prefix("--camera=")
	scene.apply_options()
	if not catalog.load_catalog() or not run_domain.growth.load_catalog():
		checkpoint.message = "콘텐츠를 불러오지 못했습니다"
	elif services == null:
		retry_load()
	if ui_enabled:
		var layer := CanvasLayer.new()
		layer.layer = 10
		add_child(layer)
		lobby = load("res://ui/lobby.gd").new()
		lobby.app = self
		layer.add_child(lobby)
		RuntimeProfile.tag_canvas(lobby, "hud")
		hud = load("res://ui/battle_hud.gd").new()
		hud.app = self
		layer.add_child(hud)
		RuntimeProfile.tag_canvas(hud, "hud")
		if services != null:
			var overlay_layer := CanvasLayer.new()
			overlay_layer.layer = 20
			add_child(overlay_layer)
			var overlay = load("res://ui/reconnect_overlay.gd").new()
			overlay.services = services
			overlay_layer.add_child(overlay)
	refresh_ui()

func refresh_ui() -> void:
	var gated: bool=services!=null and services.boot_host!=null and services.boot_host.blocks_app_ui()
	if scene != null:
		scene.set_battle_visible(not in_lobby and not gated)
	if lobby != null:
		lobby.visible = in_lobby and not gated
		lobby.refresh()
	if hud != null:
		hud.visible = not in_lobby and not gated
		hud.refresh()

func board_input_policy() -> BoardInput:
	if services != null and services.blocks_play(): return BoardInput.CANCEL_CONTACTS
	if in_lobby: return BoardInput.IGNORE
	# A plain pause keeps camera, selection and building available; a failed
	# save and reward replacement targeting do not.
	if save_failed: return BoardInput.CANCEL_CONTACTS
	if is_instance_valid(hud):
		if hud.blocks_board_input(): return BoardInput.CANCEL_CONTACTS
		var rewards = hud.get("rewards")
		if rewards != null and rewards.targeting() and rewards.replacing(): return BoardInput.CANCEL_CONTACTS
	return BoardInput.ACCEPT

func battlefield_rect() -> Rect2:
	return hud.battlefield_rect() if is_instance_valid(hud) else Rect2()

func refresh_economy_ui() -> void:
	if lobby != null and in_lobby: lobby.refresh_economy()
	if hud != null and not in_lobby: hud.refresh()

func refresh_selection() -> void:
	selection_view.apply(self)
	scene.request_native_frame()

func enter_stage(index: int, bootstrap: Dictionary = {}, session_state: Dictionary = {}, restored_state: Dictionary = {}, server_run_id: Variant = null) -> bool:
	var entered := super.enter_stage(index, bootstrap, session_state, restored_state, server_run_id)
	refresh_selection()
	return entered

func board_tap(tile: Vector2i) -> void:
	if _battle_preparation_pending(): return
	if hud != null and hud.get("rewards") != null and hud.rewards.targeting():
		hud.rewards.board_tap(tile)
		refresh_selection()
		return
	var changed := selected != tile
	selected = tile
	if changed: selection_view.level_preview = false
	if hud != null: hud.on_board_selection()
	refresh_selection()
	if hud != null: hud.refresh()

func retry_load() -> bool:
	if services != null and services.updates != null and services.updates.blocked: return false
	if not startup_blocked: return true
	# Keep the validated, paused simulation live for save/growth/settlement and
	# Continue UI. Only battle presentation waits for an explicit stage entry.
	# Account slot replacement also returns through this path.
	scene.begin_deferred_battle_presentation()
	if not catalog.is_loaded() or run_domain.growth.data.is_empty():
		if not catalog.load_catalog() or not run_domain.growth.load_catalog(): return false
	# Resolve a durable transition before probing individual files: an interrupted
	# first checkpoint may only have a partial .tmp, with valid undo in the journal.
	if not checkpoint.store._begin():
		checkpoint.message = checkpoint.store.last_error_message
		refresh_ui()
		return false
	# The store may restore a valid backup. If neither file is readable, preserve
	# both for explicit repair and never mistake damaged data for a new player.
	var existing := false
	var readable := false
	for path in [checkpoint.store.primary_path, checkpoint.store.backup_path]:
		# Match Store._recover precedence without deleting recovery evidence.
		var candidate: String = path
		if not FileAccess.file_exists(candidate):
			candidate = path + ".replace" if FileAccess.file_exists(path + ".replace") else path + ".tmp"
		if not FileAccess.file_exists(candidate): continue
		existing = true
		var parsed: Dictionary = SaveJson.parse_record(FileAccess.get_file_as_string(candidate))
		if parsed.ok and SaveCodec.is_canonical_v2(parsed.get("value")): readable = true
	if existing and not readable:
		checkpoint.message = "저장 파일을 읽을 수 없습니다. 파일을 복구한 뒤 다시 불러오세요."
		refresh_ui()
		return false
	checkpoint.reward_queue = null
	var queue = checkpoint.rewards()
	if not queue.loaded:
		refresh_ui()
		return false
	var result: Error = checkpoint.load_session(self)
	if result == ERR_FILE_NOT_FOUND:
		var empty: Dictionary = SaveCodec.decode({"version":2,"progression":run_domain.growth.data.defaultProgression,"turretModules":{},"preferences":{},"activeRun":null})
		progression_inputs = empty.progression.duplicate(true)
		progression_inputs.turretModules = empty.turretModules.duplicate(true)
		if checkpoint.owner != "guest" and not queue.state.get("lastServerSnapshot", {}).is_empty():
			var mapped: Dictionary = checkpoint.RewardSnapshot.new().apply_authoritative(progression_inputs, queue.state.lastServerSnapshot)
			if mapped.is_empty():
				checkpoint.message = "계정 보상 스냅샷을 복구할 수 없습니다"
				return false
			progression_inputs = mapped
		checkpoint.message = "새 게임을 시작할 수 있습니다"
	elif result != OK:
		refresh_ui()
		return false
	auto_start_mode = str(checkpoint.preferences.get("autoStartMode", "pauseEachRound"))
	startup_blocked = false
	in_lobby = true
	if run_domain.state.is_empty():
		epoch += 1
		scene.apply_frame({"reset":true,"sceneEpoch":epoch})
	elif scene.combat_runtime.active: command([], {"paused":true})
	if is_inside_tree() and not _detached_debug_lifecycle(): checkpoint.enable_worker(self)
	refresh_ui()
	return true

func start_stage(index: int) -> bool:
	if _gem_reroll_requesting or _pending_gem_reroll(): return false
	if _battle_preparation_pending(): return false
	if not _detached_debug_lifecycle() and (services == null or services.blocks_play()):
		var update_required: bool = services != null and services.updates != null and services.updates.blocked
		checkpoint.message = "업데이트 확인을 완료해 주세요" if update_required else "계정 연결과 닉네임 설정을 완료해 주세요"
		if lobby != null: lobby.open_service("업데이트" if update_required else "계정 및 저장")
		return false
	if startup_blocked or index < 0 or index >= stage_count(): return false
	var progression: Dictionary = progression_inputs if run_domain.state.is_empty() else run_domain.state.progression
	if not StageProgression.stage_unlocked(progression,catalog.stage_id(index)):
		checkpoint.message = "아직 잠긴 스테이지입니다"
		return false
	if save_failed and not persist_progression(): return false
	var pause_generation := _pause_generation
	_stage_entry_pending = true
	_stage_entry_cancelled = false
	if scene.combat_runtime.active: command([], {"paused":true})
	# Finish the acknowledged reward checkpoint before replacing its run. This
	# keeps crash recovery distinguishable from a rollback to an unrelated run.
	if services != null and services.online != null and services.online.state.get("gemAckPending", false):
		var flushed: Dictionary = await services.sync()
		if not flushed.get("ok", false):
			checkpoint.message = "서버 보상 저장을 완료한 뒤 다시 시작해 주세요."
			return _finish_stage_entry(false, start_stage.bind(index))
		if _stage_entry_cancelled: return _finish_stage_entry(false)
	if not await _prepare_stage_resources(index):
		return _finish_stage_entry(false, start_stage.bind(index))
	if _stage_entry_cancelled: return _finish_stage_entry(false)
	if _detached_debug_lifecycle():
		if not prepare_run_transition():
			_record_save_failure()
			return _finish_stage_entry(false, start_stage.bind(index))
		if not enter_stage(index):
			return _finish_stage_entry(false, start_stage.bind(index))
	else:
		# Recover the exact pending lifecycle command before replacing its local
		# provisional/checkpoint state. A retried start must not create two runs.
		var recovering := _pending_run_command()
		if not recovering.is_empty():
			var recovered: Dictionary = await services.perform("refresh")
			if not recovered.get("ok", false):
				checkpoint.message = "서버 도전 상태를 확인하지 못했습니다. 다시 시도해 주세요."
				return _finish_stage_entry(false, start_stage.bind(index))
			if _stage_entry_cancelled: return _finish_stage_entry(false)
			if recovering == "start_run" and stage == index and _server_run_matches():
				return await _complete_server_stage_entry(index, pause_generation)
		if not await _close_server_run():
			return _finish_stage_entry(false, start_stage.bind(index))
		if _stage_entry_cancelled: return _finish_stage_entry(false)
		# The server binds its UUID to this complete, pristine checkpoint. The
		# provisional run is paused and cannot accept input or advance combat.
		if not enter_stage(index, {}, {"paused":true}, {}, ""):
			return _finish_stage_entry(false, start_stage.bind(index))
		if run_domain.state.is_empty() or not persist_progression():
			return _finish_stage_entry(false, start_stage.bind(index))
		var started: Dictionary = await services.perform("start_run", {"stageNumber":catalog.stage_id(index)})
		if not started.get("ok", false) or stage != index or not _server_run_matches():
			checkpoint.message = "서버에서 도전을 시작하지 못했습니다. 다시 시도해 주세요."
			return _finish_stage_entry(false, start_stage.bind(index))
		if _stage_entry_cancelled: return _finish_stage_entry(false)
		return await _complete_server_stage_entry(index, pause_generation)
	if not persist_progression():
		command([], {"paused":true})
		return _finish_stage_entry(false, resume_run)
	if not await _realize_battle_presentation():
		command([], {"paused":true})
		return _finish_stage_entry(false, resume_run)
	return _finish_stage_entry(true)

# Detached verification/development controllers do not enter the formal app.
# An in-tree app always requires an authenticated server lifecycle.
func _detached_debug_lifecycle() -> bool:
	return services == null and not is_inside_tree()

func _pending_run_command() -> String:
	var box = checkpoint.rewards()
	if box == null or not box.loaded: return ""
	var pending: Variant = box.state.get("inFlight")
	if pending is Dictionary and pending.get("kind") in ["start_run", "close_run"]: return str(pending.kind)
	return ""

func _server_run_matches() -> bool:
	if services == null or services.economy == null or run_domain.state.is_empty(): return false
	var lifecycle: Variant = services.economy.snapshot.get("run")
	return lifecycle is Dictionary and lifecycle.get("status") == "active" \
		and not str(run_domain.state.get("economyRunId", "")).is_empty() \
		and lifecycle.get("runId") == run_domain.state.get("economyRunId") \
		and int(lifecycle.get("stageNumber", 0)) == catalog.stage_id(stage)

func _close_server_run() -> bool:
	if run_domain.state.is_empty(): return true
	var identity: Variant = run_domain.state.get("economyRunId")
	if identity == null or str(identity).is_empty(): return true # Unaccepted pristine provisional run.
	# Preserve completed-round rewards before closing. The command worker drains
	# this durable settlement first, then clears the server's active checkpoint.
	if not prepare_run_transition():
		_record_save_failure()
		return false
	var closed: Dictionary = await services.perform("close_run", {"runId":identity})
	if not closed.get("ok", false) or not run_domain.state.is_empty():
		checkpoint.message = "서버 도전 종료와 보상 정산을 완료하지 못했습니다. 다시 시도해 주세요."
		return false
	_gem_purchase_resume.clear()
	return true

func _complete_server_stage_entry(index: int, pause_generation: int) -> bool:
	if stage != index or not _server_run_matches():
		checkpoint.message = "서버 도전 상태가 변경되었습니다. 다시 불러와 주세요."
		return _finish_stage_entry(false, resume_run)
	# Applying the canonical checkpoint rebuilds the paused simulation and may
	# unload the preflight resources. Rebind presentation to that exact run.
	if not await _prepare_stage_resources(index, run_domain.state): return _finish_stage_entry(false, resume_run)
	if _stage_entry_cancelled: return _finish_stage_entry(false)
	if not await _realize_battle_presentation(): return _finish_stage_entry(false, resume_run)
	if _stage_entry_cancelled: return _finish_stage_entry(false)
	if not _server_run_matches():
		checkpoint.message = "서버 도전 상태가 변경되었습니다. 다시 불러와 주세요."
		return _finish_stage_entry(false, resume_run)
	if run_domain.state.get("phase") == "preparation" and pause_generation == _pause_generation:
		if not command([], {"paused":false}): return _finish_stage_entry(false, resume_run)
	return _finish_stage_entry(true)

func resume_run() -> bool:
	if _battle_preparation_pending(): return false
	if not _detached_debug_lifecycle() and (services == null or services.blocks_play()): return false
	if startup_blocked or not scene.combat_runtime.active or run_domain.state.is_empty(): return false
	if save_failed and not persist_progression(): return false
	# Keep simulation paused until the returning battlefield is fully ready.
	if not command([], {"paused":true}): return false
	var pause_generation := _pause_generation
	_stage_entry_pending = true
	_stage_entry_cancelled = false
	if not _detached_debug_lifecycle():
		var recovered: Dictionary = await services.perform("refresh")
		if not recovered.get("ok", false) or run_domain.state.is_empty():
			checkpoint.message = "서버 도전 상태를 확인하지 못했습니다. 다시 시도해 주세요."
			return _finish_stage_entry(false, resume_run)
		if not run_domain.is_finished() and not _server_run_matches():
			checkpoint.message = "서버에서 시작한 도전만 이어할 수 있습니다."
			return _finish_stage_entry(false, start_stage.bind(stage))
		if _stage_entry_cancelled: return _finish_stage_entry(false)
	if not await _prepare_stage_resources(stage, run_domain.state): return _finish_stage_entry(false, resume_run)
	if _stage_entry_cancelled: return _finish_stage_entry(false)
	if not await _realize_battle_presentation(): return _finish_stage_entry(false, resume_run)
	if _stage_entry_cancelled: return _finish_stage_entry(false)
	if save_failed: return _finish_stage_entry(false, resume_run)
	# Waiting for a wave is not a game pause. Active waves still require the
	# HUD's explicit resume; automatic entry keeps following the selected mode.
	if run_domain.state.get("phase") == "preparation" and pause_generation == _pause_generation:
		if not command([], {"paused":false}): return _finish_stage_entry(false, resume_run)
	return _finish_stage_entry(true)

func _stage_boot():
	if not is_inside_tree(): return null
	return get_tree().get_first_node_in_group("rune_app_boot")

func _finish_stage_entry(success: bool, retry: Callable = Callable()) -> bool:
	success = success and not _stage_entry_cancelled
	if not success: scene.cancel_stage_preparation()
	_stage_entry_pending = false
	in_lobby = not success
	var boot = _stage_boot()
	if boot != null:
		if not success and not _stage_entry_cancelled:
			boot.fail_stage_preparation(checkpoint.message, retry)
		else: boot.set_battle_preparing(false)
	if _stage_entry_cancelled and not save_failed: checkpoint.message = "스테이지 준비를 취소했습니다"
	refresh_ui()
	return success

func cancel_stage_entry() -> void:
	if not _stage_entry_pending: return
	_stage_entry_cancelled = true
	scene.request_stage_preparation_cancel()
	if scene.combat_runtime.active: pause_and_save()
	# The current threaded request is collected before the overlay is dismissed.
	# No subsequent stage can enter while the old coroutine still owns resources.

func _prepare_stage_resources(index: int, restored_state: Dictionary = {}) -> bool:
	var progression: Dictionary = progression_inputs if run_domain.state.is_empty() else run_domain.state.progression
	if await scene.prepare_stage_resources(catalog, index, run_domain.growth.derive(progression), restored_state): return true
	checkpoint.message = "스테이지 리소스를 준비하지 못했습니다. 다시 시도해 주세요."
	return false

func _realize_battle_presentation() -> bool:
	if await scene.realize_battle_presentation(): return true
	checkpoint.message = "전투 화면을 준비하지 못했습니다. 다시 시도해 주세요."
	return false

func _battle_preparation_pending() -> bool:
	return _stage_entry_pending or _run_close_pending or (scene != null and scene.battle_preparation_pending())

func open_stage_menu_destination() -> bool:
	if _gem_reroll_requesting or _pending_gem_reroll() or _battle_preparation_pending(): return false
	if scene.combat_runtime.active: command([], {"paused":true})
	if not persist_progression():
		refresh_ui()
		return false
	in_lobby = true
	if lobby != null:
		lobby.page = "스테이지"
		lobby.stages.reset_navigation()
	refresh_ui()
	return true

func show_lobby() -> void:
	if _gem_reroll_requesting or _pending_gem_reroll() or _run_close_pending: return
	if _stage_entry_pending: cancel_stage_entry(); return
	if scene.combat_runtime.active: command([], {"paused":true})
	in_lobby = true
	persist_progression()
	refresh_ui()

func _record_save_failure() -> void:
	save_failed = true
	var failure: String = checkpoint.message
	if scene.combat_runtime.active: command([], {"paused":true})
	checkpoint.message = failure

func persist_progression() -> bool:
	if startup_blocked or saving: return false
	if RuntimeProfile.options.get("skip_save", false): return true
	var save_tick := RuntimeProfile.begin()
	saving = true
	var result: Error
	if scene.combat_runtime.active and not run_domain.state.is_empty():
		result = checkpoint.save_session(self)
	else:
		result = checkpoint.save_progression(self, progression_inputs)
	saving = false
	if result != OK: _record_save_failure()
	if result == OK:
		save_failed = false
		autosave_elapsed = 0.0
		if not run_domain.state.is_empty(): progression_inputs = run_domain.state.progression.duplicate(true)
		if services != null: services.request_run_settlement()
	RuntimeProfile.finish("save", save_tick)
	return result == OK

# Accepted background snapshot; durable consumers use persist_progression().
# Completion is consumed on main before any service/play gate can return early.
func request_checkpoint() -> bool:
	if startup_blocked or saving: return false
	if RuntimeProfile.options.get("skip_save", false): return true
	if not scene.combat_runtime.active or run_domain.state.is_empty(): return persist_progression()
	var save_tick := RuntimeProfile.begin()
	saving = true
	var result: Error = checkpoint.request_session(self)
	saving = false
	if result != OK: _record_save_failure()
	else:
		autosave_elapsed = 0.0
		progression_inputs = run_domain.state.progression.duplicate(true)
	RuntimeProfile.finish("save_request", save_tick)
	return result == OK

func _poll_checkpoint_completions() -> void:
	for result in checkpoint.poll_completions():
		if result.error != OK:
			checkpoint.message = result.message
			_record_save_failure()

func _exit_tree() -> void:
	checkpoint.shutdown()

func apply_growth_command(request: Dictionary) -> bool:
	if _gem_reroll_requesting or _pending_gem_reroll() or _battle_preparation_pending(): return false
	if services != null and services.blocks_play(): return false
	if startup_blocked: return false
	if save_failed and not persist_progression(): return false
	var active: bool = scene.combat_runtime.active and not run_domain.state.is_empty()
	if active and not command(): return false
	var current: Dictionary = run_domain.state.progression if active else progression_inputs
	var result: Dictionary = run_domain.growth.execute(current, request)
	if not result.get("ok", false):
		checkpoint.message = str(result.get("error", "성장 명령을 적용할 수 없습니다"))
		return false
	if active and str(request.get("kind", request.get("type", ""))) == "completeFinishedResearches":
		# Finished research spends nothing, and its saved start time and duration
		# complete it again after a crash. Apply at once; save in the background.
		var candidate: Dictionary = run_domain.state.duplicate(true)
		candidate.progression = result.state
		apply_run_state(candidate)
		var requested := request_checkpoint()
		refresh_selection()
		refresh_ui()
		return requested
	if not commit_progression(result.state):
		_record_save_failure()
		return false
	refresh_selection()
	refresh_ui()
	return true

func apply_run_command(request: Dictionary) -> bool:
	if _gem_reroll_requesting or _pending_gem_reroll(): return false
	if request.get("kind") in ["purchaseGemChoice", "rerollRewardFree", "chooseRewardGem", "chooseRewardGemEquip", "chooseRewardShards"]: return false # Server commands exclusively own candidates and grants.
	if services != null and services.blocks_play(): return false
	if startup_blocked or in_lobby or _battle_preparation_pending(): return false
	if save_failed and not persist_progression(): return false
	if request.get("kind") == "buildSupportCore":
		if support_core_blocked():
			checkpoint.message = "이 도전에서는 지원 코어를 지을 수 없습니다."
			return false
		request = request.duplicate()
		request.deckLog = checkpoint.owner != "guest"
	if not super.apply_run_command(request): return false
	refresh_selection()
	if not request_checkpoint(): return false
	# Command receipts, rather than equipment snapshots, own this transient cue.
	# Loading, removing gems and repeated selection frames cannot replay it.
	if request.get("kind") in ["equipGem", "chooseRewardGemEquip"]:
		scene.play_gem_equip_burst(int(request.get("id", -1)), str(request.get("type", "")))
	return true

func start_wave() -> void:
	if _gem_reroll_requesting or _pending_gem_reroll(): return
	if services != null and services.blocks_play(): return
	if startup_blocked or in_lobby or _battle_preparation_pending(): return
	if save_failed and not persist_progression(): return
	super.start_wave()
	request_checkpoint()

func toggle_pause() -> void:
	if _gem_reroll_requesting or _pending_gem_reroll(): return
	if services != null and services.blocks_play(): return
	if startup_blocked or in_lobby or _battle_preparation_pending(): return
	if save_failed and not persist_progression(): return
	super.toggle_pause()
	request_checkpoint()

func toggle_speed() -> void:
	if services != null and services.blocks_play(): return
	if startup_blocked or _battle_preparation_pending() or (save_failed and not persist_progression()): return
	super.toggle_speed()
	request_checkpoint()

func toggle_camera() -> void:
	super.toggle_camera()
	# The chosen view carries over to later stages and app restarts on this device.
	var settings := DevicePreferences.read()
	settings.camera = scene.options.camera
	DevicePreferences.write(settings)

func set_speed(value: float) -> void:
	if services != null and services.blocks_play(): return
	if value not in [1.0, 2.0, 4.0] or startup_blocked or in_lobby or _battle_preparation_pending(): return
	if save_failed and not persist_progression(): return
	if command([], {"speed":value}): request_checkpoint()

func begin_modal_pause() -> bool:
	if startup_blocked or in_lobby or save_failed: return false
	var running := not bool(scene.combat_runtime.session.get("paused", false))
	_modal_resume_allowed = running
	if running:
		command([], {"paused":true})
		request_checkpoint()
	return running

func end_modal_pause(was_running: bool) -> void:
	if services != null and services.blocks_play(): return
	var resume := was_running and _modal_resume_allowed
	_modal_resume_allowed = false
	if not resume or in_lobby or startup_blocked or save_failed or _battle_preparation_pending(): return
	if run_domain.state.get("phase") not in ["preparation", "wave"]: return
	if command([], {"paused":false}): request_checkpoint()

func abandon_run() -> bool:
	if _gem_reroll_requesting or _pending_gem_reroll() or _battle_preparation_pending(): return false
	if startup_blocked or in_lobby: return false
	if not _detached_debug_lifecycle():
		if services == null or services.blocks_play(): return false
		_run_close_pending = true
		if scene.combat_runtime.active: command([], {"paused":true})
		refresh_ui()
		var closed := await _close_server_run()
		_run_close_pending = false
		if not closed:
			refresh_ui()
			return false
		return open_stage_menu_destination()
	if not prepare_run_transition():
		_record_save_failure()
		return false
	command([], {"phase":run_domain.state.phase,"paused":true})
	progression_inputs = run_domain.state.progression.duplicate(true)
	return open_stage_menu_destination()

func cycle_auto_start() -> void:
	var modes := ["pauseEachRound", "skipBossRounds", "fullAuto"]
	set_auto_start_mode(modes[(modes.find(auto_start_mode) + 1) % modes.size()])

func set_auto_start_mode(value: String) -> void:
	if value not in ["pauseEachRound", "skipBossRounds", "fullAuto"] or value == auto_start_mode: return
	if startup_blocked or (save_failed and not persist_progression()): return
	var previous := auto_start_mode
	auto_start_mode = value
	checkpoint.preferences.autoStartMode = auto_start_mode
	if not persist_progression():
		auto_start_mode = previous
		checkpoint.preferences.autoStartMode = previous
	refresh_ui()

func _on_combat_step_completed() -> void:
	var previous_phase: String = str(run_domain.state.get("phase", ""))
	super._on_combat_step_completed()
	if startup_blocked or save_failed or _stage_entry_pending: return
	if str(run_domain.state.get("phase", "")) != previous_phase:
		if not persist_progression(): return
	# Resolve automatic round entry at the same boundary as completion, before
	# a second fixed step in this frame can advance the preparation state.
	_maybe_auto_start()

func _maybe_auto_start() -> void:
	if services != null and services.blocks_play(): return
	if in_lobby or auto_start_mode == "pauseEachRound" or run_domain.state.is_empty(): return
	if run_domain.state.phase != "preparation" or bool(scene.combat_runtime.session.get("paused", false)): return
	if next_round <= 0 or next_round >= catalog.wave_count(stage): return
	if auto_start_mode == "skipBossRounds" and catalog.wave_has_boss(stage, next_round): return
	start_wave()

func retry_stage() -> bool:
	return await start_stage(stage)

func enter_next() -> void:
	var ordinal := StageProgression.ordinal_for(catalog.stage_id(stage))
	if ordinal > 0 and ordinal < StageProgression.ORDER.size(): await start_stage(catalog.stage_index(int(StageProgression.ORDER[ordinal])))

func exit_stage() -> void:
	show_lobby()

func save_session() -> void:
	persist_progression()

func load_session() -> void:
	if startup_blocked: retry_load()

func pause_runtime() -> void:
	_pause_generation += 1
	_modal_resume_allowed = false
	if scene.combat_runtime.active: command([], {"paused":true})

func pause_and_save() -> bool:
	pause_runtime()
	return persist_progression()

func request_quit() -> bool:
	# A corrupt startup has no live mutations to preserve and can safely close.
	if startup_blocked or pause_and_save():
		if checkpoint.shutdown() != OK:
			_record_save_failure()
			refresh_ui()
			return false
		get_tree().quit()
		return true
	refresh_ui()
	return false

func _notification(what: int) -> void:
	if scene == null: return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# The reconnect overlay owns the screen until it resolves or opens the gate.
		if services != null and services.get("reconnecting") == true: return
		if _stage_entry_pending:
			cancel_stage_entry()
			return
		var boot = _stage_boot()
		if boot != null and boot.dismiss_stage_failure():
			in_lobby = true
			refresh_ui()
			return
		if not in_lobby:
			if hud == null or not hud.close_back(): show_lobby()
		elif lobby != null: lobby.go_back()
		else: request_quit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST: request_quit()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if what == NOTIFICATION_APPLICATION_PAUSED and services != null: services.note_login_pause()
		pause_and_save()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_resume_services()

func _resume_services() -> void:
	if services == null: return
	if services.consume_login_resume(): return
	if services.updates != null:
		if services.updates.busy: return
		# A live session already passed the startup gate. Ordinary app switching
		# preserves its screen; only an existing update/installer gate needs a
		# foreground recheck. Server-required updates still open that gate.
		if services.updates.blocked: await services.updates.check()
		if services.updates.blocked: return
	if services.account != null and not services.busy: await services.resume_session()

func _process(delta: float) -> void:
	_poll_checkpoint_completions()
	if services != null and services.blocks_play(): return
	if _stage_entry_pending or _run_close_pending: return
	if services != null and services.updates != null and services.updates.blocked: return
	if startup_blocked: return
	if save_failed:
		autosave_elapsed += delta
		if autosave_elapsed >= autosave_interval:
			autosave_elapsed = 0.0
			persist_progression()
		return
	var previous_phase: String = str(run_domain.state.get("phase", ""))
	var session_tick := RuntimeProfile.begin()
	super._process(delta)
	RuntimeProfile.finish("session", session_tick)
	if checkpoint.store.last_error != OK or (checkpoint.reward_queue != null and checkpoint.reward_queue.last_error != OK):
		_record_save_failure()
		return
	if str(run_domain.state.get("phase", "")) != previous_phase: request_checkpoint()
	if services != null: services.request_run_settlement()
	_maybe_request_gem_offer()
	_maybe_auto_start()
	if run_domain.state.is_empty():
		var now := _due_research_millis(progression_inputs)
		if now >= 0: apply_growth_command({"type":"completeFinishedResearches","nowMillis":now})
	autosave_elapsed += delta
	if autosave_elapsed >= autosave_interval:
		autosave_elapsed = 0.0
		request_checkpoint()

# Every offer/purchase/choice/reroll is an immutable account command. In-flight state
# is read from the checkpoint even before the economy service has been configured.
func _pending_gem_reroll() -> bool:
	var box = checkpoint.rewards()
	if box == null or not box.loaded: return true
	var pending: Variant = box.state.get("inFlight")
	return pending is Dictionary and pending.get("kind") in ["offer_gems", "purchase_gems", "reroll_gems", "choose_gem"]

func gem_reroll_state() -> Dictionary:
	var state: Dictionary = run_domain.state
	var used := clampi(int(state.get("gemRerollsUsed", 0)), 0, GemReroll.MAX_USES)
	var view := {"status":"available", "remaining":GemReroll.MAX_USES-used, "free":used == 0, "available":false, "locked":false, "note":_gem_reroll_note}
	var purchased := bool(state.get("isPurchasedGemReward", false))
	if state.get("phase") != "reward" or (not purchased and not GemReroll.eligible(state)): return view
	if _gem_deck_missing():
		view.merge({"status":"processing", "locked":true, "note":"젬 후보를 불러오는 중…"}, true)
		return view
	if not _gem_deck().is_empty():
		# Deck runs never wait for the network; only local save health matters.
		if save_failed:
			view.merge({"status":"save_failed", "available":true, "locked":true, "note":"저장에 실패했습니다. 다시 눌러 저장을 재시도하세요."}, true)
			return view
		return _gem_reroll_budget(view, state, purchased)
	if _gem_reroll_requesting or (services != null and services.economy != null and services.economy.busy):
		view.merge({"status":"processing", "locked":true, "note":"서버 보상 확인 중…"}, true)
		return view
	if checkpoint.owner == "guest" or services == null or not services.connected() or not services.online_ready or services.blocks_play():
		view.merge({"status":"offline", "locked":true, "note":"인증과 서버 연결을 완료해 주세요."}, true)
		return view
	if _pending_gem_reroll():
		view.merge({"status":"recovering", "available":true, "locked":true, "note":"처리 결과를 확인해야 합니다. 다시 눌러 확인하세요."}, true)
		return view
	if save_failed:
		view.merge({"status":"save_failed", "available":true, "locked":true, "note":"저장에 실패했습니다. 다시 눌러 저장을 재시도하세요."}, true)
		return view
	if services.economy == null or int(services.economy.snapshot.get("gemOfferVersion", 0)) != 1:
		view.merge({"status":"unsupported", "locked":true, "note":"서버 젬 보상을 사용할 수 없습니다."}, true)
		return view
	if not GemReroll.current_offer(state):
		view.merge({"status":"awaiting_offer", "available":true, "locked":true, "note":"서버 젬 후보를 확인하고 있습니다. 다시 눌러 재시도하세요."}, true)
		return view
	return _gem_reroll_budget(view, state, purchased)

func _gem_reroll_budget(view: Dictionary, state: Dictionary, purchased: bool) -> Dictionary:
	var used := clampi(int(state.get("gemRerollsUsed", 0)), 0, GemReroll.MAX_USES)
	if not GemReroll.current_offer(state):
		view.merge({"status":"awaiting_offer", "locked":true}, true)
		return view
	if purchased:
		view.status = "purchased"
		return view
	if used >= GemReroll.MAX_USES:
		view.merge({"status":"exhausted", "note":"이번 도전의 리롤을 모두 사용했습니다."}, true)
		return view
	if used > 0 and int(state.get("progression", {}).get("gemResetTickets", 0)) <= 0:
		view.merge({"status":"empty", "note":"젬 리셋권이 없습니다."}, true)
		return view
	view.available = true
	return view

func _gem_values() -> Dictionary:
	var state: Dictionary = run_domain.state
	return {"runId":state.get("economyRunId", ""), "completedRounds":state.get("completedRounds", 0),
		"offerId":state.get("gemOfferId", ""), "expectedOfferRevision":int(state.get("gemOfferRevision", 0)),
		"expectedRerollCount":int(state.get("gemRerollsUsed", 0))}

func _maybe_request_gem_offer() -> void:
	if in_lobby: return
	if run_domain.state.get("isPurchasedGemReward", false) or not GemReroll.eligible(run_domain.state) or GemReroll.current_offer(run_domain.state): return
	if _gem_reroll_requesting or Time.get_ticks_msec() < _gem_offer_retry_at: return
	var deck := _gem_deck()
	if not deck.is_empty():
		if not _apply_gem_step(func(state: Dictionary) -> Dictionary: return GemDeck.offer(state, deck)).get("ok", false):
			_gem_offer_retry_at = Time.get_ticks_msec() + 5000
		return
	if _gem_deck_missing():
		_gem_offer_retry_at = Time.get_ticks_msec() + 5000
		if services != null and not services.blocks_play() and not services.economy.busy: _reload_gem_deck.call_deferred()
		return
	if services == null or services.blocks_play() or services.economy == null or services.economy.busy: return
	_gem_offer_retry_at = Time.get_ticks_msec() + 5000
	reroll_reward_gems.call_deferred()

func reroll_reward_gems() -> Dictionary:
	if run_domain.state.get("isPurchasedGemReward", false): return {"ok":false,"code":"REROLL_UNAVAILABLE"}
	var deck := _gem_deck()
	if not deck.is_empty():
		if save_failed and not persist_progression(): return {"ok":false, "code":"LOCAL_SAVE_FAILED", "initialOffer":false}
		var available := gem_reroll_state()
		if not available.available or available.locked: return {"ok":false, "code":"REROLL_UNAVAILABLE", "initialOffer":false}
		var rerolled := _apply_gem_step(func(state: Dictionary) -> Dictionary: return GemDeck.reroll(state, deck))
		rerolled.initialOffer = false
		return rerolled
	var view := gem_reroll_state()
	if not view.available or _gem_reroll_requesting or startup_blocked or in_lobby or _gem_deck_missing(): return {"ok":false, "code":"REROLL_UNAVAILABLE"}
	if save_failed and not persist_progression(): return {"ok":false, "code":"LOCAL_SAVE_FAILED"}
	if not GemReroll.eligible(run_domain.state): return {"ok":false, "code":"STALE_REWARD"}
	var initial := not GemReroll.current_offer(run_domain.state)
	var action := "refresh" if _pending_gem_reroll() else ("offer_gems" if initial else "reroll_gems")
	var result: Dictionary = await _perform_gem_command(action, _gem_values())
	result.initialOffer = initial
	return result

func purchase_reward_gems() -> Dictionary:
	if _gem_reroll_requesting or startup_blocked or in_lobby or _battle_preparation_pending() or _gem_deck_missing(): return {"ok":false,"code":"GEM_PURCHASE_UNAVAILABLE"}
	if _pending_gem_reroll(): return await recover_reward_command()
	if services == null or services.blocks_play() or not _server_run_matches(): return {"ok":false,"code":"ACCOUNT_REQUIRED"}
	if save_failed and not persist_progression(): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	if not command() or run_domain.state.get("phase") not in ["preparation", "wave"]: return {"ok":false,"code":"STALE_REWARD"}
	var cost := int(run_domain.growth.data.constants.gemChoicePurchaseCost)
	if int(run_domain.state.get("gemShards", 0)) < cost: return {"ok":false,"code":"INSUFFICIENT_GEM_SHARDS"}
	var deck := _gem_deck()
	if not deck.is_empty():
		var resume := {"runId":run_domain.state.get("economyRunId", ""), "running":not bool(scene.combat_runtime.session.get("paused", false)), "pauseGeneration":_pause_generation}
		if not command([], {"paused":true}): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
		var purchased := _apply_gem_step(func(state: Dictionary) -> Dictionary: return GemDeck.purchase(state, deck, cost))
		if purchased.get("ok", false): _gem_purchase_resume = resume
		elif resume.running and int(resume.pauseGeneration) == _pause_generation: command([], {"paused":false})
		return purchased
	return await _perform_gem_command("purchase_gems", _gem_values())

func recover_reward_command() -> Dictionary:
	if startup_blocked or in_lobby: return {"ok":false,"code":"GEM_OFFER_PENDING"}
	if save_failed and not persist_progression(): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	return await _perform_gem_command("refresh", {})

func choose_reward(command: Dictionary) -> Dictionary:
	if startup_blocked or in_lobby: return {"ok":false,"code":"GEM_OFFER_PENDING"}
	if gem_reroll_state().locked or not GemReroll.current_offer(run_domain.state): return {"ok":false,"code":"GEM_OFFER_PENDING"}
	if command.get("kind") not in ["chooseRewardGem", "chooseRewardGemEquip", "chooseRewardShards"]: return {"ok":false,"code":"INVALID_CHOICE"}
	if command.kind == "chooseRewardShards" and run_domain.state.get("isPurchasedGemReward", false): return {"ok":false,"code":"INVALID_CHOICE"}
	var values := _gem_values()
	values.choice = "shards" if command.kind == "chooseRewardShards" else str(command.get("type", ""))
	if values.choice != "shards" and values.choice not in run_domain.state.rewardOptions: return {"ok":false,"code":"INVALID_CHOICE"}
	if command.kind == "chooseRewardGemEquip":
		if not run_domain.service.validate_reward_equip(run_domain.state, command): return {"ok":false,"code":"INVALID_EQUIP"}
		var target: Dictionary = run_domain.service.turret(run_domain.state, int(command.get("id", -1)))
		values.equipIntent = {"x":target.x,"y":target.y,"turretType":target.type,"slot":command.get("slot", -1),"buySlot":command.get("buySlot", false)}
	if not _gem_deck().is_empty():
		var chosen := _apply_gem_step(func(state: Dictionary) -> Dictionary: return _deck_choice(state, str(values.choice), command))
		if chosen.get("ok", false) and command.kind == "chooseRewardGemEquip": scene.play_gem_equip_burst(int(command.id), str(values.choice))
		_resume_after_gem_purchase()
		refresh_ui()
		return chosen
	return await _perform_gem_command("choose_gem", values)

## Server runs reconcile owned gems through the deck log, so a support core can
## spend a gem only in deck runs; a run without a deck validates every upload
## against server ownership instead. Guest runs keep their gems locally.
func support_core_blocked() -> bool:
	return checkpoint.owner != "guest" and _gem_deck().is_empty()

## The active run's gem deck, or {} when rewards use server commands.
func _gem_deck() -> Dictionary:
	if services == null or services.economy == null or checkpoint.owner == "guest" or run_domain.state.is_empty() or not services.economy.has_method("gem_deck"): return {}
	return services.economy.gem_deck(str(run_domain.state.get("economyRunId", "")))

func _gem_deck_missing() -> bool:
	if services == null or services.economy == null or run_domain.state.is_empty() or not services.economy.has_method("gem_deck_missing"): return false
	return services.economy.gem_deck_missing(str(run_domain.state.get("economyRunId", "")))

# A restarted process reads the deck again; deck runs never use server offers.
func _reload_gem_deck() -> void:
	_gem_reroll_requesting = true
	refresh_ui()
	await services.perform("refresh")
	_gem_reroll_requesting = false
	refresh_ui()

## Applies one deck reward step to the live run and its durable checkpoint.
func _apply_gem_step(step: Callable) -> Dictionary:
	if startup_blocked or in_lobby or _battle_preparation_pending(): return {"ok":false,"code":"GEM_OFFER_PENDING"}
	if (step.call(run_domain.state) as Dictionary).is_empty(): return {"ok":false,"code":"REROLL_UNAVAILABLE"}
	# Settle combat events first so the step builds on the live run.
	if not command(): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	var next: Dictionary = step.call(run_domain.state)
	if next.is_empty(): return {"ok":false,"code":"REROLL_UNAVAILABLE"}
	if not commit_run_state(next):
		_record_save_failure()
		return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	_gem_reroll_note = ""
	refresh_selection()
	refresh_ui()
	return {"ok":true}

func _deck_choice(state: Dictionary, choice: String, request: Dictionary) -> Dictionary:
	var next := GemDeck.choose(state, choice)
	if next.is_empty() or request.get("kind") != "chooseRewardGemEquip": return next
	var service = run_domain.service
	var id := int(request.get("id", -1))
	if request.get("buySlot", false):
		var linked: Dictionary = service.apply(next, {"kind":"link", "id":id})
		if not linked.get("ok", false): return {}
		next = linked.state
	var equipped: Dictionary = service.apply(next, {"kind":"equipGem", "id":id, "slot":int(request.get("slot", -1)), "type":choice})
	if not equipped.get("ok", false): return {}
	next = equipped.state
	next.gemOfferEquipRevision = next.gemOfferRevision
	return next

func _perform_gem_command(action: String, values: Dictionary) -> Dictionary:
	if _gem_reroll_requesting or _battle_preparation_pending(): return {"ok":false,"code":"BUSY"}
	if services == null or services.blocks_play() or checkpoint.owner == "guest": return {"ok":false,"code":"ACCOUNT_REQUIRED"}
	_gem_reroll_requesting = true
	_gem_reroll_note = ""
	if action == "purchase_gems":
		_gem_purchase_resume = {"runId":run_domain.state.get("economyRunId", ""), "running":not bool(scene.combat_runtime.session.get("paused", false)), "pauseGeneration":_pause_generation}
		if not command([], {"paused":true}):
			_gem_reroll_requesting = false
			return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	refresh_ui()
	var result: Dictionary = await services.perform(action, values)
	_gem_reroll_requesting = false
	_gem_offer_retry_at = Time.get_ticks_msec() + 5000
	if not result.get("ok", false):
		var code := str(result.get("code", "REQUEST_FAILED"))
		if code in ["INSUFFICIENT_GEM_RESET_TICKETS", "INSUFFICIENT_GEM_TICKETS"]: _gem_reroll_note = "젬 리셋권이 없습니다."
		elif code == "INSUFFICIENT_GEM_SHARDS": _gem_reroll_note = "젬 파편이 부족합니다."
		elif code == "GEM_REROLL_LIMIT_REACHED": _gem_reroll_note = "이번 도전의 리롤을 모두 사용했습니다."
		else: _gem_reroll_note = "서버 보상을 확인하지 못했습니다. 다시 시도해 주세요."
	if result.get("ok", false) and action == "choose_gem" and values.has("equipIntent") and run_domain.state.get("economyRunId") == values.get("runId"):
		var intent: Dictionary = values.equipIntent
		for target in run_domain.state.get("turrets", []):
			var slot := int(intent.get("slot", -1))
			var slots: Array = target.get("equippedGemSlots", [])
			if target.x == intent.x and target.y == intent.y and target.type == intent.turretType and slot >= 0 and slot < slots.size() and slots[slot] == values.choice:
				scene.play_gem_equip_burst(int(target.id), str(values.choice))
				break
	_resume_after_gem_purchase()
	if action == "purchase_gems" and not result.get("ok", false): checkpoint.message = _gem_reroll_note
	refresh_selection()
	refresh_ui()
	return result

# A purchased choice paused combat; resume it once that reward is finished.
func _resume_after_gem_purchase() -> void:
	if _gem_purchase_resume.is_empty(): return
	var same_run: bool = run_domain.state.get("economyRunId") == _gem_purchase_resume.get("runId")
	var reward_finished: bool = run_domain.state.get("phase") in ["preparation", "wave"]
	if not same_run or (reward_finished and not _pending_gem_reroll()):
		if same_run and _gem_purchase_resume.get("running", false) and int(_gem_purchase_resume.pauseGeneration) == _pause_generation:
			command([], {"paused":false})
		_gem_purchase_resume.clear()
