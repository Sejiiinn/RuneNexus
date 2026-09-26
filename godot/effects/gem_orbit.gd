extends Node3D
## Presentation only. The caller supplies the authoritative combat clock.
## Geometry is cached by membership count; time updates rotate one parent only.

const GEM_PATH := "res://assets/effects/gem_orbit/gem.glb"
const RIBBON_SHADER = preload("res://effects/gem_orbit_ribbon.gdshader")
const RADIUS := 0.445
const ORBIT_HEIGHT := 0.32
const GEM_SCALE := 0.16
const ANGULAR_SPEED := 1.25
const MAX_SPAN := TAU * 150.0 / 360.0
const HEAD_GAP := 0.19
const RIBBON_WIDTH := 0.058
const SEGMENTS := 48
const LIGHT_RANGE := 0.7
const LIGHT_ENERGY := 1.1

static var _gem_scene: PackedScene
static var _ribbon_meshes: Dictionary = {}
static var _gem_materials: Dictionary = {}
static var _ribbon_materials: Dictionary = {}

var _colors: Array = []
var _rotor: Node3D
var _combat_time := 0.0


func configure(gem_colors: Array) -> void:
	if _colors == gem_colors:
		return
	_colors = gem_colors.duplicate()
	if _rotor != null:
		remove_child(_rotor)
		_rotor.free()
	_rotor = null
	visible = not _colors.is_empty()
	if _colors.is_empty():
		return
	if _gem_scene == null:
		_gem_scene = load(GEM_PATH) as PackedScene
	if _gem_scene == null:
		push_error("Satellite gem asset is unavailable: " + GEM_PATH)
		return
	_rotor = Node3D.new()
	_rotor.name = "OrbitRotor"
	add_child(_rotor)
	var ribbon_mesh := _mesh_for_count(_colors.size())
	for i in range(_colors.size()):
		var color: Color = _colors[i]
		var slot := Node3D.new()
		slot.name = "GemSlot%d" % i
		slot.rotation.y = -TAU * float(i) / float(_colors.size())
		_rotor.add_child(slot)
		var gem := _gem_scene.instantiate() as Node3D
		gem.name = "Gem"
		gem.position = Vector3(RADIUS, ORBIT_HEIGHT, 0.0)
		# Authored nose is +X. Increasing orbit angle travels toward +Z here.
		gem.rotation.y = -PI * 0.5
		gem.scale = Vector3.ONE * GEM_SCALE
		slot.add_child(gem)
		_tint_gem(gem, _gem_material_for(color))
		# Local color spill only; no extra shadow pass. Normalizing energy keeps
		# several equipped gems from washing the entire turret white.
		var light := OmniLight3D.new()
		light.name = "GemLight"
		light.position = gem.position
		light.light_color = color
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.8
		light.light_energy = LIGHT_ENERGY / sqrt(float(_colors.size()))
		light.shadow_enabled = false
		slot.add_child(light)
		var ribbon := MeshInstance3D.new()
		ribbon.name = "TrailingRibbon"
		ribbon.mesh = ribbon_mesh
		ribbon.material_override = _ribbon_material_for(color)
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slot.add_child(ribbon)
	update_time(_combat_time)


func update_time(combat_time: float) -> void:
	_combat_time = combat_time
	if _rotor != null:
		_rotor.rotation.y = -fposmod(combat_time * ANGULAR_SPEED, TAU)


static func trail_span(count: int) -> float:
	return minf(MAX_SPAN, TAU / float(maxi(count, 1)) * 0.8)


static func _mesh_for_count(count: int) -> ArrayMesh:
	if _ribbon_meshes.has(count):
		return _ribbon_meshes[count]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var span := trail_span(count)
	for j in range(SEGMENTS + 1):
		var t := float(j) / float(SEGMENTS)
		# Every vertex lies behind the head. The terminal point narrows to zero.
		var angle := -lerpf(HEAD_GAP, span, t)
		var half_width := RIBBON_WIDTH * 0.5 * pow(1.0 - t, 0.72)
		for side in [-1.0, 1.0]:
			var radius: float = RADIUS + half_width * side
			vertices.append(Vector3(cos(angle) * radius, ORBIT_HEIGHT, sin(angle) * radius))
			normals.append(Vector3.UP)
			uvs.append(Vector2(t, (side + 1.0) * 0.5))
		if j < SEGMENTS:
			var k := j * 2
			indices.append_array(PackedInt32Array([k, k + 2, k + 1, k + 1, k + 2, k + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_ribbon_meshes[count] = mesh
	return mesh


static func _gem_material_for(color: Color) -> StandardMaterial3D:
	if _gem_materials.has(color):
		return _gem_materials[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.24
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	_gem_materials[color] = material
	return material


static func _ribbon_material_for(color: Color) -> ShaderMaterial:
	if _ribbon_materials.has(color):
		return _ribbon_materials[color]
	var material := ShaderMaterial.new()
	material.shader = RIBBON_SHADER
	material.set_shader_parameter("ribbon_color", color)
	_ribbon_materials[color] = material
	return material


static func _tint_gem(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_tint_gem(child, material)
