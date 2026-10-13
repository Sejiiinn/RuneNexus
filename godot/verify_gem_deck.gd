extends SceneTree
## Generation-10 run gem deck: local offers/rerolls/choices/purchases, the
## replayable gemDeckLog in saves, held reset tickets and the memory-only deck.
const Deck = preload("res://app/gem_deck.gd")
const Offer = preload("res://app/gem_reroll.gd")
const Codec = preload("res://app/save_codec.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Service = preload("res://services/economy_service.gd")
const Outbox = preload("res://app/reward_outbox.gd")
const Id = preload("res://app/reward_settlement.gd")
const ACCOUNT := "00000000-0000-4000-8000-000000000001"
const RUN := "0198b955-3656-7c40-b3cb-87f427b90be7"
const WAVE_OFFER := "0198b955-3656-7c40-b3cb-87f427b90b05"
const TEN_OFFER := "0198b955-3656-7c40-b3cb-87f427b90b10"
const BUY_OFFER := "0198b955-3656-7c40-b3cb-87f427b90b01"
const CHAIN := [["attackSpeed","range","physicalDamage"],["elementalDamage","lightWeapon","heavyWeapon"],["chain","explosion","criticalChance"],["attackSpeed","range","armorPiercing"]]
const BUY := ["damageOverTime","aimSpeed","damageAmplifier"]
class Session extends Node:
	var credentials := {"accountId":ACCOUNT}
	var economy: Dictionary = {}
	func request(method, _path, _body := "", _headers := {}) -> Dictionary:
		if method == "GET": return {"ok":true,"status":200,"body":economy.duplicate(true)}
		return {"ok":false,"status":0,"code":"NETWORK_ERROR","body":{}}
var failures: Array = []
var checks := 0
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label)
func deck() -> Dictionary:
	return {"version":1,"runId":RUN,"waves":{"5":{"offerId":WAVE_OFFER,"options":CHAIN},"10":{"offerId":TEN_OFFER,"options":[CHAIN[2]]}},"purchases":[{"offerId":BUY_OFFER,"options":BUY}]}
func reward_state() -> Dictionary:
	return {"economyRunId":RUN,"phase":"reward","completedRounds":5,"roundIndex":5,"gemShards":30,"gemInventory":{},"rewardOptions":[],"gemRerollsUsed":0,"isPurchasedGemReward":false,"progression":{"gemResetTickets":1}}

func run():
	_transitions()
	_purchase()
	_save_format()
	_held_tickets()
	await _memory_only_deck()
	print("GEM_DECK checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _transitions() -> void:
	var d := deck()
	check(Deck.valid(d, RUN) and not Deck.valid(d, Id.uuid()) and not Deck.valid({"version":2,"runId":RUN,"waves":{},"purchases":[]}, RUN), "deck bound to its run and version")
	var state := Deck.offer(reward_state(), d)
	check(state.rewardOptions == CHAIN[0] and state.gemOfferId == WAVE_OFFER and state.gemOfferRevision == 1 and Offer.current_offer(state), "wave offer presents the first chain entry")
	check(state.gemDeckLog == [{"kind":"wave","wave":5,"rerolls":0,"choice":""}], "offer recorded for replay")
	check(Deck.offer(state, d).is_empty(), "an open offer is never replaced")
	state = Deck.reroll(state, d)
	check(state.rewardOptions == CHAIN[1] and state.gemRerollsUsed == 1 and state.progression.gemResetTickets == 1 and state.gemDeckLog[0].rerolls == 1, "first reroll of a run is free")
	state = Deck.reroll(state, d)
	check(state.rewardOptions == CHAIN[2] and state.gemRerollsUsed == 2 and state.progression.gemResetTickets == 0 and state.gemOfferRevision == 3, "second reroll spends a ticket")
	check(Deck.reroll(state, d).is_empty(), "no reroll without a ticket")
	var funded := state.duplicate(true)
	funded.progression.gemResetTickets = 5
	funded = Deck.reroll(funded, d)
	check(funded.rewardOptions == CHAIN[3] and funded.gemRerollsUsed == 3 and Deck.reroll(funded, d).is_empty(), "run reroll budget is three")
	check(Deck.choose(state, "aimSpeed").is_empty(), "choice limited to presented candidates")
	var chosen := Deck.choose(state, CHAIN[2][1])
	check(chosen.gemInventory == {CHAIN[2][1]:1} and chosen.phase == "preparation" and chosen.rewardOptions.is_empty() and chosen.gemOfferStatus == "chosen" and chosen.gemDeckLog[0].choice == CHAIN[2][1] and not Offer.current_offer(chosen), "gem choice grants and closes the offer")
	var shards := Deck.choose(state, "shards")
	check(shards.gemShards == 40 and shards.gemInventory.is_empty() and shards.gemDeckLog[0].choice == "shards", "wave shard alternative")
	check(Deck.pending_ticket_cost(chosen) == 1 and Deck.pending_ticket_cost(reward_state()) == 0, "held tickets follow the run reroll count")
	var next := chosen.duplicate(true)
	next.phase = "reward"
	next.completedRounds = 10
	next = Deck.offer(next, d)
	check(next.rewardOptions == CHAIN[2] and next.gemDeckLog.size() == 2 and next.gemOfferRevision == 1 and Deck.reroll(next, d).is_empty(), "later wave uses its own short chain")
	var missing := chosen.duplicate(true)
	missing.phase = "reward"
	missing.completedRounds = 15
	check(Deck.offer(missing, d).is_empty(), "absent deck wave keeps the reward closed")

func _purchase() -> void:
	var d := deck()
	var state := reward_state()
	state.phase = "wave"
	state.completedRounds = 7
	check(Deck.purchase(state, d, 40).is_empty(), "purchase requires shards")
	var bought := Deck.purchase(state, d, 20)
	check(bought.phase == "reward" and bought.isPurchasedGemReward and bought.rewardReturnPhase == "wave" and bought.gemShards == 10 and bought.rewardOptions == BUY and bought.gemOfferId == BUY_OFFER and Offer.current_offer(bought), "purchase presents its deck entry")
	check(Deck.reroll(bought, d).is_empty() and Deck.choose(bought, "shards").is_empty(), "purchases cannot reroll or take shards")
	var chosen := Deck.choose(bought, BUY[0])
	check(chosen.phase == "wave" and not chosen.isPurchasedGemReward and chosen.rewardReturnPhase == null and chosen.gemInventory == {BUY[0]:1} and chosen.gemDeckLog == [{"kind":"purchase","sequence":1,"choice":BUY[0]}], "purchased choice returns to combat")
	check(Deck.purchase(chosen, d, 0).is_empty(), "exhausted purchase entries fall back")

func _save_format() -> void:
	var state := Deck.reroll(Deck.offer(reward_state(), deck()), deck())
	var envelope := {"version":2,"preferences":{},"progression":{},"turretModules":{},"activeRun":state}
	var decoded: Dictionary = Codec.decode(envelope)
	check(decoded.activeRun.gemDeckLog == state.gemDeckLog, "codec keeps the deck log")
	var noisy := envelope.duplicate(true)
	noisy.activeRun.gemDeckLog.append({"kind":"wave","wave":10,"rerolls":9,"choice":"notAGem"})
	noisy.activeRun.gemDeckLog.append({"kind":"purchase","sequence":0,"choice":""})
	noisy.activeRun.gemDeckLog.append("bad")
	var normalized: Dictionary = Codec.decode(noisy)
	check(normalized.activeRun.gemDeckLog.size() == 2 and normalized.activeRun.gemDeckLog[1] == {"kind":"purchase","sequence":1,"choice":""}, "codec normalizes malformed entries")
	check(Codec.is_normalized_v2(decoded) and Codec.decode(decoded) == decoded, "normalized log roundtrips")
	var changed := decoded.duplicate(true)
	changed.activeRun.gemDeckLog[0].rerolls = 0
	check(Hash.hash_payload(decoded) != Hash.hash_payload(changed), "save hash covers the deck log")
	var without := {"version":2,"preferences":{},"progression":{},"turretModules":{},"activeRun":reward_state()}
	check(not Codec.decode(without).activeRun.has("gemDeckLog"), "legacy runs gain no deck log")

func _held_tickets() -> void:
	var state := Deck.choose(Deck.reroll(Deck.reroll(Deck.offer(reward_state(), deck()), deck()), deck()), "shards")
	var progression := {"gemResetTickets":4}
	Checkpoint._hold_deck_tickets(progression, state, {"run":{"runId":RUN,"stageNumber":1,"status":"active"}})
	check(progression.gemResetTickets == 3, "open deck run holds its spent tickets")
	progression = {"gemResetTickets":4}
	Checkpoint._hold_deck_tickets(progression, state, {"run":null})
	check(progression.gemResetTickets == 4, "closed run was debited by the server")
	progression = {"gemResetTickets":0}
	Checkpoint._hold_deck_tickets(progression, state, {"run":{"runId":RUN,"stageNumber":1,"status":"active"}})
	check(progression.gemResetTickets == 0, "held tickets never go negative")
	var legacy := reward_state()
	legacy.gemRerollsUsed = 2
	progression = {"gemResetTickets":4}
	Checkpoint._hold_deck_tickets(progression, legacy, {"run":{"runId":RUN,"stageNumber":1,"status":"active"}})
	check(progression.gemResetTickets == 4, "legacy runs were charged per command")

func _memory_only_deck() -> void:
	var directory := OS.get_cache_dir().path_join("godot-gem-deck-" + Id.uuid())
	var box = Outbox.new(directory, ACCOUNT)
	check(box.load_state() == OK, "outbox load")
	var session := Session.new()
	root.add_child(session)
	session.economy = {"authorityState":"server_authoritative","authorityEpoch":"epoch","authorityVersion":1,"catalogVersion":1,"economyRevision":3,"serverTime":"2026-10-13T00:00:00Z","wallet":{"freeDiamonds":0,"paidDiamonds":0,"moduleTickets":0,"gemResetTickets":2},"turretModules":{"drawCount":0,"ticketPurchaseCount":0,"items":[]},"entitlements":{"researchSlotTwoUnlocked":false},"pendingProgressionEffects":[],"claimedRewardKeys":[],"run":{"runId":RUN,"stageNumber":1,"status":"active"},"gemDeckVersion":1,"gemDeck":deck()}
	var service = Service.new()
	root.add_child(service)
	service.configure(session, box, {"sync":func(): return {"ok":true}, "snapshot":func(_value): return true})
	var result: Dictionary = await service.refresh()
	check(result.ok and service.gem_deck(RUN) == deck() and service.gem_deck(Id.uuid()).is_empty(), "current read provides the run deck")
	var reread = Outbox.new(directory, ACCOUNT)
	check(reread.load_state() == OK and not reread.state.lastServerSnapshot.has("gemDeck") and reread.state.lastServerSnapshot.run.runId == RUN, "deck never persists locally")
	var restarted = Service.new()
	root.add_child(restarted)
	restarted.configure(session, reread, {"sync":func(): return {"ok":true}, "snapshot":func(_value): return true})
	check(restarted.gem_deck(RUN).is_empty() and restarted.gem_deck_missing(RUN) and not restarted.gem_deck_missing(Id.uuid()), "restart knows a deck run before reading its deck")
	result = await restarted.refresh()
	check(result.ok and restarted.gem_deck(RUN) == deck() and not restarted.gem_deck_missing(RUN), "refresh restores the deck")
	restarted.queue_free()
	service.queue_free()
	session.queue_free()
