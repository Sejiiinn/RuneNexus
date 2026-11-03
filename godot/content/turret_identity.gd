extends RefCounted
## Turret ids renamed in client compatibility 17 to match their display names.
## Saves, journals and server replays written before then still carry the old
## ids, so every reader maps them here before validating content identities.
const LEGACY := {"arrow": "machinegun", "magic": "flame"}
const UNLOCK_PREFIX := "turret:"

static func canonical(value: Variant) -> Variant:
	return LEGACY.get(value, value) if value is String else value

## Save trees (v1 or v2, whole envelope or one section) with every turret id
## field mapped. Returns the input itself when it holds no legacy id, so the
## common current-save path neither copies nor changes its identity.
static func migrate_save(value: Variant) -> Variant:
	if not _has_legacy(value, ""): return value
	return _migrate(value, "")

static func _legacy_entry(value: Variant, key: String) -> bool:
	if not value is String: return false
	if key == "grandfatherUnlocks": return value.begins_with(UNLOCK_PREFIX) and LEGACY.has(value.trim_prefix(UNLOCK_PREFIX))
	return LEGACY.has(value)

static func _has_legacy(value: Variant, key: String) -> bool:
	if value is Dictionary:
		for child in value:
			var item: Variant = value[child]
			if child == "turretType" and LEGACY.has(item): return true
			if child == "type" and key == "turrets" and LEGACY.has(item): return true
			if _has_legacy(item, child): return true
	elif value is Array:
		for item in value:
			if key in ["challengeTurretTypes", "grandfatherUnlocks"] and _legacy_entry(item, key): return true
			if _has_legacy(item, key): return true
	return false

static func _migrate(value: Variant, key: String) -> Variant:
	if value is Dictionary:
		var out := {}
		for child in value:
			var item: Variant = value[child]
			out[child] = canonical(item) if child == "turretType" or (child == "type" and key == "turrets") else _migrate(item, child)
		return out
	if value is Array:
		var out := []
		for item in value:
			if key == "challengeTurretTypes": out.append(canonical(item))
			elif key == "grandfatherUnlocks" and _legacy_entry(item, key): out.append(UNLOCK_PREFIX + LEGACY[item.trim_prefix(UNLOCK_PREFIX)])
			else: out.append(_migrate(item, key))
		return out
	return value
