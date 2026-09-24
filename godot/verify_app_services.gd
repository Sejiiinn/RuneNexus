extends SceneTree
const Services = preload("res://services/app_services.gd")
const Auth = preload("res://services/account_session.gd")
const Economy = preload("res://services/economy_service.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Codec = preload("res://app/save_codec.gd")
const Json = preload("res://app/save_json.gd")
const Http = preload("res://services/http_transport.gd")
const Growth = preload("res://app/growth_rules.gd")
const UI = preload("res://ui/lobby_services.gd")
const ACCOUNT_A = "00000000-0000-4000-8000-000000000001"
const ACCOUNT_B = "00000000-0000-4000-8000-000000000002"
var failures: Array[String] = []
var folder: String
var app
var service
var server
var platform

class ModalLobby extends "res://ui/lobby.gd":
	func _ready(): pass

class Platform extends Node:
	signal google_sign_in_completed(raw: String)
	var value: Variant = null
	var reads := 0
	var selected := "a"
	func session_read(): reads+=1; return {"ok":true,"value":value}
	func session_write(raw): value = raw; return {"ok":true}
	func session_delete(): value = null; return {"ok":true}
	func sign_in_google(_id):
		google_sign_in_completed.emit.call_deferred(JSON.stringify({"ok":true,"idToken":selected}))
		return true
	func sign_out_google(): return true

class GateFixture extends Node:
	signal changed
	var blocked := true
	var mandatory := true
	var server_required := false
	func check() -> Dictionary:
		await get_tree().process_frame
		return {"ok":false,"code":"UPDATE_CHECK_FAILED"}
	func skip() -> void:
		if mandatory: return
		blocked=false
		changed.emit()

class ModalUpdateFixture extends "res://services/update_service.gd":
	var accepted := true
	func _check() -> Dictionary:
		await get_tree().process_frame
		blocked = not accepted
		if accepted: message = "최신 버전입니다"
		return {"ok":accepted}

class FixtureServer extends RefCounted:
	var tree: SceneTree
	var calls: Array = []
	var nickname: Variant = null
	var active := ACCOUNT_A
	var revision := 0
	var writer := 0
	var save: Variant = null
	var offline := false
	var fail_profile := false
	var economy_revision := 0
	var effects: Array = []
	var settled: Array = []
	var claims: Array = []
	func economy_snapshot() -> Dictionary:
		return {"authorityState":"server_authoritative","authorityEpoch":"fixture-epoch","authorityVersion":1,"catalogVersion":1,"economyRevision":economy_revision,"serverTime":"2026-09-24T00:00:00Z","wallet":{"freeDiamonds":42+settled.size()*3,"paidDiamonds":2,"moduleTickets":0},"turretModules":{"drawCount":0,"ticketPurchaseCount":0,"items":[]},"entitlements":{"researchSlotTwoUnlocked":false},"pendingProgressionEffects":effects.duplicate(true),"claimedRewardKeys":[]}
	func reply(status: int, body: Dictionary = {}, code := "") -> Dictionary:
		return {"ok":status>=200 and status<300,"status":status,"body":body,"code":code,"retryable":status==0 or status>=500}
	func request(method, url, raw := "", headers := {}) -> Dictionary:
		var path: String = url.trim_prefix("http://127.0.0.1:19764")
		var body: Variant = {} if raw.is_empty() else Json.parse(raw)
		calls.append({"method":method,"path":path,"raw":raw,"headers":headers.duplicate(true)})
		await tree.process_frame
		if offline: return reply(0,{},"NETWORK_UNAVAILABLE")
		if path.ends_with("/google") or path.ends_with("/refresh"):
			if path.ends_with("/google"): active = ACCOUNT_B if body.idToken == "b" else ACCOUNT_A
			return reply(200,{"account":{"id":active},"accessToken":"fixture-access","refreshToken":"fixture-refresh","accessExpiresAt":"2099-01-01T00:00:00Z"})
		if path.ends_with("/logout"): return reply(204)
		if path == "/v1/account/nickname": nickname = body.nickname; return reply(200,{"nickname":nickname,"tag":"0012"})
		if path == "/v1/account/profile":
			if fail_profile: return reply(503,{},"NETWORK_UNAVAILABLE")
			return reply(200,{"nickname":nickname,"tag":"0012" if nickname != null else null})
		if path == "/v1/save/writer": writer+=1; return reply(200,{"writerGeneration":writer,"claimedAt":"2026-09-24T00:00:00Z"})
		if path == "/v1/save":
			if method == HTTPClient.METHOD_GET:
				if save == null: return reply(404,{},"SAVE_NOT_FOUND")
				if headers.get("If-None-Match") == '"rn-save-%d"' % revision: return reply(304)
				return reply(200,{"revision":revision,"serverSavedAt":"2026-09-24T00:00:00Z","data":save.duplicate(true)})
			if body.expectedRevision != revision: return reply(409,{},"SAVE_REVISION_CONFLICT")
			revision+=1
			save=body.data.duplicate(true)
			return reply(200,{"revision":revision,"serverSavedAt":"2026-09-24T00:00:00Z"})
		if path == "/v1/economy":
			return reply(409,{},"ECONOMY_NOT_BOOTSTRAPPED") if economy_revision==0 else reply(200,economy_snapshot())
		if path == "/v1/economy/bootstrap": economy_revision=1; return reply(200,{"economy":economy_snapshot()})
		if path == "/v1/economy/runs/settle":
			if not body.runId in settled: settled.append(body.runId); economy_revision+=1
			return reply(200,{"economy":economy_snapshot()})
		if path.contains("/progression-effects/") and path.ends_with("/ack"):
			effects.clear(); economy_revision+=1
			return reply(200,{"economy":economy_snapshot()})
		if path == "/v1/economy/rewards/claim":
			claims.append(body.duplicate(true))
			return reply(200,{"weekKey":99,"rewardType":body.rewardType,"diamonds":5,"moduleTickets":0})
		return reply(500,{},"UNEXPECTED_FIXTURE_ENDPOINT")

class SceneStub extends RefCounted:
	var _native_combat := {"active":false}
	func _apply_frame(_frame): pass
class DomainStub extends RefCounted:
	var state := {}
	var growth = Growth.new()
	var now_millis: Callable = func(): return 1800000000000
class AppStub extends RefCounted:
	var checkpoint
	var catalog = preload("res://content/content_catalog.gd").new()
	var progression_inputs := {}
	var scene = SceneStub.new()
	var run_domain = DomainStub.new()
	var startup_blocked := false
	var save_failed := false
	var in_lobby := true
	var epoch := 0
	var lobby = null
	var services
	var persist_count := 0
	var retry_count := 0
	func _refresh_ui():
		if is_instance_valid(lobby): lobby.refresh()
	func retry_load() -> bool:
		retry_count+=1
		var data: Variant = checkpoint.store.load_save()
		if data == null: data = Codec.decode({"version":2,"preferences":{},"progression":{},"turretModules":{},"activeRun":null})
		progression_inputs=data.progression.duplicate(true)
		progression_inputs.turretModules=data.turretModules.duplicate(true)
		checkpoint.preferences=data.preferences.duplicate(true)
		startup_blocked=false
		return checkpoint.rewards().loaded
	func persist_progression() -> bool:
		persist_count+=1
		return not startup_blocked and checkpoint.save_progression(self,progression_inputs)==OK
	func pause_and_save() -> bool: return persist_progression()

func _initialize():
	folder=OS.get_environment("RUNE_APP_TEST_ROOT")
	if folder.is_empty(): quit(2); return
	_run.call_deferred()
func check(value: bool, label: String):
	if not value: failures.append(label); push_error(label)
func _run():
	await _gate_checks()
	await _update_modal_checks()
	app=AppStub.new()
	app.run_domain.growth.load_catalog()
	app.checkpoint=Checkpoint.new(folder)
	app.retry_load()
	app.progression_inputs.runes=27
	app.persist_progression()
	platform=Platform.new();root.add_child(platform)
	server=FixtureServer.new();server.tree=self
	service=Services.new();service.app=app;service.root_path=folder;service.platform=platform;service.config={"googleClientId":"fixture-client"};root.add_child(service);service.set_process(false)
	app.services=service
	service.account=Auth.new();service.add_child(service.account);service.account.configure("http://127.0.0.1:19764",platform,server)
	service.economy=Economy.new();service.add_child(service.economy)
	var result: Dictionary=await service.login()
	check(result.ok and service.needs_profile() and service.blocks_play(),"Nickname required blocks play before account bootstrap")
	check(app.checkpoint.owner=="guest" and server.calls.all(func(call):return not call.path.begins_with("/v1/save")),"Nickname gate does not publish or overwrite guest save")
	result=await service.request("PUT","v1/account/nickname",{"nickname":"룬기사"})
	check(result.ok and service.online_ready and app.checkpoint.owner==ACCOUNT_A and not service.blocks_play(),"Nickname commit binds real online store and unlocks play")
	check(server.save.progression.runes==27 and app.progression_inputs.freeDiamonds==42,"Interactive bootstrap adopts guest progress and server wallet")
	# Pending runtime rewards must use the current synced revision and writer.
	var reward={"runId":Http.uuid(),"stageNumber":1,"completedRounds":2,"success":false,"pendingDiamonds":3,"firstClearModuleTickets":0,"createdAtMillis":1}
	app.checkpoint.rewards().enqueue(reward)
	result=await service.economy.refresh()
	check(result.ok and server.settled.size()==1 and app.checkpoint.rewards().state.pendingRewards.is_empty() and app.progression_inputs.freeDiamonds==45,"Run outbox settles and applies server wallet through real checkpoint")
	result=await service.economy.refresh()
	check(result.ok and server.settled.size()==1,"Refreshing cannot pay the same run twice")
	server.effects=[{"id":Http.uuid(),"effectType":"complete_research","payload":{"researchType":"researchEfficiency","targetLevel":1}}]
	server.economy_revision+=1
	result=await service.economy.refresh()
	check(result.ok and app.progression_inputs.researchLevels.get("researchEfficiency")==1 and server.effects.is_empty(),"Progression effect saves, syncs, and acknowledges")
	app.progression_inputs.dailyQuestDayKey=99
	app.persist_progression()
	result=await service.perform("claim_reward",{"period":"daily","rewardType":"attendance"})
	check(result.ok and app.progression_inputs.dailyAttendanceRewardClaimed,"Daily receipt updates persisted claim flag")
	# An automatic remote rebase must replace live progression before unquiescing.
	server.save.progression.runes=333
	server.revision+=1
	service.online._reconcile=true
	result=await service.online.sync()
	check(result.ok and service.online.requires_reload and app.startup_blocked,"Automatic sync quiesces before applying newer remote")
	service._process(0)
	check(not service.online.requires_reload and not app.startup_blocked and app.progression_inputs.runes==333,"Automatic rebase reloads checkpoint and acknowledges")
	server.offline=true
	result=await service.logout()
	check(not result.ok and not service.connected() and app.checkpoint.owner=="guest" and Json.parse(platform.value).logoutPending,"Offline logout changes slot while preserving server revoke intent")
	server.offline=false
	result=await service.account.restore()
	check(result.ok and platform.value==null,"Next restore finishes offline logout")
	# Profile failure after interactive login must retain guest-adoption intent.
	platform.selected="b";server.active=ACCOUNT_B;server.save=null;server.revision=0;server.economy_revision=0;server.effects=[];server.settled=[];server.nickname="새계정";server.fail_profile=true
	result=await service.login()
	check(not result.ok and service.blocks_play() and app.checkpoint.owner=="guest","Failed profile lookup prevents cross-account play")
	server.fail_profile=false
	result=await service.retry()
	check(result.ok and app.checkpoint.owner==ACCOUNT_B and server.save.progression.runes==27,"Retry retains interactive bootstrap intent for new account")
	service._background_busy=true;service.busy=true
	check(not service.blocks_play(),"Background synchronization does not disable gameplay controls")
	service._background_busy=false;service.busy=false
	await _ui_checks()
	# Initial offline restore selects only the bound local account slot.
	server.offline=true
	service.account.credentials.clear()
	service.online_ready=false
	await service._initialize()
	check(app.checkpoint.owner==ACCOUNT_B and not service.connected() and service.account.account_id_hint==ACCOUNT_B,"Offline restore selects bound cached account, never guest")
	service.account.account_id_hint=""
	service.busy=true
	service._account_changed()
	await process_frame
	check(app.checkpoint.owner==ACCOUNT_B,"Session expiry waits for an active operation to finish")
	service.busy=false
	service._process(0)
	check(app.checkpoint.owner=="guest" and not service.online_ready,"Deferred definitive session expiry invalidates economy and switches to guest")
	service.online.dispose()
	service.queue_free();platform.queue_free()
	await process_frame
	print("APP_SERVICES failures=",failures.size()," ",failures)
	quit(0 if failures.is_empty() else 1)

func _labels(node: Node) -> Array[String]:
	var result: Array[String]=[]
	if node is Label or node is Button: result.append(node.text)
	for child in node.get_children(): result.append_array(_labels(child))
	return result

func _update_modal_checks() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	var gated_app=AppStub.new()
	gated_app.catalog.load_catalog()
	gated_app.run_domain.growth.load_catalog()
	gated_app.startup_blocked=true
	var gated=Services.new();root.add_child(gated)
	gated.set_process(false);gated.app=gated_app;gated._startup_pending=false
	gated_app.services=gated
	# Run the actual home refresh path, including its kept_modal preservation.
	var lobby=load("res://ui/lobby.gd").new();lobby.app=gated_app;lobby.size=Vector2(440,760);root.add_child(lobby)
	gated_app.lobby=lobby
	var update=ModalUpdateFixture.new();gated.add_child(update)
	update.setup(RefCounted.new(),"https://fixture.invalid/update.json")
	gated.updates=update;update.changed.connect(gated._update_changed)
	update.check()
	check(update.busy and is_instance_valid(lobby.modal) and "업데이트 정보를 확인하고 있습니다" in _labels(lobby.modal),"Initial update check opens busy gate modal")
	await process_frame;await process_frame
	check(not update.busy and not update.blocked and not is_instance_valid(lobby.modal),"Automatic initial success removes stale busy modal")
	lobby.refresh()
	check(not is_instance_valid(lobby.modal),"Home refresh cannot preserve the finished gate")
	update.accepted=false
	await update.check()
	check(update.blocked and is_instance_valid(lobby.modal) and update.message in _labels(lobby.modal),"Failed check keeps retryable failure modal")
	lobby.close_modal()
	check(is_instance_valid(lobby.modal),"Failed gate remains mandatory")
	update.accepted=true
	await lobby._services._update_action()
	check(not is_instance_valid(lobby.modal),"Manual retry success cannot recreate the completed gate after await")
	lobby._service("업데이트")
	lobby._services._update_action()
	lobby.open_modal("다른 화면의 대화상자")
	var replacement=lobby.modal
	await process_frame;await process_frame
	check(lobby.modal==replacement and is_instance_valid(replacement),"Await from an old update view cannot overwrite its replacement")
	lobby.open_modal("다른 대화상자")
	var other=lobby.modal
	update.changed.emit()
	check(lobby.modal==other and is_instance_valid(other),"Unblocked notification leaves unrelated modal open")
	update.blocked=true
	update.release={"versionCode":2,"versionName":"fixture","notes":"","minimumSupportedVersionCode":2}
	update.installed={"versionCode":1}
	update.changed.emit()
	update.skip()
	check(update.blocked and is_instance_valid(lobby.modal),"Required update still cannot skip its modal")
	update.release.minimumSupportedVersionCode=0
	update.skip()
	check(not update.blocked and not is_instance_valid(lobby.modal),"Optional skip closes only the update modal")
	lobby.queue_free();gated.queue_free()
	await process_frame

func _ui_checks() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	service.updates=load("res://services/update_service.gd").new()
	service.add_child(service.updates)
	service.updates.setup(null,"")
	var lobby=ModalLobby.new()
	lobby.app=app
	lobby.size=Vector2(440,760)
	root.add_child(lobby)
	var ui=UI.new();ui.lobby=lobby
	var prior: Dictionary=service.profile.duplicate(true)
	service.profile={"nickname":null}
	ui.open("계정 및 저장")
	ui._render();ui._render()
	await process_frame
	await process_frame
	check(lobby.get_children().filter(func(node):return node is Control).size()==1,"Mandatory nickname rerenders keep one modal")
	lobby.close_modal()
	check(is_instance_valid(lobby.modal),"Nickname modal cannot be dismissed before profile exists")
	service.profile=prior
	service.updates.blocked=true
	ui.open("업데이트");ui._render()
	await process_frame
	await process_frame
	check(lobby.get_children().filter(func(node):return node is Control).size()==1,"Mandatory update replacement keeps one modal")
	lobby.close_modal()
	check(is_instance_valid(lobby.modal),"Required update modal cannot be dismissed")
	service.updates.blocked=false
	check(lobby.diamonds()==44,"Paid and free wallet fields supply UI balance")
	ui.open("모듈 뽑기",{"count":1,"turretType":"arrow"})
	check("모듈 1개를 획득합니다. 모듈권 0장 · 다이아 40개" in _labels(lobby.modal),"Draw confirmation displays server contract cost")
	ui.data={"economy":server.economy_snapshot(),"drawnModules":[{"grade":"rare","turretType":"arrow","part":"core"}]}
	ui._render()
	check("희귀 · 기관총 · 코어" in _labels(lobby.modal) and not "확인" in _labels(lobby.modal),"Draw success shows localized result without duplicate purchase button")
	ui.open("연구 슬롯 구매")
	check(_labels(lobby.modal).any(func(text):return text.begins_with("필요 다이아 ") and "보유 44" in text),"Research service displays actual cost and combined balance")
	lobby.queue_free()
	await process_frame

func _gate_checks() -> void:
	var gated_app=AppStub.new()
	gated_app.checkpoint=Checkpoint.new(folder.path_join("update-gate"))
	gated_app.startup_blocked=true
	var secure=Platform.new();root.add_child(secure)
	var wire=FixtureServer.new();wire.tree=self
	var gated=Services.new();root.add_child(gated);gated.set_process(false)
	gated.app=gated_app;gated.platform=secure;gated.root_path=folder.path_join("update-gate")
	gated.account=Auth.new();gated.add_child(gated.account);gated.account.configure("http://127.0.0.1:19764",secure,wire)
	gated.updates=GateFixture.new();gated.add_child(gated.updates)
	gated.updates.changed.connect(gated._update_changed)
	await gated._initialize()
	check(gated_app.retry_count==0 and gated_app.persist_count==0 and secure.reads==0 and wire.calls.is_empty(),"Failed initial update check touches neither local save, secure session nor API")
	gated.updates.skip()
	await process_frame
	check(gated_app.retry_count==0 and secure.reads==0,"Required update cannot skip initialization gate")
	gated.updates.mandatory=false
	gated.updates.skip()
	await process_frame;await process_frame;await process_frame
	check(gated_app.retry_count==1 and secure.reads==1 and not gated._startup_pending,"Optional update skip initializes local save and secure restore once")
	gated.updates.changed.emit()
	await process_frame
	check(gated_app.retry_count==1 and secure.reads==1,"Repeated gate notification cannot duplicate initialization")
	gated.queue_free();secure.queue_free()
	await process_frame
