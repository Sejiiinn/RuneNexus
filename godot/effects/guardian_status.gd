extends RefCounted
## Three shared, offline-merged meshes reuse the guardian skin: burn + shards + grains.
const MESHES := {
	"EnemyBurn": [preload("res://assets/enemies/normal_status_burn.res")],
	"EnemyFrost": [preload("res://assets/enemies/normal_status_frost_shards.res"), preload("res://assets/enemies/normal_status_frost_grains.res")],
}
static var _materials := {}


static func attach(entry: Dictionary, _templates: Array, materials: Array, label: String) -> Node3D:
	var body: MeshInstance3D = entry.root.find_children("*", "MeshInstance3D", true, false)[0]
	var skeleton := body.get_node(body.skeleton) as Skeleton3D
	var container := Node3D.new()
	container.name = label
	body.get_parent().add_child(container)
	container.transform = body.transform
	if not _materials.has(label):
		var shared: Array = []
		for material: Material in materials:
			if material is ShaderMaterial:
				var adapted := material.duplicate() as ShaderMaterial
				adapted.set_shader_parameter("skinned_status", true)
				shared.append(adapted)
			else: shared.append(material)
		_materials[label] = shared
	for index in range(MESHES[label].size()):
		var effect := MeshInstance3D.new()
		effect.mesh = MESHES[label][index]
		effect.skin = body.skin
		effect.material_override = _materials[label][index]
		effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effect.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		container.add_child(effect)
		effect.skeleton = effect.get_path_to(skeleton)
		if label == "EnemyBurn":
			effect.set_instance_shader_parameter("phase_offset", float(entry.root.get_instance_id() % 997) / 997.0 * 4.0)
	return container


static func set_burn_time(time: float) -> void:
	if _materials.has("EnemyBurn"):
		_materials.EnemyBurn[0].set_shader_parameter("burn_time", time)
