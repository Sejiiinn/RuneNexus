extends SceneTree
const Effect = preload("res://effects/lightning_attack.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var effect := Effect.new()
	root.add_child(effect)
	var charge := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.445, 0.84))
	var electrodes := PackedVector3Array([Vector3(-0.213, 0.411, 0.568), Vector3(0.213, 0.411, 0.568)])
	effect.sample_charge(charge, 0.22, 0.3, 0, electrodes)
	assert(effect.visible and effect._charge.visible and effect._aura.visible)
	assert(effect._feeds[0].visible and effect._feeds[1].visible and not effect._feeds[2].visible)
	var pose: Transform3D = effect._charge.global_transform
	var mesh: Mesh = effect._charge.mesh
	var energy: float = effect._charge_material.get_shader_parameter("energy")
	for frame in range(10):
		effect.sample_charge(charge, 0.22, 0.3, 0, electrodes)
	assert(pose == effect._charge.global_transform and mesh == effect._charge.mesh)
	assert(energy == effect._charge_material.get_shader_parameter("energy"))
	var target := Vector3(1.4, 0.7, 4.7)
	effect.sample_discharge(charge.origin, target, 0.06, 0.28, 2, 1.2)
	var length: float = effect._beam_material.get_shader_parameter("beam_length")
	assert((effect._beam.global_transform * Vector3(0, 0, length)).distance_to(target) < 0.00001)
	target += Vector3(-0.8, -0.15, 0.2)
	effect.sample_discharge(charge.origin, target, 0.06, 0.28, 2, 1.2)
	length = effect._beam_material.get_shader_parameter("beam_length")
	assert((effect._beam.global_transform * Vector3(0, 0, length)).distance_to(target) < 0.00001)
	assert(effect._impact.global_position.distance_to(target) < 0.00001)
	assert(not effect._feeds[0].visible)
	effect.set_volume_enabled(false)
	assert(not effect._aura.visible and not effect._contact_aura.visible)
	assert(effect._beam.visible and effect._impact.visible)
	effect.sample_discharge(charge.origin, target, 0.06, 0.28, 2, 1.2)
	assert(not effect._aura.visible and not effect._contact_aura.visible)
	effect.set_volume_enabled(true)
	effect.sample_discharge(charge.origin, target, 0.06, 0.28, 2, 1.2)
	assert(effect._aura.visible and effect._contact_aura.visible)
	var second := Effect.new()
	root.add_child(second)
	second.sample_discharge(Vector3.ZERO, Vector3(0, 0, 2), 0.1)
	assert(second._beam_material != effect._beam_material)
	assert(second._aura.mesh == effect._aura.mesh)
	var ids := []
	for i in Effect.BEAM_MESHES + Effect.CHARGE_MESHES + Effect.FEED_MESHES:
		ids.append(i.get_instance_id())
	for frame in range(5000):
		effect.sample_discharge(charge.origin, target, float(frame % 27) / 100.0, 0.28, frame)
	var after := []
	for i in Effect.BEAM_MESHES + Effect.CHARGE_MESHES + Effect.FEED_MESHES:
		after.append(i.get_instance_id())
	assert(ids == after)
	effect.sample_charge(charge, 0.3)
	assert(not effect.visible)
	effect.sample_discharge(charge.origin, target, 0.28)
	assert(not effect.visible)
	effect.sample_discharge(charge.origin, target, -0.001)
	assert(not effect.visible)
	effect.sample_discharge(charge.origin, target, 0.01)
	assert(effect.visible)
	effect.reset()
	assert(not effect.visible)
	effect.free()
	second.free()
	print("LIGHTNING_MODULE_PASS: phase/expiry, repeated-age freeze, moving endpoint, pool reset, independent materials, shared resource reuse")
	quit()
