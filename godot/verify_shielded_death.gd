extends SceneTree
## Shielded Death: authored clip handoff, ground contact, combat-clock determinism,
## dying rune power and spark bursts. Run after prepare_godot_project.py/import.
const Units = preload("res://presentation/battlefield_units.gd")
const Native = preload("res://combat/native_combat_runtime.gd")
const Shielded = preload("res://presentation/shielded_presentation.gd")
const Death = preload("res://effects/shielded_death.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
const Preparation = preload("res://presentation/effect_preparation.gd")
const RUNE_FRONT_NORMAL := Vector3(-.21980593, -.4528548, .86406475)
class OfflineApp extends "res://app/app_lifecycle.gd":
	func _detached_debug_lifecycle() -> bool: return true
var failures: Array[String] = []
var checks := 0
var directory := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func parts(model_root: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for label: String in Shielded.PART_NAMES:
		result.append(model_root.find_child(label, true, false) as MeshInstance3D)
	return result

func poses(entry: Dictionary) -> Array:
	return parts(entry.root).map(func(body: MeshInstance3D): return body.global_transform)

func same(a: Array, b: Array, epsilon := 1e-4) -> bool:
	for index in a.size():
		var x: Transform3D = a[index]
		var y: Transform3D = b[index]
		if x.origin.distance_to(y.origin) > epsilon: return false
		for axis in 3:
			if x.basis[axis].distance_to(y.basis[axis]) > epsilon: return false
	return true

func lowest(entry: Dictionary) -> float:
	var low := INF
	for body: MeshInstance3D in parts(entry.root):
		var vertices: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var pose := body.global_transform
		for index in range(0, vertices.size(), 3): low = minf(low, (pose * vertices[index]).y)
	return low

func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera)
	var units := Units.new(world, camera)
	var runtime := Native.new()
	check(runtime.start(1, {"path":[[0.0,0.0],[8.0,0.0]],"tileSize":1.0,"enemies":[
		{"id":1,"type":"shielded","maxHp":100.0,"maxShield":100.0,"shield":0.0,"presentationScale":.59}]}, {}) == "", "native fixture starts")
	var kill_time := 7.3
	units.configure(kill_time, Vector2i(8, 10), {})
	var row = runtime.decorate_frame({}).enemies[0]
	row.x = 4.2; row.y = 5.4; row.facing = .8
	units._sync_enemies([row])
	var live: Dictionary = units.enemies[1]
	var live_poses := poses(live)
	var wreck := Death.create(world, kill_time)
	check(not wreck.is_empty(), "shielded GLB provides Idle and Death")
	if wreck.is_empty():
		quit(1); return
	wreck.root.transform = live.root.transform
	Death.sample(wreck, 0.0)
	check(same(live_poses, poses(wreck)), "death starts exactly at the live combat-clock pose")
	var clip: Animation = wreck.player.get_animation(Death.CLIP)
	print("SHIELDED_DEATH clip=", clip.length, " tracks=", clip.get_track_count())
	check(absf(clip.length - Death.CLIP_SECONDS) < 1e-3, "authored Death length matches the presentation contract")
	check(wreck.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "Death has no engine wall clock")
	var shielded_only := Preparation.resource_paths(["shielded"], [])
	check(Death.ARC_MESH in shielded_only and Death.CONTACT_MESH in shielded_only, "shielded-only stage preloads both authored electrical resources without a lightning tower")
	check(wreck.death_sparks.multimesh.instance_count == 3 and wreck.death_contacts.multimesh.instance_count == 2, "electricity uses two sparse shared batches instead of individual spark nodes")
	check(wreck.death_sparks.multimesh.mesh.resource_path == Death.ARC_MESH and wreck.death_contacts.multimesh.mesh.resource_path == Death.CONTACT_MESH, "electrical branches reuse the accepted Blender-authored mesh resources")
	var arc_triangles: int = wreck.death_sparks.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	var contact_triangles: int = wreck.death_contacts.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	check(arc_triangles == 1344 and contact_triangles == 1064 and arc_triangles*3+contact_triangles*2 == 6160, "electrical submitted geometry has the known two-batch budget of 6160 triangles")
	check(Death._contact_points.size() == 6, "six actual mesh-local contacts are prepared once")
	for burst in range(Death.BURSTS.size()):
		var electrical_age: float = Death.BURSTS[burst] + .012
		Death.sample(wreck, electrical_age)
		check(Death.active_burst(electrical_age) == burst and wreck.death_sparks.visible and wreck.death_contacts.visible, "authored jolt/impact enables its short electrical failure "+str(burst))
		var model_inverse: Transform3D = wreck.death_model.global_transform.affine_inverse()
		for index in range(6):
			var expected: Vector3 = model_inverse * wreck.death_bodies[index].global_transform * Death._contact_points[index]
			var uniform_name := "anchor_%d" % index
			check((wreck.death_sparks.get_instance_shader_parameter(uniform_name) as Vector3).is_equal_approx(expected) and (wreck.death_contacts.get_instance_shader_parameter(uniform_name) as Vector3).is_equal_approx(expected), "both electrical batches attach to the sampled part surface "+str(burst)+"/"+str(index))
		check(is_equal_approx((wreck.death_sparks.get_instance_shader_parameter("anchor_6") as Vector3).y,-Shielded.MODEL_LIFT+.006), "impact contact remains on the actual path surface in model coordinates")
		var electrical_pose: Vector3 = wreck.death_sparks.get_instance_shader_parameter("anchor_0")
		Death.sample(wreck,1.0)
		Death.sample(wreck,electrical_age)
		check((wreck.death_sparks.get_instance_shader_parameter("anchor_0") as Vector3).is_equal_approx(electrical_pose), "electrical contact rewinds with the rigid pose "+str(burst))
	# Compare the complete assembly against the authored clip in its calibrated
	# model coordinate frame, including every part's rigid fall and contact.
	var authored_root := Node3D.new(); world.add_child(authored_root)
	authored_root.transform = live.root.transform
	var authored: Node3D = load(Shielded.MODEL).instantiate()
	authored.position.y = Shielded.MODEL_LIFT
	authored.basis = Shielded.model_heading_correction()
	authored_root.add_child(authored)
	var authored_player: AnimationPlayer = authored.find_child("AnimationPlayer", true, false)
	authored_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	authored_player.play(Death.CLIP)
	var authored_parts := parts(authored)
	var original_facing: float = row.facing
	for facing in [0.0, PI / 2.0, PI, -PI / 2.0]:
		row.facing = facing
		units._sync_enemies([row])
		wreck.root.transform = live.root.transform
		Death.sample(wreck, 0.0)
		check(same(poses(live),poses(wreck)), "death handoff has no turn at native heading "+str(facing))
		var front: Vector3 = parts(wreck.root)[0].global_basis * RUNE_FRONT_NORMAL
		front.y = 0.0
		check(front.normalized().dot(Vector3(cos(facing),0,sin(facing))) > .99999, "death starts with the actual front rune facing travel "+str(facing))
	row.facing = original_facing
	units._sync_enemies([row])
	wreck.root.transform = live.root.transform
	# Every part stays on or above the path surface throughout the clip and hold.
	var deepest := INF
	var age := 0.0
	while age <= Death.FADE_START:
		Death.sample(wreck, age)
		deepest = minf(deepest, lowest(wreck))
		if age >= Death.HANDOFF_SECONDS:
			authored_player.seek(minf(age, Death.CLIP_SECONDS), true)
			var corrected_pose: Transform3D = wreck.death_bodies[0].global_transform
			var authored_pose := authored_parts[0].global_transform
			var vertices: PackedVector3Array = authored_parts[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var heights_unchanged := true
			for vertex in vertices:
				if absf((corrected_pose*vertex).y-(authored_pose*vertex).y) > 1e-5: heights_unchanged = false; break
			check(heights_unchanged, "front correction preserves all authored body contact heights "+str(age))
			for part in range(6): check(wreck.death_bodies[part].global_transform.is_equal_approx(authored_parts[part].global_transform), "common front calibration preserves authored assembly pose "+str(part)+"/"+str(age))
		age += 1.0 / 24.0
	print("SHIELDED_DEATH lowest=", deepest)
	check(deepest > -.01, "wreck never sinks below the path surface")
	Death.sample(wreck, Death.CLIP_SECONDS)
	check(absf(lowest(wreck)) < .02, "settled wreck rests on the path surface")
	# Pause and rewind resample the same pose.
	Death.sample(wreck, 1.0)
	var at_one := poses(wreck)
	Death.sample(wreck, 1.0)
	check(same(at_one, poses(wreck), 1e-6), "paused sampling never accumulates")
	Death.sample(wreck, .4)
	Death.sample(wreck, 1.0)
	check(same(at_one, poses(wreck), 1e-6), "rewind resamples the authored clip exactly")
	Death.sample(wreck, .05)
	var handoff := poses(wreck)
	Death.sample(wreck, 1.0)
	Death.sample(wreck, .05)
	check(same(handoff, poses(wreck), 1e-6), "rewind into handoff restores the blended live pose")
	for t in [.051, .119]:
		Death.sample(wreck,t)
		var paused_handoff := poses(wreck)
		for repeat in range(100): Death.sample(wreck,t)
		check(same(paused_handoff,poses(wreck),1e-7), "paused handoff does not accumulate rotation or scale "+str(t))
		Death.sample(wreck,1.0)
		Death.sample(wreck,t)
		check(same(paused_handoff,poses(wreck),1e-7), "handoff rewind restores the untouched authored scale "+str(t))
	# Failing power: flicker with flares on the jolts, fully dark once falling.
	var body: MeshInstance3D = wreck.death_bodies[0]
	var lit := 0
	var dark := 0
	for step in range(0, 48):
		var t := step / 60.0
		Death.sample(wreck, t)
		if float(body.get_instance_shader_parameter("death_light")) > .1: lit += 1
		else: dark += 1
	check(lit > 12 and dark > 5, "rune power flickers during the stagger")
	Death.sample(wreck, Death.BURSTS[1])
	check(float(body.get_instance_shader_parameter("death_light")) > 1.0 and wreck.death_lights.all(func(l): return l.visible and l.light_energy > 0.0), "jolt flares the rune glow and real lights")
	Death.sample(wreck, 1.0)
	check(float(body.get_instance_shader_parameter("death_light")) == 0.0 and wreck.death_lights.all(func(l): return not l.visible), "runes and lights are dark during the fall")
	check(not wreck.death_sparks.visible and not wreck.death_contacts.visible and is_equal_approx(float(wreck.death_sparks.get_instance_shader_parameter("death_age")), 1.0), "electrical current goes dark between failures without a trailing firework")
	Death.sample(wreck, Death.BURSTS[-1] + .012)
	check(float(body.get_instance_shader_parameter("death_light")) == 0.0 and wreck.death_lights.any(func(l): return l.visible and l.light_energy > .1), "impact gives a short local contact flash while the rune power stays off")
	Death.sample(wreck, Death.BURSTS[-1] + .5)
	check(not wreck.death_sparks.visible and not wreck.death_contacts.visible, "both electrical batches hide after the brief impact failure")
	Death.sample(wreck, Death.FADE_START)
	check(float(body.get_instance_shader_parameter("death_opacity")) == 1.0, "wreck holds fully opaque until the fade")
	Death.sample(wreck, Death.LIFETIME - .01)
	check(float(body.get_instance_shader_parameter("death_opacity")) < .1, "wreck fades out by its lifetime")
	var other := Death.create(world, 2.0)
	check(other.death_sparks.multimesh == wreck.death_sparks.multimesh and other.death_contacts.multimesh == wreck.death_contacts.multimesh and other.death_bodies[0].get_active_material(0) == body.get_active_material(0), "both electrical batches and dying materials are shared")
	Death.sample(wreck, Death.BURSTS[0]+.012)
	Death.sample(other, Death.BURSTS[1]+.05)
	check(wreck.death_sparks.get_instance_shader_parameter("burst_index") == 0 and other.death_sparks.get_instance_shader_parameter("burst_index") == 1, "simultaneous deaths keep independent electrical phases on the shared material")
	wreck.root.free(); other.root.free(); authored_root.free()
	units.clear(); world.free()
	Death.retain_stage(["shielded"], [])
	check(Death._sparks != null, "stage with shielded keeps prepared caches")
	Death.retain_stage([], [])
	check(Death._sparks == null and Death._contacts == null and Death._contact_points.is_empty() and Death._materials.is_empty(), "stage exit releases shielded death geometry and contact caches")
	directory = OS.get_environment("RUNE_SHIELDED_DEATH_CAPTURE_DIR")
	if not directory.is_empty() and DisplayServer.get_name() != "headless": await review_app()
	print("SHIELDED_DEATH failures=", JSON.stringify(failures), " checks=", checks)
	quit(0 if failures.is_empty() else 1)


func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "capture " + label)

func review_app() -> void:
	# Actual Stage 10 app, official session clock, real kill/ACK/render delivery.
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(440, 900)
	var scene = load("res://main.gd").new()
	scene.app_mode = true
	root.add_child(scene)
	var original = scene.session_controller
	if original.services != null: original.services.free()
	original.services = null
	original.free()
	var app := OfflineApp.new()
	scene.session_controller = app
	scene.add_child(app)
	if app.services != null: app.services.free()
	app.services = null
	app.checkpoint = load("res://session/session_checkpoint.gd").new(directory.path_join("isolated-save"))
	app.checkpoint.allow_progression_only = true
	check(app.retry_load(), "isolated offline app startup")
	app.progression_inputs.unlockedStageIds = [1, 10]
	check(await app.start_stage(app.catalog.stage_index(10)), "actual Stage10 app preparation")
	app.hud.start.pressed.emit()
	scene.set_process(false)
	app.set_process(false)
	var runtime = scene.combat_runtime
	for step in range(480): runtime.advance_session(1.0 / 60.0)
	var target: Dictionary = {}
	for enemy: Dictionary in runtime.enemies.values():
		if enemy.type == "shielded": target = enemy; break
	check(not target.is_empty(), "real wave produced a shielded enemy")
	if target.is_empty(): scene.free(); return
	var zoom := "--wide" not in OS.get_cmdline_user_args()
	if zoom:
		app.toggle_camera()
		if scene.camera_transition != null and scene.camera_transition.is_running(): await scene.camera_transition.finished
		scene._session_input.set_zoom(2.5)
	scene.apply_frame(scene.combat_base_frame)
	var live: Node3D = scene.enemies[int(target.id)].root
	if zoom:
		var point: Vector2 = scene.camera.unproject_position(live.global_position + Vector3(0, .28, 0))
		scene._session_input.pan = ((Vector2(220, 420) - point) / Vector2(440, 900)).clamp(Vector2(-.75, -.75), Vector2(.75, .75))
	scene.apply_frame(scene.combat_base_frame)
	await capture("death-000-live")
	# The runtime's own damage step must kill it so the kill event and reward ACK
	# reach the renderer exactly as in combat (direct hp edits retire silently).
	target.shield = 0.0
	target.shieldBroken = true
	target.hp = 1.0
	Enemy.add_burn(target, {"damagePerSecond": 600.0, "duration": 1.0})
	var units = scene._units
	for frame in range(1, 90):
		runtime.advance_session(1.0 / 30.0)
		scene.apply_frame(scene.combat_base_frame)
		app.hud.refresh()
		await capture("death-%03d" % frame)
		if frame == 3:
			var dying: Dictionary = units._guardian_preview.deaths.get(int(target.id), {})
			check(dying.get("type", "") == "shielded", "actual kill delivers the shielded death")
			check(not scene.enemies.has(int(target.id)) or not is_instance_valid(live), "live body retired once its wreck appears")
	scene.free()
	await process_frame
