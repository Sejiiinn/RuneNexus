extends RefCounted
## Accepted shielded model's authored Death clip (failing hover stagger, then the
## rigid fall baked in Blender) on the combat clock. Rune power flickers and dies,
## spark bursts follow the authored jolts and impact. No physics, process or tweens.
const StageResources = preload("res://presentation/stage_resources.gd")
const Presentation = preload("res://presentation/shielded_presentation.gd")
const CLIP := "Death"
# Authored frames 1..48 at 24 fps: stagger to 17, body impact at 36, settled at 48.
const CLIP_SECONDS := 47.0 / 24.0
const HANDOFF_SECONDS := 0.12
const FADE_START := CLIP_SECONDS + 0.25
const LIFETIME := FADE_START + 0.35
# Spark bursts coincide with the hover jolts; the last one is the ground impact.
const BURSTS := [0.083, 0.292, 0.5, 0.667, 1.458]
const SPARKS_PER_BURST := 14
const FLICKER := "####.###+##.#+#..##.+#..#.+...#..+...."
const LIGHT_ENERGY := {"RuneFront": .16, "RuneBack": .09}
const ANIMATED_NODES := ["HoverRoot", "BodyPivot", "RingPivot", "StoneLowerLeftPivot",
	"StoneUpperRightPivot", "StoneLowerRightPivot", "StoneUpperLeftPivot"]
static var _materials := {}
static var _sparks: MultiMesh
static var _spark_material: ShaderMaterial


static func create(world: Node3D, live_time: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "ShieldedDeath"
	var model: Node3D = (StageResources.load_resource(Presentation.MODEL) as PackedScene).instantiate()
	model.position.y = Presentation.MODEL_LIFT
	root.add_child(model)
	world.add_child(root)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player == null or not player.has_animation(CLIP) or not player.has_animation("Idle"):
		root.free()
		return {}
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# The kill frame's live pose: the same combat-clock Idle sample and upright body.
	player.play("Idle")
	player.seek(fposmod(live_time, player.get_animation("Idle").length), true)
	Presentation._upright_body(model.find_child("BodyPivot", true, false))
	var start := {}
	for label: String in ANIMATED_NODES:
		var node := model.find_child(label, true, false) as Node3D
		if node != null: start[node] = node.transform
	player.play(CLIP)
	player.seek(0.0, true)
	var bodies: Array[MeshInstance3D] = []
	for label: String in Presentation.PART_NAMES:
		var body := model.find_child(label, true, false) as MeshInstance3D
		if body == null: continue
		bodies.append(body)
		for surface in range(body.mesh.get_surface_count()):
			body.set_surface_override_material(surface, _material(body.get_active_material(surface)))
	var lights: Array[OmniLight3D] = []
	for anchor_name: String in LIGHT_ENERGY:
		var anchor := model.find_child(anchor_name, true, false) as Node3D
		if anchor == null: continue
		var light := OmniLight3D.new()
		light.name = "RuneLight"
		light.light_color = Color(.25, .72, 1.0)
		light.omni_range = .40 * Presentation.VISUAL_SCALE
		light.omni_attenuation = 1.8
		light.shadow_enabled = false
		light.set_meta("base_energy", LIGHT_ENERGY[anchor_name])
		anchor.add_child(light)
		lights.append(light)
	var sparks := MultiMeshInstance3D.new()
	sparks.name = "DeathSparks"
	sparks.multimesh = _spark_mesh()
	sparks.material_override = _spark_material
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.custom_aabb = AABB(Vector3(-1.4, -.8, -1.4), Vector3(2.8, 2.2, 2.8))
	model.add_child(sparks)
	var entry := {"root": root, "type": "shielded", "player": player, "death_bodies": bodies,
		"death_lights": lights, "death_sparks": sparks, "death_start": start,
		"death_pose_time": -INF}
	sample(entry, 0.0)
	return entry


static func power(age: float) -> float:
	# Authored failing-power rhythm (1/30 s per step): rare dropouts that grow
	# into stutter, flares on each jolt, then dark before the fall.
	var envelope := 1.0 - smoothstep(0.2, 0.9, age)
	if envelope <= 0.0: return 0.0
	var step := floori(age * 30.0)
	var flicker := 0.0
	if step < FLICKER.length():
		flicker = {"#": 1.0, "+": .3, ".": 0.0}[FLICKER[step]]
	var flare := 0.0
	for burst: float in BURSTS:
		flare = maxf(flare, 1.0 - smoothstep(0.0, 0.06, absf(age - burst)))
	return envelope * maxf(flicker, 1.6 * flare)


static func sample(entry: Dictionary, age: float) -> void:
	var pose_time := clampf(age, 0.0, CLIP_SECONDS)
	# Settled/paused frames keep the last pose; rewinds resample the clip.
	if pose_time != float(entry.death_pose_time) or age < HANDOFF_SECONDS:
		entry.player.seek(pose_time, true)
		entry.death_pose_time = pose_time
		var blend := smoothstep(0.0, HANDOFF_SECONDS, age)
		if blend < 1.0:
			for node: Node3D in entry.death_start:
				node.transform = entry.death_start[node].interpolate_with(node.transform, blend)
	var light := power(age)
	var opacity := 1.0 - smoothstep(FADE_START, LIFETIME, age)
	for body: MeshInstance3D in entry.death_bodies:
		body.set_instance_shader_parameter("death_light", light)
		body.set_instance_shader_parameter("death_opacity", opacity)
	for rune: OmniLight3D in entry.death_lights:
		rune.light_energy = float(rune.get_meta("base_energy")) * light
		rune.visible = light > 0.0
	entry.death_sparks.set_instance_shader_parameter("death_age", age)
	entry.death_sparks.visible = age < BURSTS[-1] + 0.4


static func _material(original: Material) -> Material:
	var standard := original as StandardMaterial3D
	if standard == null: return original
	if not _materials.has(standard):
		var material := ShaderMaterial.new()
		material.shader = preload("res://effects/shielded_death_body.gdshader")
		material.resource_name = standard.resource_name
		material.set_shader_parameter("albedo_map", standard.albedo_texture)
		material.set_shader_parameter("normal_map", standard.normal_texture)
		material.set_shader_parameter("emission_map", standard.emission_texture)
		material.set_shader_parameter("albedo_tint", standard.albedo_color)
		material.set_shader_parameter("roughness_factor", standard.roughness)
		material.set_shader_parameter("metallic_factor", standard.metallic)
		material.set_shader_parameter("normal_strength", standard.normal_scale)
		material.set_shader_parameter("emission_tint", standard.emission * standard.emission_energy_multiplier if standard.emission_enabled else Color.BLACK)
		material.set_shader_parameter("use_normal", standard.normal_enabled and standard.normal_texture != null)
		material.set_shader_parameter("use_emission", standard.emission_enabled and standard.emission_texture != null)
		_materials[standard] = material
	return _materials[standard]


static func _spark_mesh() -> MultiMesh:
	if _sparks != null: return _sparks
	var streak := BoxMesh.new()
	streak.size = Vector3.ONE
	_sparks = MultiMesh.new()
	_sparks.transform_format = MultiMesh.TRANSFORM_3D
	_sparks.use_custom_data = true
	_sparks.mesh = streak
	_sparks.instance_count = BURSTS.size() * SPARKS_PER_BURST
	for burst in range(BURSTS.size()):
		var impact := burst == BURSTS.size() - 1
		for i in range(SPARKS_PER_BURST):
			var index := burst * SPARKS_PER_BURST + i
			var azimuth := float(index) * 2.399963 + float(burst) * .7
			# Jolt sparks spray up/outward; impact sparks skim low along the ground.
			var elevation := lerpf(.08, .45, float(i % 4) / 3.0) if impact else lerpf(.25, 1.15, float(i % 5) / 4.0)
			var speed := (1.8 if impact else 1.45) + .45 * float((i * 7) % 5) / 4.0
			_sparks.set_instance_transform(index, Transform3D.IDENTITY)
			_sparks.set_instance_custom_data(index, Color(float(burst), azimuth, elevation, speed))
	_spark_material = ShaderMaterial.new()
	_spark_material.shader = preload("res://effects/shielded_death_sparks.gdshader")
	return _sparks


static func retain_stage(enemy_types: Array, _tower_types: Array) -> void:
	if "shielded" in enemy_types: return
	_materials.clear()
	_sparks = null
	_spark_material = null
