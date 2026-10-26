extends "res://session/session_controller.gd"
## App flags shared by every layer, plus selection refresh, server-run match,
## preparation gate and the durable save/checkpoint helpers.
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

func refresh_selection() -> void:
	selection_view.apply(self)
	scene.request_native_frame()

func _server_run_matches() -> bool:
	if services == null or services.economy == null or run_domain.state.is_empty(): return false
	var lifecycle: Variant = services.economy.snapshot.get("run")
	return lifecycle is Dictionary and lifecycle.get("status") == "active" \
		and not str(run_domain.state.get("economyRunId", "")).is_empty() \
		and lifecycle.get("runId") == run_domain.state.get("economyRunId") \
		and int(lifecycle.get("stageNumber", 0)) == catalog.stage_id(stage)

func _battle_preparation_pending() -> bool:
	return _stage_entry_pending or _run_close_pending or (scene != null and scene.battle_preparation_pending())

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
