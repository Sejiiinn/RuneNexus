extends SceneTree
## Run: Godot --headless --path godot --script verify_range_projection_cache.gd
## Exercises real Camera3D projection without rendering the overlay or masks.

class CountingOverlay:
	extends "res://ui/battlefield_selection.gd"
	var projection_count := 0
	func _ready() -> void:
		pass
	func _project(point: Vector2, height: float = 0.04) -> Vector2:
		projection_count += 1
		return super._project(point, height)

var failures := 0
var checks := 0
var overlay: CountingOverlay
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var map_size := Vector2(16, 24)
var center := Vector2(5.5, 8.5)
var radius := 3.25

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("RANGE CACHE: " + message)

func _prepare() -> void:
	overlay.prepare_context(camera, map_size, world, false)

func _check_geometry(point: Vector2, range_radius: float, label: String) -> void:
	var expected := overlay._path(point, range_radius)
	var actual := overlay._range_path(point, range_radius)
	_expect(actual == expected, label + ": cached points exactly match original projection")
	_expect(actual.size() == 97, label + ": keeps original 96 segments")
	overlay.projection_count = 0
	_prepare()
	_expect(overlay._range_path(point, range_radius) == actual, label + ": stable result")
	_expect(overlay.projection_count == 0, label + ": repeat performs no projections")

func _check_invalidation(label: String) -> void:
	_prepare()
	_expect(overlay._range_paths.is_empty(), label + ": invalidates existing screen points")
	overlay.projection_count = 0
	overlay._range_path(center, radius)
	_expect(overlay.projection_count == 97, label + ": regenerates exactly one ring")
	_check_geometry(center, radius, label)

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	viewport.own_world_3d = true
	root.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(4, 20, 17)
	camera.look_at(Vector3.ZERO)
	camera.set_orthogonal(26, 0.05, 100)
	camera.current = true
	overlay = CountingOverlay.new()
	viewport.add_child(overlay)
	await process_frame
	_prepare()
	_check_geometry(center, radius, "initial orthographic")
	_check_geometry(center, radius + 0.75, "upgrade radius")
	_check_geometry(center + Vector2(1, 0), radius, "different turret position")
	_expect(overlay._range_paths.size() == 3, "distinct positions and radii retain separate entries")

	camera.position.x += 0.125
	_check_invalidation("camera translation")
	camera.rotation.y += 0.02
	_check_invalidation("camera rotation")
	camera.size += 0.5
	_check_invalidation("orthographic size")
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	_check_invalidation("camera aspect policy")
	camera.h_offset += 0.15
	_check_invalidation("camera horizontal offset")
	camera.v_offset += 0.15
	_check_invalidation("camera vertical offset")
	camera.set_perspective(65, 0.05, 100)
	_check_invalidation("perspective mode")
	camera.fov += 3
	_check_invalidation("perspective FOV")
	camera.set_frustum(3, Vector2(0.1, 0.2), 0.05, 100)
	_check_invalidation("frustum mode")
	camera.frustum_offset += Vector2(0.05, 0.03)
	_check_invalidation("frustum offset")
	camera.near += 0.01
	_check_invalidation("near plane")
	camera.far += 10
	_check_invalidation("far plane")
	world.position.x += 0.01
	_check_invalidation("world shake translation")
	world.rotation.z += 0.001
	_check_invalidation("world rotation")
	world.scale *= 1.01
	_check_invalidation("world scale")
	map_size.x += 1
	_check_invalidation("map size")
	viewport.size = Vector2i(800, 1280)
	await process_frame
	_check_invalidation("viewport resize")

	# Animation/color updates must not invalidate geometry, including an
	# identical new frame dictionary and the default redraw=true path.
	overlay.apply_frame({"time": 12.0, "turrets": [{"animationPhase": 1.2}]})
	overlay.prepare_context(camera, map_size, world)
	overlay.projection_count = 0
	overlay._range_path(center, radius)
	_expect(overlay.projection_count == 0, "frame animation and redraw do not invalidate fixed geometry")
	overlay.clear()
	_expect(overlay._range_paths.is_empty(), "clear discards all cached coordinates")
	_prepare()
	overlay.projection_count = 0
	overlay._range_path(center, radius)
	_expect(overlay.projection_count == 97, "clear forces next ring to project again")

	for i in range(600):
		overlay._range_path(Vector2(float(i), 4), 2.0)
		_expect(overlay._range_paths.size() <= 256, "cache bound at unique ring %d" % i)
	_check_geometry(Vector2(599, 4), 2.0, "most recent ring after eviction")
	_check_geometry(center, radius, "revisited ring after eviction")

	# CPU-only microbenchmark: same six rings for 600 stable frames. This
	# reports coordinate work, not draw cost, GPU time or game frame rate.
	camera.set_orthogonal(26, 0.05, 100)
	_prepare()
	var started := Time.get_ticks_usec()
	overlay.projection_count = 0
	for frame in range(600):
		for turret in range(6):
			overlay._path(Vector2(3 + turret, 8), radius)
	var baseline_us := Time.get_ticks_usec() - started
	var baseline_projections := overlay.projection_count
	overlay.clear()
	_prepare()
	started = Time.get_ticks_usec()
	overlay.projection_count = 0
	for frame in range(600):
		_prepare()
		for turret in range(6):
			overlay._range_path(Vector2(3 + turret, 8), radius)
	var cached_us := Time.get_ticks_usec() - started
	_expect(baseline_projections == 349200, "baseline measures all 600 x 6 x 97 projections")
	_expect(overlay.projection_count == 582, "cached stable frames project only first six rings")
	print("RANGE_CACHE_CPU ", JSON.stringify({"frames": 600, "rings": 6, "baseline_us": baseline_us, "cached_us_including_context": cached_us, "baseline_projections": baseline_projections, "cached_projections": overlay.projection_count}))
	print("RANGE_CACHE_TEST ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	viewport.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
