extends RefCounted
## Shared slot rules and edits on caller-owned state. Transactions own payment,
## slot selection, phase changes and any legacy-save migration policy.

# Capability requirements and their visible labels share one content source.
static var _capabilities: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/gem_capabilities.json"))

static func required_capabilities(gem: Variant) -> Array:
	return _capabilities.get("gemRequirements", {}).get(str(gem), [])

static func capability_label(key: String) -> String:
	return str(_capabilities.get("labels", {}).get(key, key))

static func requirement_text(gem: Variant) -> String:
	var names := PackedStringArray()
	for capability in required_capabilities(gem): names.append(capability_label(str(capability)))
	return "" if names.is_empty() else "장착 조건: " + " · ".join(names)

static func is_compatible(gem: Variant, rule: Variant) -> bool:
	var required := required_capabilities(gem)
	if not required.is_empty():
		if not rule is Dictionary: return false
		for capability in required:
			if capability not in rule.get("attackCapabilities", []): return false
		return true
	# Arrays remain accepted for old callers/tests of the legacy whitelist.
	return gem in (rule.get("compatibleGems", []) if rule is Dictionary else rule)

static func can_equip(turret: Dictionary, gem: Variant, rule: Variant) -> bool:
	return gem not in turret.equippedGemSlots and is_compatible(gem, rule)

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
