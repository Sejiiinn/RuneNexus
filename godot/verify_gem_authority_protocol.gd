extends SceneTree
## Command outcomes and current authority are deliberately different fixtures.
const Economy = preload("res://services/economy_service.gd")
const Outbox = preload("res://app/reward_outbox.gd")
const Result = preload("res://app/gem_command_result.gd")
const Offer = preload("res://app/gem_reroll.gd")
const Json = preload("res://app/save_json.gd")
const ACCOUNT := "12345678-1234-4234-8234-123456789abc"
const RUN := "22345678-1234-4234-8234-123456789abc"
const ID := "32345678-1234-4234-8234-123456789abc"
const STAMP := "2026-10-12T00:00:00Z"
class Remote extends RefCounted:
	var credentials := {"accountId":ACCOUNT}
	var current: Dictionary
	var result: Dictionary
	var next: Dictionary
	var reads_fail := false
	var mutated := false
	var calls: Array = []
	func request(method, path, raw := "", headers := {}) -> Dictionary:
		calls.append({"method":method,"path":path,"raw":raw,"headers":headers.duplicate(true)})
		if method == "GET":
			if mutated and reads_fail: return {"ok":false,"status":0,"code":"NETWORK_ERROR","body":{}}
			return {"ok":true,"status":200,"body":current.duplicate(true)}
		mutated = true
		if not next.is_empty(): current = next.duplicate(true)
		return {"ok":true,"status":200,"body":result.duplicate(true)}
var checks := 0
var failures: Array[String] = []
var applied: Array = []
var acks: Array = []
var events: Array[String] = []
var fixture_index := 0
func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label)
func sync() -> Dictionary: return {"ok":true,"accountId":ACCOUNT,"sourceSaveRevision":8,"writerGeneration":2}
func apply(value: Dictionary) -> bool:
	events.append("apply:%d" % value.economyRevision)
	applied.append(value.duplicate(true))
	return true
func gem_apply(value: Dictionary, _command: Dictionary) -> bool: return apply(value)
func ack(value: Dictionary) -> bool:
	events.append("reconcile:%d" % value.currentEconomy.economyRevision)
	acks.append(value.duplicate(true))
	return true
func offer(revision := 1, purchase := false, chosen := false) -> Dictionary:
	var value := {"runId":RUN,"offerId":ID,"rewardWave":0 if purchase else 5,"revision":revision,"economyRevision":10+revision,"totalUsed":0,"gemOptions":["attackSpeed","range","chain"],"status":"chosen" if chosen else "pending","choice":"attackSpeed" if chosen else "","grantedGem":"attackSpeed" if chosen else "","grantedShards":0,"gemInventory":{"attackSpeed":1} if chosen else {},"gemShards":20}
	if purchase: value.merge({"kind":"purchase","returnPhase":"wave","purchaseSequence":1})
	return value
func snapshot(revision: int, reward: Variant = null) -> Dictionary:
	return {"authorityState":"server_authoritative","authorityEpoch":"epoch","authorityVersion":1,"catalogVersion":1,"economyRevision":revision,"serverTime":STAMP,"wallet":{"freeDiamonds":42,"paidDiamonds":0,"moduleTickets":0,"gemResetTickets":2},"turretModules":{"drawCount":0,"ticketPurchaseCount":0,"items":[]},"entitlements":{"researchSlotTwoUnlocked":false},"pendingProgressionEffects":[],"claimedRewardKeys":[],"gemOfferVersion":1,"gemOffer":reward,"run":{"runId":RUN,"stageNumber":1,"status":"active"}}
func compact(reward: Dictionary) -> Dictionary:
	return {"gemReceipt":{"version":1,"economyRevision":reward.economyRevision,"authorityEpoch":"epoch","gemResetTickets":2},"gemOffer":reward.duplicate(true),"saveRevision":9,"serverSavedAt":STAMP}
func fixture() -> Dictionary:
	fixture_index += 1
	var box = Outbox.new(OS.get_user_data_dir().path_join("protocol-%d" % fixture_index), ACCOUNT)
	check(box.load_state() == OK,"fixture outbox")
	var service = Economy.new()
	root.add_child(service)
	var remote := Remote.new()
	remote.current = snapshot(10)
	service.configure(remote, box, {"sync":sync,"snapshot":apply,"gem_snapshot":gem_apply,"gem_save":ack})
	return {"service":service,"remote":remote,"box":box}
func run():
	var f := fixture()
	var original_offer := offer()
	f.remote.result = compact(original_offer)
	f.remote.next = snapshot(11, original_offer)
	var issued: Dictionary = await f.service.execute("offer_gems", {"runId":RUN,"completedRounds":5})
	check(issued.ok and f.box.state.inFlight == null,"compact success retires after current reads")
	check(events == ["apply:10","reconcile:11","apply:11"],"current-save provenance is checked BEFORE installing offer markers")
	check(not issued.body.has("activeRun") and not issued.body.has("economy") and acks.back().currentEconomy.economyRevision == 11,"compact response does not smuggle historical save/economy")
	var chosen := offer(2, false, true)
	f.remote.result = compact(chosen)
	f.remote.next = snapshot(12, chosen)
	f.remote.reads_fail = true
	f.remote.mutated = false
	var before := applied.size()
	var failed: Dictionary = await f.service.execute("choose_gem", {"runId":RUN,"completedRounds":5,"offerId":ID,"expectedOfferRevision":1,"choice":"attackSpeed"})
	check(not failed.ok and f.box.state.inFlight != null and applied.size() == before+1,"lost current read retains immutable success command without projecting its historical grant")
	var pending: Dictionary = f.box.state.inFlight.duplicate(true)
	f.remote.reads_fail = false
	f.remote.next = snapshot(20)
	var recovered: Dictionary = await f.service.refresh()
	check(recovered.ok and f.box.state.inFlight == null and applied.back().economyRevision == 20,"historical outcome resolves then CURRENT economy applies")
	var posts: Array = f.remote.calls.filter(func(call): return call.method == "POST")
	check(posts[-1].raw == pending.encodedBody and posts[-1].headers["Idempotency-Key"] == pending.idempotencyKey,"lost response exact bytes and key")
	check(acks.back().gemOffer == chosen and acks.back().currentEconomy.gemOffer == null,"receipt outcome and current projection kept distinct")
	# Legacy v8 full response is immutable, but its full old save is never applied.
	var legacy_body: Dictionary = Json.parse(pending.encodedBody)
	legacy_body.clientCompatibilityVersion = 8
	pending.encodedBody = JSON.stringify(legacy_body)
	var queued: Dictionary = f.box.state.duplicate(true)
	queued.inFlight = pending
	check(f.box.save_state(queued) == OK,"legacy command durable")
	f.remote.result = {"economy":snapshot(12, chosen),"gemOffer":chosen,"saveRevision":9,"activeRun":{"economyRunId":"obsolete"}}
	before = applied.size()
	check((await f.service.refresh()).ok and applied.slice(before).all(func(value): return value.economyRevision == 20),"generation8 replay never reapplies historical economy")
	f.service.free()
	f = fixture()
	var purchased := offer(1, true)
	f.remote.result = compact(purchased)
	f.remote.next = snapshot(11, purchased)
	check((await f.service.execute("purchase_gems", {"runId":RUN,"completedRounds":0})).ok,"zero-round purchase uses server command")
	posts = f.remote.calls.filter(func(call): return call.method == "POST")
	var body: Dictionary = Json.parse(posts[0].raw)
	check(posts[0].path == "v1/economy/gems/purchase" and body.clientCompatibilityVersion == 10 and not body.has("offerId"),"purchase wire contract")
	var local := {"economyRunId":RUN,"phase":"wave","completedRounds":0,"gemInventory":{},"gemShards":40,"rewardOptions":[]}
	var pending_purchase := Offer.project(local, purchased)
	check(pending_purchase.phase == "reward" and pending_purchase.gemShards == 20 and pending_purchase.isPurchasedGemReward,"purchase projection debits only confirmed twenty shards")
	var granted := offer(2, true, true)
	var owned := Offer.project(pending_purchase, granted)
	check(owned.phase == "wave" and owned.gemInventory.attackSpeed == 1 and not owned.isPurchasedGemReward,"purchase choice returns exact wave phase")
	owned.gemInventory = {} # The owned gem is now equipped; never re-add it.
	check(Offer.project(owned, granted).gemInventory.is_empty(),"same chosen replay preserves newer allocation")
	var old_purchase := purchased.duplicate(true)
	old_purchase.offerId = "42345678-1234-4234-8234-123456789abc"
	check(Offer.project(owned, old_purchase) == owned,"older same-round purchase cannot reopen reward or roll allocation back")
	var invalid := granted.duplicate(true)
	invalid.choice = "shards"; invalid.grantedGem = ""; invalid.grantedShards = 10
	check(not Offer.valid_offer(invalid),"purchase never grants shard fallback")
	f.service.free()
	print("GEM_AUTHORITY_PROTOCOL checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
