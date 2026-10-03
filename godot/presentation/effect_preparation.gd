extends Node
## Loading-only presentation rehearsal. Never advances combat, saves, or its RNG.
const Units = preload("res://presentation/battlefield_units.gd")
const Projectiles = preload("res://presentation/battlefield_projectiles.gd")
const Fire = preload("res://effects/runic_fire.gd")
const Frost = preload("res://effects/frost_tower.gd")
const Burn = preload("res://effects/enemy_burn.gd")
const Lightning = preload("res://effects/lightning_attack.gd")
var _failed := false

func _draw() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw

func prepare(scene: Node3D) -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192, 192)
	viewport.own_world_3d = true
	viewport.msaa_3d = scene.get_viewport().msaa_3d
	viewport.use_hdr_2d = scene.get_viewport().use_hdr_2d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = scene._world_environment
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = scene.sun.rotation
	sun.light_energy = scene.sun.light_energy
	sun.shadow_enabled = scene.sun.shadow_enabled
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = scene.camera.projection
	camera.size = 7.0
	camera.position = Vector3(0, 4, 6)
	world.add_child(camera)
	camera.look_at(Vector3(0, .4, 0))
	camera.current = true
	var units := Units.new(world, camera)
	var projectiles := Projectiles.new(world, camera)
	var lightning := Lightning.new()
	world.add_child(lightning)
	units.failure.connect(func(_message): _failed = true)
	projectiles.failure.connect(func(_message): _failed = true)
	# The large impact field is already prepared by main.initialize().
	projectiles.field = scene.field
	if projectiles.field.is_empty():
		viewport.free()
		return false
	var options := {"volume":true, "burn_effects":true}
	units.configure(0.0, Vector2i(8, 10), options)
	units._sync_turrets(_turrets(0))
	lightning.sample_charge(Transform3D(Basis.IDENTITY, Vector3(0, .45, 0)), .2, .3, 0,
		PackedVector3Array([Vector3(-.21, .41, -.27), Vector3(.21, .41, -.27)]))
	await _draw()
	if Fire._flame_noise == null or Frost._noise == null:
		_dispose(scene, units, projectiles, viewport)
		return false
	# Procedural noise is generated asynchronously; don't mark readiness while
	# either texture is still a placeholder. No resource is regenerated per run.
	var deadline := Time.get_ticks_msec() + 10000
	while Fire._flame_noise.get_image() == null or Frost._noise.get_image() == null:
		if Time.get_ticks_msec() >= deadline:
			_dispose(scene, units, projectiles, viewport)
			return false
		await get_tree().process_frame
	# Exercise both native skinned status variants and the shared rigid variants.
	for kind in ["normal", "fast", "armored", "shielded", "tank", "boss"]:
		units._sync_enemies([[10, 4.0, 5.0, 0.0, 0.0, 1.0, 0.0, kind, true, true]])
		await _draw()
	# Two real frames advance the explicit particle clock and execute its first
	# GPU dispatch. Invisible instancing alone doesn't dispatch these emitters.
	for step in 3:
		var time := .05 * step
		lightning.sample_discharge(Vector3(0, .45, 0), Vector3(1, .4, 1), time, .28, step)
		units.configure(time, Vector2i(8, 10), options)
		units._sync_turrets(_turrets(1))
		projectiles.configure(time, Vector2i(8, 10), options)
		projectiles._sync_projectiles([
			[20,3.7,5.0,1.0,0.0,"cannon",3.0,5.0,null,1,false,-1.0,null,null],
			[21,4.7,5.0,1.0,0.0,"magic",4.0,5.0,null,1,false,-1.0,null,null],
			[22,3.7,5.3,1.0,0.0,"cannon",3.0,5.3,null,1,false,-1.0,null,null],
			[23,4.7,5.3,1.0,0.0,"magic",4.0,5.3,null,1,false,-1.0,null,null],
		], {})
		projectiles._update_impacts([[30,3.0,5.0,.8,.08 + time],[31,5.0,5.0,.8,.08 + time]])
		await _draw()
	projectiles._sync_projectiles([], {})
	lightning.reset()
	projectiles._update_impacts([])
	if not _failed:
		scene._projectile_renderer.adopt_prepared(projectiles)
	_dispose(scene, units, projectiles, viewport)
	return not _failed

func _dispose(scene, units, projectiles, viewport: SubViewport) -> void:
	units.clear()
	projectiles.clear()
	# Rehearsal uses only presentation clocks. Restore any paused restored run.
	var real_time := float(scene.last_frame.get("time", 0.0))
	Burn.set_time(real_time)
	Fire._scroll_materials(real_time)
	viewport.free()

func _turrets(shot: int) -> Array:
	return [[1,3.0,5.0,0.0,shot,0.0,"cannon",1],
		[2,4.0,5.0,0.0,shot,0.0,"magic",1],
		[3,5.0,5.0,0.0,shot,0.0,"frost",1,{"cooldown":0.0,"duration":2.0,"radius":1.58}],
		[4,6.0,5.0,0.0,shot,0.0,"lightning",1]]
