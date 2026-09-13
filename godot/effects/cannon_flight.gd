extends Node3D

## 철구 지름 안의 짧은 체적 꼬리. 탄체는 부모의 원본 GLB가 담당한다.
const VOLUME_SHADER = preload("res://effects/cannon_flight.gdshader")
const MAX_LENGTH := 0.28
static var _noise: ImageTexture3D
static var _box: BoxMesh
static var _spark_mesh: SphereMesh
var volume := MeshInstance3D.new()
var material := ShaderMaterial.new()
var sparks := MultiMeshInstance3D.new()

func _init() -> void:
	if _noise == null:
		var bytes := FileAccess.get_file_as_bytes("res://assets/machinegun_muzzle_noise.bin")
		var slices: Array[Image] = []
		for z in range(32):
			slices.append(Image.create_from_data(32, 32, false, Image.FORMAT_L8, bytes.slice(z * 1024, (z + 1) * 1024)))
		_noise = ImageTexture3D.new()
		_noise.create(Image.FORMAT_L8, 32, 32, 32, false, slices)
		_box = BoxMesh.new()
		_box.size = Vector3.ONE
		_spark_mesh = SphereMesh.new()
		_spark_mesh.radius = 1.0
		_spark_mesh.height = 2.0
		_spark_mesh.radial_segments = 4
		_spark_mesh.rings = 2
		var spark_material := StandardMaterial3D.new()
		spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_material.vertex_color_use_as_albedo = true
		spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spark_mesh.material = spark_material
	volume.name = "CannonFlightVolume"
	volume.mesh = _box
	material.shader = VOLUME_SHADER
	material.set_shader_parameter("u_noise", _noise)
	volume.material_override = material
	volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(volume)
	sparks.name = "CannonFlightSparks"
	sparks.multimesh = MultiMesh.new()
	sparks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	sparks.multimesh.use_colors = true
	sparks.multimesh.instance_count = 3
	sparks.multimesh.mesh = _spark_mesh
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.custom_aabb = AABB(Vector3(-0.14, -0.14, -0.44), Vector3(0.28, 0.28, 0.31))
	add_child(sparks)
	reset()

func reset() -> void:
	visible = false
	volume.visible = false
	material.set_shader_parameter("u_opacity", 0.0)
	for index in range(3):
		sparks.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))

func update_flight(time: float, length: float, opacity: float) -> void:
	visible = opacity > 0.0 and length > 0.01
	volume.visible = visible
	if not visible:
		return
	var span := minf(MAX_LENGTH, length)
	volume.transform = Transform3D(Basis.from_scale(Vector3(0.22, 0.22, span)), Vector3(0, 0.018, -0.14 - span / 2.0))
	material.set_shader_parameter("u_time", time)
	material.set_shader_parameter("u_opacity", opacity)
	for index in range(3):
		var age := fposmod(time * 4.5 + index * 0.3333, 1.0)
		var phase := index * 2.39996
		var point := Vector3(sin(phase) * (0.035 + age * 0.055), cos(phase) * (0.035 + age * 0.055), -0.14 - span * age)
		var radius := 0.0045 * (1.0 - age * 0.6)
		sparks.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3(radius, radius, radius * 1.8)), point))
		sparks.multimesh.set_instance_color(index, Color(1.0, 0.37 + age * 0.16, 0.025, opacity * (1.0 - age)))

func update_camera(camera: Camera3D) -> void:
	if not visible or not volume.visible:
		return
	var pose := camera.get_camera_transform()
	var inverse := volume.global_transform.affine_inverse()
	var local_camera := inverse * pose.origin
	material.set_shader_parameter("u_view_to_local", inverse * pose)
	material.set_shader_parameter("u_camera_local", local_camera)
	material.set_shader_parameter("u_ray_direction", inverse.basis * -pose.basis.z)
	material.set_shader_parameter("u_orthographic", camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	material.set_shader_parameter("u_camera_inside", absf(local_camera.x) < 0.5 and absf(local_camera.y) < 0.5 and absf(local_camera.z) < 0.5)
