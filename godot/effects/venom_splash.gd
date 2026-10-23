extends Node3D

## 독 포탑 착탄. 독액 덩어리가 철퍽 퍼지며 방울이 튀어 떨어지고, 착탄 범위만큼
## 독 웅덩이(독 장판)가 번져 장판 유지 시간 동안 남는다. 외부 전투 시계의 진행도로만 재생한다.
## 노드는 배율 1이고 착탄 반경은 타일 단위로 받는다.
const Goo = preload("res://effects/venom_goo.gd")
const PUDDLE_SHADER = preload("res://effects/venom_puddle.gdshader")
## 튄 방울·안개의 길이. 웅덩이는 lifetime(장판 유지 시간) 동안 남는다.
const DURATION := 1.1
const DROP_COUNT := 16
const MIST_COUNT := 4
const HIT_HEIGHT := 0.3
const GROUND_HEIGHT := 0.03
const GRAVITY := 9.0
const SPLAT_SECONDS := 0.14

var splat := MeshInstance3D.new()
var puddle := MeshInstance3D.new()
var drops: MultiMeshInstance3D
var mists: Array[MeshInstance3D] = []
var _puddle_material := ShaderMaterial.new()
var lifetime := DURATION
var _scattered_id := -1
var _velocities := PackedVector3Array()
var _sizes := PackedFloat32Array()
var _delays := PackedFloat32Array()


func _init() -> void:
	name = "VenomSplash"
	splat.mesh = Goo.drop_mesh()
	splat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(splat)
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	_puddle_material.shader = PUDDLE_SHADER
	puddle.mesh = plane
	puddle.material_override = _puddle_material
	puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puddle.position.y = GROUND_HEIGHT
	add_child(puddle)
	drops = Goo.drops(DROP_COUNT, 3.0)
	add_child(drops)
	for index in range(MIST_COUNT):
		var mist := Goo.mist()
		mists.append(mist)
		add_child(mist)
	_velocities.resize(DROP_COUNT)
	_sizes.resize(DROP_COUNT)
	_delays.resize(DROP_COUNT)
	visible = false


func update_impact(progress: float, radius: float, impact_id: int, _camera: Camera3D) -> void:
	progress = clampf(progress, 0.0, 1.0)
	visible = progress < 1.0
	if not visible:
		return
	radius = maxf(radius, 0.05)
	if impact_id != _scattered_id:
		_scatter(impact_id, radius)
	var age := progress * maxf(lifetime, 0.001)
	_puddle_material.set_shader_parameter("u_duration", lifetime)
	# 덩어리가 맞은 높이에서 땅으로 짓눌리며 웅덩이가 된다.
	var squash := clampf(age / SPLAT_SECONDS, 0.0, 1.0)
	splat.visible = squash < 1.0
	if splat.visible:
		var size := 0.11 * (1.0 - 0.3 * squash)
		splat.position = Vector3(0.0, lerpf(HIT_HEIGHT, GROUND_HEIGHT, squash), 0.0)
		splat.scale = Vector3(size * (1.0 + 2.2 * squash), size * (1.0 - 0.8 * squash), size * (1.0 + 2.2 * squash))
	puddle.scale = Vector3(radius, 1.0, radius)
	_puddle_material.set_shader_parameter("u_age", age)
	for index in range(DROP_COUNT):
		var t := age - _delays[index]
		var velocity := _velocities[index]
		var at := Vector3(0.0, HIT_HEIGHT * 0.6, 0.0) + velocity * t + Vector3(0.0, -0.5 * GRAVITY * t * t, 0.0)
		if t <= 0.0:
			drops.multimesh.set_instance_transform(index, Goo.stretched(at, velocity, 0.0, 1.0))
		elif at.y > GROUND_HEIGHT:
			drops.multimesh.set_instance_transform(index, Goo.stretched(at, velocity + Vector3(0.0, -GRAVITY * t, 0.0), _sizes[index], 1.7))
		else:
			# 땅에 닿은 방울은 납작하게 퍼졌다가 웅덩이와 함께 사라진다.
			var landed := 1.0 - clampf((age - 0.4) / 0.5, 0.0, 1.0)
			var size := _sizes[index] * 1.5 * landed
			var flat := Vector3(at.x, GROUND_HEIGHT + 0.004, at.z)
			drops.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3(size, size * 0.22, size)), flat))
	var k := clampf(age / DURATION, 0.0, 1.0)
	for index in range(MIST_COUNT):
		var mist := mists[index]
		var t := maxf(0.0, age - 0.05 * index)
		var angle := float(_scattered_id % 97) + index * TAU / MIST_COUNT
		mist.position = Vector3(cos(angle), 0.0, sin(angle)) * radius * 0.35 + Vector3(0.0, 0.22 + 0.4 * t, 0.0)
		mist.scale = Vector3.ONE * radius * (0.35 + 0.55 * sqrt(t / DURATION))
		mist.set_instance_shader_parameter("u_alpha", 0.07 * pow(1.0 - k, 1.6) * clampf(t / 0.08, 0.0, 1.0))


func update_camera(_camera: Camera3D) -> void:
	pass


func reset() -> void:
	visible = false
	_scattered_id = -1


## 같은 착탄 ID는 같은 모양. 새 착탄에서 한 번만 방울 궤적을 정한다.
func _scatter(impact_id: int, radius: float) -> void:
	_scattered_id = impact_id
	var random := RandomNumberGenerator.new()
	random.seed = hash(impact_id)
	_puddle_material.set_shader_parameter("u_seed", random.randf() * 60.0)
	for index in range(DROP_COUNT):
		var azimuth := random.randf() * TAU
		var rise := random.randf_range(1.2, 2.3)
		# 공중에 머무는 시간 동안 착탄 반경의 0.6~1.25배까지 날아간다.
		var airtime := (rise + sqrt(rise * rise + 2.0 * GRAVITY * HIT_HEIGHT * 0.6)) / GRAVITY
		var reach := radius * random.randf_range(0.6, 1.25)
		_velocities[index] = Vector3(cos(azimuth) * reach / airtime, rise, sin(azimuth) * reach / airtime)
		_sizes[index] = random.randf_range(0.018, 0.036)
		_delays[index] = random.randf_range(0.0, 0.04)
