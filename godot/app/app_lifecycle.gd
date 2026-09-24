extends "res://session/session_controller.gd"
## Formal application only. Debug --session deliberately retains its manual lifecycle.
const SaveJson = preload("res://app/save_json.gd")
const SaveCodec = preload("res://app/save_codec.gd")
const DevicePreferences = preload("res://app/device_preferences.gd")
const RuntimeProfile = preload("res://app/runtime_profile.gd")
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
	scene._apply_options()
	if not catalog.load_catalog() or not run_domain.growth.load_catalog():
		checkpoint.message = "콘텐츠를 불러오지 못했습니다"
	elif services == null or services.updates == null or not services.updates.blocked:
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
	_refresh_ui()

func _refresh_ui() -> void:
	if lobby != null:
		lobby.visible = in_lobby
		lobby.refresh()
	if hud != null:
		hud.visible = not in_lobby
		hud.refresh()

func refresh_selection() -> void:
	selection_view.apply(self)
	if not scene._native_combat_base_frame.is_empty(): scene._apply_frame(scene._native_combat_base_frame)

func enter_stage(index: int, bootstrap: Dictionary = {}, session_state: Dictionary = {}, restored_state: Dictionary = {}) -> void:
	super.enter_stage(index, bootstrap, session_state, restored_state)
	refresh_selection()

func board_tap(tile: Vector2i) -> void:
	if hud != null and hud.get("rewards") != null and hud.rewards.targeting():
		hud.rewards.board_tap(tile)
		refresh_selection()
		return
	var changed := selected != tile
	selected = tile
	if changed: selection_view.level_preview = false
	if hud != null and hud.has_method("on_board_selection"): hud.on_board_selection()
	refresh_selection()
	if hud != null: hud.refresh()

func retry_load() -> bool:
	if services != null and services.updates != null and services.updates.blocked: return false
	if not startup_blocked: return true
	if catalog.data.is_empty() or run_domain.growth.data.is_empty():
		if not catalog.load_catalog() or not run_domain.growth.load_catalog(): return false
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
		_refresh_ui()
		return false
	checkpoint.reward_queue = null
	var queue = checkpoint.rewards()
	if not queue.loaded:
		_refresh_ui()
		return false
	var result: Error = checkpoint.load_session(self)
	if result == ERR_FILE_NOT_FOUND:
		var empty: Dictionary = SaveCodec.decode({"version":2,"progression":{},"turretModules":{},"preferences":{},"activeRun":null})
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
		_refresh_ui()
		return false
	auto_start_mode = str(checkpoint.preferences.get("autoStartMode", "pauseEachRound"))
	startup_blocked = false
	in_lobby = true
	if run_domain.state.is_empty():
		epoch += 1
		scene._apply_frame({"reset":true,"sceneEpoch":epoch})
	elif scene._native_combat.active: command([], {"paused":true})
	_refresh_ui()
	return true

func start_stage(index: int) -> bool:
	if services != null and services.blocks_play():
		var update_required: bool = services.updates != null and services.updates.blocked
		checkpoint.message = "업데이트 확인을 완료해 주세요" if update_required else "계정 연결과 닉네임 설정을 완료해 주세요"
		if lobby != null: lobby._service("업데이트" if update_required else "계정 및 저장")
		return false
	if startup_blocked or index < 0 or index >= stage_count(): return false
	var progression: Dictionary = progression_inputs if run_domain.state.is_empty() else run_domain.state.progression
	if int(catalog.stage(index).id) > int(progression.get("unlockedStageCount", 1)):
		checkpoint.message = "아직 잠긴 스테이지입니다"
		return false
	if save_failed and not persist_progression(): return false
	if not prepare_run_transition():
		_record_save_failure()
		return false
	enter_stage(index)
	if not persist_progression():
		command([], {"paused":true})
		return false
	in_lobby = false
	_refresh_ui()
	return true

func resume_run() -> bool:
	if services != null and services.blocks_play(): return false
	if startup_blocked or not scene._native_combat.active or run_domain.state.is_empty(): return false
	if save_failed and not persist_progression(): return false
	in_lobby = false
	command([], {"paused":false})
	_refresh_ui()
	return true

func open_stage_menu_destination() -> bool:
	if scene._native_combat.active: command([], {"paused":true})
	if not persist_progression():
		_refresh_ui()
		return false
	in_lobby = true
	if lobby != null:
		lobby.page = "스테이지"
		lobby.stages.reset_navigation()
	_refresh_ui()
	return true

func show_lobby() -> void:
	if scene._native_combat.active: command([], {"paused":true})
	in_lobby = true
	persist_progression()
	_refresh_ui()

func _record_save_failure() -> void:
	save_failed = true
	var failure: String = checkpoint.message
	if scene._native_combat.active: command([], {"paused":true})
	checkpoint.message = failure

func persist_progression() -> bool:
	if startup_blocked or saving: return false
	if RuntimeProfile.options.get("skip_save", false): return true
	var save_tick := RuntimeProfile.begin()
	saving = true
	var result: Error
	if scene._native_combat.active and not run_domain.state.is_empty():
		result = checkpoint.save_session(self)
	else:
		result = checkpoint.save_progression(self, progression_inputs)
	saving = false
	if result != OK: _record_save_failure()
	if result == OK:
		save_failed = false
		autosave_elapsed = 0.0
		if not run_domain.state.is_empty(): progression_inputs = run_domain.state.progression.duplicate(true)
	RuntimeProfile.finish("save", save_tick)
	return result == OK

func apply_growth_command(request: Dictionary) -> bool:
	if services != null and services.blocks_play(): return false
	if startup_blocked: return false
	if save_failed and not persist_progression(): return false
	var active: bool = scene._native_combat.active and not run_domain.state.is_empty()
	if active and not command(): return false
	var current: Dictionary = run_domain.state.progression if active else progression_inputs
	var result: Dictionary = run_domain.growth.execute(current, request)
	if not result.get("ok", false):
		checkpoint.message = str(result.get("error", "성장 명령을 적용할 수 없습니다"))
		return false
	if active:
		var candidate: Dictionary = run_domain.state.duplicate(true)
		candidate.progression = result.state
		var refresh: Dictionary = run_domain.service.refresh(candidate)
		# Durable save precedes live mutation; failed purchases never spend balances.
		if checkpoint.persist_state(self, refresh.state) != OK:
			_record_save_failure()
			return false
		run_domain.state = refresh.state
		var effects: Dictionary = run_domain.growth.derive(result.state)
		var updates: Array = refresh.get("commands", [])
		updates.append({"kind":"defenseConfig","config":effects.defenseConfig})
		updates.append({"kind":"coreConfig","config":run_domain.growth.core_config(run_domain.state, stage, int(run_domain.state.roundIndex), catalog)})
		command(updates)
	elif checkpoint.save_progression(self, result.state) != OK:
		_record_save_failure()
		return false
	progression_inputs = result.state.duplicate(true)
	refresh_selection()
	_refresh_ui()
	return true

func apply_run_command(request: Dictionary) -> bool:
	if services != null and services.blocks_play(): return false
	if startup_blocked or in_lobby: return false
	if save_failed and not persist_progression(): return false
	if not super.apply_run_command(request): return false
	refresh_selection()
	return persist_progression()

func start_wave() -> void:
	if startup_blocked or in_lobby: return
	if save_failed and not persist_progression(): return
	super.start_wave()
	persist_progression()

func toggle_pause() -> void:
	if startup_blocked or in_lobby: return
	if save_failed and not persist_progression(): return
	super.toggle_pause()
	persist_progression()

func toggle_speed() -> void:
	if startup_blocked or (save_failed and not persist_progression()): return
	super.toggle_speed()
	persist_progression()

func set_speed(value: float) -> void:
	if value not in [1.0, 2.0, 4.0] or startup_blocked or in_lobby: return
	if save_failed and not persist_progression(): return
	if command([], {"speed":value}): persist_progression()

func begin_modal_pause() -> bool:
	if startup_blocked or in_lobby or save_failed: return false
	var running := not bool(scene._native_combat.session.get("paused", false))
	_modal_resume_allowed = running
	if running:
		command([], {"paused":true})
		persist_progression()
	return running

func end_modal_pause(was_running: bool) -> void:
	var resume := was_running and _modal_resume_allowed
	_modal_resume_allowed = false
	if not resume or in_lobby or startup_blocked or save_failed: return
	if run_domain.state.get("phase") not in ["preparation", "wave"]: return
	if command([], {"paused":false}): persist_progression()

func abandon_run() -> bool:
	if startup_blocked or in_lobby: return false
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
	_refresh_ui()

func _maybe_auto_start() -> void:
	if in_lobby or auto_start_mode == "pauseEachRound" or run_domain.state.is_empty(): return
	if run_domain.state.phase != "preparation" or bool(scene._native_combat.session.get("paused", false)): return
	if next_round <= 0 or next_round >= stage_source(stage).waves.size(): return
	if auto_start_mode == "skipBossRounds":
		for group in stage_source(stage).waves[next_round].groups:
			if str(group.enemyType).to_lower().contains("boss"): return
	start_wave()

func retry_stage() -> bool:
	return start_stage(stage)

func enter_next() -> void:
	start_stage(stage + 1)

func exit_stage() -> void:
	show_lobby()

func save_session() -> void:
	persist_progression()

func load_session() -> void:
	if startup_blocked: retry_load()

func pause_and_save() -> bool:
	_modal_resume_allowed = false
	if scene._native_combat.active: command([], {"paused":true})
	return persist_progression()

func request_quit() -> bool:
	# A corrupt startup has no live mutations to preserve and can safely close.
	if startup_blocked or pause_and_save():
		get_tree().quit()
		return true
	_refresh_ui()
	return false

func _notification(what: int) -> void:
	if scene == null: return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not in_lobby:
			if hud == null or not hud.has_method("close_back") or not hud.close_back(): show_lobby()
		elif lobby != null and lobby.has_method("go_back"): lobby.go_back()
		else: request_quit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST: request_quit()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		pause_and_save()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_resume_services()

func _resume_services() -> void:
	if services == null: return
	if services.updates != null:
		if services.updates.busy: return
		await services.updates.check()
		if services.updates.blocked: return
	if services.account != null and not services.busy: await services.retry()

func _process(delta: float) -> void:
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
	if str(run_domain.state.get("phase", "")) != previous_phase: persist_progression()
	_maybe_auto_start()
	if run_domain.state.is_empty() and Time.get_ticks_msec() >= next_research_check:
		next_research_check = Time.get_ticks_msec() + 1000
		var now := int(Time.get_unix_time_from_system() * 1000)
		for research in progression_inputs.get("activeResearches", []):
			if now >= int(research.startedAtMillis) + int(research.durationMillis):
				apply_growth_command({"type":"completeFinishedResearches","nowMillis":now})
				break
	autosave_elapsed += delta
	if autosave_elapsed >= autosave_interval:
		# Retry failed writes at the same bounded interval, preserving the error.
		autosave_elapsed = 0.0
		persist_progression()
