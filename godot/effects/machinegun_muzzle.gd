extends Node3D

## 고정 수의 포구 화염·분리된 연기·불티를 실제 발사 순번에 맞춰 재사용.
const FLAME = preload("res://assets/effects/machinegun_muzzle.glb")
const FLASH_SHADER = preload("res://effects/machinegun_flash.gdshader")
const SMOKE_SHADER = preload("res://effects/machinegun_smoke.gdshader")
const FLASH_SECONDS := 0.055
const SMOKE_SECONDS := 0.32
const SPARK_SECONDS := 0.15
const SHOT_CAPACITY := 6
const SPARKS_PER_SHOT := 4
static var _noise: ImageTexture3D
static var _smoke_box: BoxMesh
static var _spark_mesh: SphereMesh

var flashes: Array[Node3D] = []
var flash_materials: Array[ShaderMaterial] = []
var shots: Array[Dictionary] = []
var sparks := MultiMeshInstance3D.new()
var light := OmniLight3D.new()
var active_port := 0
var fire_start := -INF
var next_slot := 0


func _ready() -> void:
	# 부모 포탑의 수명은 따르되 지난 연기·불티는 월드 좌표에 고정.
	top_level = true
	global_transform = Transform3D.IDENTITY
	if _noise == null:
		var bytes := FileAccess.get_file_as_bytes("res://assets/machinegun_muzzle_noise.bin")
		if bytes.size() != 32 * 32 * 32:
			push_error("기관총 연기장의 크기가 맞지 않습니다.")
			return
		var slices: Array[Image] = []
		for z in range(32):
			slices.append(Image.create_from_data(32, 32, false, Image.FORMAT_L8, bytes.slice(z * 1024, (z + 1) * 1024)))
		_noise = ImageTexture3D.new()
		var error := _noise.create(Image.FORMAT_L8, 32, 32, 32, false, slices)
		if error != OK:
			push_error("기관총 연기장 업로드 실패: %s" % error_string(error))
			_noise = null
			return
		_smoke_box = BoxMesh.new()
		_smoke_box.size = Vector3.ONE
		_spark_mesh = SphereMesh.new()
		_spark_mesh.radius = 1.0
		_spark_mesh.height = 2.0
		_spark_mesh.radial_segments = 4
		_spark_mesh.rings = 2
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = Color(1.0, 0.35, 0.035)
		material.emission_energy_multiplier = 2.0
		_spark_mesh.material = material
	for port in range(2):
		var flame: Node3D = FLAME.instantiate()
		var material := ShaderMaterial.new()
		material.shader = FLASH_SHADER
		for mesh: MeshInstance3D in flame.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		flame.visible = false
		flashes.append(flame)
		flash_materials.append(material)
	for slot in range(SHOT_CAPACITY):
		var smoke := MeshInstance3D.new()
		smoke.name = "MuzzleSmoke_%d" % slot
		smoke.mesh = _smoke_box
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = SMOKE_SHADER
		material.set_shader_parameter("u_noise", _noise)
		smoke.material_override = material
		smoke.visible = false
		add_child(smoke)
		shots.append({"smoke": smoke, "material": material, "start": -INF,
			"pose": Transform3D.IDENTITY, "seed": 0.0})
	sparks.multimesh = MultiMesh.new()
	sparks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	sparks.multimesh.use_colors = true
	sparks.multimesh.instance_count = SHOT_CAPACITY * SPARKS_PER_SHOT
	sparks.multimesh.mesh = _spark_mesh
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.custom_aabb = AABB(Vector3(-8, -1, -10), Vector3(16, 5, 20))
	add_child(sparks)
	light.light_color = Color(1.0, 0.56, 0.18)
	light.light_energy = 0.0
	light.omni_range = 0.9
	light.shadow_enabled = false
	add_child(light)
	reset()


func reset() -> void:
	fire_start = -INF
	next_slot = 0
	for flash in flashes:
		flash.visible = false
	for shot in shots:
		shot["start"] = -INF
		shot["smoke"].visible = false
	if sparks.multimesh:
		for index in range(sparks.multimesh.instance_count):
			sparks.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	light.light_energy = 0.0


func fire(muzzle: Node3D, time: float, sequence: int) -> void:
	if shots.is_empty():
		return
	active_port = posmod(sequence, 2)
	fire_start = time
	var pose := muzzle.global_transform.orthonormalized()
	pose.origin = muzzle.to_global(Vector3(-0.062 if active_port == 0 else 0.062, 0, 0.018))
	var shot: Dictionary = shots[next_slot]
	shot["start"] = time
	shot["pose"] = pose
	shot["seed"] = float(sequence % 997) * 2.39996
	flash_materials[active_port].set_shader_parameter("u_seed", shot["seed"])
	shot["material"].set_shader_parameter("u_seed", shot["seed"])
	next_slot = (next_slot + 1) % SHOT_CAPACITY


func update_effect(muzzle: Node3D, time: float, camera: Camera3D) -> void:
	var age := time - fire_start
	for port in range(flashes.size()):
		var flash := flashes[port]
		flash.visible = port == active_port and age >= 0.0 and age < FLASH_SECONDS
		if flash.visible:
			flash.global_transform = muzzle.global_transform.orthonormalized()
			flash.global_position = muzzle.to_global(Vector3(-0.062 if port == 0 else 0.062, 0, 0.018))
			flash_materials[port].set_shader_parameter("u_progress", age / FLASH_SECONDS)
			light.global_position = flash.global_position + flash.global_basis.z * 0.13
	light.light_energy = 0.7 * pow(1.0 - age / FLASH_SECONDS, 2.0) if age >= 0.0 and age < FLASH_SECONDS else 0.0
	for slot in range(shots.size()):
		var shot: Dictionary = shots[slot]
		var elapsed := time - float(shot["start"])
		var progress := clampf(elapsed / SMOKE_SECONDS, 0.0, 1.0)
		var smoke: MeshInstance3D = shot["smoke"]
		var pose: Transform3D = shot["pose"]
		smoke.visible = elapsed >= 0.0 and elapsed < SMOKE_SECONDS
		if smoke.visible:
			var width := 0.16 + progress * 0.28
			smoke.global_transform = Transform3D(pose.basis.scaled_local(Vector3(width, width, 0.42 + progress * 0.28)),
				pose.origin + pose.basis.z * (0.17 + progress * 0.20) + Vector3.UP * progress * 0.17)
			shot["material"].set_shader_parameter("u_progress", progress)
		for index in range(SPARKS_PER_SHOT):
			var transform := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
			if elapsed >= 0.0 and elapsed < SPARK_SECONDS:
				var seed := float(shot["seed"]) + float(index) * 2.39996
				var velocity := pose.basis * Vector3(sin(seed) * 0.65, cos(seed * 1.3) * 0.5, 2.2 + sin(seed * 0.7) * 0.6)
				var direction := velocity.normalized()
				var right := direction.cross(Vector3.UP).normalized()
				var basis := Basis(right, direction.cross(right), direction)
				var fade := 1.0 - elapsed / SPARK_SECONDS
				transform = Transform3D(basis.scaled_local(Vector3(0.004, 0.004, 0.032 * fade)),
					pose.origin + velocity * elapsed + Vector3.DOWN * 1.6 * elapsed * elapsed)
				sparks.multimesh.set_instance_color(slot * SPARKS_PER_SHOT + index, Color(1.0, 0.66, 0.20, fade))
			sparks.multimesh.set_instance_transform(slot * SPARKS_PER_SHOT + index, transform)
	update_camera(camera)


func update_camera(camera: Camera3D) -> void:
	# HUD 맞춤 h/v_offset까지 반영된 실제 렌더 카메라를 사용.
	var camera_pose := camera.get_camera_transform()
	for shot in shots:
		var smoke: MeshInstance3D = shot["smoke"]
		if not smoke.visible:
			continue
		var inverse := smoke.global_transform.affine_inverse()
		var local_camera := inverse * camera_pose.origin
		var material: ShaderMaterial = shot["material"]
		material.set_shader_parameter("u_view_to_local", inverse * camera_pose)
		material.set_shader_parameter("u_camera_local", local_camera)
		material.set_shader_parameter("u_ray_direction", inverse.basis * -camera_pose.basis.z)
		material.set_shader_parameter("u_orthographic", camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
		material.set_shader_parameter("u_camera_inside", absf(local_camera.x) < 0.5 and absf(local_camera.y) < 0.5 and absf(local_camera.z) < 0.5)
