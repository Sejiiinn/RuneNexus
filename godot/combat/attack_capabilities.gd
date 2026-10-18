extends RefCounted
## Explicit authored capabilities are authoritative; legacy fixtures use kinematics.
static func supports_projectile(definition: Dictionary) -> bool:
	if definition.has("attackCapabilities"):
		return "projectile" in definition.attackCapabilities
	return float(definition.get("projectileSpeed", 0.0)) > 0.0 and not bool(definition.get("instantHit", false)) and not bool(definition.get("centeredAreaAttack", false))
