extends SceneTree
## Formal controller contract with real checkpoint/runtime and deterministic authority.
const App = preload("res://app/app_lifecycle.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Fixture = preload("res://verify_run_transition.gd")
const Id = preload("res://app/reward_settlement.gd")
const ACCOUNT := "00000000-0000-4000-8000-000000000001"
const SERVER_RUN := "00000000-0000-4000-8000-000000000901"
class Host extends Fixture.Host:
	func request_stage_preparation_cancel() -> void: pass
class LiveApp extends App:
	func _ready() -> void: pass
class Online extends RefCounted:
	var state: Dictionary = {}
class Economy extends RefCounted:
	var snapshot := {"run":null, "gemOfferVersion":1}
	var busy := false
class Services extends RefCounted:
	signal release
	var app
	var online = Online.new()
	var economy = Economy.new()
	var updates = null
	var boot_host = null
	var online_ready := true
	var busy := false
	var authenticated := true
	var requests: Array = []
	var closed_runs: Array = []
	var failures: Array = []
	var fail_action := ""
	var hold_action := ""
	var recover_start := false
	var chosen := false
	var next_run := 901
	func connected() -> bool: return authenticated
	func blocks_play() -> bool: return not authenticated
	func request_run_settlement(_retry := false) -> void: pass
	func sync() -> Dictionary:
		return {"ok":app.persist_progression()}
	func _canonical(saved: Dictionary) -> bool:
		if app.checkpoint.store.save_save(saved) != OK: return false
		app.startup_blocked = true
		app.run_domain.state = {}
		app.scene.combat_runtime.active = false
		return app.retry_load()
	func _start() -> Dictionary:
		var saved: Dictionary = app.checkpoint.store.load_save()
		if saved.get("activeRun") == null or saved.activeRun.get("economyRunId") not in [null, ""] or not app.scene.combat_runtime.session.paused:
			failures.append("start requires paused pristine empty-ID checkpoint")
		var identity := "00000000-0000-4000-8000-%012d" % next_run
		next_run += 1
		saved.activeRun.economyRunId = identity
		economy.snapshot.run = {"runId":identity,"stageNumber":saved.activeRun.stageNumber,"status":"active"}
		var ok := _canonical(saved)
		return {"ok":ok,"body":{"run":economy.snapshot.run.duplicate()}}
	func perform(action: String, values: Dictionary = {}) -> Dictionary:
		requests.append({"action":action,"values":values.duplicate(true)})
		if action == hold_action: await release
		if action == fail_action: return {"ok":false,"code":"NETWORK_UNAVAILABLE"}
		if action == "start_run": return _start()
		if action == "close_run":
			var saved: Dictionary = app.checkpoint.store.load_save()
			if not saved.activeRun is Dictionary or saved.activeRun.economyRunId != values.runId or saved.activeRun.phase not in ["success","failure"]:
				failures.append("close requires durable matching terminal checkpoint")
			closed_runs.append(saved.activeRun.duplicate(true))
			var box = app.checkpoint.rewards()
			var next: Dictionary = box.state.duplicate(true)
			if not next.has("completedRunIds"): next.completedRunIds = []
			for reward in next.pendingRewards:
				if reward.runId not in next.completedRunIds: next.completedRunIds.append(reward.runId)
			next.pendingRewards = []
			box.save_state(next)
			saved.activeRun = null
			economy.snapshot.run = null
			return {"ok":_canonical(saved),"body":{"run":{"runId":values.runId,"status":"closed"}}}
		if action == "refresh" and recover_start:
			recover_start = false
			var result := _start()
			var box = app.checkpoint.rewards()
			var next: Dictionary = box.state.duplicate(true)
			next.inFlight = null
			box.save_state(next)
			return result
		if action == "purchase_gems":
			if not app.scene.combat_runtime.session.paused: failures.append("purchase must pause combat before authority sync")
			var return_phase: String = app.run_domain.state.phase
			app.run_domain.state.merge({"phase":"reward","rewardReturnPhase":return_phase,"isPurchasedGemReward":true,"gemOfferId":"purchase-1","gemOfferRevision":1,"gemOfferStatus":"pending","rewardOptions":["attackSpeed","range","chain"],"gemShards":int(app.run_domain.state.gemShards)-20},true)
			app.command([], {"phase":"reward"})
			return {"ok":true}
		if action == "choose_gem":
			chosen = true
			var state: Dictionary = app.run_domain.state
			state.gemInventory[values.choice] = int(state.gemInventory.get(values.choice,0))+1
			var return_phase: String = state.get("rewardReturnPhase", "preparation")
			state.merge({"phase":return_phase,"isPurchasedGemReward":false,"rewardOptions":[],"gemOfferStatus":"chosen"},true)
			app.command([], {"phase":return_phase})
			return {"ok":true}
		return {"ok":true}
var failures: Array = []
var checks := 0
var directory := ""
var pending_result := false
var pending_purchase: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAILED: "+message)
func make_app(name: String):
	var app = App.new()
	app.scene = Host.new()
	app.checkpoint = Checkpoint.new(directory.path_join(name), ACCOUNT)
	app.checkpoint.allow_progression_only = true
	check(app.catalog.load_catalog() and app.run_domain.growth.load_catalog() and app.retry_load(), name+" startup")
	var service = Services.new()
	service.app = app
	app.services = service
	return app
func destroy(app) -> void:
	failures.append_array(app.services.failures)
	app.services.app = null
	app.services = null
	app.scene.free()
	app.free()
func begin_start(app) -> void:
	pending_result = await app.start_stage(0)
func begin_purchase(app) -> void:
	pending_purchase = await app.purchase_reward_gems()
func run() -> void:
	directory = OS.get_cache_dir().path_join("server-run-lifecycle-"+Id.uuid())
	var live = LiveApp.new()
	live.scene = Host.new()
	root.add_child(live)
	check(not await live.start_stage(0), "in-tree formal app cannot use detached debug fallback")
	live.scene.free(); live.queue_free()
	await process_frame
	var app = make_app("start")
	check(await app.start_stage(0), "authority accepts initial start: "+app.checkpoint.message)
	if app.services.economy.snapshot.run == null:
		destroy(app)
		print("SERVER_RUN_LIFECYCLE checks=%d failures=%s" % [checks,JSON.stringify(failures)])
		quit(1)
		return
	check(app.run_domain.state.economyRunId == SERVER_RUN and not app.in_lobby and not app.scene.combat_runtime.session.paused, "play begins with exact server UUID")
	check(app.services.requests.size() == 1 and app.services.requests[0].action == "start_run", "initial run requires one server command")
	app.show_lobby()
	check(await app.resume_run() and app.run_domain.state.economyRunId == SERVER_RUN, "resume preserves verified lifecycle UUID")
	app.show_lobby()
	app.services.economy.snapshot.run.runId = "different-server-run"
	check(not await app.resume_run() and app.in_lobby and app.scene.combat_runtime.session.paused, "mismatched lifecycle cannot resume")
	app.services.economy.snapshot.run.runId = SERVER_RUN
	check(await app.resume_run(), "matching lifecycle can recover")
	app.services.fail_action = "close_run"
	check(not await app.start_stage(0), "failed close blocks replacement")
	check(app.run_domain.state.economyRunId == SERVER_RUN and app.run_domain.state.phase == "failure", "failed close retains durable terminal and original identity")
	app.services.fail_action = ""
	check(await app.start_stage(0) and app.run_domain.state.economyRunId != SERVER_RUN, "replacement closes old lifecycle before new server UUID")
	var requests: Array = app.services.requests
	check(requests[-2].action == "close_run" and requests[-1].action == "start_run", "close-before-start ordering")
	check(await app.abandon_run() and app.run_domain.state.is_empty() and app.in_lobby, "abandon closes authority and clears local checkpoint")
	check(app.checkpoint.store.load_save().activeRun == null, "abandoned checkpoint is canonically null")
	destroy(app)
	app = make_app("failed")
	app.services.fail_action = "start_run"
	check(not await app.start_stage(0), "failed server start reports failure")
	check(app.run_domain.state.get("economyRunId") in [null, ""] and app.in_lobby and app.scene.combat_runtime.session.paused, "failed start never publishes local UUID or playable run")
	check(not await app.resume_run(), "unaccepted provisional cannot resume")
	app.services.fail_action = ""
	var box = app.checkpoint.rewards()
	var pending: Dictionary = box.state.duplicate(true)
	pending.inFlight = {"kind":"start_run","path":"v1/economy/runs/start","idempotencyKey":Id.uuid(),"encodedBody":"{\"stageNumber\":1}","createdAtMillis":0}
	check(box.save_state(pending) == OK, "lost start command remains durable")
	app.services.recover_start = true
	check(await app.start_stage(0), "lost start command can recover safely")
	check(app.services.requests[-1].action == "refresh" and app.services.requests.filter(func(request): return request.action == "start_run").size() == 1, "recovery does not start a second lifecycle")
	destroy(app)
	app = make_app("cancel")
	app.services.hold_action = "start_run"
	begin_start(app)
	await process_frame
	check(app._stage_entry_pending and not await app.start_stage(0) and not await app.resume_run(), "duplicate entry blocked during delayed start")
	app.cancel_stage_entry()
	app.services.release.emit()
	await process_frame
	check(not pending_result and app.in_lobby and app.scene.combat_runtime.session.paused, "canceled response remains saved and paused")
	check(await app.resume_run() and app.run_domain.state.economyRunId == SERVER_RUN, "canceled successful start resumes same authority run")
	destroy(app)
	app = make_app("purchase")
	check(await app.start_stage(0), "purchase fixture authority start")
	app.run_domain.state.gemShards = 40
	app.run_domain.state.phase = "wave"
	app.command([], {"phase":"wave","paused":false})
	var before: Dictionary = app.run_domain.state.duplicate(true)
	check(not app.apply_run_command({"kind":"purchaseGemChoice"}) and app.run_domain.state == before, "local purchase path cannot generate or charge")
	app.services.hold_action = "purchase_gems"
	begin_purchase(app)
	await process_frame
	check(app._gem_reroll_requesting and app.run_domain.state == before and app.scene.combat_runtime.session.paused, "purchase waits paused without optimistic candidate or shard mutation")
	check(not (await app.purchase_reward_gems()).ok and app.services.requests.filter(func(request): return request.action == "purchase_gems").size() == 1, "duplicate purchase cannot dispatch")
	app.services.release.emit()
	await process_frame
	check(pending_purchase.get("ok",false) and app.run_domain.state.gemShards == 20, "server purchase supplies candidates and spends shards")
	check(not app.gem_reroll_state().locked and not app.gem_reroll_state().available, "purchased candidates chooseable without reroll")
	var count: int = app.services.requests.size()
	check(not (await app.reroll_reward_gems()).ok and app.services.requests.size() == count, "purchase never rerolls")
	check(not (await app.choose_reward({"kind":"chooseRewardShards"})).ok, "purchased offer cannot choose shards")
	check((await app.choose_reward({"kind":"chooseRewardGem","type":"range"})).ok and app.services.chosen and app.run_domain.state.gemInventory.range == 1, "purchased gem choice uses server command")
	check(not app.scene.combat_runtime.session.paused, "confirmed purchased choice resumes previously running combat")
	destroy(app)
	for purchased in [false, true]:
		app = make_app("abandon-purchase" if purchased else "abandon-wave")
		check(await app.start_stage(0), "pending offer abandonment starts")
		if purchased:
			app.run_domain.state.gemShards = 40
			check((await app.purchase_reward_gems()).ok, "pending purchased offer created by authority")
		else:
			app.run_domain.state.merge({"phase":"reward","roundIndex":5,"completedRounds":5,"isPurchasedGemReward":false,
				"gemOfferId":"wave-abandon","gemOfferRevision":1,"gemOfferStatus":"pending","rewardOptions":["attackSpeed","range","chain"]},true)
			app.command([], {"phase":"reward","paused":true})
		var pending_offer: Dictionary = app.run_domain.state.duplicate(true)
		check(await app.abandon_run(), "pending offer can be abandoned and closed")
		check(app.services.closed_runs.size() == 1 and app.run_domain.state.is_empty(), "closed pending offer clears canonical run")
		if not app.services.closed_runs.is_empty():
			var terminal: Dictionary = app.services.closed_runs[0]
			for field in ["gemOfferId","gemOfferRevision","gemOfferStatus","rewardOptions","isPurchasedGemReward","rewardReturnPhase","gemInventory","gemShards","gemRerollsUsed"]:
				check(terminal.get(field) == pending_offer.get(field), "abandon preserves authoritative pending "+field)
			check(terminal.phase == "failure", "pending offer terminalizes without granting its choice")
		check(await app.start_stage(0) and app.run_domain.state.economyRunId != pending_offer.economyRunId, "new server lifecycle starts after pending offer closes")
		destroy(app)
	print("SERVER_RUN_LIFECYCLE checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
