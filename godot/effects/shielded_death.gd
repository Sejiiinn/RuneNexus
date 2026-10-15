extends RefCounted
## Accepted shielded model's authored Death clip (failing hover stagger, then the
## rigid fall baked in Blender) on the combat clock. Rune power flickers and dies,
## spatial electrical failures follow the authored jolts and impact.
## No physics, process or tweens.
const StageResources = preload("res://presentation/stage_resources.gd")
const Presentation = preload("res://presentation/shielded_presentation.gd")
const CLIP := "Death"
# Authored frames 1..48 at 24 fps: stagger to 17, body impact at 36, settled at 48.
const CLIP_SECONDS := 47.0 / 24.0
const HANDOFF_SECONDS := 0.12
const FADE_START := CLIP_SECONDS + 0.25
const LIFETIME := FADE_START + 0.35
# Electrical failures coincide with hover jolts; the last one is ground impact.
const BURSTS := [0.083, 0.292, 0.5, 0.667, 1.458]
const ELECTRIC_WINDOW := .18
const ARC_MESH := "res://effects/lightning_attack_meshes/beam04.res"
const CONTACT_MESH := "res://effects/lightning_attack_meshes/impact.res"
const ARC_LINKS := 3
const CONTACT_FORKS := 2
# Central front emissive triangle centroid / outward normal in the mesh's
# authored coordinates. Other contacts are selected from actual vertices once.
const RUNE_CONTACT := Vector3(-.03822179, -.00511456, .17157987)
const RUNE_NORMAL := Vector3(-.21980593, -.4528548, .86406475)
const FLICKER := "####.###+##.#+#..##.+#..#.+...#..+...."
const LIGHT_ENERGY := {"RuneFront": .16, "RuneBack": .09}
const ANIMATED_NODES := ["HoverRoot", "BodyPivot", "RingPivot", "StoneLowerLeftPivot",
	"StoneUpperRightPivot", "StoneLowerRightPivot", "StoneUpperLeftPivot"]
static var _materials := {}
static var _sparks: MultiMesh
static var _spark_material: ShaderMaterial
static var _contacts: MultiMesh
static var _contact_material: ShaderMaterial
static var _contact_points := PackedVector3Array()
static var _body_center := Vector3.ZERO


static func create(world: Node3D, live_time: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "ShieldedDeath"
	var model: Node3D = (StageResources.load_resource(Presentation.MODEL) as PackedScene).instantiate()
	model.position.y = Presentation.MODEL_LIFT
	model.basis = Presentation.model_heading_correction()
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
	var authored := {}
	for node: Node3D in start: authored[node] = node.transform
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
	_prepare_electricity(bodies)
	var sparks := _electric_node(model, "FailureArcs", _sparks, _spark_material)
	var contacts := _electric_node(model, "ContactCorona", _contacts, _contact_material)
	var entry := {"root": root, "type": "shielded", "player": player, "death_bodies": bodies,
		"death_lights": lights, "death_sparks": sparks, "death_contacts": contacts,
		"death_model": model, "death_start": start,
		"death_authored_pose": authored,
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
	if pose_time != float(entry.death_pose_time):
		# Animation tracks omit unchanged scales. Restore the immutable clip-zero
		# pose so transform decomposition never feeds its tiny floating-point
		# scale error into the next sample (or a rewind).
		for node: Node3D in entry.death_authored_pose: node.transform = entry.death_authored_pose[node]
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
		# Reuse the two short-range rune lights for a tiny electrical contact
		# response, including impact after the rune's own power has gone dark.
		var contact := contact_flash(age) * (1.0 if rune.get_parent().name == "RuneFront" else .45)
		rune.light_energy = float(rune.get_meta("base_energy")) * light + contact
		rune.visible = rune.light_energy > 0.0
	_sample_electricity(entry, age)


static func active_burst(age: float) -> int:
	for index in range(BURSTS.size() - 1, -1, -1):
		if age >= BURSTS[index] and age < BURSTS[index] + ELECTRIC_WINDOW: return index
	return -1


static func contact_flash(age: float) -> float:
	var burst := active_burst(age)
	if burst < 0: return 0.0
	var t := age - float(BURSTS[burst])
	var strike := 1.0 - smoothstep(.004, .04, t)
	if t >= .047: strike = maxf(strike, .55 * (1.0 - smoothstep(.003, .027, t - .047)))
	return strike * (.32 if burst == BURSTS.size() - 1 else .15)


static func _sample_electricity(entry: Dictionary, age: float) -> void:
	var burst := active_burst(age)
	var nodes := [entry.death_sparks, entry.death_contacts]
	for node: MultiMeshInstance3D in nodes:
		node.visible = burst >= 0
		node.set_instance_shader_parameter("death_age", age)
		if burst >= 0: node.set_instance_shader_parameter("burst_index", burst)
	if burst < 0: return
	# Shared mesh-local landmarks follow the current sampled rigid transforms.
	# No vertex search, mesh rebuild or independent particle clock in this path.
	var model_inverse: Transform3D = entry.death_model.global_transform.affine_inverse()
	var anchors := PackedVector3Array()
	for index in range(entry.death_bodies.size()):
		var body: MeshInstance3D = entry.death_bodies[index]
		anchors.append(model_inverse * body.global_transform * _contact_points[index])
	var body_center: Vector3 = model_inverse * entry.death_bodies[0].global_transform * _body_center
	anchors.append(Vector3(body_center.x, -Presentation.MODEL_LIFT + .006, body_center.z))
	for index in range(anchors.size()):
		for node: MultiMeshInstance3D in nodes: node.set_instance_shader_parameter("anchor_%d" % index, anchors[index])


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


static func _prepare_electricity(bodies: Array[MeshInstance3D]) -> void:
	if _sparks != null: return
	# The accepted Blender-authored sparse discharge and seven spatial contact
	# forks are immutable resources. Only two shared batches/materials are used.
	_sparks = _electric_batch(StageResources.load_resource(ARC_MESH) as Mesh, ARC_LINKS)
	_contacts = _electric_batch(StageResources.load_resource(CONTACT_MESH) as Mesh, CONTACT_FORKS)
	_spark_material = ShaderMaterial.new()
	_spark_material.shader = preload("res://effects/shielded_death_sparks.gdshader")
	_contact_material = ShaderMaterial.new()
	_contact_material.shader = _spark_material.shader
	_contact_material.set_shader_parameter("contact_forks", true)
	_body_center = bodies[0].mesh.get_aabb().get_center()
	_contact_points.append(RUNE_CONTACT + RUNE_NORMAL * .005)
	for index in range(1, bodies.size()):
		var body := bodies[index]
		var target := Vector3(.17, -.12, .27) if index == 1 else Vector3(0.0, 0.0, .12)
		var point := Vector3.ZERO
		var best := INF
		var vertices: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var distance := vertex.distance_squared_to(target)
			if distance < best: best = distance; point = vertex
		_contact_points.append(point)


static func _electric_batch(mesh: Mesh, count: int) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	batch.mesh = mesh
	batch.instance_count = count
	for index in range(count):
		batch.set_instance_transform(index, Transform3D.IDENTITY)
		batch.set_instance_custom_data(index, Color(float(index), float(index) * 2.399963, 0.0, 0.0))
	return batch


static func _electric_node(model: Node3D, label: String, batch: MultiMesh, material: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = batch
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Bounds include live attachments, the falling rigid body and the brief
	# ground corona. GPU longitudinal stretching never relies on source bounds.
	node.custom_aabb = AABB(Vector3(-1.0, -.75, -1.0), Vector3(2.0, 1.59, 2.0))
	model.add_child(node)
	return node


static func retain_stage(enemy_types: Array, _tower_types: Array) -> void:
	if "shielded" in enemy_types: return
	_materials.clear()
	_sparks = null
	_spark_material = null
	_contacts = null
	_contact_material = null
	_contact_points.clear()
