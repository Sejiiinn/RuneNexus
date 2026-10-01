extends SceneTree
const Service = preload("res://services/economy_service.gd")
const Outbox = preload("res://app/reward_outbox.gd")
const Update = preload("res://services/update_service.gd")
const Id = preload("res://app/reward_settlement.gd")
const ACCOUNT := "00000000-0000-4000-8000-000000000001"
class CountingOutbox extends Outbox:
	var writes := 0
	var reject_writes := false
	var draw_commands := 0
	func save_state(next: Dictionary) -> Error:
		if next.get("inFlight") is Dictionary and next.inFlight.kind == "draw_modules" and state.get("inFlight") == null: draw_commands += 1
		if reject_writes: return ERR_FILE_CANT_WRITE
		return super.save_state(next)
	func _write_atomic(path: String, contents: String) -> Error:
		writes += 1
		return super._write_atomic(path, contents)
class Session extends Node:
	var credentials := {"accountId":ACCOUNT}
	var sent: Array = []
	var response: Dictionary = {}
	var economy: Dictionary = {}
	var on_send: Callable
	func request(method, path, body := "", headers := {}) -> Dictionary:
		sent.append({"method":method,"path":path,"body":body,"headers":headers.duplicate()})
		if on_send.is_valid(): on_send.call()
		if method == "GET": return {"ok":true,"status":200,"body":economy.duplicate(true)}
		return response.duplicate(true)
var failures: Array = []
var applied: Array = []
var receipts: Array = []
var effects: Array = []
var synced := true
var directory := ""
var local_current := true
var reject_snapshot := false
var sync_hook: Callable
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	if not value: failures.append(label)
func sync() -> Dictionary:
	if sync_hook.is_valid(): sync_hook.call()
	return {"ok":synced,"accountId":ACCOUNT,"sourceSaveRevision":8,"writerGeneration":2}
func apply(value: Dictionary) -> bool:
	applied.append(value.duplicate(true))
	return not reject_snapshot
func snapshot_current(_value: Dictionary) -> bool:
	return local_current
func receipt(value: Dictionary) -> bool:
	receipts.append(value.duplicate(true))
	return true
func effect(value: Dictionary) -> bool:
	effects.append(value.duplicate(true))
	return true
func snapshot(revision: int = 3) -> Dictionary:
	return {"authorityState":"server_authoritative","authorityEpoch":"epoch","authorityVersion":1,"catalogVersion":1,"economyRevision":revision,"serverTime":"2026-09-24T00:00:00Z","wallet":{"freeDiamonds":42,"paidDiamonds":0,"moduleTickets":0},"turretModules":{"drawCount":0,"ticketPurchaseCount":0,"items":[]},"entitlements":{"researchSlotTwoUnlocked":false},"pendingProgressionEffects":[],"claimedRewardKeys":[]}
func run():
	directory = OS.get_cache_dir().path_join("godot-economy-"+Id.uuid())
	await _snapshot_dedup_tests()
	await _draw_quote_tests()
	var box = Outbox.new(directory,ACCOUNT)
	check(box.load_state() == OK,"outbox load")
	var session = Session.new()
	root.add_child(session)
	session.economy = snapshot()
	session.response = {"ok":false,"status":0,"code":"NETWORK_ERROR","body":{}}
	var service = Service.new()
	root.add_child(service)
	var hooks := {"sync":sync,"snapshot":apply,"receipt":receipt,"effect":effect}
	service.configure(session,box,hooks)
	var result: Dictionary = await service.execute("draw_modules",{"count":1,"turretType":"arrow","buyMissingTicketsWithDiamonds":true,"approvedDrawQuote":{"moduleTickets":0,"diamonds":40}})
	check(not result.ok and box.state.inFlight != null,"lost response durable request")
	var pending: Dictionary = box.state.inFlight.duplicate(true)
	var original_bytes: String = pending.encodedBody
	var recovered = Outbox.new(directory,ACCOUNT)
	check(recovered.load_state() == OK,"restart recovery")
	service.configure(session,recovered,hooks)
	session.sent.clear()
	session.response = {"ok":true,"status":200,"body":{"economy":snapshot(4),"drawnModules":[]}}
	session.economy = snapshot(4)
	result = await service.refresh()
	check(result.ok and session.sent[0].method == "POST" and session.sent[0].body == original_bytes and session.sent[0].headers["Idempotency-Key"] == pending.idempotencyKey,"non-run exact replay precedes refresh")
	check(recovered.state.inFlight == null,"receipt clears durable command")
	var old_applied := applied.size()
	result = await service._apply(snapshot(2),service.generation)
	check(result.ok and applied.size() == old_applied and service.snapshot.economyRevision == 4,"old receipt cannot roll back")
	# Every economic command requires successful real save synchronization first.
	synced = false
	session.sent.clear()
	result = await service.execute("draw_modules",{"count":1,"turretType":"arrow","buyMissingTicketsWithDiamonds":true,"approvedDrawQuote":{"moduleTickets":0,"diamonds":40}})
	check(not result.ok and session.sent.all(func(item):return item.method == "GET") and recovered.state.inFlight == null,"failed save prohibits spending")
	synced = true
	# A server already-claimed receipt updates local flags and refreshes wallet.
	session.response = {"ok":false,"status":409,"body":{"code":"REWARD_ALREADY_CLAIMED","reward":{"weekKey":123,"rewardType":"attendance"}}}
	result = await service.execute("claim_reward",{"period":"daily","rewardType":"attendance"})
	check(result.ok and receipts.back().dayKey == 123 and recovered.state.inFlight == null,"already-claimed daily receipt recovery")
	# Pending run settlement survives repeated exact response loss and is tombstoned.
	var run_id := Id.uuid()
	check(recovered.enqueue({"runId":run_id,"stageNumber":1,"completedRounds":2,"success":false,"pendingDiamonds":42,"firstClearModuleTickets":0,"createdAtMillis":1}) == OK,"queue run")
	session.response = {"ok":false,"status":0,"code":"NETWORK_ERROR","body":{}}
	result = await service.refresh()
	check(not result.ok and recovered.state.pendingRewards.size() == 1,"run retained on timeout")
	session.response = {"ok":false,"status":426,"code":"CLIENT_UPDATE_REQUIRED","body":{"code":"CLIENT_UPDATE_REQUIRED"}}
	result = await service.refresh()
	check(not result.ok and recovered.state.inFlight != null and recovered.state.pendingRewards.size() == 1 and not run_id in recovered.state.get("completedRunIds",[]),"current-version 426 preserves unpaid run")
	session.response = {"ok":true,"status":200,"body":{"economy":snapshot(5)}}
	session.economy = snapshot(5)
	result = await service.refresh()
	check(result.ok and recovered.state.pendingRewards.is_empty() and run_id in recovered.state.completedRunIds,"run settled exactly once")
	# Late response cannot mutate a newly bound account or clear the old outbox.
	session.on_send = func():
		if session.sent.back().method == "POST": service.invalidate()
	var before := applied.size()
	result = await service.execute("disassemble_modules",{"ids":["a"]})
	check(not result.ok and result.code == "STALE_BINDING" and recovered.state.inFlight != null,"late response preserves old pending command")
	check(applied.size() == before+1,"only pre-command refresh applies before invalidation")
	session.on_send = Callable()
	# A poisoned persisted command cannot route bearer credentials elsewhere.
	var bad: Dictionary = recovered.state.duplicate(true)
	bad.inFlight.path = "https://other.invalid/steal"
	check(recovered.save_state(bad) == OK,"poison fixture stored")
	service.configure(session,recovered,hooks)
	session.sent.clear()
	result = await service.refresh()
	check(not result.ok and session.sent.is_empty(),"unrecognized path never sent")
	var manifest := {"schemaVersion":1,"versionCode":7000,"versionName":"0.2","packageName":"com.example.rune_nexus","apkUrl":"https://example.test/game.apk","sha256":"a".repeat(64),"sizeBytes":1000,"notes":"test","minimumSupportedVersionCode":6000}
	check(Update.valid_manifest(manifest),"valid manifest")
	manifest.minimumSupportedVersionCode = 7001
	check(not Update.valid_manifest(manifest),"invalid minimum rejected")
	manifest.minimumSupportedVersionCode = 6000
	manifest.apkUrl = "http://example.test/game.apk"
	check(not Update.valid_manifest(manifest),"insecure APK rejected")
	var updater = Update.new()
	root.add_child(updater)
	updater.installed = {"versionCode":6028,"apkSha256":"b".repeat(64)}
	updater.release = {"minimumSupportedVersionCode":6029,"versionCode":6030,"sizeBytes":1000,"patches":[{"format":"rune-apk-delta-v1","fromVersionCode":6028,"fromSha256":"b".repeat(64),"url":"https://example.test/patch","sha256":"c".repeat(64),"sizeBytes":400}]}
	updater.blocked = true
	updater.skip()
	check(updater.blocked and updater._patch().sizeBytes == 400,"required update cannot skip and matching patch selected")
	updater.release.minimumSupportedVersionCode = 6028
	updater.server_required = true
	updater.skip()
	check(updater.blocked,"server 426 overrides optional manifest")
	updater.server_required = false
	updater.skip()
	check(not updater.blocked,"optional update can defer")
	service.free(); session.free(); updater.free()
	print("ECONOMY_SERVICE failures=",failures.size()," ",failures)
	_remove(directory)
	quit(0 if failures.is_empty() else 1)
func _remove(path: String):
	for file in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	for child in DirAccess.get_directories_at(path): _remove(path.path_join(child))
	DirAccess.remove_absolute(path)

func _snapshot_dedup_tests():
	var box = CountingOutbox.new(directory.path_join("snapshot"), ACCOUNT)
	check(box.load_state() == OK and box.save_state(box.state) == OK, "initialize snapshot test outbox")
	var writes: int = box.writes
	check(box.save_state(box.state.duplicate(true)) == OK and box.writes == writes, "identical outbox does not flush or rotate backup")
	var session = Session.new()
	root.add_child(session)
	var service = Service.new()
	root.add_child(service)
	var hooks := {"sync":sync,"snapshot":apply,"snapshot_current":snapshot_current,"receipt":receipt,"effect":effect}
	service.configure(session, box, hooks)
	check((await service._apply(snapshot(), service.generation)).ok, "first live snapshot applies")
	var count := applied.size()
	writes = box.writes
	var unchanged := snapshot()
	unchanged.serverTime = "2026-09-25T00:00:00Z"
	check((await service._apply(unchanged, service.generation)).ok and applied.size() == count and box.writes == writes, "time-only snapshot skips local apply and durable writes")
	check(service.snapshot.serverTime == unchanged.serverTime, "time-only metadata remains current in memory")
	var invalid := unchanged.duplicate(true)
	invalid.wallet.freeDiamonds = -1
	check(not (await service._apply(invalid, service.generation)).ok and applied.size() == count, "unchanged revision still validates complete snapshot")
	local_current = false
	check((await service._apply(unchanged, service.generation)).ok and applied.size() == count + 1, "changed local equipment or balance reapplies same economy")
	local_current = true
	count = applied.size()
	service.configure(session, box, hooks)
	check((await service._apply(unchanged, service.generation)).ok and applied.size() == count + 1, "restored snapshot does not skip first live application")
	for field in ["authorityEpoch", "authorityVersion", "catalogVersion", "claimedRewardKeys", "pendingProgressionEffects"]:
		var next: Dictionary = service.snapshot.duplicate(true)
		match field:
			"authorityEpoch": next[field] = "new-epoch"
			"authorityVersion", "catalogVersion": next[field] += 1
			"claimedRewardKeys": next[field] = ["daily:20260925:attendance"]
			"pendingProgressionEffects": next[field] = [{"id": Id.uuid(), "effectType":"complete_research", "payload":{"researchType":"bossBounty","targetLevel":1}}]
		count = applied.size()
		check((await service._apply(next, service.generation)).ok and applied.size() == count + 1, "same revision change applies " + field)
	var next: Dictionary = service.snapshot.duplicate(true)
	next.wallet.freeDiamonds += 1
	reject_snapshot = true
	count = applied.size()
	check(not (await service._apply(next, service.generation)).ok and service.snapshot.wallet != next.wallet, "failed local apply never publishes snapshot")
	reject_snapshot = false
	box.reject_writes = true
	check(not (await service._apply(next, service.generation)).ok and service.snapshot.wallet != next.wallet, "failed outbox write never publishes snapshot")
	box.reject_writes = false
	check((await service._apply(next, service.generation)).ok and applied.size() == count + 3, "failed applies retry actual callback")
	count = applied.size()
	service.invalidate()
	check(not (await service._apply(next, service.generation - 1)).ok and applied.size() == count, "stale binding never calls local snapshot callback")
	# Read corruption even when memory and requested state are identical.
	var file := FileAccess.open(box.primary_path, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	check(box.save_state(box.state) == ERR_FILE_CORRUPT, "identical outbox still rejects disk corruption")
	service.free()
	session.free()

func _draw_quote_tests():
	var cases := [
		{"name":"same quote", "approved":4, "latest":4, "send":true},
		{"name":"tickets decrease", "approved":4, "latest":2, "send":false},
		{"name":"tickets increase", "approved":2, "latest":4, "send":false},
		{"name":"free to paid", "approved":5, "latest":4, "send":false},
		{"name":"paid to free", "approved":4, "latest":5, "send":false},
		{"name":"surplus tickets same usage", "approved":5, "latest":8, "send":true},
		{"name":"same quote newer revision", "approved":4, "latest":4, "revision":8, "send":true},
		{"name":"insufficient balance", "approved":4, "latest":4, "diamonds":39, "send":false, "code":"INSUFFICIENT_DIAMONDS"},
		{"name":"final sync changes quote", "approved":4, "latest":4, "syncTickets":2, "send":false},
		{"name":"pending settlement changes quote", "approved":4, "latest":4, "settledTickets":5, "send":false},
		{"name":"missing approval", "approved":4, "latest":4, "missing":true, "send":false},
	]
	for test in cases:
		var box = CountingOutbox.new(directory.path_join(test.name.replace(" ","-")),ACCOUNT)
		check(box.load_state() == OK, test.name + " outbox loads")
		var session = Session.new()
		root.add_child(session)
		var service = Service.new()
		root.add_child(service)
		session.economy = snapshot(int(test.get("revision",3)))
		session.economy.wallet.moduleTickets = test.latest
		session.economy.wallet.freeDiamonds = test.get("diamonds",1000)
		session.response = {"ok":true,"status":200,"body":{"economy":session.economy.duplicate(true),"drawnModules":[]}}
		if test.has("settledTickets"):
			check(box.enqueue({"runId":Id.uuid(),"stageNumber":11,"completedRounds":5,"success":true,"pendingDiamonds":0,"firstClearModuleTickets":5,"createdAtMillis":1}) == OK,"queue quote settlement")
			session.response.body.economy.wallet.moduleTickets = test.settledTickets
			session.response.body.economy.economyRevision += 1
		service.configure(session,box,{"sync":sync,"snapshot":apply,"receipt":receipt,"effect":effect})
		if test.has("syncTickets"):
			sync_hook = func(): service.snapshot.wallet.moduleTickets = test.syncTickets
		var used: int = mini(5,test.approved)
		var values := {"count":5,"turretType":"arrow","buyMissingTicketsWithDiamonds":used < 5,"approvedDrawQuote":{"moduleTickets":used,"diamonds":(5-used)*40}}
		if test.get("missing",false): values.erase("approvedDrawQuote")
		var result: Dictionary = await service.execute("draw_modules",values)
		sync_hook = Callable()
		var draws: Array = session.sent.filter(func(item): return item.path == "v1/economy/turret-modules/draw")
		if test.send:
			check(result.ok and draws.size()==1 and box.draw_commands==1,test.name + " sends one draw")
			if not draws.is_empty():
				var body: Dictionary = JSON.parse_string(draws[0].body)
				check(not body.has("approvedDrawQuote") and body.buyMissingTicketsWithDiamonds == values.buyMissingTicketsWithDiamonds,test.name + " keeps HTTP contract")
				check(body.expectedEconomyRevision == test.get("revision",3),test.name + " pins checked economy revision")
		else:
			check(not result.ok and result.get("code") == test.get("code","DRAW_QUOTE_CHANGED"),test.name + " asks for review")
			check(draws.is_empty() and box.state.inFlight == null and box.draw_commands==0,test.name + " creates no draw command")
		if test.has("settledTickets"): check(box.state.pendingRewards.is_empty(),"quote checked after pending settlement completes")
		service.free()
		session.free()
