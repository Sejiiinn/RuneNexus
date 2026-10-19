extends RefCounted
## Magic/rare tier rim on every enemy model through GeometryInstance3D overlays.
## Applied only when an actor's tier changes; ordinary enemies keep no overlay.
const SHADER = preload("res://effects/enemy_rarity_glow.gdshader")
const COLORS := {"magic": Color(0.42, 0.58, 1.0), "rare": Color(1.0, 0.8, 0.28)}
const META := &"rarity_glow"
static var _materials: Dictionary = {}

static func material(rarity: String) -> ShaderMaterial:
	if not _materials.has(rarity):
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SHADER
		shader_material.set_shader_parameter("rim_color", COLORS[rarity])
		_materials[rarity] = shader_material
	return _materials[rarity]

## Pooled roots may change tier, so the applied tier lives on the root itself.
static func apply(root: Node3D, rarity: String) -> void:
	if str(root.get_meta(META, "")) == rarity: return
	root.set_meta(META, rarity)
	var overlay: Material = material(rarity) if COLORS.has(rarity) else null
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = overlay
