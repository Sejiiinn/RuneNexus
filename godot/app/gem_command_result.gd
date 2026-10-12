extends RefCounted
## Immutable command outcomes establish success only. Recovery uses CURRENT reads.
const Offers = preload("res://app/gem_reroll.gd")
const Json = preload("res://app/save_json.gd")
const GEM_ACTIONS := ["offer_gems", "purchase_gems", "reroll_gems", "choose_gem"]
const RUN_ACTIONS := ["start_run", "close_run"]

static func valid_header(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1: return false
	if not value.get("authorityEpoch") is String or value.authorityEpoch.is_empty(): return false
	for key in ["economyRevision", "gemResetTickets"]:
		if not value.get(key) is int or value[key] < 0: return false
	return true

static func valid_run(value: Variant) -> bool:
	return value is Dictionary and value.get("runId") is String and not value.runId.is_empty() and value.get("stageNumber") is int and value.stageNumber > 0 and value.get("status") in ["active", "closed"]

static func validate(command: Dictionary, result: Dictionary) -> bool:
	var request: Variant = Json.parse(command.encodedBody)
	if not request is Dictionary: return false
	var kind: String = command.kind
	var compatibility := int(request.get("clientCompatibilityVersion", 1))
	if compatibility >= 9:
		if not valid_header(result.get("gemReceipt")): return false
		if not result.get("saveRevision") is int or result.saveRevision <= 0: return false
		if not result.get("serverSavedAt") is String or RegEx.create_from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2}T").search(result.serverSavedAt) == null: return false
	elif kind == "reroll_gems" and compatibility < 8 and result.get("gemOffer") == null:
		var old: Variant = result.get("gemReroll")
		return Offers.valid_receipt(old) and result.get("economy") is Dictionary and result.economy.get("gemReroll") == old and old.runId == request.get("runId") and old.rewardWave == request.get("completedRounds") and old.totalUsed == int(request.get("expectedRerollCount", -1)) + 1
	if kind in RUN_ACTIONS:
		var run: Variant = result.get("run")
		if not valid_run(run): return false
		if kind == "start_run": return run.status == "active" and run.stageNumber == request.get("stageNumber")
		return run.status == "closed" and run.runId == request.get("runId")
	var offer: Variant = result.get("gemOffer")
	if not Offers.valid_offer(offer) or offer.runId != request.get("runId") or offer.rewardWave != request.get("completedRounds"): return false
	if compatibility < 9:
		if not result.get("economy") is Dictionary or result.economy.get("gemOfferVersion") != 1 or result.economy.get("gemOffer") != offer: return false
		if not result.get("saveRevision") is int or result.saveRevision <= 0 or not result.get("activeRun") is Dictionary: return false
	if kind in ["reroll_gems", "choose_gem"] and offer.offerId != request.get("offerId"): return false
	if kind == "purchase_gems" and (offer.get("kind") != "purchase" or offer.status != "pending"): return false
	if kind == "offer_gems" and offer.get("kind", "wave") != "wave": return false
	if kind == "reroll_gems" and (offer.get("kind", "wave") != "wave" or offer.status != "pending" or offer.totalUsed != int(request.get("expectedRerollCount", -1)) + 1 or offer.revision != int(request.get("expectedOfferRevision", 0)) + 1): return false
	if kind == "choose_gem" and (offer.status != "chosen" or offer.choice != request.get("choice") or offer.revision != int(request.get("expectedOfferRevision", 0)) + 1): return false
	return true
