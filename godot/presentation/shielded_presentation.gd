extends RefCounted
## Accepted rigid model: one manually sampled Idle and six moving mesh pieces.
const StageResources = preload("res://presentation/stage_resources.gd")
const ShieldShader = preload("res://effects/enemy_shield.gdshader")
const RigidStatus = preload("res://effects/shielded_status.gd")
const MODEL := "res://assets/enemies/shielded.glb"
const VISUAL_SCALE := 1.5
# The accepted mesh has this measured lower-to-upper tip axis baked into its
# vertices (centroids within 4 cm of each Y extremum), despite identity pivots.
const BODY_LONG_AXIS := Vector3(.02246770748806868, .8929408223784795, .44961304457308127)
const MODEL_LIFT := .61
const PART_NAMES := ["Body", "Ring", "StoneLowerLeft", "StoneUpperRight", "StoneLowerRight", "StoneUpperLeft"]
static var _shell_mesh: SphereMesh
static var _shell_material: ShaderMaterial

static func create(world: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "ShieldedEnemy"
	var model: Node3D = (StageResources.load_resource(MODEL) as PackedScene).instantiate()
	root.add_child(model)
	# Source is centered. Keep the approved size and lift it above the path.
	model.position.y = MODEL_LIFT
	world.add_child(root)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var parts: Array[MeshInstance3D] = []
	for label: String in PART_NAMES:
		var part := model.find_child(label, true, false) as MeshInstance3D
		if part != null: parts.append(part)
	if player != null and player.has_animation("Idle"):
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play("Idle")
		player.seek(0.0, true)
	var body_pivot := model.find_child("BodyPivot", true, false) as Node3D
	_upright_body(body_pivot)
	var rest_parts: Array[Transform3D] = []
	for part: MeshInstance3D in parts: rest_parts.append(root.global_transform.affine_inverse()*part.global_transform)
	if _shell_mesh == null:
		_shell_mesh = SphereMesh.new()
		_shell_mesh.radius = .56
		_shell_mesh.height = 1.12
		_shell_mesh.radial_segments = 16
		_shell_mesh.rings = 6
		_shell_material = ShaderMaterial.new()
		_shell_material.shader = ShieldShader
	var shell := MeshInstance3D.new()
	shell.name = "ShieldShell"
	shell.mesh = _shell_mesh
	shell.material_override = _shell_material
	shell.position.y = MODEL_LIFT - .06
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.set_meta("exclude_selection_mask", true)
	shell.set_meta("exclude_enemy_status", true)
	shell.visible = false
	root.add_child(shell)
	# A short-range, shadow-free real light adds a small cyan response to nearby
	# stone; emission alone cannot illuminate the model in the Mobile renderer.
	var lights: Array[OmniLight3D] = []
	for anchor_name: String in ["RuneFront", "RuneBack"]:
		var anchor := model.find_child(anchor_name, true, false) as Node3D
		if anchor == null: continue
		var light := OmniLight3D.new()
		light.name = "RuneLight"
		light.light_color = Color(.25, .72, 1.0)
		light.light_energy = .16 if anchor_name == "RuneFront" else .09
		light.omni_range = .40 * VISUAL_SCALE
		light.omni_attenuation = 1.8
		light.shadow_enabled = false
		anchor.add_child(light)
		lights.append(light)
	return {"root": root, "model": model, "type": "shielded", "shielded_presentation": true,
		"player": player, "parts": parts, "body_pivot": body_pivot,
		"rest_parts": rest_parts, "shield_shell": shell, "rune_lights": lights}

static func update(entry: Dictionary, row, time: float) -> void:
	var player: AnimationPlayer = entry.player
	if player != null and player.has_animation("Idle"):
		player.seek(fposmod(time, player.get_animation("Idle").length), true)
	_upright_body(entry.body_pivot)
	var ratio := clampf(row.shield / row.max_shield, 0.0, 1.0) if row.has_shield and row.max_shield > 0.0 else 0.0
	var shell: MeshInstance3D = entry.shield_shell
	shell.visible = ratio > 0.0
	shell.set_instance_shader_parameter("shield_ratio", ratio)
	RigidStatus.update(entry)

static func _upright_body(pivot: Node3D) -> void:
	# Keep the approved ring/stone channels, yaw and bob; only the central body
	# cancels HoverRoot rocking and aligns its intrinsic long axis with gravity.
	var hover := pivot.get_parent() as Node3D
	pivot.basis = hover.basis.orthonormalized().inverse() * Basis(Quaternion(BODY_LONG_AXIS, Vector3.UP))

static func label_top(entry: Dictionary, camera: Camera3D) -> float:
	var top := INF
	# Follow the actual animated silhouette without changing saved/combat sizes.
	# The shell is deliberately omitted so shield depletion never moves the bars.
	for body: MeshInstance3D in entry.parts:
		var bounds := body.mesh.get_aabb()
		var pose := body.global_transform
		for corner in range(8): top = minf(top, camera.unproject_position(pose*bounds.get_endpoint(corner)).y)
	return top

static func retain_stage(enemy_types: Array, _tower_types: Array) -> void:
	if "shielded" in enemy_types: return
	_shell_mesh = null
	_shell_material = null
