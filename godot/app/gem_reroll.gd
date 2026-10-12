extends RefCounted
## Deterministic offers and pure authoritative projection, isolated from combat RNG.
const MAX_USES := 3
const DOMAIN := "rune-nexus:gem-reroll:v1"

static func eligible(state: Dictionary) -> bool:
	return state.get("phase") == "reward" and not state.get("isPurchasedGemReward", false) and int(state.get("completedRounds", 0)) > 0 and int(state.get("completedRounds", 0)) % 5 == 0 and state.get("rewardOptions", []).size() == 3

static func options(run_id: String, wave: int, total_used: int, available: Array, previous: Array) -> Array:
	var ranked: Array = []
	for gem in available:
		if gem in previous: continue
		var rank := ("%s:%s:%d:%d:%s" % [DOMAIN, run_id, wave, total_used, gem]).sha256_text()
		ranked.append({"gem":gem, "rank":rank})
	ranked.sort_custom(func(a, b): return a.rank < b.rank if a.rank != b.rank else a.gem < b.gem)
	var result: Array = []
	for item in ranked.slice(0, mini(3, ranked.size())): result.append(item.gem)
	return result

static func valid_receipt(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not value.get("runId") is String or value.runId.is_empty(): return false
	if not value.get("rewardWave") is int or value.rewardWave <= 0 or value.rewardWave % 5 != 0: return false
	if not value.get("totalUsed") is int or value.totalUsed < 1 or value.totalUsed > MAX_USES: return false
	if not value.get("gemOptions") is Array or value.gemOptions.size() != 3: return false
	var seen := {}
	for gem in value.gemOptions:
		if not gem is String or gem.is_empty() or seen.has(gem): return false
		seen[gem] = true
	return true

static func project(state: Dictionary, receipt: Variant) -> Dictionary:
	var next := state.duplicate(true)
	if receipt == null: return next
	if not valid_receipt(receipt): return {}
	if state.get("economyRunId") != receipt.runId: return next
	# The ledger survives later waves. A delayed response cannot reopen a reward.
	next.gemRerollsUsed = maxi(int(state.get("gemRerollsUsed", 0)), int(receipt.totalUsed))
	if eligible(state) and int(state.get("completedRounds", 0)) == int(receipt.rewardWave):
		if int(state.get("gemRerollsUsed", 0)) <= int(receipt.totalUsed):
			next.rewardOptions = receipt.gemOptions.duplicate()
	return next
