extends Node3D
## Standalone art preview. No battle model, save data, or shipping effect changes.

const ROOT := "res://previews/runic_fire/"
var camera: Camera3D
var turret: Node3D
var fire: Node3D
var paused := false
var view_mode := "fixed"
var game_size := false
var pause_button: Button
var camera_buttons: Array[Button] = []
var clock := 0.0


func _ready() -> void:
	_setup_environment()
	turret = load(ROOT + "model/magic.glb").instantiate() as Node3D
	turret.name = "ApprovedTurret"
	add_child(turret)
	for mesh: MeshInstance3D in turret.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material != null and material.resource_name.begins_with("Runes |"):
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var port := turret.find_child("upper_flame_port", true, false) as Node3D
	assert(port != null, "Approved upper flame attachment must be present")
	fire = load(ROOT + "body_fire.tscn").instantiate() as Node3D
	add_child(fire)
	fire.global_position = port.global_position
	_setup_controls()
	set_view("fixed")
	print("FLAME_PREVIEW_READY: native GPUParticles3D; 1 flame + 8 embers; 18 triangles; no custom shader")
	if "--capture" in OS.get_cmdline_user_args():
		_capture_sequence()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101b20")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.86, 1.0)
	env.ambient_light_energy = 0.16
	env.sky = load(ROOT + "model/battlefield_reflection_sky.tres") as Sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -125, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 8.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.1
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-40, 135, 0)
	fill.light_color = Color(0.65, 0.8, 1.0)
	fill.light_energy = 0.14
	add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("17252a")
	ground.roughness = 0.92
	plane.material = ground
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.008
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.name = "PreviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.02
	camera.far = 100
	add_child(camera)
	camera.current = true


func _setup_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PreviewControls"
	add_child(layer)
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	var title := Label.new()
	title.text = "룬 화염 · 입자 시안"
	title.position = Vector2(34, 28)
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("f1d9ac"))
	overlay.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "몸체에 피어오르는 불길과 흩어지는 불티"
	subtitle.position = Vector2(35, 69)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("92a9af"))
	overlay.add_child(subtitle)
	var row := HBoxContainer.new()
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 34.0
	row.offset_top = -76.0
	row.offset_bottom = -34.0
	row.add_theme_constant_override("separation", 12)
	overlay.add_child(row)
	for item in [["고정 시점", "fixed"], ["드론 시점", "drone"], ["뒤쪽 시점", "rear"]]:
		var button := _button(item[0])
		button.pressed.connect(set_view.bind(item[1]))
		row.add_child(button)
		camera_buttons.append(button)
	var size_button := _button("게임 크기")
	size_button.pressed.connect(func():
		game_size = not game_size
		size_button.text = "확대 보기" if game_size else "게임 크기"
		set_view(view_mode))
	row.add_child(size_button)
	pause_button = _button("일시정지")
	pause_button.pressed.connect(toggle_pause)
	row.add_child(pause_button)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(122, 42)
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("20363d")
	normal.border_color = Color("49616a")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("35505a")
	button.add_theme_stylebox_override("hover", hover)
	return button


func set_view(mode: String) -> void:
	view_mode = mode
	var target := Vector3(0, 0.50, 0.06)
	var direction := Vector3(3.2, 2.6, 3.0)
	if mode == "drone":
		direction = Vector3(0.1, 5, 1.5)
	elif mode == "rear":
		direction = Vector3(-2.6, 2.5, -3)
	camera.position = target + direction
	camera.look_at(target)
	camera.size = 7.0 if game_size else 2.05


func toggle_pause() -> void:
	set_paused(not paused)


func set_paused(value: bool) -> void:
	paused = value
	for emitter: GPUParticles3D in fire.get_children():
		emitter.speed_scale = 0.0 if paused else 1.0
	pause_button.text = "재생" if paused else "일시정지"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle_pause()
		elif event.keycode == KEY_C:
			set_view("drone" if view_mode == "fixed" else "fixed")


func _process(delta: float) -> void:
	if not paused:
		clock += delta


func diagnostic_summary() -> Dictionary:
	return {"view": view_mode, "paused": paused, "game_size": game_size,
		"particle_capacity": 9, "body_triangles": 18,
		"custom_shader": false, "clock": clock,
		"attachment": fire.global_position}


func _capture_sequence() -> void:
	# Optional deterministic engine movie capture, independent of product runtime.
	await get_tree().create_timer(1.0).timeout
	set_view("fixed")
	await get_tree().create_timer(3.0).timeout
	set_view("drone")
	await get_tree().create_timer(3.0).timeout
	set_view("rear")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
