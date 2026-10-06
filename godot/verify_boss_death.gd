extends SceneTree
## Focused production boss lifecycle contract. Run in a prepared full-asset project.
const Units = preload("res://presentation/battlefield_units.gd")
const Motion = preload("res://presentation/guardian_preview.gd")
const BossDeath = preload("res://effects/boss_death.gd")
var failures: Array[String] = []
var checks := 0
var completed_aliases := 0
var completed_other_enemies := 0

class Runtime:
	extends RefCounted
	var epoch := 1
	var tile_size := 48.0
	var origin := Vector2.ZERO
	var enemies := {}
	var events: Array = []
	func _visual_enemy_offset(_enemy: Dictionary) -> Vector2: return Vector2.ZERO

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func pose(entry: Dictionary) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var skeleton: Skeleton3D = entry.root.find_children("*", "Skeleton3D", true, false)[0]
	for bone in skeleton.get_bone_count(): result.append(skeleton.get_bone_pose(bone))
	return result

func same_pose(a: Array[Transform3D], b: Array[Transform3D]) -> bool:
	if a.size() != b.size(): return false
	for index in a.size():
		if not a[index].is_equal_approx(b[index]): return false
	return true

func parameter(entry: Dictionary, name: String) -> float:
	return float(entry.boss_bodies[0].get_instance_shader_parameter(name))

func surface_floor(entry: Dictionary, dominant_bone: String) -> float:
	# Skin actual mesh vertices, rather than treating a joint origin as contact.
	var floor_y := INF
	for body: MeshInstance3D in entry.boss_bodies:
		if body.skin == null: continue
		var skeleton: Skeleton3D = body.get_node(body.skeleton)
		skeleton.force_update_all_bone_transforms()
		var transforms: Array[Transform3D] = []
		var names: Array[String] = []
		for bind in body.skin.get_bind_count():
			var bone := body.skin.get_bind_bone(bind)
			if bone < 0: bone = skeleton.find_bone(body.skin.get_bind_name(bind))
			transforms.append(skeleton.get_bone_global_pose(bone) * body.skin.get_bind_pose(bind))
			names.append(skeleton.get_bone_name(bone))
		for surface in body.mesh.get_surface_count():
			var arrays := body.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for vertex in vertices.size():
				var offset := vertex * 4
				var dominant := 0
				for influence in range(1, 4):
					if weights[offset + influence] > weights[offset + dominant]: dominant = influence
				if names[joints[offset + dominant]] != dominant_bone: continue
				var point := Vector3.ZERO
				for influence in 4:
					point += (transforms[joints[offset + influence]] * vertices[vertex]) * weights[offset + influence]
				floor_y = minf(floor_y, (body.global_transform * point).y)
	return floor_y

func verify_alias(world: Node3D, camera: Camera3D, kind: String, index: int) -> void:
	var units := Units.new(world, camera)
	units.failure.connect(func(message): check(false, message))
	var motion: Motion = units._guardian_preview
	var runtime := Runtime.new()
	var id := 30 + index
	var survivor_id := id + 100
	var size: float = [.79, .81, .83][index]
	var data := [id, 4.0, 5.0, .35, 0.0, size, 0.0, kind, true, true, false, false, 4.0, 5.0, {"teleportSerial":0}]
	var survivor_data := [survivor_id, 5.0, 5.0, 0.0, 0.0, size, 0.0, kind, false, false, false, false, 5.0, 5.0]
	var stride: float = Motion.BOSS_STRIDE_TILES * size / .79
	runtime.enemies = {str(id): {"id":id, "type":kind, "distanceTravelled":stride*48.0*.3125, "facingAngle":.35, "presentationScale":size}, str(survivor_id): {"id":survivor_id, "type":kind, "distanceTravelled":0.0, "facingAngle":0.0, "presentationScale":size}}
	motion.observe_native(runtime, 1.0, Vector2i(8,10))
	units.configure(1.0, Vector2i(8,10), {})
	units._sync_enemies([data, survivor_data])
	var live: Dictionary = units.enemies[id]
	var survivor: Dictionary = units.enemies[survivor_id]
	check(live.clip == "HeavyWalk", kind + " explicitly selects living clip")
	check(live.player.has_animation("BossDeath"), kind + " imports death clip")
	check(live.boss_core_light.light_energy > 0.0, kind + " living core light is active")
	check(live.burn.visible and live.frost.visible, kind + " both statuses coexist with living core")
	check(live.boss_bodies[0].get_active_material(0).next_pass != null, kind + " frost coat remains on shader-backed boss")
	check(survivor.boss_bodies[0].get_active_material(0).next_pass == null, kind + " frost does not contaminate same-type survivor")
	var initial := pose(live)
	var alive_light: float = survivor.boss_core_light.light_energy
	units._sync_enemies([data, survivor_data])
	check(same_pose(initial, pose(live)), kind + " paused combat clock keeps living pose")
	data[8] = false; data[9] = false
	units._sync_enemies([data, survivor_data])
	check(not live.burn.visible and not live.frost.visible, kind + " status expiration hides attachments")
	check(live.boss_bodies[0].get_active_material(0).next_pass == null, kind + " frost expiration restores core material")
	data[8] = true; data[9] = true
	units._sync_enemies([data, survivor_data])
	check(live.boss_bodies[0].get_active_material(0).next_pass != null, kind + " frost reapplies after expiration")
	var kill_pose := pose(live)
	var kill_transform: Transform3D = live.root.global_transform
	var original_native := runtime.enemies.duplicate(true)
	runtime.events = [{"id":1, "kind":"kill", "enemyId":id, "x":192.0, "y":240.0}]
	motion.observe_native(runtime, 1.5, Vector2i(8,10))
	check(runtime.enemies == original_native, kind + " presentation never mutates native enemy state")
	check(motion.deaths.has(id), kind + " kill creates boss corpse")
	if not motion.deaths.has(id):
		units.clear()
		return
	var dead: Dictionary = motion.deaths[id]
	check(dead.clip == "BossDeath", kind + " explicitly selects death clip")
	check(dead.root.global_transform.is_equal_approx(kill_transform), kind + " corpse preserves displayed transform")
	check(same_pose(kill_pose, pose(dead)), kind + " death starts from interrupted walking pose")
	check(not dead.has("burn") and not dead.has("frost"), kind + " corpse does not retain living status nodes")
	check(dead.boss_bodies[0].get_active_material(0).next_pass == null, kind + " corpse has no stale frost coat")
	units._sync_enemies([survivor_data])
	check(not motion.walkers.has(id), kind + " living walker bookkeeping removed")
	var death_root: Node3D = dead.root
	motion.observe_native(runtime, 1.5, Vector2i(8,10))
	check(motion.deaths[id].root == death_root, kind + " repeated kill journal does not restart corpse")
	var baseline := parameter(dead, "core_strength")
	var peak := baseline
	var last := baseline
	var decreasing := false
	for step in range(1, 31):
		var age := float(step)*.01
		motion.update_deaths(1.5+age)
		var strength := parameter(dead, "core_strength")
		peak = maxf(peak, strength)
		if strength < last - .00001: decreasing = true
		if decreasing: check(strength <= last + .00001, kind + " core emits only one early pulse")
		last = strength
	check(peak > baseline + 1.0, kind + " death pulse brightens core once")
	motion.update_deaths(2.4)
	check(is_zero_approx(parameter(dead, "core_strength")), kind + " core emission off by .9 seconds")
	check(is_zero_approx(parameter(dead, "death_light")), kind + " authored emission off by .9 seconds")
	check(is_zero_approx(dead.boss_core_light.light_energy), kind + " attached light off by .9 seconds")
	check(is_equal_approx(survivor.boss_core_light.light_energy, alive_light), kind + " dying light does not change survivor")
	check(is_equal_approx(parameter(survivor, "core_strength"), BossDeath.CORE_EMISSION), kind + " dying emission does not change survivor")
	check(is_equal_approx(float(dead.death_age), .9), kind + " large native-clock step samples absolute death age")
	var paused_evaluations := int(dead.death_pose_evaluations)
	var held := pose(dead)
	var held_opacity := parameter(dead, "death_opacity")
	motion.update_deaths(2.4)
	check(same_pose(held, pose(dead)) and is_equal_approx(parameter(dead, "death_opacity"), held_opacity), kind + " death pauses with combat time")
	check(int(dead.death_pose_evaluations) == paused_evaluations, kind + " paused death does not reevaluate bones")
	motion.update_deaths(1.5+BossDeath.CONTACT)
	check(not dead.death_chips.is_empty() and not dead.death_puffs.is_empty(), kind + " contact debris is authored and present")
	check(dead.death_chips.any(func(chip): return chip.mesh.visible) and dead.death_puffs.any(func(puff): return puff.mesh.visible), kind + " contact activates small chips and dust")
	var skeleton: Skeleton3D = dead.death_skeleton
	var wrist := skeleton.find_bone("hand.R")
	check(wrist >= 0, kind + " bracing wrist exists")
	var wrist_contact: Transform3D = skeleton.get_bone_global_pose(wrist)
	if index == 0:
		var knee_y := surface_floor(dead, "shin.R")
		check(knee_y >= -.002 and knee_y <= .005, "boss real knee surface reaches floor without penetration")
	motion.update_deaths(1.5+1.6)
	check(skeleton.get_bone_global_pose(wrist).is_equal_approx(wrist_contact), kind + " bracing wrist remains planted after contact")
	if index == 0:
		var knee_y := surface_floor(dead, "shin.R")
		check(knee_y >= -.002 and knee_y <= .005, "boss knee contact retained after body settles")
	motion.update_deaths(1.5+BossDeath.COLLAPSE)
	check(dead.death_settled and not dead.player.is_playing(), kind + " terminal animation paused and cached")
	check(dead.death_chips.all(func(chip): return not chip.mesh.visible) and dead.death_puffs.all(func(puff): return not puff.mesh.visible), kind + " contact debris expires before terminal hold")
	var terminal := pose(dead)
	var evaluations := int(dead.death_pose_evaluations)
	var opacity := parameter(dead, "death_opacity")
	for age: float in [2.3,2.4,2.5,2.65]:
		motion.update_deaths(1.5+age)
		check(int(dead.death_pose_evaluations) == evaluations, kind + " terminal hold does not resample bones")
		check(same_pose(terminal, pose(dead)), kind + " terminal hold preserves pose")
		var next_opacity := parameter(dead, "death_opacity")
		check(next_opacity <= opacity + .00001, kind + " opacity fades monotonically")
		opacity = next_opacity
	check(is_zero_approx(opacity), kind + " fully faded by2.65seconds")
	# A direct presentation time sample into collapse invalidates the hold.
	motion.update_deaths(1.5+1.0)
	check(not dead.death_settled and int(dead.death_pose_evaluations) > evaluations, kind + " rewind into collapse invalidates terminal cache")
	motion.update_deaths(1.5+BossDeath.LIFETIME)
	check(not motion.deaths.has(id) and not is_instance_valid(death_root), kind + " lifetime frees corpse and all effects")
	# Epoch replacement and a same-epoch rewind clear retained old kills.
	runtime.epoch += 1
	runtime.events.clear()
	motion.observe_native(runtime, 4.5, Vector2i(8,10))
	units.configure(4.5, Vector2i(8,10), {})
	units._sync_enemies([data, survivor_data])
	runtime.enemies[str(id)].teleportSerial = 1
	runtime.enemies[str(id)].facingAngle = PI / 2.0
	runtime.events = [{"id":2,"kind":"kill","enemyId":id,"x":384.0,"y":432.0}]
	motion.observe_native(runtime, 5.0, Vector2i(8,10))
	check(motion.deaths.has(id), kind + " a new epoch can create a new corpse")
	if motion.deaths.has(id):
		check(motion.deaths[id].root.position.is_equal_approx(Vector3(4.0,0.0,4.0)), kind + " native teleport kill uses exit position before display sync")
		check(is_zero_approx(motion.deaths[id].root.rotation.y), kind + " native teleport kill uses exit facing")
	motion.observe_native(runtime, 4.9, Vector2i(8,10))
	check(motion.deaths.is_empty(), kind + " same-epoch rewind clears future corpse and ignores old journal")
	runtime.epoch += 1
	runtime.events.clear()
	motion.observe_native(runtime, 0.0, Vector2i(8,10))
	check(motion.deaths.is_empty() and motion.walkers.is_empty(), kind + " epoch reset clears presentation history")
	units.clear()
	completed_aliases += 1

func verify_other_enemies(world: Node3D, camera: Camera3D) -> void:
	for kind: String in ["normal","fast","tank"]:
		var units := Units.new(world,camera)
		units.failure.connect(func(message): check(false,message))
		var runtime := Runtime.new()
		runtime.enemies = {"1":{"id":1,"type":kind,"distanceTravelled":0.0,"facingAngle":0.0,"presentationScale":.55}}
		var motion: Motion = units._guardian_preview
		motion.observe_native(runtime,0.0,Vector2i(8,10))
		units.configure(0.0,Vector2i(8,10),{})
		units._sync_enemies([[1,4.0,5.0,0.0,0.0,.55,0.0,kind,false,false,false,false]])
		check(not units.enemies[1].has("boss_core_light"),kind+" does not acquire boss controller")
		runtime.events = [{"id":1,"kind":"kill","enemyId":1,"x":192.0,"y":240.0}]
		motion.observe_native(runtime,.1,Vector2i(8,10))
		check(motion.deaths.has(1),kind+" existing death still spawns")
		if motion.deaths.has(1): check(not motion.deaths[1].has("boss_core_light"),kind+" death remains isolated")
		units._sync_enemies([])
		motion.update_deaths(10.0)
		check(motion.deaths.is_empty(),kind+" existing death cleanup retained")
		units.clear()
		completed_other_enemies += 1

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,4,6)
	camera.look_at(Vector3(0,.5,0))
	for index in Motion.BOSS_KINDS.size(): verify_alias(world,camera,Motion.BOSS_KINDS[index],index)
	verify_other_enemies(world,camera)
	check(completed_aliases == Motion.BOSS_KINDS.size(), "all boss alias lifecycle cases executed to completion")
	check(completed_other_enemies == 3, "all existing enemy regression cases executed to completion")
	world.free()
	print("BOSS_DEATH checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
