extends RefCounted
## Converts the validated HTTP economy snapshot to local progression + inventory.
const Codec = preload("res://app/save_codec.gd")
const Json = preload("res://app/save_json.gd")
var error := ""
var _catalog: Dictionary = {}

func _invalid(message: String) -> Dictionary:
	error = message
	return {}

func _integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum

func apply_authoritative(progression: Dictionary, snapshot: Dictionary) -> Dictionary:
	error = ""
	if _catalog.is_empty(): _catalog = Json.parse_record(FileAccess.get_file_as_string("res://content/growth_content.json")).value.module
	if not snapshot.get("wallet") is Dictionary or not snapshot.get("turretModules") is Dictionary or not snapshot.get("entitlements") is Dictionary: return _invalid("Missing economy snapshot objects")
	var wallet: Dictionary = snapshot.wallet
	var inventory: Dictionary = snapshot.turretModules
	for field in ["freeDiamonds", "paidDiamonds", "moduleTickets"]:
		if not _integer(wallet.get(field)): return _invalid("Invalid wallet " + field)
	for field in ["drawCount", "ticketPurchaseCount"]:
		if not _integer(inventory.get(field)): return _invalid("Invalid inventory " + field)
	if not inventory.get("items") is Array or not snapshot.entitlements.get("researchSlotTwoUnlocked") is bool: return _invalid("Invalid inventory or entitlement")
	var equipped := {}
	for item in progression.get("turretModules", {}).get("items", []):
		if item.get("equipped", false): equipped[item.id] = true
	var items := {}
	var sequence := 0
	for raw in inventory.items:
		if not raw is Dictionary: return _invalid("Invalid module")
		if not raw.get("id") is String or raw.id.strip_edges().is_empty() or not _integer(raw.get("acquiredOrder"), 1) or not raw.get("options") is Array or raw.options.is_empty(): return _invalid("Invalid module identity or options")
		for field in {"turretType": "TurretType", "part": "TurretModulePart", "family": "TurretModuleFamily", "grade": "TurretModuleGrade"}:
			var enum_name: String = {"turretType": "TurretType", "part": "TurretModulePart", "family": "TurretModuleFamily", "grade": "TurretModuleGrade"}[field]
			if not raw.get(field) in Codec.ENUMS[enum_name]: return _invalid("Unsupported module " + field)
		sequence = maxi(sequence, int(raw.acquiredOrder))
		var options: Array = []
		var seen := {}
		for option in raw.options:
			if not option is Dictionary or not option.get("type") in Codec.ENUMS.TurretModuleOptionType or not _integer(option.get("value"), 1): return _invalid("Unsupported module option")
			if seen.has(option.type) or not option.type in _catalog.pools[raw.turretType][raw.part]: continue
			seen[option.type] = true
			var limits: Dictionary = _catalog.ranges.get(option.type, {}).get(raw.grade, {})
			if limits.is_empty(): continue
			options.append({"type": option.type, "value": clampi(int(option.value), int(limits.min), int(limits.max))})
		if _catalog.families[raw.turretType][raw.part] != raw.family: continue
		items[raw.id] = {"id": raw.id, "turretType": raw.turretType, "part": raw.part, "family": raw.family, "grade": raw.grade, "options": options, "acquiredOrder": int(raw.acquiredOrder), "equipped": equipped.has(raw.id) or equipped.has(raw.get("legacyItemId"))}
	var slots := {}
	var result: Array = []
	for item in items.values():
		if item.options.is_empty(): continue
		var slot: String = item.turretType + ":" + item.part
		if item.equipped:
			if slots.has(slot): item.equipped = false
			else: slots[slot] = true
		result.append(item)
	result.sort_custom(_compare)
	var p := progression.duplicate(true)
	p.freeDiamonds = int(wallet.freeDiamonds)
	p.paidDiamonds = int(wallet.paidDiamonds)
	p.turretModules = {"tickets": int(wallet.moduleTickets), "drawCount": int(inventory.drawCount), "ticketPurchaseCount": int(inventory.ticketPurchaseCount), "itemSequence": sequence, "items": result}
	p.researchSlotTwoUnlocked = snapshot.entitlements.researchSlotTwoUnlocked
	return p

func _compare(a: Dictionary, b: Dictionary) -> bool:
	if a.turretType != b.turretType: return Codec.ENUMS.TurretType.find(a.turretType) < Codec.ENUMS.TurretType.find(b.turretType)
	if a.grade != b.grade: return Codec.ENUMS.TurretModuleGrade.find(a.grade) > Codec.ENUMS.TurretModuleGrade.find(b.grade)
	if a.options.size() != b.options.size(): return a.options.size() > b.options.size()
	if a.acquiredOrder != b.acquiredOrder: return a.acquiredOrder > b.acquiredOrder
	return Codec.ENUMS.TurretModulePart.find(a.part) < Codec.ENUMS.TurretModulePart.find(b.part)
