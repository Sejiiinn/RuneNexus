extends SceneTree

const RunicFire = preload("res://effects/runic_fire.gd")

func _initialize() -> void:
	call_deferred("_visual" if "--visual" in OS.get_cmdline_user_args() else "_verify")

func _verify() -> void:
	_verify_animation()
	# 메시 외형은 실제 GLB 화면 검수에서 판정한다. 이 검사는 시계/재사용 계약이다.
	# GLB가 없는 소스 전용 검사에서도 엔진 API 오류와 수명 계약을 검증한다.
	if not ResourceLoader.exists(RunicFire.ASSET):
		for key in ["fire_tongue_outer", "fire_tongue_core", "fire_ember"]:
			RunicFire._meshes[key] = BoxMesh.new()
	var turret := RunicFire.new(false)
	var projectile := RunicFire.new(true)
	var port := Node3D.new()
	var muzzle := Node3D.new()
	root.add_child(port)
	root.add_child(muzzle)
	root.add_child(turret)
	root.add_child(projectile)
	turret.update_turret(port, muzzle, 5.0)
	var paused_pose: Transform3D = turret._tongues[0].transform
	turret.update_turret(port, muzzle, 5.0)
	assert(turret._tongues[0].transform.is_equal_approx(paused_pose))
	turret.fire(muzzle, 5.0, 1)
	turret.update_turret(port, muzzle, 5.02)
	assert(turret._shot_time == 5.0)
	for emitter: GPUParticles3D in turret._particles:
		assert(emitter.speed_scale == 0.0)
		assert(not emitter.local_coords)
		assert(emitter.process_material is ParticleProcessMaterial)
	projectile.update_projectile(1199.99)
	projectile.update_projectile(0.01)
	assert(is_equal_approx(projectile._last_time, 0.01))
	projectile.update_projectile(0.04, false, 0.6)
	assert(not projectile._flame.visible)
	for emitter: GPUParticles3D in projectile._particles:
		assert(not emitter.emitting)
	projectile.reset()
	assert(not projectile.visible)
	assert(not is_finite(projectile._last_time))
	turret.reset()
	assert(not turret.visible)
	assert(not is_finite(turret._shot_time))
	# An unused burst must not be visible to the renderer, which otherwise
	# schedules its GPU copy even with no live particles and speed_scale=0.
	turret.update_turret(port, muzzle, 10.0)
	assert(not turret._burst.visible)
	assert(turret._sparks.visible)
	turret.fire(muzzle, 10.0, 2)
	turret.update_turret(port, muzzle, 10.05)
	assert(turret._burst.visible)
	var tail: float = turret._particle_tails[turret._burst]
	turret.update_turret(port, muzzle, 10.05)
	assert(is_equal_approx(turret._particle_tails[turret._burst], tail))
	# First non-emitting update consumes the full remaining lifetime, even
	# across a long delta; it remains visible for that final GPU dispatch.
	turret.update_turret(port, muzzle, 10.65)
	assert(turret._burst.visible)
	assert(turret._particle_tails[turret._burst] == 0.0)
	turret.update_turret(port, muzzle, 10.65)
	assert(not turret._burst.visible)
	assert(turret._muzzle_flame.visible)
	turret.fire(muzzle, 10.65, 3)
	turret.update_turret(port, muzzle, 10.67)
	assert(turret._burst.visible)
	# A discontinuity clears stale particles, not the continuous pilot flame.
	turret.update_turret(port, muzzle, 20.0)
	assert(not turret._burst.visible)
	assert(turret._sparks.visible)
	projectile.update_projectile(20.0)
	projectile.update_projectile(20.05)
	projectile.update_projectile(20.70, false, 0.3)
	for emitter: GPUParticles3D in projectile._particles:
		assert(emitter.visible)
		assert(projectile._particle_tails[emitter] == 0.0)
	projectile.update_projectile(20.70, false, 0.3)
	for emitter: GPUParticles3D in projectile._particles:
		assert(not emitter.visible)
	projectile.reset()
	for emitter: GPUParticles3D in projectile._particles:
		assert(not emitter.visible)
		assert(not emitter.emitting)
		assert(emitter.speed_scale == 0.0)
	projectile.update_projectile(30.0)
	for emitter: GPUParticles3D in projectile._particles:
		assert(emitter.visible)
		assert(emitter.emitting)
	print("RunicFire particles / pause / wrap / seek / residual expiry / pool reuse: PASS")
	quit()


func _reference_animation(tongues: Array[MeshInstance3D], time: float, size: Vector3) -> void:
	# Original per-node formula: protects Euler order and nonuniform local scale.
	for index in range(tongues.size()):
		var tongue := tongues[index]
		var phase := float(index) * 2.39996
		var strength := 0.57 if index >= 3 else (1.0 if index == 0 else 0.78)
		var sway := sin(time * 6.8 + phase)
		tongue.position = Vector3(sin(phase) * size.x * 0.13, 0, cos(phase) * size.z * 0.13)
		tongue.rotation = Vector3(sway * 0.10, phase + sin(time * 2.4 + phase) * 0.20, cos(time * 5.4 + phase) * 0.11)
		tongue.scale = size * strength * Vector3(1.0 + sway * 0.08, 1.0 + sin(time * 8.2 + phase) * 0.13, 1.0 - sway * 0.06)


func _verify_animation() -> void:
	var effect := RunicFire.new()
	var actual: Array[MeshInstance3D] = []
	var expected: Array[MeshInstance3D] = []
	for index in range(5):
		actual.append(MeshInstance3D.new())
		expected.append(MeshInstance3D.new())
	# Alternate slots, then revisit the same clock with different pulse sizes.
	# Backward seek, wrap, pause, and nonuniform scales retain the old poses.
	for time in [0.0, 0.016, 5.0, 5.0, 1199.99, 0.01, 20.0, 3.0]:
		for size in [Vector3(0.28, 0.35, 0.28), Vector3(0.12, 0.30, 0.12), Vector3(0.045, 0.14, 0.045), Vector3(0.12, 0.45, 0.12), Vector3(0.17, 0.39, 0.23)]:
			for slot in [0, 1, 0]:
				var clock: float = time + slot * 3.0
				effect._animate(actual, clock, size, slot)
				_reference_animation(expected, clock, size)
				for index in range(5):
					assert(actual[index].transform.is_equal_approx(expected[index].transform), "Flame pose differs from original formula")
	assert(RunicFire._animation_poses.size() == 2)
	for poses in RunicFire._animation_poses:
		assert(poses.size() == 5)
	for node in actual + expected:
		node.free()
	effect.free()
	print("RunicFire cached transforms / interleaved clocks: PASS")


func _visual() -> void:
	root.size = Vector2i(720, 720)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.9
	root.add_child(camera)
	camera.position = Vector3(0.6, 0.65, 1.3)
	camera.look_at(Vector3(0, 0.20, 0))
	var port := Node3D.new()
	var muzzle := Node3D.new()
	root.add_child(port)
	root.add_child(muzzle)
	muzzle.position = Vector3(0.22, 0.12, 0)
	var effect := RunicFire.new(false)
	root.add_child(effect)
	effect.update_turret(port, muzzle, 1.0)
	effect.fire(muzzle, 1.0, 1)
	for i in range(8):
		effect.update_turret(port, muzzle, 1.0 + i * 0.02)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/runic_fire_native_tongues.png")
	# Only GPU particle nodes remain: image changes cannot come from mesh sway.
	effect._flame.visible = false
	effect._muzzle_flame.visible = false
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	first.save_png("/tmp/runic_fire_particles_before.png")
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var paused := root.get_texture().get_image()
	assert(first.get_data() == paused.get_data(), "Particles advanced without battle time")
	for i in range(8):
		effect.update_turret(port, muzzle, 1.16 + i * 0.02)
		await process_frame
	await RenderingServer.frame_post_draw
	var advanced := root.get_texture().get_image()
	advanced.save_png("/tmp/runic_fire_particles_after.png")
	assert(first.get_data() != advanced.get_data(), "GPU particles did not advance at explicit battle delta")
	print("RunicFire rendered GPU explicit advance + paused pixels: PASS")
	quit()
