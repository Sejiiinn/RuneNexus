extends Node3D

## 독 포탑 발사: 포구에서 앞으로 튀어 나가 떨어지는 독액 방울과 옅은 독 안개.
## 전투 시계(time)로만 재생하며 마지막 발사 하나만 그린다.
const Goo = preload("res://effects/venom_goo.gd")
const DROP_COUNT := 9
const SPRAY_SECONDS := 0.42
const MIST_COUNT := 3
const MIST_SECONDS := 0.5
const GRAVITY := 7.0

var drops: MultiMeshInstance3D
var mists: Array[MeshInstance3D] = []
var start := -INF
var pose := Transform3D.IDENTITY
var velocities := PackedVector3Array()
var sizes := PackedFloat32Array()


func _init() -> void:
	name = "VenomMuzzle"
	top_level = true
	drops = Goo.drops(DROP_COUNT, 3.0)
	add_child(drops)
	for index in range(MIST_COUNT):
		var mist := Goo.mist()
		mists.append(mist)
		add_child(mist)
	velocities.resize(DROP_COUNT)
	sizes.resize(DROP_COUNT)
	reset()


func reset() -> void:
	start = -INF
	visible = false


func fire(muzzle: Node3D, time: float, sequence: int) -> void:
	start = time
	pose = muzzle.global_transform.orthonormalized()
	pose.origin = muzzle.to_global(Vector3(0.0, 0.0, 0.03))
	for index in range(DROP_COUNT):
		var seed := float(sequence % 997) * 2.39996 + float(index) * 1.618
		velocities[index] = pose.basis * Vector3(sin(seed) * 0.55, cos(seed * 1.3) * 0.45 + 0.35, 1.3 + 0.7 * fposmod(seed, 1.0))
		sizes[index] = 0.018 + 0.016 * fposmod(seed * 3.7, 1.0)


func update_effect(_muzzle: Node3D, time: float, _camera: Camera3D) -> void:
	var age := time - start
	visible = age >= 0.0 and age < MIST_SECONDS
	if not visible:
		return
	global_transform = Transform3D.IDENTITY
	var spray := clampf(age / SPRAY_SECONDS, 0.0, 1.0)
	for index in range(DROP_COUNT):
		var velocity := velocities[index] + Vector3(0.0, -GRAVITY * age, 0.0)
		var at := pose.origin + velocities[index] * age + Vector3(0.0, -0.5 * GRAVITY * age * age, 0.0)
		drops.multimesh.set_instance_transform(index, Goo.stretched(at, velocity, sizes[index] * (1.0 - spray), 1.0 + 0.8 * (1.0 - spray)))
	var forward := pose.basis.z
	var k := age / MIST_SECONDS
	for index in range(MIST_COUNT):
		var mist := mists[index]
		var spread := float(index) / float(MIST_COUNT - 1) - 0.5
		mist.position = pose.origin + forward * (0.04 + 0.22 * pow(k, 0.6) * (1.0 + 0.3 * index)) + pose.basis.x * spread * 0.08 + Vector3(0.0, 0.12 * k, 0.0)
		mist.scale = Vector3.ONE * (0.08 + 0.2 * sqrt(k)) * (1.0 - 0.15 * index)
		mist.set_instance_shader_parameter("u_alpha", 0.3 * pow(1.0 - k, 2.0))


func update_camera(_camera: Camera3D) -> void:
	pass
