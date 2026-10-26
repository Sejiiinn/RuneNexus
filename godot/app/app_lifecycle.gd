extends "res://app/app_gem_rewards.gd"
## Formal --app entry: startup restore, stage entry/exit, lobby, pause and quit.
## Layers below it (save state → gem rewards) may only call downward; GDScript
## rejects an upward call at parse time.

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
	if request.get("kind") in [RunKinds.PURCHASE_GEM_CHOICE, RunKinds.REROLL_REWARD_FREE] + RunKinds.REWARD_CHOICES: return false # Server commands exclusively own candidates and grants.
	if services != null and services.blocks_play(): return false
	if startup_blocked or in_lobby or _battle_preparation_pending(): return false
	if save_failed and not persist_progression(): return false
	if request.get("kind") == RunKinds.BUILD_SUPPORT_CORE:
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
	if request.get("kind") in [RunKinds.EQUIP_GEM, RunKinds.CHOOSE_REWARD_GEM_EQUIP]:
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
