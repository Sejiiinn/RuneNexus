extends SceneTree
## Focused authored-rig contract: motion clock, distinct skins, status and cleanup.
const Motion = preload("res://presentation/guardian_preview.gd")
const Burn = preload("res://effects/enemy_burn.gd")
const Frost = preload("res://effects/enemy_frost.gd")
const Status = preload("res://effects/guardian_status.gd")
var failures := 0

class Runtime:
	extends RefCounted
	var epoch := 1
	var tile_size := 48.0
	var origin := Vector2.ZERO
	var enemies := {}
	var events: Array = []
	func _visual_enemy_offset(_enemy: Dictionary) -> Vector2:
		return Vector2.ZERO

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var motion := Motion.new(world)
	var runtime := Runtime.new()
	var normal := motion.new_walker()
	var fast := motion.new_walker("fast")
	check(not normal.is_empty() and not fast.is_empty(), "Both authored rigs load")
	if normal.is_empty() or fast.is_empty():
		world.free()
		quit(1)
		return
	check(fast.type == "fast" and fast.player.get_animation(fast.clip).length > 0.56, "Fast Run imported")
	check(is_equal_approx(Motion.RUN_STRIDE_TILES, 0.6445833333333333 * Motion.FAST_VISUAL_SCALE), "Fast stride follows visual scale without changing combat speed")
	for entry: Dictionary in [normal, fast]:
		var id := 1 if entry.type == "normal" else 2
		var stride: float = Motion.STRIDE_TILES if id == 1 else Motion.RUN_STRIDE_TILES
		var seconds: float = Motion.WALK_SECONDS if id == 1 else Motion.RUN_SECONDS
		var data := [id, 0.0, 0.0, 0.0, 0.0, 0.48, 0.0, entry.type, false, false, false, false, 0.0, 0.0]
		runtime.enemies[str(id)] = {"id": id, "type": entry.type, "distanceTravelled": stride * 48.0 * 0.25, "facingAngle": 0.0}
		motion.observe_native(runtime, 1.0, Vector2i(8, 8))
		motion.update_walker(entry, data, 1.0)
		check(is_equal_approx(entry.player.current_animation_position, seconds * 0.25), entry.type + " native distance drives phase")
		data[1] = 12.0 # Smoothed/display movement must not advance a paused logical rig.
		motion.update_walker(entry, data, 1.0)
		check(is_equal_approx(entry.player.current_animation_position, seconds * 0.25), entry.type + " paused phase ignores display displacement")
		runtime.enemies[str(id)].distanceTravelled = stride * 48.0 * 0.5
		motion.observe_native(runtime, 1.1, Vector2i(8, 8))
		motion.update_walker(entry, data, 1.1)
		check(is_equal_approx(entry.player.current_animation_position, seconds * 0.5), entry.type + " slow/4x clock uses traveled distance")
		var before: float = entry.root.rotation.y
		data[3] = PI / 2.0
		motion.update_walker(entry, data, 1.1)
		check(is_equal_approx(entry.root.rotation.y, before), entry.type + " corner starts without snapping")
		motion.update_walker(entry, data, 1.16)
		check(entry.root.rotation.y < before and entry.root.rotation.y > 0.0, entry.type + " corner eases with combat clock")
		var body: MeshInstance3D = entry.root.find_children("*", "MeshInstance3D", true, false)[0]
		var original := body.get_active_material(0)
		Burn.apply(entry, true, 1.16)
		Frost.apply(entry, true)
		check(entry.burn.get_child_count() == 1 and entry.frost.get_child_count() == 2, entry.type + " status remains three shared meshes")
		var burn_mesh: MeshInstance3D = entry.burn.get_child(0)
		check(burn_mesh.mesh == Status.MESHES[entry.type].EnemyBurn[0] and burn_mesh.skin == body.skin, entry.type + " species mesh reuses own skin")
		check(burn_mesh.get_node(burn_mesh.skeleton) == body.get_node(body.skeleton), entry.type + " status follows live skeleton")
		check(is_equal_approx(burn_mesh.material_override.get_shader_parameter("coordinate_scale"), Status.COORDINATE_SCALES[entry.type]), entry.type + " burn rise and billboard use own rig normalization")
		var coat: ShaderMaterial = body.get_active_material(0).next_pass
		check(coat.get_shader_parameter("body_albedo") == original.albedo_texture and coat.get_shader_parameter("preserve_colored_core"), entry.type + " frost preserves own cyan/purple core atlas")
		check(is_equal_approx(coat.get_shader_parameter("coordinate_scale"), Frost.COORDINATE_SCALES[entry.type]), entry.type + " frost uses own normalization")
		if entry.type == "fast":
			check(coat.get_shader_parameter("preserve_emission_core") and coat.get_shader_parameter("body_emission") == original.emission_texture, "Blue hound stone receives frost; only authored emission is protected")
		Burn.apply(entry, false, 1.16)
		Frost.apply(entry, false)
		check(not entry.burn.visible and not entry.frost.visible and body.get_active_material(0) == original, entry.type + " status expiry restores material")
	Burn.set_time(7.0)
	check(is_equal_approx(normal.burn.get_child(0).material_override.get_shader_parameter("burn_time"), 7.0), "Shared burn clock updates skinned effects")
	check(is_equal_approx(fast.burn.get_child(0).material_override.get_shader_parameter("burn_time"), 7.0), "Both rig scales share the combat burn clock")
	check(normal.burn.get_child(0).mesh != fast.burn.get_child(0).mesh, "Guardian status is not reused on hound skeleton")
	runtime.events = [{"id": 1, "kind": "kill", "enemyId": 2, "x": 0.0, "y": 0.0}, {"id": 2, "kind": "kill", "enemyId": 1, "x": 0.0, "y": 0.0}]
	motion.observe_native(runtime, 2.0, Vector2i(8, 8))
	check(motion.deaths.has(1) and not motion.deaths.has(2), "Fast kill never creates a guardian death mesh")
	motion.forget_walker(2)
	fast.root.free()
	check(not motion.walkers.has(2), "Fast removal clears motion reference and status children")
	motion.observe_native(runtime, 1.0, Vector2i(8, 8))
	check(motion.deaths.is_empty(), "Rewind clears deaths without replaying journal")
	motion.clear()
	world.free()
	print("SKINNED_ENEMY_PRESENTATION ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
