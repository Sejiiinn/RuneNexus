extends RefCounted
## Observe only configuration, not wallets, combat damage or quest journals.
## This also detects direct state edits used by restore tools and regression tests.
const TURRET_FIELDS := ["id", "type", "x", "y", "level", "slotLimit", "primaryTrait", "secondaryTrait", "equippedGemSlots", "targetPriority", "investedGold"]
var revision := 0
var derive_count := 0
var _stage := -1
var _turrets: Array = []
var _upgrades: Dictionary = {}
var _progression: Dictionary = {}
var _fields: Array = []
var _derived: Dictionary = {}

func sync(state: Dictionary, growth_data: Dictionary) -> int:
	if _fields.is_empty():
		_fields = ["researchLevels", "corePassiveNodeRanks", "turretModules", "clearedStageNumbers"]
		for key in growth_data.get("permanentUpgrades", {}):
			_fields.append(growth_data.permanentUpgrades[key].get("field", key + "UpgradeLevel"))
	if revision > 0 and _matches(state): return revision
	_stage = int(state.get("stage", -1))
	_turrets.clear()
	for turret in state.get("turrets", []):
		var entry := {}
		for field in TURRET_FIELDS: entry[field] = _owned(turret.get(field))
		_turrets.append(entry)
	_upgrades = state.get("runUpgradeLevels", {}).duplicate(true)
	_progression.clear()
	for field in _fields: _progression[field] = _owned(state.get("progression", {}).get(field))
	_derived = {}
	revision += 1
	return revision

func derived(state: Dictionary, service) -> Dictionary:
	if _derived.is_empty():
		_derived = service.derived(state)
		derive_count += 1
	return _derived

func _matches(state: Dictionary) -> bool:
	if _stage != int(state.get("stage", -1)) or _upgrades != state.get("runUpgradeLevels", {}): return false
	var current: Array = state.get("turrets", [])
	if current.size() != _turrets.size(): return false
	for i in range(current.size()):
		for field in TURRET_FIELDS:
			if current[i].get(field) != _turrets[i].get(field): return false
	var progression: Dictionary = state.get("progression", {})
	for field in _fields:
		if progression.get(field) != _progression.get(field): return false
	return true

func _owned(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value
