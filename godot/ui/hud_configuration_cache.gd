extends RefCounted
## Observe only configuration, not wallets, combat damage or quest journals.
## Explicit sync also detects direct state edits by tools and regression tests.
## Timer polling may trust a run-session replacement/finish revision.
const TURRET_FIELDS := ["id", "type", "x", "y", "level", "slotLimit", "primaryTrait", "secondaryTrait", "equippedGemSlots", "targetPriority", "investedGold"]
var revision := 0
var derive_count := 0
var _stage := -1
var _turrets: Array = []
var _upgrades: Dictionary = {}
var _progression: Dictionary = {}
var _fields: Array = []
var _derived: Dictionary = {}
var _source_id := 0
var _source_revision := -1
var _context: Array = []
var _catalog_inputs: Dictionary = {}
var _stat_entries: Dictionary = {}

# Called before either polling or explicit sync. A new owner/service/catalog must
# not inherit the previous run's derived configuration or display stats.
func bind(owner, catalog, service) -> void:
	var context := [owner.get_instance_id(), catalog.get_instance_id(), service.get_instance_id(), service.growth.get_instance_id()]
	var inputs := {"turrets":catalog.data.get("turrets", {}), "units":catalog.data.get("units", {})}
	if context == _context and inputs == _catalog_inputs: return
	_context = context
	_catalog_inputs = inputs.duplicate(true)
	invalidate()

# Runtime growth state changes are detected by sync. Tools that hot-edit the
# growth catalog data in place must invalidate explicitly; polling does not scan
# the entire growth catalog. Replacing the growth object is detected by bind.
func invalidate() -> void:
	_fields.clear()
	_derived.clear()
	_stat_entries.clear()
	_source_id = 0
	_source_revision = -1
	_stage = -1
	revision += 1

func stat_input(configuration: Dictionary, turret: Dictionary) -> Dictionary:
	var input: Dictionary = configuration.get("turretStatInputs", {}).get(turret.type, {}).duplicate(true)
	input.merge({"level":turret.level,"primaryTrait":turret.get("primaryTrait"),"secondaryTrait":turret.get("secondaryTrait"),"gems":turret.get("equippedGemSlots",[]).filter(func(g): return g != null)},true)
	return input

func stats(catalog, turret: Dictionary, input: Dictionary, tile_size: float) -> Dictionary:
	var key := str(turret.get("id", "build:"+str(turret.type)))+":"+str(tile_size)
	var entries: Array = _stat_entries.get(key, [])
	for entry in entries:
		if entry.type == turret.type and entry.input == input: return entry.stats
	var result: Dictionary = catalog.turret_stats(turret.type,{"tileSize":tile_size,"statInput":input})
	# Keep current and next-level previews independently, with bounded history.
	if entries.size() >= 2: entries.pop_front()
	entries.append({"type":turret.type,"input":input.duplicate(true),"stats":result})
	_stat_entries[key] = entries
	return result

func _prune_stats(state: Dictionary) -> void:
	var active := {}
	for turret in state.get("turrets", []): active[str(turret.id)] = true
	for key in _stat_entries.keys():
		if not str(key).begins_with("build:") and not active.has(str(key).get_slice(":",0)):
			_stat_entries.erase(key)

func sync_polled(state: Dictionary, growth_data: Dictionary, source_id: int, source_revision: int) -> int:
	if revision > 0 and source_id != 0 and source_revision >= 0 and source_id == _source_id and source_revision == _source_revision:
		return revision
	var result := sync(state, growth_data)
	_source_id = source_id
	_source_revision = source_revision
	return result

func sync(state: Dictionary, growth_data: Dictionary) -> int:
	# An explicit refresh always checks contents, even after a tracked poll.
	_source_id = 0
	_source_revision = -1
	if _fields.is_empty():
		_fields = ["researchLevels", "corePassiveNodeRanks", "turretModules", "clearedStageNumbers"]
		for key in growth_data.get("permanentUpgrades", {}):
			_fields.append(growth_data.permanentUpgrades[key].get("field", key + "UpgradeLevel"))
	if revision > 0 and _matches(state): return revision
	_prune_stats(state)
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
