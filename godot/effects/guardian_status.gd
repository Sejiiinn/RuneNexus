extends RefCounted
## Each authored rig shares three offline-merged meshes: burn + shards + grains.
const AttachmentKind = preload("res://effects/enemy_attachment_kind.gd")
const MESHES := {
	"normal": {
		"EnemyBurn": [preload("res://assets/enemies/normal_status_burn.res")],
		"EnemyFrost": [preload("res://assets/enemies/normal_status_frost_shards.res"), preload("res://assets/enemies/normal_status_frost_grains.res")],
	},
	"fast": {
		"EnemyBurn": [preload("res://assets/enemies/fast_status_burn.res")],
		"EnemyFrost": [preload("res://assets/enemies/fast_status_frost_shards.res"), preload("res://assets/enemies/fast_status_frost_grains.res")],
	},
	"boss": {
		"EnemyBurn": [preload("res://assets/enemies/boss_status_burn.res")],
		"EnemyFrost": [preload("res://assets/enemies/boss_status_frost_shards.res"), preload("res://assets/enemies/boss_status_frost_grains.res")],
	},
	"tank": {
		"EnemyBurn": [preload("res://assets/enemies/tank_status_burn.res")],
		"EnemyFrost": [preload("res://assets/enemies/tank_status_frost_shards.res"), preload("res://assets/enemies/tank_status_frost_grains.res")],
	},
}
const COORDINATE_SCALES := {"normal": 1.0940977489373418, "fast": 0.522027035655198, "tank": 0.2997284531593323, "boss": 1.292772412300}
static var _materials := {}


static func attach(entry: Dictionary, _templates: Array, materials: Array, label: String) -> Node3D:
	var body: MeshInstance3D = entry.root.find_children("*", "MeshInstance3D", true, false)[0]
	var skeleton := body.get_node(body.skeleton) as Skeleton3D
	var container := Node3D.new()
	container.name = label
	body.get_parent().add_child(container)
	container.transform = body.transform
	var kind := AttachmentKind.resolve(entry.type)
	var material_key := label + ":" + kind
	if not _materials.has(material_key):
		var shared: Array = []
		for material: Material in materials:
			if material is ShaderMaterial:
				var adapted := material.duplicate() as ShaderMaterial
				adapted.set_shader_parameter("skinned_status", true)
				if label == "EnemyBurn":
					adapted.set_shader_parameter("coordinate_scale", COORDINATE_SCALES[kind])
				shared.append(adapted)
			else: shared.append(material)
		_materials[material_key] = shared
	var meshes: Array = MESHES[kind][label]
	for index in range(meshes.size()):
		var effect := MeshInstance3D.new()
		effect.mesh = meshes[index]
		effect.skin = body.skin
		effect.material_override = _materials[material_key][index]
		effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effect.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		container.add_child(effect)
		effect.skeleton = effect.get_path_to(skeleton)
		if label == "EnemyBurn":
			effect.set_instance_shader_parameter("phase_offset", float(entry.root.get_instance_id() % 997) / 997.0 * 4.0)
	return container


static func set_burn_time(time: float) -> void:
	for key: String in _materials:
		if key.begins_with("EnemyBurn:"):
			_materials[key][0].set_shader_parameter("burn_time", time)
