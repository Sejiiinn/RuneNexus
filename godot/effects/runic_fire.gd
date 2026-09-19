extends Node3D

## 승인된 Blender 입체 불꽃 메시 + Godot 기본 재질·GPU 입자.
## 전투 프레임의 시계만 받는다. _process/TIME/커스텀 셰이더는 사용하지 않는다.
const ASSET := "res://assets/effects/runic_fire.glb"
const FLASH_SECONDS := 0.20
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _flame_noise: NoiseTexture2D
static var _material_time := -INF
# Main flames/projectiles share one clock; muzzle tongues use time + 3.
# Two bounded slots avoid invalidating each other as effects are updated.
static var _animation_times: Array[float] = [-INF, -INF]
static var _animation_poses: Array[Array] = [[], []]
## Local profiling switch; shipping/default behavior remains all.
static var _diagnostic_mode := "all"
static var _diagnostic_instances: Array[WeakRef] = []
var projectile := false
var _flame: Node3D
var _muzzle_flame: Node3D
var _tongues: Array[MultiMeshInstance3D] = []
var _muzzle_tongues: Array[MultiMeshInstance3D] = []
var _particles: Array[GPUParticles3D] = []
## Conservative residual lifetime, in battle seconds, for each emitter.
var _particle_tails: Dictionary = {}
var _sparks: GPUParticles3D
var _burst: GPUParticles3D
var _last_time := -INF
var _shot_time := -INF
var _configured := false


static func set_diagnostic_mode(mode: String) -> void:
	if mode == "no_model":
		mode = "off"
	var next_mode := mode if mode in ["all", "no_particles", "off"] else "all"
	if next_mode == _diagnostic_mode:
		return
	_diagnostic_mode = next_mode
	var live: Array[WeakRef] = []
	for ref in _diagnostic_instances:
		var effect = ref.get_ref()
		if not is_instance_valid(effect):
			continue
		live.append(ref)
		for emitter: GPUParticles3D in effect._particles:
			emitter.emitting = false
			# Hidden, zero-speed particles never age into inactivity. Allow them
			# to expire during the diagnostic warmup, including pooled objects.
			emitter.speed_scale = 0.0 if next_mode == "all" else 1.0
			emitter.visible = next_mode == "all"
	_diagnostic_instances = live


func _init(is_projectile: bool = false) -> void:
	projectile = is_projectile
	name = "RunicFireProjectile" if projectile else "RunicFireTurret"


func _ready() -> void:
	if not _load_meshes():
		return
	if not projectile:
		top_level = true
		global_transform = Transform3D.IDENTITY
	_flame = Node3D.new()
	add_child(_flame)
	_tongues = _add_tongues(_flame)
	_sparks = _make_particles("DriftingEmbers", "fire_ember", 12 if projectile else 8, 0.55, false)
	_sparks.process_material.direction = Vector3(0, 0.35, -1) if projectile else Vector3.UP
	_sparks.process_material.initial_velocity_min = 0.12
	_sparks.process_material.initial_velocity_max = 0.40
	_sparks.process_material.gravity = Vector3(0, 0.20, 0)
	_sparks.process_material.scale_min = 0.008
	_sparks.process_material.scale_max = 0.016
	if projectile:
		_flame.rotation.x = -PI / 2.0
		var tail := _make_particles("DetachedFireTrail", "fire_tongue_outer", 14, 0.24, false)
		tail.process_material.direction = Vector3(0, 0, -1)
		tail.process_material.initial_velocity_min = 0.05
		tail.process_material.initial_velocity_max = 0.16
		tail.process_material.gravity = Vector3(0, 0.04, 0)
		tail.process_material.scale_min = 0.06
		tail.process_material.scale_max = 0.11
		tail.process_material.particle_flag_align_y = true
	else:
		_muzzle_flame = Node3D.new()
		add_child(_muzzle_flame)
		_muzzle_tongues = _add_tongues(_muzzle_flame)
		_burst = _make_particles("MuzzleBurstSparks", "fire_ember", 9, 0.24, true)
		_burst.process_material.direction = Vector3.BACK
		_burst.process_material.initial_velocity_min = 0.7
		_burst.process_material.initial_velocity_max = 1.8
		_burst.process_material.spread = 20.0
		_burst.process_material.gravity = Vector3(0, -0.35, 0)
		_burst.process_material.scale_min = 0.010
		_burst.process_material.scale_max = 0.025
	_configured = true
	reset()
	_diagnostic_instances.append(weakref(self))
	for emitter in _particles:
		emitter.speed_scale = 0.0 if _diagnostic_mode == "all" else 1.0


func reset() -> void:
	_last_time = -INF
	_shot_time = -INF
	visible = false
	for emitter in _particles:
		emitter.restart(true)
		emitter.emitting = false
		emitter.visible = false
		emitter.transparency = 0.0
		_particle_tails[emitter] = 0.0
		# Hidden particles are not queued by the renderer. Preserve the original
		# non-emitting restart step when this pooled emitter next becomes visible.
		emitter.request_particles_process(0.0, 0.001)


func fire(muzzle: Node3D, time: float, sequence: int) -> void:
	if not _configured or projectile or _diagnostic_mode != "all":
		return
	_shot_time = time
	_burst.global_transform = muzzle.global_transform.orthonormalized()
	_burst.seed = posmod(sequence, 2147483646) + 1
	_burst.restart(true)
	_burst.emitting = true


func update_turret(port: Node3D, muzzle: Node3D, time: float) -> void:
	if not _configured or projectile or port == null or muzzle == null:
		return
	if _diagnostic_mode == "off":
		visible = false
		_last_time = time
		return
	visible = true
	_flame.global_transform = port.global_transform.orthonormalized()
	_sparks.global_transform = _flame.global_transform
	_sparks.emitting = _diagnostic_mode == "all"
	_animate(_tongues, time, Vector3(0.28, 0.35, 0.28))
	var age := fposmod(time - _shot_time, 1200.0) if is_finite(_shot_time) else 1.0
	_burst.emitting = age < 0.24 and _diagnostic_mode == "all"
	# Small permanent pilot flame, fuller short pulse when the combat model fires.
	var pulse := pow(maxf(0.0, 1.0 - age / FLASH_SECONDS), 0.65)
	_muzzle_flame.global_transform = muzzle.global_transform.orthonormalized()
	_muzzle_flame.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	_animate(_muzzle_tongues, time + 3.0, Vector3(0.045 + 0.075 * pulse, 0.14 + 0.31 * pulse, 0.045 + 0.075 * pulse), 1)
	_advance(time)


func update_projectile(time: float, active: bool = true, opacity: float = 1.0) -> void:
	if not _configured or not projectile:
		return
	if _diagnostic_mode == "off":
		visible = false
		_last_time = time
		return
	visible = opacity > 0.0
	_flame.visible = active
	_animate(_tongues, time, Vector3(0.12, 0.30, 0.12))
	for emitter in _particles:
		emitter.emitting = active and _diagnostic_mode == "all"
		emitter.transparency = 1.0 - clampf(opacity, 0.0, 1.0)
	_advance(time)


func _advance(time: float) -> void:
	_scroll_materials(time)
	if _diagnostic_mode == "no_particles":
		for emitter in _particles:
			emitter.visible = false
		_last_time = time
		return
	var delta := 0.0
	if is_finite(_last_time):
		delta = time - _last_time
		if delta < -1190.0:
			delta += 1200.0
		if delta < 0.0 or delta > 0.75:
			# Seeking/reconnection discards stale world trails; never simulates a huge gap.
			for emitter in _particles:
				var was_emitting := emitter.emitting
				emitter.restart(true)
				emitter.emitting = was_emitting and not emitter.one_shot
				_particle_tails[emitter] = 0.0
				emitter.request_particles_process(0.0, 0.0)
			delta = 0.0
	_last_time = time
	for emitter in _particles:
		if emitter.emitting:
			# Keep a complete residual lifetime after the last emitting frame.
			# One extra fixed step covers births at a simulation-step boundary.
			_particle_tails[emitter] = emitter.lifetime + 1.0 / emitter.fixed_fps
		var remaining := float(_particle_tails.get(emitter, 0.0))
		if not emitter.emitting and remaining <= 0.0:
			# At speed_scale=0 Godot's internal inactive timer cannot advance.
			# Hide empty systems as well as stopping explicit requests: otherwise
			# visibility keeps scheduling their GPU instance-copy dispatch.
			emitter.visible = false
			emitter.request_particles_process(0.0, 0.0)
			continue
		emitter.visible = true
		if delta > 0.0:
			# Godot 4.7: 첫 인수는 방출도 켠다. 종료된 꼬리는 residual로만 전진.
			if emitter.emitting:
				emitter.request_particles_process(delta)
			else:
				# Finish the last required step even across a large battle delta.
				# Hide on the next update, after this final request can be rendered.
				var residual := minf(delta, remaining)
				emitter.request_particles_process(0.0, residual)
				_particle_tails[emitter] = maxf(0.0, remaining - residual)


func _animate(tongues: Array[MultiMeshInstance3D], time: float, size: Vector3, slot: int = 0) -> void:
	var poses: Array = _animation_poses[slot]
	if time != _animation_times[slot]:
		poses.clear()
		for index in range(5):
			var phase := float(index) * 2.39996
			var strength := 0.57 if index >= 3 else (1.0 if index == 0 else 0.78)
			var sway := sin(time * 6.8 + phase)
			var rotation := Vector3(sway * 0.10, phase + sin(time * 2.4 + phase) * 0.20, cos(time * 5.4 + phase) * 0.11)
			var scale := strength * Vector3(1.0 + sway * 0.08, 1.0 + sin(time * 8.2 + phase) * 0.13, 1.0 - sway * 0.06)
			poses.append(Transform3D(Basis.from_euler(rotation).scaled_local(scale), Vector3(sin(phase) * 0.13, 0, cos(phase) * 0.13)))
		_animation_times[slot] = time
	for index in range(5):
		var pose: Transform3D = poses[index]
		var batch := tongues[1 if index >= 3 else 0].multimesh
		batch.set_instance_transform(index - 3 if index >= 3 else index,
			Transform3D(pose.basis.scaled_local(size), pose.origin * size))


func _add_tongues(parent: Node3D) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	# Separate batches retain the shared outer/core native materials. Transform
	# buffers belong to this flame; sharing them would overwrite other pulses.
	for key: String in ["fire_tongue_outer", "fire_tongue_core"]:
		var tongue := MultiMeshInstance3D.new()
		tongue.name = key
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _meshes[key]
		batch.instance_count = 2 if key == "fire_tongue_core" else 3
		tongue.multimesh = batch
		tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Leave custom_aabb empty: Godot derives the bounds from the mesh and
		# every CPU-authored instance transform, including nonuniform scales.
		parent.add_child(tongue)
		result.append(tongue)
	return result


func _make_particles(label: String, key: String, count: int, lifetime: float, one_shot: bool) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = label
	emitter.amount = count
	emitter.lifetime = lifetime
	emitter.one_shot = one_shot
	emitter.explosiveness = 1.0 if one_shot else 0.0
	emitter.local_coords = false
	emitter.speed_scale = 0.0
	emitter.fixed_fps = 60
	emitter.use_fixed_seed = true
	emitter.seed = 1404
	emitter.draw_pass_1 = _meshes[key]
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6))
	var material := ParticleProcessMaterial.new()
	material.spread = 18.0
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.018
	material.angular_velocity_min = -80.0
	material.angular_velocity_max = 80.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.95))
	gradient.add_point(0.4, Color(1, 0.6, 0.2, 0.8))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.8, 0.1, 0.015, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.65))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(1, 0.03))
	var curve_texture := CurveTexture.new()
	curve_texture.curve = curve
	material.scale_curve = curve_texture
	emitter.process_material = material
	add_child(emitter)
	_particles.append(emitter)
	return emitter


static func _load_meshes() -> bool:
	if not _meshes.is_empty():
		return true
	var packed := load(ASSET) as PackedScene
	if packed == null:
		push_error("룬 화염 원본 메시를 불러오지 못했습니다: " + ASSET)
		return false
	var source := packed.instantiate()
	for key: String in ["fire_tongue_outer", "fire_tongue_core", "fire_ember"]:
		var node := source.find_child(key, true, false) as MeshInstance3D
		if node == null or node.mesh == null:
			push_error("룬 화염 메시 누락: " + key)
			source.free()
			_meshes.clear()
			return false
		var mesh := node.mesh.duplicate() as Mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color(1.0, 0.43, 0.065, 0.80) if key == "fire_tongue_outer" else Color(1.0, 0.83, 0.28, 0.9)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.35, 0.03) if key == "fire_tongue_outer" else Color(1.0, 0.75, 0.2)
		material.emission_energy_multiplier = 0.9
		if key != "fire_ember":
			material.albedo_texture = _shared_flame_noise()
			material.uv1_scale = Vector3(1.0, 1.4, 1.0)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		for surface in range(mesh.get_surface_count()):
			mesh.surface_set_material(surface, material)
		_materials[key] = material
		_meshes[key] = mesh
	source.free()
	return true


static func _shared_flame_noise() -> NoiseTexture2D:
	if _flame_noise != null:
		return _flame_noise
	var noise := FastNoiseLite.new()
	noise.seed = 1404
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.04
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.03))
	gradient.add_point(0.32, Color(1, 1, 1, 0.18))
	gradient.add_point(0.53, Color(1, 1, 1, 0.65))
	gradient.add_point(0.74, Color(1, 1, 1, 0.94))
	gradient.set_color(gradient.get_point_count() - 1, Color.WHITE)
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	_flame_noise = NoiseTexture2D.new()
	_flame_noise.width = 128
	_flame_noise.height = 256
	_flame_noise.seamless = true
	_flame_noise.generate_mipmaps = true
	_flame_noise.color_ramp = gradient
	_flame_noise.noise = noise
	return _flame_noise


static func _scroll_materials(time: float) -> void:
	# 재질/노이즈는 공유하고 전투 프레임당 한 번만 갱신한다. 정지 중 UV도 정지.
	if time == _material_time:
		return
	_material_time = time
	for key: String in _materials:
		if key == "fire_ember":
			continue
		var core := key == "fire_tongue_core"
		var material: StandardMaterial3D = _materials[key]
		material.uv1_offset = Vector3(fposmod(time * 0.08 + (0.37 if core else 0.0), 1.0),
			fposmod(-time * 0.85 + (0.21 if core else 0.0), 1.0), 0.0)
