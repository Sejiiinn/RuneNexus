extends RefCounted
const Capabilities = preload("res://combat/attack_capabilities.gd")
## Integer attack properties compose additively, not through numeric gem scaling.
const GEM_MODIFIERS := {"piercing":{"pierceCount":2}}
static func pierce_count(input: Dictionary) -> int:
	var definition: Dictionary = input.get("definition", {})
	if not Capabilities.supports_projectile(definition): return 0
	var count := int(definition.get("pierceCount", 0))
	for gem in input.get("gems", []):
		count += int(GEM_MODIFIERS.get(gem, {}).get("pierceCount", 0))
	for modifier in input.get("attackModifiers", []):
		count += int(modifier.get("pierceCount", 0))
	return maxi(0, count)
