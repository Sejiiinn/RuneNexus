extends RefCounted
## Support cores (docs/support_core_design.md): non-attacking structures on a
## build tile that strengthen orthogonally adjacent turrets. Pure board rules,
## shared by run transactions, HUD stat previews and the connection presentation.
const BUILD_GOLD := 150
## Damage family: added to the module damage increase layer (damageIncreaseRate).
const FAMILY_BONUS := {"damage": 0.15}
const FAMILY_INPUT := {"damage": "damageIncreaseRate"}

static func cores(state: Dictionary) -> Array:
	var value: Variant = state.get("supportCores")
	return value if value is Array else []

static func at(state: Dictionary, x: int, y: int) -> Dictionary:
	for core in cores(state):
		if int(core.x) == x and int(core.y) == y: return core
	return {}

static func adjacent(a_x: int, a_y: int, b_x: int, b_y: int) -> bool:
	return absi(a_x - b_x) + absi(a_y - b_y) == 1

## Strongest bonus per family from cores touching (x, y). Families stack; cores
## of one family never add up.
static func bonuses_at(state: Dictionary, x: int, y: int) -> Dictionary:
	var out := {}
	for core in cores(state):
		if not adjacent(int(core.x), int(core.y), x, y): continue
		var family := str(core.get("family", ""))
		out[family] = maxf(float(out.get(family, 0.0)), float(FAMILY_BONUS.get(family, 0.0)))
	return out

## Adds the core bonuses to one turret's stat input in place.
static func apply_to_input(input: Dictionary, state: Dictionary, turret: Dictionary) -> Dictionary:
	# Build previews have no tile yet.
	if not turret.has("x") or not turret.has("y"): return input
	var bonuses := bonuses_at(state, int(turret.x), int(turret.y))
	if bonuses.is_empty(): return input
	var module: Dictionary = input.get("moduleEffect", {}).duplicate()
	for family in bonuses:
		var field: String = FAMILY_INPUT.get(family, "")
		if not field.is_empty(): module[field] = float(module.get(field, 0.0)) + float(bonuses[family])
	input.moduleEffect = module
	return input

## [core tile, turret tile, turret id] for every active connection.
static func connections(state: Dictionary) -> Array:
	var out := []
	for core in cores(state):
		for turret in state.get("turrets", []):
			if adjacent(int(core.x), int(core.y), int(turret.x), int(turret.y)):
				out.append([Vector2i(int(core.x), int(core.y)), Vector2i(int(turret.x), int(turret.y)), int(turret.id)])
	return out

static func occupied(state: Dictionary, x: int, y: int) -> bool:
	if not at(state, x, y).is_empty(): return true
	for turret in state.get("turrets", []):
		if int(turret.x) == x and int(turret.y) == y: return true
	return false
