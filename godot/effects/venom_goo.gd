extends RefCounted

## 독 포탑 발사·비행·착탄이 함께 쓰는 독액 메시와 재질. 거품처럼 비치지 않도록
## 불투명하고 반들거리는 진한 독초록 독액으로 칠하고, 안개만 반투명으로 둔다.
const MIST_SHADER = preload("res://effects/venom_mist.gdshader")
static var _drop_mesh: SphereMesh
static var _mist_mesh: SphereMesh


## 반지름 1 독액 방울. 노드나 인스턴스 배율로 크기와 늘어짐을 정한다.
static func drop_mesh() -> SphereMesh:
	if _drop_mesh == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.1, 0.55, 0.14)
		material.roughness = 0.08
		material.clearcoat_enabled = true
		material.clearcoat = 1.0
		material.clearcoat_roughness = 0.05
		material.emission_enabled = true
		material.emission = Color(0.08, 0.5, 0.14)
		material.emission_energy_multiplier = 0.35
		material.rim_enabled = true
		material.rim = 0.55
		material.rim_tint = 0.2
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 1.0
		_drop_mesh.height = 2.0
		_drop_mesh.radial_segments = 14
		_drop_mesh.rings = 7
		_drop_mesh.material = material
	return _drop_mesh


static func mist_mesh() -> SphereMesh:
	if _mist_mesh == null:
		var material := ShaderMaterial.new()
		material.shader = MIST_SHADER
		_mist_mesh = SphereMesh.new()
		_mist_mesh.radius = 1.0
		_mist_mesh.height = 2.0
		_mist_mesh.radial_segments = 16
		_mist_mesh.rings = 8
		_mist_mesh.material = material
	return _mist_mesh


static func drops(count: int, extent: float) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = drop_mesh()
	instances.instance_count = count
	instances.custom_aabb = AABB(-Vector3.ONE * extent, Vector3.ONE * extent * 2.0)
	var group := MultiMeshInstance3D.new()
	group.multimesh = instances
	group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return group


static func mist() -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mist_mesh()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return instance


## 진행 방향으로 늘어난 방울 자세. stretch는 길이 배율, 0이면 숨김.
static func stretched(position: Vector3, velocity: Vector3, radius: float, stretch: float) -> Transform3D:
	if radius <= 0.0:
		return Transform3D(Basis.from_scale(Vector3.ZERO), position)
	var forward := velocity.normalized() if velocity.length_squared() > 0.000001 else Vector3.DOWN
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 0.0001: side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(forward).normalized()
	var thin := radius / sqrt(maxf(stretch, 0.01))
	return Transform3D(Basis(side * thin, up * thin, forward * radius * stretch), position)
