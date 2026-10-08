extends Node
## Loading-only presentation rehearsal. Never advances combat, saves, or its RNG.
const Units = preload("res://presentation/battlefield_units.gd")
const Projectiles = preload("res://presentation/battlefield_projectiles.gd")
const Fire = preload("res://effects/runic_fire.gd")
const Frost = preload("res://effects/frost_tower.gd")
const Burn = preload("res://effects/enemy_burn.gd")
const Lightning = preload("res://effects/lightning_attack.gd")
const GuardianStatus = preload("res://effects/guardian_status.gd")
const TargetSurface = preload("res://effects/sniper_target_surface.gd")
const AttachmentKind = preload("res://effects/enemy_attachment_kind.gd")
const EFFECT_CACHES := [
	Fire, Frost, Burn, Lightning, GuardianStatus,
	preload("res://effects/enemy_frost.gd"),
	preload("res://effects/boss_death.gd"),
	preload("res://effects/hound_death.gd"),
	preload("res://effects/tank_death.gd"),
	preload("res://effects/machinegun_muzzle.gd"),
	preload("res://effects/cannon_flight.gd"),
	preload("res://effects/godot_impact.gd"),
	preload("res://effects/field_cache.gd"),
	preload("res://effects/ballistic_projectile.gd"),
	preload("res://effects/sniper_vfx.gd"),
	TargetSurface,
	preload("res://effects/gem_orbit.gd"),
	preload("res://effects/weapon_atlas.gd"),
]
const TOWER_PATHS := {
	"arrow": ["res://assets/effects/machinegun_muzzle.glb"],
	"cannon": ["res://assets/projectiles/cannonball.glb", "res://assets/effects/muzzle_flash.png", "res://assets/effects/gun_smoke.png"],
	"magic": ["res://assets/effects/runic_fire.glb"],
	"frost": ["res://assets/effects/frost_tower/mist-volume.glb"],
	"sniper": ["res://assets/effects/sniper/flash.glb", "res://assets/effects/sniper/aim_line.glb"],
}
var _failed := false
var _generation := 0


static func resource_paths(enemy_types: Array, tower_types: Array) -> Array[String]:
	var unique := {}
	if not tower_types.is_empty():
		unique["res://assets/effects/placement_dust.glb"] = true
		unique["res://assets/effects/gem_orbit/gem.glb"] = true
	for kind: String in tower_types:
		for path: String in TOWER_PATHS.get(kind, []): unique[path] = true
	if "lightning" in tower_types:
		for path: String in Lightning.CHARGE_MESHES + Lightning.BEAM_MESHES + Lightning.FEED_MESHES + [Lightning.IMPACT_MESH]:
			unique[path] = true
	if not enemy_types.is_empty():
		if "magic" in tower_types: unique["res://assets/effects/enemy_burn/flame_atlas.png"] = true
		if "frost" in tower_types:
			unique["res://assets/effects/enemy_frost/crystals.glb"] = true
			unique["res://assets/effects/enemy_frost/grain.png"] = true
	for kind: String in enemy_types:
		var family := AttachmentKind.resolve(kind)
		if family == "boss": unique["res://assets/effects/boss_core_mask.png"] = true
		if not GuardianStatus.MESHES.has(family): continue
		for status: String in ["EnemyBurn", "EnemyFrost"]:
			if status == "EnemyBurn" and not "magic" in tower_types: continue
			if status == "EnemyFrost" and not "frost" in tower_types: continue
			for path: String in GuardianStatus.MESHES[family][status]: unique[path] = true
	var result: Array[String] = []
	for path: String in unique: result.append(path)
	return result


static func retain_stage(enemy_types: Array, tower_types: Array) -> void:
	# Call after retiring old scene nodes/pools so no discarded family pins maps.
	for script: Script in EFFECT_CACHES: script.retain_stage(enemy_types, tower_types)


func _draw() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
		await get_tree().process_frame


func prepare(scene: Node3D, manifest: Dictionary) -> bool:
	_generation = scene._stage_preparation_generation
	if not _is_current(scene): return false
	_failed = false
	await _draw()
	if not _is_current(scene): return false
	var enemy_types: Array = manifest.get("enemy_types", [])
	var tower_types: Array = manifest.get("tower_types", [])
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
	var lightning: Node3D
	if "lightning" in tower_types:
		lightning = Lightning.new()
		world.add_child(lightning)
	units.failure.connect(func(_message): _failed = true)
	projectiles.failure.connect(func(_message): _failed = true)
	# Cannon owns the large impact field. A stage without cannon needs none.
	projectiles.field = scene.field
	if "cannon" in tower_types and projectiles.field.is_empty():
		_dispose(scene, units, projectiles, viewport)
		return false
	var options := {"volume":true, "burn_effects":true}
	units.configure(0.0, Vector2i(8, 10), options)
	# Instance one additional tower family per feedback frame. GPU driver work
	# inside a family may still stall; drawing the overlay is not a smoothness guarantee.
	for count in range(1, tower_types.size() + 1):
		units._sync_turrets(_turrets(tower_types.slice(0, count), 0))
		await _draw()
		if not _is_current(scene):
			_dispose(scene, units, projectiles, viewport)
			return false
	if not tower_types.is_empty(): units._placement_dust._prepare()
	if lightning != null:
		lightning.sample_charge(Transform3D(Basis.IDENTITY, Vector3(0, .45, 0)), .2, .3, 0,
			PackedVector3Array([Vector3(-.21, .41, -.27), Vector3(.21, .41, -.27)]))
	await _draw()
	if not _is_current(scene):
		_dispose(scene, units, projectiles, viewport)
		return false
	var noises: Array[NoiseTexture2D] = []
	if "magic" in tower_types:
		if Fire._flame_noise == null: _failed = true
		else: noises.append(Fire._flame_noise)
	if "frost" in tower_types:
		if Frost._noise == null: _failed = true
		else: noises.append(Frost._noise)
	# Noise textures are generated asynchronously, only for eligible families.
	var deadline := Time.get_ticks_msec() + 10000
	for noise in noises:
		while noise.get_image() == null:
			if Time.get_ticks_msec() >= deadline:
				_dispose(scene, units, projectiles, viewport)
				return false
			await get_tree().process_frame
			if not _is_current(scene):
				_dispose(scene, units, projectiles, viewport)
				return false
	for kind: String in enemy_types:
		units._sync_enemies([[10, 4.0, 5.0, 0.0, 0.0, 1.0, 0.0, kind,
			"magic" in tower_types, "frost" in tower_types]])
		# Prepare all possible stage targets while loading, not at first aim/fire.
		# Reuse the real model path, including skinned walkers and boss variants.
		# Each family yields to the loading UI; no posed hit points survive it.
		if "sniper" in tower_types or "lightning" in tower_types:
			var target: Dictionary = units.enemies.get(10, {})
			if target.is_empty(): _failed = true
			else: TargetSurface.prewarm(target.root, kind)
		await _draw()
		if not _is_current(scene):
			_dispose(scene, units, projectiles, viewport)
			return false
	# Real frames execute the selected particle/GPU variants before combat.
	for step in 3:
		var time := .05 * step
		if lightning != null:
			lightning.sample_discharge(Vector3(0, .45, 0), Vector3(1, .4, 1), time, .28, step)
		units.configure(time, Vector2i(8, 10), options)
		units._sync_turrets(_turrets(tower_types, 1))
		projectiles.configure(time, Vector2i(8, 10), options)
		projectiles._sync_projectiles(_projectiles(tower_types), {})
		if "cannon" in tower_types:
			projectiles._update_impacts([[30,3.0,5.0,.8,.08 + time],[31,5.0,5.0,.8,.08 + time]])
		await _draw()
		if not _is_current(scene):
			_dispose(scene, units, projectiles, viewport)
			return false
	projectiles._sync_projectiles([], {})
	if lightning != null: lightning.reset()
	projectiles._update_impacts([])
	if not _failed:
		scene._projectile_renderer.adopt_prepared(projectiles)
	_dispose(scene, units, projectiles, viewport)
	return not _failed


func _is_current(scene: Node3D) -> bool:
	return is_instance_valid(scene) and scene.is_inside_tree() and _generation == scene._stage_preparation_generation


func _dispose(scene, units, projectiles, viewport: SubViewport) -> void:
	units.clear()
	units.retain_stage([])
	projectiles.clear()
	# A suspended caller can retain this local presenter until its coroutine
	# unwinds. Release the borrowed field immediately, before a stage switch.
	projectiles.field = {}
	# Rehearsal uses presentation clocks. Restore a paused restored run's clocks.
	var real_time := float(scene.last_frame.get("time", 0.0))
	Burn.set_time(real_time)
	Fire._scroll_materials(real_time)
	viewport.free()


func _turrets(tower_types: Array, shot: int) -> Array:
	var result := []
	for index in tower_types.size():
		var data: Array = [index + 1, 1.5 + index, 5.0, 0.0, shot, 0.0, tower_types[index], 1]
		if tower_types[index] == "frost":
			data.append({"cooldown":0.0,"duration":2.0,"radius":1.58})
		result.append(data)
	return result


func _projectiles(tower_types: Array) -> Array:
	var result := []
	for kind: String in tower_types:
		if not kind in ["arrow", "cannon", "magic", "sniper"]: continue
		for index in 2:
			result.append([20 + result.size(), 3.7, 5.0 + index * .3, 1.0, 0.0,
				kind, 3.0, 5.0 + index * .3, null, 1, false, -1.0, null, null])
	return result
