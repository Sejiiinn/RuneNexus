extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _rendered_image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _screen_bounds(mesh: MeshInstance3D, camera: Camera3D) -> Rect2:
	var bounds := Rect2(camera.unproject_position(mesh.global_position), Vector2.ZERO)
	for corner in range(8):
		bounds = bounds.expand(camera.unproject_position(mesh.to_global(mesh.get_aabb().get_endpoint(corner))))
	return bounds

func _pixel(image: Image, screen: Vector2, overlay: Node2D) -> Color:
	var point := Vector2i(screen / overlay.get_viewport_rect().size * Vector2(image.get_size()))
	return image.get_pixelv(point.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE))

func _verify() -> void:
	root.size = Vector2i(480, 800)
	var scene := Node3D.new()
	root.add_child(scene)
	var background := WorldEnvironment.new()
	background.environment = Environment.new()
	background.environment.background_mode = Environment.BG_COLOR
	background.environment.background_color = Color(0.4, 0.4, 0.4)
	scene.add_child(background)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(6, 9, 8)
	camera.look_at(Vector3.ZERO)
	var world := Node3D.new()
	scene.add_child(world)
	var overlay: Node2D = load("res://ui/battlefield_selection.gd").new()
	root.add_child(overlay)
	await process_frame
	var model := Node3D.new()
	world.add_child(model)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.25, 0.8, 0.7)
	mesh.material_override = material
	mesh.position.y = 1.4
	model.add_child(mesh)
	overlay.set_turrets({1: {"root": model}})
	var frame := {"logicalTileSize": 48.0, "visualScale": 1.0,
		"rewardTargeting": true, "rewardViewport": [10, 20, 300, 400],
		"viewport": [overlay.get_viewport_rect().size.x / 2, overlay.get_viewport_rect().size.y / 2],
		"rewardTargets": [{"position": [4.0, 4.0], "requiresReplacement": true}],
		"turrets": [{"position": [4.0, 4.0], "range": 1.3, "selected": true,
			"previewRange": 1.5, "auraTier": 4, "gemColors": [0xff00ffaa],
			"aimTarget": [5.0, 5.0], "aimProgress": 0.5}]}
	overlay.apply_frame(frame)
	overlay.present(camera, Vector2(8, 8), world)
	_check(overlay.supported_groups() == ["selection"], "Initialized selection capability missing")
	_check(overlay._dim.visible, "Reward dim missing")
	_check(overlay._mask_meshes.size() == 1, "Target silhouette missing")
	_check(overlay._mask_viewport.own_world_3d and overlay._mask_viewport.transparent_bg, "Mask does not isolate target geometry")
	var clone: MeshInstance3D = overlay._mask_meshes[mesh.get_instance_id()]
	_check(clone.mesh == mesh.mesh, "Target mask duplicated geometry")
	_check(clone.global_transform.is_equal_approx(mesh.global_transform), "Target mask lost live model transform")
	_check(overlay._clip_material.get_shader_parameter("clip_rect") == Vector4(20, 40, 620, 840), "Reward clip does not match logical viewport scale")
	var first: Rect2 = _screen_bounds(mesh, camera)
	var gpu := OS.get_cmdline_user_args().has("--capture")
	if gpu:
		var image := await _rendered_image()
		image.save_png("res://selection-verification.png")
		var screen: Vector2 = camera.unproject_position(mesh.global_position)
		_check(_pixel(image, screen, overlay).g > 0.6, "Target model was dimmed by misaligned silhouette")
		# This pixel was incorrectly exposed by the rejected AABB mask.
		var outside: Vector2 = first.position + Vector2(3, 3)
		_check(_pixel(image, outside, overlay).g < 0.25, "Model AABB corner exposed surrounding background")
		frame["rewardViewport"] = [0, 0, 10, 10]
		overlay.apply_frame(frame)
		overlay.present(camera, Vector2(8, 8), world)
		image = await _rendered_image()
		_check(_pixel(image, screen, overlay).g < 0.4, "Model silhouette leaked outside reward viewport")
	frame["rewardViewport"] = null
	overlay.apply_frame(frame)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 6.0
	camera.h_offset = 0.12
	camera.v_offset = -0.05
	camera.position = Vector3(0, 12, 0.01)
	camera.look_at(Vector3.ZERO)
	overlay.present(camera, Vector2(8, 8), world)
	var second: Rect2 = _screen_bounds(mesh, camera)
	_check(not first.is_equal_approx(second), "Selection projection stale after camera change")
	_check(overlay._mask_camera.projection == camera.projection and overlay._mask_camera.keep_aspect == camera.keep_aspect and overlay._mask_camera.size == camera.size, "Mask camera lost orthographic projection")
	_check(overlay._mask_camera.h_offset == camera.h_offset and overlay._mask_camera.v_offset == camera.v_offset, "Mask camera lost projection offsets")
	mesh.position.x = 1.2
	world.rotation.y = 0.5
	overlay.present(camera, Vector2(8, 8), world)
	_check(overlay._mask_meshes[mesh.get_instance_id()] == clone, "Camera or recoil recreated the cached mask mesh")
	_check(clone.global_transform.is_equal_approx(mesh.global_transform), "Target mask ignored model/world movement")
	if gpu:
		var image := await _rendered_image()
		image.save_png("res://selection-drone-verification.png")
		_check(_pixel(image, camera.unproject_position(mesh.global_position), overlay).g > 0.6, "Drone silhouette did not follow camera and live model")
	mesh.hide()
	overlay.present(camera, Vector2(8, 8), world)
	_check(overlay._mask_meshes.is_empty(), "Hidden target remains in silhouette pass")
	mesh.show()
	frame["rewardTargeting"] = false
	overlay.apply_frame(frame)
	overlay.present(camera, Vector2(8, 8), world)
	_check(overlay._mask_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and overlay._mask_meshes.is_empty(), "Silhouette renderer remains active outside reward targeting")
	overlay.clear()
	_check(not overlay._dim.visible and overlay._frame.is_empty(), "Clear retained selection or dim")
	print("Battlefield selection verification: %d failures; exact silhouette, shared meshes, camera, reward clip, lifecycle" % failures)
	quit(0 if failures == 0 else 1)
