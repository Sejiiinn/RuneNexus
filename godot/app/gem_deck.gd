extends RefCounted
## Run gem deck (generation 10). The server pre-commits every wave chain and
## purchase choice at run start. Offers, rerolls and choices apply locally with
## no network wait; gemDeckLog records them so the server can replay the run
## against the deck and charge reset tickets when it closes.
## The deck lives in memory only (economy snapshot); it is never saved locally.
const VERSION := 1
const MAX_REROLLS := 3
const GemReroll = preload("res://app/gem_reroll.gd")

static func valid(deck: Variant, run_id: String) -> bool:
	if not deck is Dictionary or deck.get("version") != VERSION or run_id.is_empty() or deck.get("runId") != run_id: return false
	return deck.get("waves") is Dictionary and deck.get("purchases") is Array

static func wave_entry(deck: Dictionary, wave: int) -> Dictionary:
	var entry: Variant = deck.waves.get(str(wave))
	return entry if entry is Dictionary and entry.get("offerId") is String and entry.get("options") is Array else {}

static func purchase_entry(deck: Dictionary, sequence: int) -> Dictionary:
	if sequence < 1 or sequence > deck.purchases.size(): return {}
	var entry: Variant = deck.purchases[sequence - 1]
	return entry if entry is Dictionary and entry.get("offerId") is String and _options(entry.get("options")) else {}

static func _options(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for index in 3:
		if value[index] not in GemReroll.GEM_TYPES or value.find(value[index]) != index: return false
	return true

static func log_of(state: Dictionary) -> Array:
	var value: Variant = state.get("gemDeckLog")
	return value.duplicate(true) if value is Array else []

## Reset tickets the run has spent locally; the server debits them at close.
## The first reroll of a run is free.
static func pending_ticket_cost(state: Dictionary) -> int:
	return maxi(0, int(state.get("gemRerollsUsed", 0)) - 1)

static func _pending(state: Dictionary) -> Dictionary:
	var entries := log_of(state)
	if entries.is_empty() or entries[-1].get("choice") != "": return {}
	return entries[-1]

static func _present(next: Dictionary, entries: Array, offer_id: String, options: Array, revision: int) -> Dictionary:
	next.gemDeckLog = entries
	next.rewardOptions = options.duplicate()
	next.gemOfferId = offer_id
	next.gemOfferRevision = revision
	next.gemOfferStatus = "pending"
	return next

## Wave reward for the just completed round. {} when not applicable.
static func offer(state: Dictionary, deck: Dictionary) -> Dictionary:
	if not GemReroll.eligible(state) or GemReroll.current_offer(state) or not _pending(state).is_empty(): return {}
	var wave := int(state.completedRounds)
	var entries := log_of(state)
	for entry in entries:
		if entry.get("kind") == "wave" and int(entry.get("wave", 0)) >= wave: return {}
	var source := wave_entry(deck, wave)
	if source.is_empty() or source.options.is_empty() or not _options(source.options[0]): return {}
	entries.append({"kind":"wave", "wave":wave, "rerolls":0, "choice":""})
	var next := state.duplicate(true)
	next.gemOfferEquipRevision = 0
	return _present(next, entries, source.offerId, source.options[0], 1)

static func reroll(state: Dictionary, deck: Dictionary) -> Dictionary:
	var pending := _pending(state)
	var used := int(state.get("gemRerollsUsed", 0))
	if pending.get("kind") != "wave" or not GemReroll.current_offer(state) or used >= MAX_REROLLS: return {}
	var cost := 1 if used > 0 else 0
	if int(state.get("progression", {}).get("gemResetTickets", 0)) < cost: return {}
	var source := wave_entry(deck, int(pending.wave))
	var rerolls := int(pending.rerolls) + 1
	if source.is_empty() or rerolls >= source.options.size() or not _options(source.options[rerolls]): return {}
	var entries := log_of(state)
	entries[-1].rerolls = rerolls
	var next := state.duplicate(true)
	next.gemRerollsUsed = used + 1
	if cost > 0: next.progression.gemResetTickets = int(next.progression.gemResetTickets) - cost
	return _present(next, entries, source.offerId, source.options[rerolls], int(state.get("gemOfferRevision", 0)) + 1)

## choice is a candidate gem, or "shards" for the wave's 10-shard alternative.
static func choose(state: Dictionary, choice: String) -> Dictionary:
	var pending := _pending(state)
	if pending.is_empty() or not GemReroll.current_offer(state): return {}
	var purchased: bool = pending.get("kind") == "purchase"
	if choice == "shards":
		if purchased: return {}
	elif choice not in state.rewardOptions: return {}
	var entries := log_of(state)
	entries[-1].choice = choice
	var next := state.duplicate(true)
	if choice == "shards": next.gemShards = int(next.get("gemShards", 0)) + 10
	else:
		var inventory: Dictionary = next.get("gemInventory", {})
		inventory[choice] = int(inventory.get(choice, 0)) + 1
		next.gemInventory = inventory
	next.gemDeckLog = entries
	next.gemOfferRevision = int(state.get("gemOfferRevision", 0)) + 1
	next.gemOfferStatus = "chosen"
	next.rewardOptions = []
	next.phase = state.get("rewardReturnPhase", "preparation") if purchased else "preparation"
	next.isPurchasedGemReward = false
	next.rewardReturnPhase = null
	return next

static func purchase(state: Dictionary, deck: Dictionary, cost: int) -> Dictionary:
	if state.get("phase") not in ["preparation", "wave"] or int(state.get("gemShards", 0)) < cost or not _pending(state).is_empty(): return {}
	var entries := log_of(state)
	var sequence := 1
	for entry in entries:
		if entry.get("kind") == "purchase": sequence += 1
	var source := purchase_entry(deck, sequence)
	if source.is_empty(): return {}
	entries.append({"kind":"purchase", "sequence":sequence, "choice":""})
	var next := state.duplicate(true)
	next.gemShards = int(state.gemShards) - cost
	next.rewardReturnPhase = state.phase
	next.phase = "reward"
	next.isPurchasedGemReward = true
	next.gemOfferEquipRevision = 0
	return _present(next, entries, source.offerId, source.options, 1)
