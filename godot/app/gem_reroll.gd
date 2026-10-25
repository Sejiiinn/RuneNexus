extends RefCounted
## Pure validation/projection. Every candidate, purchase and grant is server owned.
const MAX_USES := 3
const GEM_TYPES := preload("res://content/generated_content_registry.gd").GEM_TYPES

static func eligible(state: Dictionary) -> bool:
	return state.get("phase") == "reward" and not state.get("isPurchasedGemReward", false) and int(state.get("completedRounds", 0)) > 0 and int(state.get("completedRounds", 0)) % 5 == 0

static func valid_receipt(value: Variant) -> bool:
	# Frozen generation-7 receipts remain decodable; never project their cards.
	if not value is Dictionary: return false
	if not value.get("runId") is String or value.runId.is_empty(): return false
	if not value.get("rewardWave") is int or value.rewardWave <= 0 or value.rewardWave % 5 != 0: return false
	if not value.get("totalUsed") is int or value.totalUsed < 1 or value.totalUsed > MAX_USES: return false
	return _valid_options(value.get("gemOptions"))

static func _valid_options(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	var seen := {}
	for gem in value:
		if gem not in GEM_TYPES or seen.has(gem): return false
		seen[gem] = true
	return true

static func valid_offer(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in ["runId", "offerId"]:
		if not value.get(key) is String or value[key].is_empty(): return false
	var kind: String = str(value.get("kind", "wave"))
	if kind not in ["wave", "purchase"] or not value.get("rewardWave") is int: return false
	if kind == "wave" and (value.rewardWave <= 0 or value.rewardWave % 5 != 0): return false
	if kind == "purchase":
		if value.rewardWave < 0 or value.get("returnPhase") not in ["preparation", "wave"]: return false
		if not value.get("purchaseSequence") is int or value.purchaseSequence < 1: return false
	if value.has("economyRevision") and (not value.economyRevision is int or value.economyRevision < 0): return false
	if not value.get("revision") is int or value.revision < 1: return false
	if not value.get("totalUsed") is int or value.totalUsed < 0 or value.totalUsed > MAX_USES: return false
	if not _valid_options(value.get("gemOptions")): return false
	if not value.get("gemInventory") is Dictionary or not value.get("gemShards") is int or value.gemShards < 0: return false
	for gem in value.gemInventory:
		if gem not in GEM_TYPES or not value.gemInventory[gem] is int or value.gemInventory[gem] < 0: return false
	if value.get("status") == "pending": return value.get("choice", "") == "" and value.get("grantedGem", "") == "" and value.get("grantedShards", 0) == 0
	if value.get("status") != "chosen": return false
	if value.get("choice") == "shards": return kind == "wave" and value.get("grantedGem", "") == "" and value.get("grantedShards") == 10
	return value.get("choice") in value.gemOptions and value.get("grantedGem") == value.choice and value.get("grantedShards", 0) == 0

static func current_offer(state: Dictionary) -> bool:
	return state.get("phase") == "reward" and (eligible(state) or state.get("isPurchasedGemReward", false)) and state.get("gemOfferStatus") == "pending" and not str(state.get("gemOfferId", "")).is_empty() and int(state.get("gemOfferRevision", 0)) > 0 and _valid_options(state.get("rewardOptions"))

static func project_snapshot(state: Dictionary, snapshot: Dictionary) -> Dictionary:
	var next := project(state, snapshot.get("gemOffer"))
	if next.is_empty(): return next
	# Generation-7 usage rows can outlive their older canonical save. The CURRENT
	# snapshot repairs only the monotonic budget before the next save/offer call.
	# Its historical candidates never become selectable or confer ownership.
	if int(snapshot.get("economyRevision", 0)) < int(state.get("gemEconomyRevision", 0)): return next
	var usage: Variant = snapshot.get("gemReroll")
	if snapshot.get("gemRerollVersion") != 1 or not valid_receipt(usage): return next
	if state.get("economyRunId") != usage.runId: return next
	if snapshot.has("run"):
		var lifecycle: Variant = snapshot.get("run")
		if not lifecycle is Dictionary or lifecycle.get("runId") != usage.runId or lifecycle.get("status") != "active": return next
	next.gemRerollsUsed = maxi(int(next.get("gemRerollsUsed", 0)), int(usage.totalUsed))
	return next

static func project(state: Dictionary, receipt: Variant) -> Dictionary:
	var next := state.duplicate(true)
	if receipt == null: return next
	if not valid_offer(receipt): return {}
	if state.get("economyRunId") != receipt.runId: return next
	if int(state.get("gemEconomyRevision", 0)) > int(receipt.get("economyRevision", 0)): return next
	next.gemRerollsUsed = maxi(int(state.get("gemRerollsUsed", 0)), int(receipt.totalUsed))
	# Only CURRENT snapshots reach projection. Round/offer revisions protect later
	# checkpoints, including local equip/remove/sell allocations of granted gems.
	if int(state.get("completedRounds", 0)) != int(receipt.rewardWave): return next
	var purchased: bool = receipt.get("kind", "wave") == "purchase"
	if state.get("gemOfferId", "") == receipt.offerId and int(state.get("gemOfferRevision", 0)) >= receipt.revision:
		if int(state.get("gemOfferRevision", 0)) == receipt.revision and receipt.status == "pending" and current_offer(state):
			next.rewardOptions = receipt.gemOptions.duplicate()
		return next
	if purchased:
		if state.get("phase") not in ["preparation", "wave", "reward"]: return next
		if state.get("phase") == "reward" and not state.get("isPurchasedGemReward", false): return next
	elif not eligible(state): return next
	if state.get("gemOfferId", "") != receipt.offerId: next.gemOfferEquipRevision = 0
	if receipt.has("economyRevision"): next.gemEconomyRevision = receipt.economyRevision
	next.gemOfferId = receipt.offerId
	next.gemOfferRevision = receipt.revision
	next.gemOfferStatus = receipt.status
	if receipt.status == "pending":
		next.rewardOptions = receipt.gemOptions.duplicate()
		if purchased:
			next.gemShards = receipt.gemShards
			next.rewardReturnPhase = receipt.returnPhase
			next.isPurchasedGemReward = true
			next.phase = "reward"
	else:
		next.gemInventory = receipt.gemInventory.duplicate(true)
		next.gemShards = receipt.gemShards
		next.rewardOptions = []
		next.rewardReturnPhase = null
		next.isPurchasedGemReward = false
		next.phase = receipt.returnPhase if purchased else "preparation"
	return next
