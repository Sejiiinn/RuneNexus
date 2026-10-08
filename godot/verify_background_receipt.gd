extends SceneTree
## Real background worker, run domain and checkpoint; HTTP and write failure are controlled.
const App = preload("res://app/app_lifecycle.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Services = preload("res://services/app_services.gd")
const Economy = preload("res://services/economy_service.gd")
const ACCOUNT := "00000000-0000-4000-8000-000000000099"
const NOW := 1700000000000
class Host extends Node3D:
	var _native_combat = preload("res://combat/native_combat_runtime.gd").new()
	var _native_combat_base_frame: Dictionary = {}
	func begin_deferred_battle_presentation() -> void: pass
	func set_battle_visible(_active: bool) -> void: pass
	func _apply_frame(frame: Dictionary) -> void:
		if frame.get("reset", false):
			_native_combat.active = false
			_native_combat_base_frame = {}
class SaveFixture extends Checkpoint:
	var reject_writes := false
	var attempts := 0
	func persist_state(app, candidate: Dictionary, abandoning := false, previous: Dictionary = {}) -> Error:
		attempts += 1
		if reject_writes: return ERR_FILE_CANT_WRITE
		return super.persist_state(app, candidate, abandoning, previous)
class ServiceFixture extends Services:
	func sync() -> Dictionary:
		if not app.persist_progression(): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
		return {"ok":true,"accountId":ACCOUNT,"sourceSaveRevision":1,"writerGeneration":1}
class AccountFixture extends Node:
	signal release
	var credentials := {"accountId":ACCOUNT}
	var waiting := false
	var stop_after_receipt := true
	var day := 0
	var posts: Array = []
	func request(method, path: String, body := "", headers: Dictionary = {}) -> Dictionary:
		if method == "POST":
			posts.append({"path":path,"body":body,"headers":headers.duplicate(true)})
			waiting = true
			await release
			waiting = false
			return {"ok":true,"status":200,"body":{"weekKey":day,"diamonds":999,"moduleTickets":999}}
		if stop_after_receipt: return {"ok":false,"status":503,"code":"STOP_AFTER_RECEIPT"}
		return {"ok":true,"status":200,"body":{
			"authorityState":"server_authoritative","authorityEpoch":"fixture","authorityVersion":1,
			"catalogVersion":1,"economyRevision":1,"serverTime":"2026-10-08T00:00:00Z",
			"wallet":{"freeDiamonds":42,"paidDiamonds":2,"moduleTickets":1},
			"turretModules":{"drawCount":0,"ticketPurchaseCount":0,"items":[]},
			"entitlements":{"researchSlotTwoUnlocked":false},"pendingProgressionEffects":[],"claimedRewardKeys":[]}}
var folder := ""
var failures: Array = []
var checks := 0
func _initialize():
	folder = OS.get_environment("RUNE_APP_TEST_ROOT")
	if folder.is_empty(): quit(2); return
	run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label)
func create_app(name: String):
	var app = App.new()
	app.scene = Host.new()
	app.checkpoint = SaveFixture.new(folder.path_join(name), ACCOUNT)
	app.checkpoint.allow_progression_only = true
	app.run_domain.now_millis = func(): return NOW
	check(app.catalog.load_catalog() and app.run_domain.growth.load_catalog() and app.retry_load(), name + " loads")
	return app
func attach(app):
	var service = ServiceFixture.new()
	service.app = app
	service.account = AccountFixture.new()
	service.account.day = app.progression_inputs.dailyQuestDayKey
	service.profile = {"nickname":"fixture"}
	service.online_ready = true
	service.economy = Economy.new()
	service.economy.configure(service.account, app.checkpoint.rewards(), {
		"sync":service.sync,"snapshot":service._apply_snapshot,"snapshot_current":service._snapshot_current,
		"receipt":service._apply_receipt,"effect":service._apply_effect})
	app.services = service
	return service
func free_app(app):
	app.services.account.free()
	app.services.economy.free()
	app.services.free()
	app.scene.free()
	app.free()
func hold_receipt(service) -> Dictionary:
	var box = service.economy.outbox
	var next: Dictionary = box.state.duplicate(true)
	next.inFlight = {"kind":"daily_reward","path":"v1/economy/rewards/claim",
		"idempotencyKey":"00000000-0000-4000-8000-000000000010",
		"encodedBody":JSON.stringify({"period":"daily","rewardType":"attendance","clientCompatibilityVersion":4}),"createdAtMillis":NOW}
	check(box.save_state(next) == OK, "pending receipt durable")
	service._background_sync()
	check(service.account.waiting and service._background_busy and not service.blocks_play(), "held background receipt permits play")
	return next.inFlight.duplicate(true)
func kill(app, collect := true):
	var runtime = app.scene._native_combat
	runtime.enemies["999999"] = {"id":999999,"type":"normal","isDebug":false,"diamondReward":7}
	runtime._emit({"kind":"kill","enemyId":999999})
	runtime.wall_elapsed += 2.5
	if collect: check(app.command(), "collect kill")
func receipt(day: int, kind := "attendance") -> Dictionary:
	return {"period":"daily","rewardType":kind,"questType":"killEnemies","dayKey":day,"rewardDiamonds":999,"rewardModuleTickets":999}
func live_receipt(collect: bool, paused: bool):
	var label := "collected" if collect else "pending"
	var app = create_app(label)
	check(await app.start_stage(0), label + " starts")
	if paused: check(app.pause_and_save(), label + " paused lobby")
	var service = attach(app)
	var pending := hold_receipt(service)
	var run_id: String = app.run_domain.state.economyRunId
	kill(app, collect)
	app.run_domain.state.progression.runes = 73
	app.run_domain.state.progression.freeDiamonds = 90
	app.run_domain.state.progression.paidDiamonds = 8
	app.run_domain.state.progression.turretModules.tickets = 6
	check(app.progression_inputs.dailyQuestProgress.get("killEnemies", 0) == 0, label + " cached input stays stale")
	service.account.release.emit()
	var p: Dictionary = app.run_domain.state.progression
	var saved: Dictionary = app.checkpoint.store.load_save()
	check(service.issue == "STOP_AFTER_RECEIPT" and service.economy.outbox.state.inFlight == pending, label + " later GET failure retains request")
	check(p.dailyQuestProgress.get("killEnemies", 0) == 1 and p.weeklyQuestProgress.get("killEnemies", 0) == 1 and p.totalPlayTimeMillis == 2500, label + " latest gameplay progression retained")
	check(p.runes == 73 and p.freeDiamonds == 90 and p.paidDiamonds == 8 and p.turretModules.tickets == 6, label + " receipt changes no local or account currency")
	check(p.dailyAttendanceRewardClaimed and saved.progression.dailyAttendanceRewardClaimed and saved.progression.dailyQuestProgress.get("killEnemies", 0) == 1 and saved.progression.runes == 73, label + " claim and latest progression durable")
	check(saved.activeRun.economyRunId == run_id and saved.activeRun.pendingEconomyDiamonds == 7 and app.scene._native_combat.session.paused == paused, label + " preserves active run and pause state")
	var before := p.duplicate(true)
	var writes: int = app.checkpoint.attempts
	check(service._apply_receipt(receipt(service.account.day)) and app.checkpoint.attempts == writes and app.run_domain.state.progression == before, label + " duplicate receipt is a no-op")
	service.account.stop_after_receipt = false
	service._background_sync()
	check(service.account.posts.size() == 2 and service.account.posts[0] == service.account.posts[1], label + " exact bytes and key replay")
	service.account.release.emit()
	p = app.run_domain.state.progression
	saved = app.checkpoint.store.load_save()
	check(service.issue.is_empty() and service.economy.outbox.state.inFlight == null, label + " retry retires durable command")
	check(p.freeDiamonds == 42 and p.paidDiamonds == 2 and p.turretModules.tickets == 1, label + " authoritative snapshot replaces wallet without union or receipt grant")
	check(p.dailyQuestProgress.killEnemies == 1 and p.runes == 73 and p.totalPlayTimeMillis == 2500 and saved.activeRun.economyRunId == run_id and saved.activeRun.pendingEconomyDiamonds == 7, label + " replay preserves progression and run rewards once")
	free_app(app)
	app = create_app(label)
	service = attach(app)
	check(app.scene._native_combat.active and app.scene._native_combat.session.paused and app.run_domain.state.economyRunId == run_id, label + " saved run restores paused")
	check(service._apply_receipt(receipt(service.account.day)) and app.checkpoint.store.load_save().activeRun.economyRunId == run_id and app.run_domain.state.progression.runes == 73, label + " restored receipt preserves activeRun")
	free_app(app)
func save_failure():
	var app = create_app("failure")
	check(await app.start_stage(0), "failure starts")
	var service = attach(app)
	var pending := hold_receipt(service)
	var saved: Dictionary = app.checkpoint.store.load_save().duplicate(true)
	kill(app)
	var before: Dictionary = app.run_domain.state.duplicate(true)
	app.checkpoint.reject_writes = true
	service.account.release.emit()
	check(service.issue == "RECEIPT_SAVE_FAILED" and service.economy.outbox.state.inFlight == pending, "failed receipt retains durable command")
	check(app.run_domain.state == before and not app.run_domain.state.progression.dailyAttendanceRewardClaimed and app.checkpoint.store.load_save() == saved, "failed receipt publishes neither claim nor stale progression")
	app.checkpoint.reject_writes = false
	service.account.stop_after_receipt = false
	service._background_sync()
	service.account.release.emit()
	check(service.issue.is_empty() and app.run_domain.state.progression.dailyQuestProgress.killEnemies == 1 and app.run_domain.state.progression.dailyAttendanceRewardClaimed, "failed save retry preserves kill and commits receipt")
	free_app(app)
func collection_failure():
	var app = create_app("collection_failure")
	check(await app.start_stage(0), "collection failure starts")
	var service = attach(app)
	var before: Dictionary = app.run_domain.state.duplicate(true)
	var saved: Dictionary = app.checkpoint.store.load_save().duplicate(true)
	app.scene._native_combat.epoch += 1
	check(not service._apply_receipt(receipt(service.account.day)), "failed event collection rejects receipt")
	check(app.run_domain.state == before and app.checkpoint.store.load_save() == saved, "failed event collection preserves claim and activeRun")
	free_app(app)
func terminal_receipt():
	var app = create_app("terminal")
	check(await app.start_stage(0), "terminal starts")
	var service = attach(app)
	hold_receipt(service)
	app.run_domain.state.phase = "success"
	check(app.command([], {"phase":"success","paused":true}), "finish run while receipt awaits")
	var before: Dictionary = app.run_domain.state.progression.duplicate(true)
	check(before.lastRunRuneReward > 0 and before.lastRunCorePointReward > 0 and app.run_domain.is_finished(), "real run grants local rewards and completion marker")
	before.dailyAttendanceRewardClaimed = true
	var run_id: String = app.run_domain.state.economyRunId
	service.account.release.emit()
	var saved: Dictionary = app.checkpoint.store.load_save()
	check(app.run_domain.state.progression == before and saved.progression.runes == before.runes and saved.progression.claimedEventIds == before.claimedEventIds, "receipt retains terminal rewards and completion marker")
	check(saved.activeRun.economyRunId == run_id and saved.activeRun.phase == "success" and service.economy.outbox.state.pendingRewards.size() == 1, "terminal activeRun and unsettled reward remain durable")
	check(service._apply_receipt(receipt(service.account.day)) and app.command() and app.run_domain.state.progression == before and service.economy.outbox.state.pendingRewards.size() == 1, "repeat receipt cannot award finished run twice")
	free_app(app)
func latest_period_and_effect():
	var app = create_app("period")
	check(await app.start_stage(0), "period starts")
	var service = attach(app)
	var old_day: int = app.progression_inputs.dailyQuestDayKey
	app.run_domain.now_millis = func(): return NOW + 86400000
	check(service._apply_receipt(receipt(old_day)), "old period receipt is retired")
	check(app.run_domain.state.progression.dailyQuestDayKey == old_day + 1 and not app.run_domain.state.progression.dailyAttendanceRewardClaimed, "period refresh happens before receipt guard")
	app.run_domain.state.progression.dailyQuestProgress.killEnemies = 100
	check(service._apply_receipt(receipt(old_day + 1, "quest")), "quest eligibility uses current progression")
	check("killEnemies" in app.run_domain.state.progression.claimedDailyQuestRewards, "latest quest receipt recorded")
	kill(app)
	var run_id: String = app.run_domain.state.economyRunId
	check(service._apply_effect({"effectType":"complete_research","payload":{"researchType":"bossBounty","targetLevel":1}}), "research effect applied")
	var p: Dictionary = app.run_domain.state.progression
	check(p.bossBountyUpgradeLevel == 1 and p.weeklyQuestProgress.killEnemies == 1 and p.totalPlayTimeMillis == 2500 and app.checkpoint.store.load_save().activeRun.economyRunId == run_id, "research effect shares latest progression transaction")
	free_app(app)
func run():
	await live_receipt(true, false)
	await live_receipt(false, true)
	await save_failure()
	await collection_failure()
	await terminal_receipt()
	await latest_period_and_effect()
	print("BACKGROUND_RECEIPT failures=%d checks=%d %s" % [failures.size(), checks, failures])
	quit(0 if failures.is_empty() else 1)
