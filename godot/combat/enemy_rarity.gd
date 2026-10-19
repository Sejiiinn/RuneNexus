extends RefCounted
## Magic/rare enemy rarity and affix rules. IDs are a code/save contract; the
## numbers come from compiled content (`enemyRarity`). Rounds author both the
## placement and the affixes; nothing is rolled at runtime. Affix effects are
## applied once to a freshly built enemy so restored enemies recompute the same maxima.

const RARITIES := ["magic", "rare"]
## Fixed application order: multipliers before ratios derived from final max HP.
const AFFIXES := ["swift", "sturdy", "plated", "warded", "regenerating", "steadfast"]
const AFFIX_FIELDS := {
	"swift": ["speedMultiplier"],
	"sturdy": ["maxHpMultiplier"],
	"plated": ["armorRatio"],
	"warded": ["shieldRatio", "shieldRegenRate"],
	"regenerating": ["hpRegenRate"],
	"steadfast": ["slowResistance"],
}

static func validate_rules(rules: Variant, enemy_types: Array) -> String:
	if not rules is Dictionary or rules.size() != 3 or not rules.has_all(["rarities", "affixes", "excludedTypes"]): return "Invalid enemy rarity fields"
	if not rules.rarities is Dictionary or rules.rarities.size() != RARITIES.size() or not rules.rarities.has_all(RARITIES): return "Invalid enemy rarity inventory"
	for rarity in RARITIES:
		var r: Variant = rules.rarities[rarity]
		if not r is Dictionary or r.size() != 4 or not r.has_all(["name", "maxHpMultiplier", "rewardGoldMultiplier", "affixCount"]): return "Invalid enemy rarity: " + rarity
		if not r.name is String or r.name.is_empty() or not _positive(r.maxHpMultiplier) or not r.rewardGoldMultiplier is int or r.rewardGoldMultiplier < 1: return "Invalid enemy rarity values: " + rarity
		var count: Variant = r.affixCount
		if not count is Array or count.size() != 2 or not count[0] is int or not count[1] is int or count[0] < 0 or count[1] < count[0] or count[1] > AFFIXES.size(): return "Invalid enemy rarity affix count: " + rarity
	if not rules.affixes is Dictionary or rules.affixes.size() != AFFIXES.size() or not rules.affixes.has_all(AFFIXES): return "Invalid enemy affix inventory"
	for affix in AFFIXES:
		var a: Variant = rules.affixes[affix]
		var fields: Array = AFFIX_FIELDS[affix]
		if not a is Dictionary or a.size() != fields.size() + 1 or not a.get("name") is String or a.name.is_empty(): return "Invalid enemy affix: " + affix
		for field in fields:
			if not _positive(a.get(field)): return "Invalid enemy affix value: " + affix
	if float(rules.affixes.steadfast.slowResistance) > 1.0: return "Slow resistance exceeds 1"
	if not rules.excludedTypes is Array: return "Invalid enemy rarity exclusions"
	for type in rules.excludedTypes:
		if not type is String or not type in enemy_types: return "Unknown enemy rarity exclusion"
	return ""

static func _positive(value: Variant) -> bool:
	return value is float and is_finite(value) and value > 0.0

## Saved/spawn values: rarity alone is a valid magic/rare enemy with no affix.
static func valid_values(rarity: Variant, affixes: Variant) -> bool:
	if not rarity is String or not rarity in RARITIES: return false
	if not affixes is Array: return false
	var seen := {}
	for affix in affixes:
		if not affix is String or not affix in AFFIXES or seen.has(affix): return false
		seen[affix] = true
	return true

static func eligible(rules: Dictionary, type: String) -> bool:
	return not rules.is_empty() and not type in rules.excludedTypes

## Authored rows must use the rarity's affix count and the fixed affix order.
static func authored_affixes_valid(rules: Dictionary, rarity: String, affixes: Variant) -> bool:
	if not valid_values(rarity, affixes) or affixes != sorted_affixes(affixes): return false
	var count_range: Array = rules.rarities[rarity].affixCount
	return affixes.size() >= int(count_range[0]) and affixes.size() <= int(count_range[1])

static func sorted_affixes(affixes: Array) -> Array:
	var result: Array = []
	for affix in AFFIXES:
		if affix in affixes: result.append(affix)
	return result

## Mutates a base enemy built from content (full HP/shield/armor) in place.
static func apply(e: Dictionary, rules: Dictionary, rarity: String, affixes: Array) -> void:
	var ordered := sorted_affixes(affixes)
	e.rarity = rarity
	e.affixes = ordered
	var hp_multiplier := float(rules.rarities[rarity].maxHpMultiplier)
	if "sturdy" in ordered: hp_multiplier *= float(rules.affixes.sturdy.maxHpMultiplier)
	e.maxHp = float(e.maxHp) * hp_multiplier
	e.hp = e.maxHp
	if "swift" in ordered: e.speed = float(e.speed) * float(rules.affixes.swift.speedMultiplier)
	if "plated" in ordered:
		e.maxArmor = float(e.get("maxArmor", 0.0)) + e.maxHp * float(rules.affixes.plated.armorRatio)
		e.armor = e.maxArmor
	if "warded" in ordered:
		e.maxShield = float(e.get("maxShield", 0.0)) + e.maxHp * float(rules.affixes.warded.shieldRatio)
		e.shield = e.maxShield
		e.shieldRegenRate = maxf(float(e.get("shieldRegenRate", 0.0)), float(rules.affixes.warded.shieldRegenRate))
	if "regenerating" in ordered: e.hpRegenRate = float(rules.affixes.regenerating.hpRegenRate)
	if "steadfast" in ordered: e.slowResistance = float(rules.affixes.steadfast.slowResistance)

static func reward_gold_multiplier(rules: Dictionary, rarity: Variant) -> int:
	if rules.is_empty() or not rarity is String or not rules.rarities.has(rarity): return 1
	return int(rules.rarities[rarity].rewardGoldMultiplier)
