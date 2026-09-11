extends Node3D

## 실제 비행 좌표와 짧게 보존된 종료 경로를 탄체·입체 예광으로 표시.
const TRACER_SHADER = preload("res://effects/projectile_tracer.gdshader")
const AFTERIMAGE_SECONDS := 0.14
static var _templates := {}

var type := "arrow"
var body := MeshInstance3D.new()
var nose := MeshInstance3D.new()
var tracer := MeshInstance3D.new()
var tracer_material := ShaderMaterial.new()
var launch_position := Vector3.ZERO
var initialized := false
var trail_length := 0.0
var opacity := 0.0


func _init(projectile_type: String = "arrow") -> void:
	type = projectile_type
	name = "Projectile_" + type
	var heavy := type == "cannon"
	if not _templates.has(type):
		var radius := 0.052 if heavy else 0.017
		var length := 0.22 if heavy else 0.13
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color("73797e") if heavy else Color("e9bc73")
		metal.metallic = 0.5
		metal.roughness = 0.42
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
		cylinder.height = length
		cylinder.radial_segments = 10
		cylinder.material = metal
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = radius
		tip.height = length * 0.38
		tip.radial_segments = 10
		tip.material = metal
		var streak := CylinderMesh.new()
		streak.top_radius = 0.019 if heavy else 0.014
		streak.bottom_radius = 0.0025
		streak.height = 1.0
		streak.radial_segments = 6
		_templates[type] = {"body": cylinder, "nose": tip, "tracer": streak, "length": length}
	var template: Dictionary = _templates[type]
	body.mesh = template["body"]
	nose.mesh = template["nose"]
	nose.position.z = float(template["length"]) * 0.69
	tracer.mesh = template["tracer"]
	tracer_material.shader = TRACER_SHADER
	tracer_material.set_shader_parameter("u_color", Color("ffac4f") if heavy else Color("ffda78"))
	tracer.material_override = tracer_material
	for mesh: MeshInstance3D in [body, nose, tracer]:
		mesh.rotation.x = PI / 2.0
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	reset()


func reset() -> void:
	initialized = false
	visible = false
	trail_length = 0.0
	opacity = 0.0


func update_flight(data: Array, time: float, map_offset: Vector3, muzzle_pose = null) -> void:
	var height := 0.56 if type == "cannon" else 0.45
	var point := Vector3(float(data[1]), height, float(data[2])) + map_offset
	var direction := Vector3(float(data[3]), 0.0, float(data[4])).normalized()
	if direction.length_squared() < 0.5:
		direction = Vector3.BACK
	var metadata := data.size() >= 12
	var finished_at := float(data[11]) if metadata else -1.0
	var finished := finished_at >= 0.0
	if not initialized:
		if metadata:
			launch_position = Vector3(float(data[6]), height, float(data[7])) + map_offset
			if not bool(data[10]):
				if muzzle_pose is Transform3D:
					launch_position = muzzle_pose.origin
				else:
					# 재접속 등으로 발사 포즈를 받지 못한 경우의 원본 총구 전방 거리.
					launch_position += direction * (0.64 if type == "cannon" else 0.507)
		else:
			launch_position = point - direction * (0.36 if type == "cannon" else 0.30)
		initialized = true
	if finished and data.size() >= 14 and data[12] != null and data[13] != null:
		# 충돌 원의 표면이 포신 안에 들어오는 근접 사격도 실제 피격 몸체까지 연결.
		# 판정 위치는 프레임의 1·2번 필드에 그대로 보존.
		point.x = float(data[12]) + map_offset.x
		point.z = float(data[13]) + map_offset.z
	var offset := point - launch_position
	var travelled := offset.dot(direction)
	if travelled > 0.01:
		direction = offset.normalized()
	var right := direction.cross(Vector3.UP).normalized()
	global_transform = Transform3D(Basis(right, direction.cross(right), direction), point)
	var age := fposmod(time - finished_at, 1200.0) if finished else 0.0
	opacity = pow(clampf(1.0 - age / AFTERIMAGE_SECONDS, 0.0, 1.0), 1.4) if finished else 1.0
	visible = travelled > 0.01 and opacity > 0.0
	# 피해를 준 탄체는 즉시 숨기고 이미 지나간 짧은 궤적만 소멸.
	body.visible = not finished
	nose.visible = not finished
	trail_length = minf(1.10 if type == "cannon" else 0.85, maxf(0.0, offset.length()))
	tracer.scale.y = trail_length
	tracer.position.z = -trail_length / 2.0
	tracer.visible = trail_length > 0.01
	tracer_material.set_shader_parameter("u_opacity", opacity)
