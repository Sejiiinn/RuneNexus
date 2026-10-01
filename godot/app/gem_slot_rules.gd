extends RefCounted
## Shared slot rules and edits on caller-owned state. Transactions own payment,
## slot selection, phase changes and any legacy-save migration policy.

static func is_compatible(gem: Variant, compatible_gems: Array) -> bool:
	return gem in compatible_gems

static func can_equip(turret: Dictionary, gem: Variant, compatible_gems: Array) -> bool:
	return gem not in turret.equippedGemSlots and is_compatible(gem, compatible_gems)

static func has_duplicates(slots: Array) -> bool:
	var seen := {}
	for gem in slots:
		if gem == null: continue
		if seen.has(gem): return true
		seen[gem] = true
	return false

static func sync_equipped(turret: Dictionary) -> void:
	turret.equippedGems = turret.equippedGemSlots.filter(func(g): return g != null)

## Caller validates the slot and incoming gem, and consumes its source if needed.
## Return the displaced gem to the same owned inventory for equip, remove or restore.
static func replace_owned(turret: Dictionary, slot: int, gem: Variant, inventory: Dictionary) -> void:
	var old = turret.equippedGemSlots[slot]
	if old != null: inventory[old] = int(inventory.get(old, 0)) + 1
	turret.equippedGemSlots[slot] = gem
	sync_equipped(turret)
