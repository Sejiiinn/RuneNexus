extends SceneTree

## GPU 모션의 CPU 계약 회귀. seed fixture는 이전 CPU 구현에서 직접 캡처했다.
## headless는 실제 vertex 출력·조명을 검증하지 않으며 Android 화면 확인을 별도로 한다.
## 필수 seed 입력: -- --fixture /absolute/path/to/test/fixtures/godot/impact_seed_1404.json
## 선택 부하 측정(위 인자 뒤): --benchmark /absolute/path/to/previous/godot_impact.gd
var failures := 0
const FIELDS := ["angle", "speed", "rise", "death", "delay", "width", "length", "stretch", "spin"]

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _new_effect(script: Script):
	var effect = script.new()
	root.add_child(effect)
	var texture := ImageTexture3D.new()
	var layer := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	texture.create(Image.FORMAT_RGBA8, 2, 2, 2, false, [layer, layer])
	effect.configure(texture, {"gridSize": 2, "atlasBricks": [1, 1, 2],
		"times": [0.0, 1.1], "densityScale": 1.0, "emissionScale": 1.0})
	return effect

func _state(effect) -> Array:
	return [effect._spark_material.get_shader_parameter("u_age"),
		effect._spark_material.get_shader_parameter("u_radius"),
		effect._spark_material.get_shader_parameter("u_angle")]

func _check_uniforms(effect, age: float, radius: float, angle: float) -> void:
	for material: ShaderMaterial in [effect._spark_material, effect._fragment_material]:
		_check(is_equal_approx(float(material.get_shader_parameter("u_age")), age), "외부 나이 미반영")
		_check(is_equal_approx(float(material.get_shader_parameter("u_radius")), radius), "반경 미반영")
		_check(is_equal_approx(float(material.get_shader_parameter("u_angle")), angle), "impact ID 방향 미반영")

func _verify() -> void:
	var script: Script = load("res://effects/godot_impact.gd")
	var effect = _new_effect(script)
	var other = _new_effect(script)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(5.0, 27.0, 13.0)
	camera.look_at(Vector3.ZERO)
	var args := OS.get_cmdline_user_args()
	var fixture_index := args.find("--fixture")
	if fixture_index < 0 or fixture_index + 1 >= args.size():
		push_error("--fixture 경로 인자가 필요합니다")
		quit(1)
		return
	var expected: Array = JSON.parse_string(FileAccess.get_file_as_string(args[fixture_index + 1]))
	var data: Texture2D = effect._spark_material.get_shader_parameter("u_particle_data")
	var pixels := data.get_image()
	_check(pixels.get_size() == Vector2i(3, 90), "정적 입자 텍스처 크기 오류")
	_check(expected.size() == 90, "CPU seed fixture 누락")
	for index in range(expected.size()):
		for field in range(FIELDS.size()):
			var actual: float = pixels.get_pixel(field / 4, index)[field % 4]
			_check(is_equal_approx(actual, float(expected[index][FIELDS[field]])),
				"기존 CPU seed와 불일치: 입자 %d / %s" % [index, FIELDS[field]])
	_check(data == other._spark_material.get_shader_parameter("u_particle_data"), "효과 간 정적 데이터 중복")
	_check(effect._spark_material != other._spark_material and effect._fragment_material != other._fragment_material,
		"동시 폭발이 동적 material을 공유함")
	var buffers: Array[PackedFloat32Array] = []
	for group: MultiMeshInstance3D in [effect._sparks, effect._fragments]:
		buffers.append(group.multimesh.buffer.duplicate())
		for index in range(group.multimesh.instance_count):
			_check(group.multimesh.get_instance_transform(index).is_equal_approx(Transform3D.IDENTITY),
				"정적 입자 transform이 identity가 아님")
	_check(effect._sparks.multimesh.instance_count == 56 and effect._fragments.multimesh.instance_count == 34,
		"입자 수 변경")
	var texture_bytes := pixels.get_data()
	other.update_impact(0.1, 0.5, 2, camera)
	var other_state := _state(other)
	effect.update_impact(0.3, 1.2, 100, camera)
	_check_uniforms(effect, 0.33, 1.2, 8.0 * 0.317)
	var paused_state := _state(effect)
	for iteration in range(3):
		await process_frame
	_check(_state(effect) == paused_state, "자체 프레임이 정지한 전투 시계를 진행함")
	camera.position += Vector3(1.0, 0.0, 0.0)
	effect.update_camera(camera)
	_check(_state(effect) == paused_state, "카메라만 이동했는데 입자 상태가 진행함")
	effect.update_impact(0.3, 1.2, 100, camera)
	_check(_state(effect) == paused_state, "같은 전투 프레임 재입력이 상태를 변경함")
	effect.update_impact(0.8, 2.4, -1, camera)
	_check_uniforms(effect, 0.88, 2.4, 22.0 * 0.317)
	_check(effect.visible and not effect._sparks.visible, "후반 섬광 숨김 계약 오류")
	var bounds := AABB(Vector3(-5.0, -0.25, -5.0) * 2.4, Vector3(10.0, 4.0, 10.0) * 2.4)
	_check(effect._sparks.multimesh.custom_aabb == bounds and effect._fragments.multimesh.custom_aabb == bounds,
		"반경 변경 시 전체 탄도 AABB 미반영")
	effect.update_impact(0.3, 1.2, 100, camera)
	_check(_state(effect) == paused_state and effect._sparks.visible, "역방향 seek가 이전 상태로 복원되지 않음")
	effect.update_impact(1.5, 1.2, 100, camera)
	_check(not effect.visible, "수명 종료 시 효과가 남음")
	effect.update_impact(-0.5, -3.0, 123, camera)
	_check(effect.visible and effect._sparks.visible, "풀 재사용 후 초기 가시성 복구 실패")
	_check_uniforms(effect, 0.0, 0.001, 8.0 * 0.317)
	_check(_state(other) == other_state, "효과 업데이트가 다른 폭발 상태를 덮어씀")
	_check(effect._sparks.multimesh.buffer == buffers[0] and effect._fragments.multimesh.buffer == buffers[1],
		"update/seek/재사용이 정적 MultiMesh 버퍼를 변경함")
	_check(data.get_image().get_data() == texture_bytes, "update가 정적 seed 텍스처를 변경함")
	effect.update_impact(0.2, 1.0, 1, null)
	_check(not effect.visible, "카메라 없는 효과가 표시됨")
	effect.free()
	other.free()
	var benchmark_index := args.find("--benchmark")
	if benchmark_index >= 0 and benchmark_index + 1 < args.size():
		_benchmark(script, args[benchmark_index + 1], camera)
	camera.free()
	print("IMPACT_MOTION_CONTRACT ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func _measure(script: Script, camera: Camera3D) -> float:
	var effects: Array = []
	for index in range(16):
		effects.append(_new_effect(script))
	for index in range(100):
		for slot in range(effects.size()):
			effects[slot].update_impact(float(index % 90) / 100.0, 1.2, slot, camera)
	var start := Time.get_ticks_usec()
	for index in range(1000):
		for slot in range(effects.size()):
			effects[slot].update_impact(float(index % 90) / 100.0, 1.2, slot, camera)
	var elapsed := float(Time.get_ticks_usec() - start) / 1000.0
	for effect in effects:
		effect.free()
	return elapsed

func _benchmark(current: Script, baseline_path: String, camera: Camera3D) -> void:
	var previous := GDScript.new()
	previous.source_code = FileAccess.get_file_as_string(baseline_path).replace("class_name GodotImpact", "")
	if previous.reload() != OK:
		_check(false, "baseline 스크립트 로드 실패")
		return
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	# 순서 편향을 줄이기 위해 측정 순서를 교대한다. GPU 프레임 시간은 측정하지 않는다.
	for run in range(5):
		if run % 2 == 0:
			cpu.append(_measure(previous, camera))
			gpu.append(_measure(current, camera))
		else:
			gpu.append(_measure(current, camera))
			cpu.append(_measure(previous, camera))
	cpu.sort()
	gpu.sort()
	print("CPU submission only: 16 impacts x 1000 updates, median of 5, baseline %.3f ms / GPU motion %.3f ms / %.2fx" % [cpu[2], gpu[2], cpu[2] / gpu[2]])
