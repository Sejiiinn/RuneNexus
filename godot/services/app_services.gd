extends Node
## Owns account transitions outside UI lifetimes. Slots never share an Outbox.
const Json = preload("res://app/save_json.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Economy = preload("res://services/economy_service.gd")
const Quests = preload("res://app/quest_progress.gd")
signal changed
var app
var platform: Object
var config: Dictionary = {}
var account
var online
var economy
var updates
var profile: Dictionary = {}
var busy := false
var issue := ""
var root_path := "user://standalone-session"
var sync_elapsed := 0.0
var online_ready := false
var epoch := 0
var _quiesced := false
var _interactive_login := false
var _background_busy := false
var _startup_pending := true
var _initializing := false
var _session_end_pending := false

func setup(application, native_platform: Object = null, settings: Dictionary = {}) -> void:
	app = application
	platform = native_platform
	if platform == null and Engine.has_singleton("RuneNexusPlatform"): platform = Engine.get_singleton("RuneNexusPlatform")
	config = settings
	if config.is_empty() and FileAccess.file_exists("res://app_config.json"):
		var parsed: Variant = Json.parse(FileAccess.get_file_as_string("res://app_config.json"))
		if parsed is Dictionary: config = parsed
	if platform != null: root_path = platform.application_support_path()
	# Native support directory matches the former app, so no destructive copying.
	if platform != null:
		app.checkpoint = Checkpoint.new(root_path)
		app.checkpoint.allow_progression_only = true
		if platform.has_method("legacy_save_path"): app.checkpoint.store.legacy_path = platform.legacy_save_path()
	updates = load("res://services/update_service.gd").new()
	add_child(updates)
	updates.setup(platform,str(config.get("updateManifestUrl","")))
	updates.changed.connect(_update_changed)
	if config.get("apiBaseUrl", "").is_empty():
		_initialize.call_deferred()
		return
	account = load("res://services/account_session.gd").new()
	add_child(account)
	account.configure(config.apiBaseUrl, platform)
	account.changed.connect(_account_changed)
	economy = Economy.new()
	add_child(economy)
	economy.changed.connect(func():
		if economy.issue == "CLIENT_UPDATE_REQUIRED": updates.require_update()
		changed.emit())
	_initialize.call_deferred()

func connected() -> bool:
	return account != null and not account.credentials.is_empty()

func needs_profile() -> bool:
	return connected() and (not profile.get("nickname") is String or profile.nickname.is_empty())

func blocks_play() -> bool:
	return (busy and not _background_busy) or needs_profile() or (connected() and (not online_ready or app.checkpoint.owner != str(account.credentials.accountId).to_lower())) or (updates != null and updates.blocked)

func _update_changed() -> void:
	if online != null: online.set_process(not updates.blocked)
	if account != null: account.set_process(not updates.blocked)
	if updates.blocked and app.lobby != null:
		if not app.startup_blocked: app.pause_and_save()
		app.in_lobby = true
		app._refresh_ui()
		app.lobby._service("업데이트")
	elif not updates.blocked:
		# Home refresh deliberately preserves open modals. Retire this gate's
		# stale busy view when the check succeeds, without closing another dialog.
		if app.lobby != null and is_instance_valid(app.lobby.modal) and app.lobby.modal.get_meta("service_page", "") == "업데이트":
			app.lobby.close_modal(true)
		if _startup_pending and not _initializing: _initialize.call_deferred()
	changed.emit()

func _account_changed() -> void:
	# A definitive timer-driven refresh failure removes account authority.
	# Defer slot changes until the authentication operation has completed.
	if not connected() and account.account_id_hint.is_empty():
		_session_end_pending = true
		_handle_session_end.call_deferred()
	changed.emit()

func _handle_session_end() -> void:
	if busy: return
	if connected() or not account.account_id_hint.is_empty() or app.checkpoint.owner == "guest":
		_session_end_pending = false
		return
	if not app.startup_blocked and not app.pause_and_save():
		issue = "LOCAL_SAVE_FAILED"
		return
	epoch += 1
	online_ready = false
	economy.invalidate()
	if online != null: online.dispose()
	profile = {}
	if not _load_slot("guest"): issue = "GUEST_SAVE_LOAD_FAILED"
	_session_end_pending = false
	_quiesced = false
	changed.emit()

func configured() -> bool:
	return platform != null and account != null and not config.get("googleClientId", "").is_empty()

func _initialize() -> void:
	if _initializing or not _startup_pending: return
	_initializing = true
	busy = true
	if updates != null and updates.blocked: await updates.check()
	if updates != null and updates.blocked:
		busy = false
		_initializing = false
		_update_changed()
		return
	# No local record, secure session or server state is touched before the gate.
	if app.startup_blocked and not app.retry_load():
		busy = false
		_initializing = false
		issue = "LOCAL_SAVE_LOAD_FAILED"
		changed.emit()
		return
	var result := {"ok":true}
	if platform != null and account != null:
		result = await account.restore()
		if result.get("ok",false) and connected(): result = await _bind(false)
		elif not account.account_id_hint.is_empty():
			if not _load_slot(account.account_id_hint): result = {"ok":false,"code":"ACCOUNT_SAVE_LOAD_FAILED"}
	_startup_pending = false
	_initializing = false
	busy = false
	issue = "" if result.get("ok",false) else str(result.get("code", ""))
	changed.emit()
	if needs_profile() and app.lobby != null: app.lobby._service("계정 및 저장")

func login() -> Dictionary:
	if updates != null and updates.blocked: return {"ok":false,"code":"CLIENT_UPDATE_REQUIRED"}
	if busy or (economy != null and economy.busy): return {"ok":false,"code":"BUSY"}
	if not configured(): return {"ok":false,"code":"LOGIN_UNAVAILABLE"}
	if not app.startup_blocked and not app.pause_and_save(): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	busy = true
	changed.emit()
	var result: Dictionary
	if not platform.sign_in_google(config.googleClientId):
		result = {"ok":false,"code":"GOOGLE_SIGN_IN_FAILED"}
	else:
		var raw: String = await platform.google_sign_in_completed
		var native: Variant = Json.parse(raw)
		if not native is Dictionary or not native.get("ok",false): result = {"ok":false,"code":str(native.get("error","GOOGLE_SIGN_IN_FAILED")) if native is Dictionary else "GOOGLE_SIGN_IN_FAILED"}
		else:
			result = await account.sign_in(str(native.get("idToken", "")))
			if result.get("ok",false): result = await _bind(true)
	busy = false
	issue = "" if result.get("ok",false) else str(result.get("code","LOGIN_FAILED"))
	app._refresh_ui()
	changed.emit()
	return result

func _bind(interactive: bool) -> Dictionary:
	epoch += 1
	var binding := epoch
	online_ready = false
	economy.invalidate()
	profile = {}
	if online != null:
		online.dispose()
		online.queue_free()
		online = null
	_interactive_login = interactive
	var loaded: Dictionary = await account.request("GET","v1/account/profile")
	if binding != epoch: return {"ok":false,"code":"STALE_BINDING"}
	if not loaded.get("ok",false): return loaded
	profile = loaded.body
	if needs_profile(): return {"ok":true,"code":"NICKNAME_REQUIRED"}
	var guest: Dictionary = {}
	if interactive and app.checkpoint.owner == "guest":
		var saved: Variant = app.checkpoint.store.load_save()
		if saved is Dictionary: guest = saved
	online = load("res://services/online_save.gd").new()
	add_child(online)
	online.configure(account, root_path, str(config.get("clientBuild","godot-local")), {"quiesce":_quiesce,"resume":_resume})
	online.changed.connect(_online_changed)
	var result: Dictionary = await online.bootstrap(guest,interactive)
	if binding != epoch: return {"ok":false,"code":"STALE_BINDING"}
	if not result.get("ok",false): return result
	if not _load_slot(str(account.credentials.accountId)): return {"ok":false,"code":"ACCOUNT_SAVE_LOAD_FAILED"}
	online.acknowledge_reload()
	online_ready = true
	_interactive_login = false
	economy.configure(account,app.checkpoint.rewards(),{"sync":sync,"snapshot":_apply_snapshot,"receipt":_apply_receipt,"effect":_apply_effect})
	return await economy.refresh()

func _load_slot(owner: String) -> bool:
	app.startup_blocked = true
	app.checkpoint = Checkpoint.new(root_path,owner)
	app.checkpoint.allow_progression_only = true
	app.run_domain.state = {}
	app.progression_inputs = {}
	app.scene._native_combat.active = false
	app.in_lobby = true
	app.save_failed = false
	app.epoch += 1
	app.scene._apply_frame({"reset":true,"sceneEpoch":app.epoch})
	return app.retry_load()

func logout() -> Dictionary:
	if updates != null and updates.blocked: return {"ok":false,"code":"CLIENT_UPDATE_REQUIRED"}
	if busy or (economy != null and economy.busy): return {"ok":false,"code":"BUSY"}
	if not app.startup_blocked and not app.pause_and_save(): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	busy = true
	epoch += 1
	economy.invalidate()
	online_ready = false
	var result: Dictionary = await account.logout()
	if account.credentials.is_empty():
		profile = {}
		_interactive_login = false
		if online != null and online.has_method("dispose"): online.dispose()
		if not _load_slot("guest"): result = {"ok":false,"code":"GUEST_SAVE_LOAD_FAILED"}
		_quiesced = false
		if platform != null: platform.sign_out_google()
	busy = false
	issue = "" if result.get("ok",false) else str(result.get("code","LOGOUT_PENDING"))
	changed.emit()
	return result

func sync() -> Dictionary:
	if updates != null and updates.blocked: return {"ok":false,"code":"CLIENT_UPDATE_REQUIRED"}
	if not connected() or not online_ready: return {"ok":false,"code":"ACCOUNT_REQUIRED"}
	if not app.persist_progression(): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	var payload: Variant = app.checkpoint.store.load_save()
	if not payload is Dictionary: return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	var result: Dictionary = await online.sync(payload)
	if online.requires_reload and online.state.get("rebase") == null:
		if not _load_slot(str(account.credentials.accountId)): return {"ok":false,"code":"ACCOUNT_SAVE_LOAD_FAILED"}
		economy.outbox = app.checkpoint.rewards()
		online.acknowledge_reload()
	return result

func retry() -> Dictionary:
	if updates != null and updates.blocked: return {"ok":false,"code":"CLIENT_UPDATE_REQUIRED"}
	if account == null: return {"ok":false,"code":"LOGIN_UNAVAILABLE"}
	if busy: return {"ok":false,"code":"BUSY"}
	busy = true
	var result: Dictionary
	if connected():
		if not online_ready: result = await _bind(_interactive_login)
		else:
			result = await online.foreground()
			if result.get("ok",false) and online.requires_reload:
				if not _load_slot(str(account.credentials.accountId)): result = {"ok":false,"code":"ACCOUNT_SAVE_LOAD_FAILED"}
				else:
					economy.outbox = app.checkpoint.rewards()
					online.acknowledge_reload()
			if result.get("ok",false): result = await economy.refresh()
	else:
		result = await account.restore()
		if result.get("ok",false) and connected(): result = await _bind(false)
	busy = false
	issue = "" if result.get("ok",false) else str(result.get("code","SYNC_FAILED"))
	if issue == "CLIENT_UPDATE_REQUIRED": updates.require_update()
	changed.emit()
	return result

func perform(action: String, values: Dictionary = {}) -> Dictionary:
	if updates != null and updates.blocked: return {"ok":false,"code":"CLIENT_UPDATE_REQUIRED"}
	if busy or not online_ready: return {"ok":false,"code":"ACCOUNT_REQUIRED" if not connected() else "SAVE_SYNC_REQUIRED"}
	var result: Dictionary = await economy.execute(action,values)
	issue = "" if result.get("ok",false) else str(result.get("code","REQUEST_FAILED"))
	app._refresh_ui()
	changed.emit()
	return result

func request(method: String, path: String, body: Dictionary = {}) -> Dictionary:
	if updates != null and updates.blocked: return {"ok":false,"code":"CLIENT_UPDATE_REQUIRED"}
	if not connected(): return {"ok":false,"code":"ACCOUNT_REQUIRED"}
	var nickname := path.trim_prefix("/") == "v1/account/nickname"
	if nickname and (busy or economy.busy): return {"ok":false,"code":"BUSY"}
	var binding := epoch
	if nickname:
		busy = true
		changed.emit()
	var result: Dictionary = await account.request(method,path,"" if body.is_empty() else JSON.stringify(body))
	if binding != epoch:
		if nickname: busy = false
		return {"ok":false,"code":"STALE_BINDING"}
	# A nickname is immutable; a lost success can be recovered by reading profile.
	if nickname and (result.get("ok",false) or result.get("code") == "NICKNAME_ALREADY_SET"):
		result = await _bind(_interactive_login)
	if nickname:
		busy = false
		issue = "" if result.get("ok",false) else str(result.get("code","PROFILE_FAILED"))
		changed.emit()
	return result

func _online_changed() -> void:
	if online == null: return
	var code := str(online.state.get("issueCode", "")) if online.state.get("issueCode") != null else ""
	if not code.is_empty(): issue = code
	if code == "CLIENT_UPDATE_REQUIRED" and updates != null and not updates.server_required:
		updates.require_update()
	changed.emit()

func _quiesce() -> bool:
	if not app.startup_blocked and not app.pause_and_save(): return false
	_quiesced = true
	app.startup_blocked = true
	return true

func _resume() -> void:
	# Loading the authoritative checkpoint is the only way to resume after rebase.
	if _quiesced and online != null and not online.requires_reload: app.startup_blocked = false
	_quiesced = false

func _apply_snapshot(value: Dictionary) -> bool:
	if not app.checkpoint.apply_economy_snapshot(app,value): return false
	app._refresh_ui()
	return true

func _store_progression(value: Dictionary) -> bool:
	if app.run_domain.state.is_empty() or not app.scene._native_combat.active:
		if app.checkpoint.save_progression(app,value) != OK: return false
		app.progression_inputs = value
	else:
		var candidate: Dictionary = app.run_domain.state.duplicate(true)
		candidate.progression = value
		var refreshed: Dictionary = app.run_domain.service.refresh(candidate)
		if app.checkpoint.persist_state(app,refreshed.state) != OK: return false
		app.run_domain.state = refreshed.state
		app.progression_inputs = value
		if not app.command(refreshed.get("commands",[])): return false
	return true

func _apply_receipt(receipt: Dictionary) -> bool:
	var p: Dictionary = app.progression_inputs
	var period: String = receipt.period
	var weekly := period == "weekly"
	var key: String = "weeklyQuestWeekKey" if weekly else "dailyQuestDayKey"
	var receipt_key: String = "weekKey" if weekly else "dayKey"
	# Old receipts are durable server outcomes; do not reapply to a new period.
	if int(p.get(key,-1)) != int(receipt.get(receipt_key,-2)): return true
	var claimed: Array = p.get("claimedWeeklyQuestRewards" if weekly else "claimedDailyQuestRewards",[])
	if receipt.rewardType == "quest" and receipt.get("questType") in claimed: return true
	if receipt.rewardType == "all_complete" and p.get(period+"QuestAllCompleteClaimed",false): return true
	if receipt.rewardType == "attendance" and p.get(period+"AttendanceRewardClaimed",false): return true
	var mapped: Dictionary = Quests.new().apply_receipt(p,receipt)
	return mapped.ok and _store_progression(mapped.progression)

func _apply_effect(effect: Dictionary) -> bool:
	if effect.get("effectType") != "complete_research": return false
	var payload: Dictionary = effect.get("payload",{})
	var id: String = payload.get("researchType","")
	var level := int(payload.get("targetLevel",0))
	if level <= 0: return false
	var p: Dictionary = app.progression_inputs.duplicate(true)
	if id == "bossBounty":
		p.bossBountyUpgradeLevel = maxi(int(p.get("bossBountyUpgradeLevel",0)),mini(level,20))
		p.researchLevels.erase(id)
	elif app.run_domain.growth.data.research.has(id):
		level = mini(level,int(app.run_domain.growth.data.research[id].maxLevel))
		p.researchLevels[id] = maxi(level,int(p.researchLevels.get(id,0)))
	else: return false
	p.activeResearches = p.get("activeResearches",[]).filter(func(r): return r.type != id or (id != "bossBounty" and int(r.targetLevel) > level))
	p.researchElapsedMillis.erase(id)
	return _store_progression(p)

func _process(delta: float) -> void:
	if updates != null and updates.blocked: return
	if _session_end_pending and not busy: _handle_session_end()
	if not busy and connected() and online_ready and online != null and online.requires_reload and online.state.get("rebase") == null:
		if not _load_slot(str(account.credentials.accountId)):
			issue = "ACCOUNT_SAVE_LOAD_FAILED"
			online_ready = false
			return
		economy.outbox = app.checkpoint.rewards()
		online.acknowledge_reload()
	if busy or not online_ready or not connected() or economy.busy or app.startup_blocked: return
	sync_elapsed += delta
	if sync_elapsed < 30.0: return
	sync_elapsed = 0.0
	_background_sync()

func _background_sync() -> void:
	_background_busy = true
	busy = true
	var result: Dictionary = await sync()
	if result.get("ok",false): result = await economy.refresh()
	busy = false
	_background_busy = false
	issue = "" if result.get("ok",false) else str(result.get("code","SYNC_FAILED"))
	changed.emit()
