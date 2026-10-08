extends SceneTree
## Focused authored-rig contract: motion clock, distinct skins, status and cleanup.
const Motion = preload("res://presentation/guardian_preview.gd")
const Burn = preload("res://effects/enemy_burn.gd")
const Frost = preload("res://effects/enemy_frost.gd")
const Status = preload("res://effects/guardian_status.gd")
var failures := 0

class PoseProbe:
	extends Node
	var writes := 0
	var value := 0.0:
		set(next):
			value = next
			writes += 1
	func _ready() -> void:
		# Exclude PackedScene property restoration from animation evaluation.
		writes = 0

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

func check_single_evaluation(world: Node3D) -> void:
	var model := Node3D.new()
	var probe := PoseProbe.new()
	probe.name = "PoseProbe"
	model.add_child(probe)
	probe.owner = model
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.owner = model
	var animation := Animation.new()
	animation.length = 1.0
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("PoseProbe:value"))
	animation.track_insert_key(track, 0.0, 0.0)
	animation.track_insert_key(track, 1.0, 1.0)
	var library := AnimationLibrary.new()
	library.add_animation("Walk", animation)
	player.add_animation_library("", library)
	var scene := PackedScene.new()
	check(scene.pack(model) == OK, "Evaluation probe packs")
	model.free()
	var motion := Motion.new(world)
	var entry := motion._instantiate(scene, 0.0)
	var sampled: PoseProbe = entry.root.get_child(0).get_node("PoseProbe")
	# First seek also restores the newly captured property cache once.
	check(sampled.writes == 2, "Initial seek restores cache then applies one pose")
	sampled.writes = 0
	motion.distances[10] = Motion.STRIDE_TILES * 0.25
	motion.update_walker(entry, [10, 0.0, 0.0, 0.0], 1.0)
	check(sampled.writes == 1, "Living manual pose evaluates once")
	sampled.writes = 0
	entry.born = 1.0
	motion.deaths[10] = entry
	motion.update_deaths(1.3)
	check(sampled.writes == 1, "Death manual pose evaluates once")
	motion.clear()
	# Reuse the property-track probe with real tank effect sampling. No GLB
	# import/cache writes are included in these per-update evaluation counts.
	for first_age in [0.0, 0.9]:
		entry = motion._instantiate(scene, 0.0)
		sampled = entry.root.get_child(0).get_node("PoseProbe")
		entry.type = "tank"
		entry.born = 0.0
		var skeleton := Skeleton3D.new()
		entry.root.add_child(skeleton)
		entry.death_skeleton = skeleton
		entry.death_start_pose = []
		entry.death_bodies = []
		var dust := MultiMeshInstance3D.new()
		entry.root.add_child(dust)
		entry.death_dust = dust
		motion.deaths[10] = entry
		sampled.writes = 0
		motion.update_deaths(first_age)
		check(sampled.writes == 1, "Fresh tank samples even when first update is already settled")
		var terminal_sampled: bool = first_age >= Motion.TankDeath.COLLAPSE
		for age in [0.05, 0.05, 0.3, 0.7, 0.9, 0.9, 1.2, 0.3, 0.8, 1.3]:
			sampled.writes = 0
			motion.update_deaths(age)
			var expected := 0 if age >= Motion.TankDeath.COLLAPSE and terminal_sampled else 1
			check(sampled.writes == expected, "Tank evaluates only changing collapse or first terminal pose at " + str(age))
			terminal_sampled = age >= Motion.TankDeath.COLLAPSE
			check(is_equal_approx(sampled.value, minf(age, Motion.TankDeath.COLLAPSE)), "Tank pose time survives pause and rewind")
			check(is_equal_approx(float(dust.get_instance_shader_parameter("death_age")), age), "Dust age updates even when terminal pose is held")
		motion.update_deaths(Motion.TankDeath.LIFETIME)
		check(motion.deaths.is_empty() and not is_instance_valid(dust), "Tank lifetime removes held corpse and dust")
		motion.clear()

func pose_snapshot(entry: Dictionary) -> Array[Transform3D]:
	var poses: Array[Transform3D] = [entry.root.transform]
	for node: Node3D in entry.root.find_children("*", "Node3D", true, false):
		poses.append(node.transform)
		if node is Skeleton3D:
			for bone in range(node.get_bone_count()):
				poses.append(node.get_bone_pose(bone))
	return poses

func check_legacy_pose(entry: Dictionary, label: String) -> void:
	var single := pose_snapshot(entry)
	# The removed second evaluation must not change any authored node/bone pose.
	entry.player.advance(0.0)
	var legacy := pose_snapshot(entry)
	check(single.size() == legacy.size(), label + " pose topology stays identical")
	for index in range(single.size()):
		check(single[index].is_equal_approx(legacy[index]), label + " pose matches legacy at transform " + str(index))

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	check_single_evaluation(world)
	var motion := Motion.new(world)
	var runtime := Runtime.new()
	var normal := motion.new_walker()
	var fast := motion.new_walker("fast")
	var tank := motion.new_walker("tank")
	check(not normal.is_empty() and not fast.is_empty() and not tank.is_empty(), "All three authored rigs load")
	if normal.is_empty() or fast.is_empty() or tank.is_empty():
		world.free()
		quit(1)
		return
	check(fast.type == "fast" and fast.player.get_animation(fast.clip).length > 0.56, "Fast Run imported")
	check(is_equal_approx(Motion.RUN_STRIDE_TILES, 0.6445833333333333 * Motion.FAST_VISUAL_SCALE), "Fast stride follows visual scale without changing combat speed")
	check(tank.clip == "Walk" and is_equal_approx(tank.player.get_animation(tank.clip).length, Motion.WALK_SECONDS), "Tank imports approved 26-frame Walk")
	check(is_equal_approx(.65 * Motion.visual_scale("tank"), .55 * Motion.NORMAL_VISUAL_SCALE), "Tank shares common display size without changing content .65")
	check(tank.has("label_bounds") and tank.label_bounds.size.y > 0.0 and not normal.has("label_bounds") and not fast.has("label_bounds"), "Only tank head supplies the new visual bar anchor")
	for entry: Dictionary in [normal, fast, tank]:
		check_legacy_pose(entry, entry.type + " initial")
		var id := {"normal":1, "fast":2, "tank":3}[entry.type] as int
		var stride: float = Motion.RUN_STRIDE_TILES if entry.type == "fast" else Motion.STRIDE_TILES
		var seconds: float = Motion.RUN_SECONDS if entry.type == "fast" else Motion.WALK_SECONDS
		var data := [id, 0.0, 0.0, 0.0, 0.0, 0.48, 0.0, entry.type, false, false, false, false, 0.0, 0.0]
		runtime.enemies[str(id)] = {"id": id, "type": entry.type, "distanceTravelled": stride * 48.0 * 0.25, "facingAngle": 0.0}
		motion.observe_native(runtime, 1.0, Vector2i(8, 8))
		motion.update_walker(entry, data, 1.0)
		check(is_equal_approx(entry.player.current_animation_position, seconds * 0.25), entry.type + " native distance drives phase")
		check_legacy_pose(entry, entry.type + " quarter stride")
		data[1] = 12.0 # Smoothed/display movement must not advance a paused logical rig.
		motion.update_walker(entry, data, 1.0)
		check(is_equal_approx(entry.player.current_animation_position, seconds * 0.25), entry.type + " paused phase ignores display displacement")
		runtime.enemies[str(id)].distanceTravelled = stride * 48.0 * 0.5
		motion.observe_native(runtime, 1.1, Vector2i(8, 8))
		motion.update_walker(entry, data, 1.1)
		check(is_equal_approx(entry.player.current_animation_position, seconds * 0.5), entry.type + " slow/4x clock uses traveled distance")
		check_legacy_pose(entry, entry.type + " half stride")
		var before: float = entry.root.rotation.y
		data[3] = PI / 2.0
		motion.update_walker(entry, data, 1.1)
		check(is_equal_approx(entry.root.rotation.y, before), entry.type + " corner starts without snapping")
		motion.update_walker(entry, data, 1.16)
		check(entry.root.rotation.y < before and entry.root.rotation.y > 0.0, entry.type + " corner eases with combat clock")
		var phase_before: float = entry.player.current_animation_position
		data.append({"teleportSerial": 1})
		motion.update_walker(entry, data, 1.16)
		data[14].teleportSerial = 2
		data[3] = PI
		motion.distances[id] += stride * 3.25
		motion.update_walker(entry, data, 1.16)
		check(is_equal_approx(entry.player.current_animation_position, phase_before), entry.type + " teleport preserves gait phase")
		check(is_equal_approx(entry.root.rotation.y, -PI / 2.0), entry.type + " teleport snaps exit facing")
		check_legacy_pose(entry, entry.type + " teleport")
		var body: MeshInstance3D = entry.root.find_children("*", "MeshInstance3D", true, false)[0]
		var original := body.get_active_material(0)
		Burn.apply(entry, true, 1.16)
		Frost.apply(entry, true)
		check(entry.burn.get_child_count() == 1 and entry.frost.get_child_count() == 2, entry.type + " status remains three shared meshes")
		var burn_mesh: MeshInstance3D = entry.burn.get_child(0)
		check(burn_mesh.mesh == load("res://presentation/stage_resources.gd").load_resource(Status.MESHES[entry.type].EnemyBurn[0]) and burn_mesh.skin == body.skin, entry.type + " species mesh reuses own skin")
		check(burn_mesh.get_node(burn_mesh.skeleton) == body.get_node(body.skeleton), entry.type + " status follows live skeleton")
		check(is_equal_approx(burn_mesh.material_override.get_shader_parameter("coordinate_scale"), Status.COORDINATE_SCALES[entry.type]), entry.type + " burn rise and billboard use own rig normalization")
		var coat: ShaderMaterial = body.get_active_material(0).next_pass
		check(coat.get_shader_parameter("body_albedo") == original.albedo_texture and coat.get_shader_parameter("preserve_colored_core"), entry.type + " frost preserves own cyan/purple core atlas")
		check(is_equal_approx(coat.get_shader_parameter("coordinate_scale"), Frost.COORDINATE_SCALES[entry.type]), entry.type + " frost uses own normalization")
		if entry.type == "fast":
			check(coat.get_shader_parameter("preserve_emission_core") and coat.get_shader_parameter("body_emission") == original.emission_texture, "Blue hound stone receives frost; only authored emission is protected")
		if entry.type == "tank":
			check(coat.get_shader_parameter("preserve_colored_with_emission"), "Tank protects both subtle eyes and nonemitting mineral rune")
			var core_count := 0
			for mesh: MeshInstance3D in entry.root.find_children("*", "MeshInstance3D", true, false):
				var core := mesh.get_active_material(0)
				if core.resource_name.ends_with("_crystal"):
					core_count += 1
					check(core.next_pass == null, "Tank frost keeps nested amber sphere material")
					if core.resource_name == "Tank_AmberNucleus_crystal":
						check(core is ShaderMaterial and core.shader == Motion.TANK_NUCLEUS_SHADER, "Tank keeps authored camera-facing amber depth on real sphere")
			check(core_count == 2, "Tank keeps both real amber spheres")
		Burn.apply(entry, false, 1.16)
		Frost.apply(entry, false)
		check(not entry.burn.visible and not entry.frost.visible and body.get_active_material(0) == original, entry.type + " status expiry restores material")
	Burn.set_time(7.0)
	check(is_equal_approx(normal.burn.get_child(0).material_override.get_shader_parameter("burn_time"), 7.0), "Shared burn clock updates skinned effects")
	check(is_equal_approx(fast.burn.get_child(0).material_override.get_shader_parameter("burn_time"), 7.0), "Both rig scales share the combat burn clock")
	check(is_equal_approx(tank.burn.get_child(0).material_override.get_shader_parameter("burn_time"), 7.0), "Tank shares combat burn clock")
	check(normal.burn.get_child(0).mesh != fast.burn.get_child(0).mesh, "Guardian status is not reused on hound skeleton")
	runtime.events = [{"id": 1, "kind": "kill", "enemyId": 2, "x": 0.0, "y": 0.0}, {"id": 2, "kind": "kill", "enemyId": 1, "x": 0.0, "y": 0.0}, {"id": 3, "kind": "kill", "enemyId": 3, "x": 0.0, "y": 0.0}]
	motion.observe_native(runtime, 2.0, Vector2i(8, 8))
	check(motion.deaths.has(1) and motion.deaths.has(2), "Both authored kinds create their own death clip")
	check(motion.deaths.has(3) and motion.deaths[3].clip == "Death", "Tank uses its own authored heavy collapse")
	var tank_death: Dictionary = motion.deaths[3]
	var live_skeleton: Skeleton3D = tank.root.find_children("*", "Skeleton3D", true, false)[0]
	for bone in range(live_skeleton.get_bone_count()):
		check(tank_death.death_skeleton.get_bone_pose(bone).is_equal_approx(live_skeleton.get_bone_pose(bone)), "Tank kill retains current gait pose at bone %d" % bone)
	check(motion.deaths[2].type == "fast" and motion.deaths[2].clip != "Run", "Fast kill uses Death rather than Run")
	check(is_equal_approx(motion.deaths[2].root.scale.x, 0.48 * Motion.FAST_VISUAL_SCALE), "Fast corpse retains live visual scale")
	for entry: Dictionary in motion.deaths.values():
		if entry.type != "tank": check_legacy_pose(entry, entry.type + " death initial")
	motion.update_deaths(2.05)
	var blended := pose_snapshot(tank_death)
	motion.update_deaths(2.05)
	var paused_blend := pose_snapshot(tank_death)
	for index in range(blended.size()):
		check(blended[index].is_equal_approx(paused_blend[index]), "Paused tank gait blend resamples authored pose without accumulating")
	motion.update_deaths(2.30)
	for entry: Dictionary in motion.deaths.values():
		check_legacy_pose(entry, entry.type + " death mid")
	var corpse: Dictionary = motion.deaths[2]
	var fade: float = (1.0 - float(corpse.death_bodies[0].get_instance_shader_parameter("death_opacity")))
	check(fade > 0.0 and fade < 1.0, "Hound fades during its floating curl")
	motion.update_deaths(2.30)
	check(is_equal_approx(corpse.player.current_animation_position, 0.30) and is_equal_approx((1.0 - float(corpse.death_bodies[0].get_instance_shader_parameter("death_opacity"))), fade), "Paused combat clock freezes pose and fade")
	motion.update_deaths(2.56)
	check(not motion.deaths.has(2) and motion.deaths.has(1), "Fast cleans up at .55 seconds; normal retains its .6 second lifetime")
	check(motion.deaths.has(3), "Tank residue remains after the old corpse lifetimes")
	motion.update_deaths(2.9)
	check(motion.deaths.size() == 1 and is_equal_approx(tank_death.player.current_animation_position, .7), "Tank holds the settled pose after .7s")
	check(is_zero_approx(float(tank_death.death_bodies[0].get_instance_shader_parameter("death_light"))), "Tank core is off after the single impact pulse")
	var settled := pose_snapshot(tank_death)
	motion.update_deaths(3.2)
	var held := pose_snapshot(tank_death)
	for index in range(settled.size()):
		check(settled[index].is_equal_approx(held[index]), "Tank holds each authored node/bone during fade")
	var tank_opacity := float(tank_death.death_bodies[0].get_instance_shader_parameter("death_opacity"))
	check(tank_opacity > 0.0 and tank_opacity < 1.0, "Tank fade progresses while terminal pose evaluation is skipped")
	check(is_equal_approx(float(tank_death.death_dust.get_instance_shader_parameter("death_age")), 1.2), "Authored tank dust continues using combat age during fade")
	check_legacy_pose(tank_death, "tank held terminal")
	motion.update_deaths(3.41)
	check(motion.deaths.is_empty(), "Tank corpse and dust are removed after 1.4s")
	motion.forget_walker(2)
	fast.root.free()
	check(not motion.walkers.has(2), "Fast removal clears motion reference and status children")
	motion.observe_native(runtime, 1.0, Vector2i(8, 8))
	check(motion.deaths.is_empty(), "Rewind clears deaths without replaying journal")
	motion.clear()
	world.free()
	print("SKINNED_ENEMY_PRESENTATION ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
