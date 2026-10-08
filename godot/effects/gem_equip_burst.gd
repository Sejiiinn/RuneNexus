extends Node3D
## A brief equipment receipt: curved energy sweeps, soft wavefronts and glints.
## Static 3D geometry; real-time shader age preserves feedback during preparation.
const SHADER = preload("res://effects/gem_equip_energy.gdshader")
const DURATION := 0.74
const FLASH_DURATION := 0.16
var color := Color("69D7FF")
var age := 0.0
var _materials: Array[ShaderMaterial] = []
var _glints: Array[Dictionary] = []
var _light: OmniLight3D

func _ready() -> void:
	name = "GemEquipBurst"
	position.y = 0.58
	set_meta("exclude_selection_mask", true)
	var stream_material := _material(-1.0)
	for index in 6:
		var angle := TAU * float(index) / 6.0 + 0.18
		var seed := float(index) / 6.0
		var delay := float(index % 3) * 0.014
		_add_mesh("EnergySweep%d" % index, _ribbon(angle, seed, delay, 0.054), stream_material)
		if index % 2 == 0:
			_add_mesh("FineWisp%d" % index, _ribbon(angle + 0.17, seed + 0.11, delay + 0.032, 0.019), stream_material)
	for index in 2:
		var wave := _add_mesh("Wavefront%d" % index, _wave(float(index) * 0.042 + 0.016, float(index) * 0.37), stream_material)
		wave.position.y = 0.035 + float(index) * 0.065
		wave.rotation.z = -0.07 + float(index) * 0.14
	var flash := SphereMesh.new()
	flash.radius = 0.26
	flash.height = 0.52
	flash.radial_segments = 16
	flash.rings = 8
	var core := _add_mesh("EquipFlash", flash, _material(2.0))
	core.position.y = 0.035
	for index in 7:
		var angle := TAU * float(index) / 7.0 + 0.32
		var sphere := SphereMesh.new()
		sphere.radius = 0.036
		sphere.height = 0.072
		sphere.radial_segments = 8
		sphere.rings = 4
		var material := _material(3.0)
		var delay := 0.045 + float(index % 4) * 0.027
		material.set_shader_parameter("delay", delay)
		material.set_shader_parameter("seed", float(index) * 1.71)
		var glint := _add_mesh("Glint%d" % index, sphere, material)
		_glints.append({"node":glint, "angle":angle, "delay":delay, "radius":0.52 + float(index % 3) * 0.055, "lift":0.18 + float(index % 4) * 0.045})
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = 0.85
	_light.light_energy = 1.15
	_light.shadow_enabled = false
	add_child(_light)
	_update(0.0)

func _material(kind: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("gem_color", color)
	material.set_shader_parameter("kind", kind)
	_materials.append(material)
	return material

func _add_mesh(label: String, mesh: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 0.1
	node.set_meta("exclude_selection_mask", true)
	add_child(node)
	return node

func _point(radius: float, angle: float, height: float) -> Vector3:
	return Vector3(cos(angle) * radius, height, sin(angle) * radius)

func _ribbon(angle: float, seed: float, delay: float, width: float) -> ArrayMesh:
	# The tangent turns as the ribbon rises. No closed circle or orbit motion.
	var turn := 0.56 if int(round(seed * 6.0)) % 2 == 0 else -0.44
	var start := _point(0.095, angle - turn * 0.18, -0.025)
	var handle_a := _point(0.26, angle - turn * 0.18, 0.025)
	var handle_b := _point(0.63, angle + turn * 0.65, 0.19 + seed * 0.08)
	var end := _point(0.65, angle + turn, 0.36 + seed * 0.13)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var metadata := PackedColorArray()
	var indices := PackedInt32Array()
	const SEGMENTS := 28
	for index in SEGMENTS + 1:
		var u := float(index) / SEGMENTS
		var point := start.bezier_interpolate(handle_a, handle_b, end, u)
		var tangent := (3.0 * (1.0-u) * (1.0-u) * (handle_a-start) + 6.0 * (1.0-u) * u * (handle_b-handle_a) + 3.0 * u*u * (end-handle_b)).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		var half_width := width * 0.5 * (0.16 + 0.84 * pow(sin(PI * u), 0.65))
		for edge in 2:
			vertices.append(point + side * half_width * (-1.0 if edge == 0 else 1.0))
			normals.append(side.cross(tangent).normalized())
			uvs.append(Vector2(u, float(edge)))
			metadata.append(Color(0.0, seed, delay, 1.0))
		if index < SEGMENTS:
			var first := index * 2
			indices.append_array(PackedInt32Array([first,first+1,first+2,first+1,first+3,first+2]))
	return _mesh(vertices, normals, uvs, metadata, indices)

func _wave(delay: float, seed: float) -> ArrayMesh:
	# A feathered sheet with micro-strands, rather than an opaque torus surface.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var metadata := PackedColorArray()
	var indices := PackedInt32Array()
	const SEGMENTS := 80
	for index in SEGMENTS + 1:
		var angle := TAU * float(index) / SEGMENTS
		for edge in 2:
			var radius := 0.565 + float(edge) * 0.07
			vertices.append(_point(radius, angle, 0.008 * sin(angle*3.0 + seed)))
			normals.append(Vector3.UP)
			uvs.append(Vector2(float(index)/SEGMENTS, float(edge)))
			metadata.append(Color(1.0, seed, delay, 1.0))
		if index < SEGMENTS:
			var first := index * 2
			indices.append_array(PackedInt32Array([first,first+1,first+2,first+1,first+3,first+2]))
	return _mesh(vertices, normals, uvs, metadata, indices)

func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, metadata: PackedColorArray, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = metadata
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _process(delta: float) -> void:
	age += delta
	_update(age)
	if age >= DURATION: queue_free()

func _update(time: float) -> void:
	for material in _materials: material.set_shader_parameter("age", time)
	for glint in _glints:
		var elapsed := maxf(time - float(glint.delay), 0.0)
		var travel := 0.70 * (1.0 - exp(-elapsed / 0.12)) + 0.30 * elapsed / 0.48
		glint.node.position = _point(lerpf(0.14, float(glint.radius), travel), float(glint.angle) + 0.24 * travel, float(glint.lift) * travel)
	_light.light_energy = 1.15 * pow(1.0 - clampf(time / FLASH_DURATION, 0.0, 1.0), 2.0)
