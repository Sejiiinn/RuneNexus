extends SceneTree
## Accepted boss visual only: all stage aliases retain native state and clock.
const Units = preload("res://presentation/battlefield_units.gd")
const Motion = preload("res://presentation/guardian_preview.gd")
const Status = preload("res://effects/guardian_status.gd")
var failures: Array[String] = []

class Runtime:
	extends RefCounted
	var epoch := 1
	var tile_size := 48.0
	var origin := Vector2.ZERO
	var enemies := {}
	var events: Array = []
	func _visual_enemy_offset(_enemy: Dictionary) -> Vector2: return Vector2.ZERO

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)

func bones(entry: Dictionary) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var skeleton: Skeleton3D = entry.root.find_children("*", "Skeleton3D", true, false)[0]
	for bone in skeleton.get_bone_count(): result.append(skeleton.get_bone_pose(bone))
	return result

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 4, 6)
	camera.look_at(Vector3(0, .5, 0))
	var units := Units.new(world, camera)
	units.failure.connect(func(message): check(false, message))
	var motion: Motion = units._guardian_preview
	var runtime := Runtime.new()
	var sizes := [.79, .81, .83]
	for index in Motion.BOSS_KINDS.size():
		var kind: String = Motion.BOSS_KINDS[index]
		var id := index + 30
		var data := [id, 4.0, 5.0, 0.0, 0.0, sizes[index], 0.0, kind, false, false, false, false, 4.0, 5.0]
		units.configure(0.0, Vector2i(8, 10), {})
		units._sync_enemies([data])
		check(units.enemies.has(id), kind + " renders")
		if not units.enemies.has(id): continue
		var entry: Dictionary = units.enemies[id]
		check(entry.clip == "HeavyWalk", kind + " explicitly selects living heavy walk")
		check(entry.guardian_preview and entry.type == kind, kind + " retains identity and uses authored motion")
		check(entry.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, kind + " never advances from wall time")
		check(bones(entry).size() == 17, kind + " retains 17-bone rig")
		check(entry.has("label_bounds") and entry.label_bounds.size.y > 0.0, kind + " HP/shield anchor follows head")
		check(is_equal_approx(entry.root.scale.x, sizes[index] * Motion.BOSS_VISUAL_SCALE), kind + " preserves content display scale")
		var length: float = entry.player.get_animation(entry.clip).length
		check(length > 1.9 and length <= 2.01, kind + " imports full heavy walk")
		var stride: float = Motion.BOSS_STRIDE_TILES * sizes[index] / .79
		runtime.enemies = {str(id): {"id":id,"type":kind,"distanceTravelled":stride * 48.0 * .25,"facingAngle":0.0}}
		motion.observe_native(runtime, 1.0, Vector2i(8, 10))
		units.configure(1.0, Vector2i(8, 10), {})
		units._sync_enemies([data])
		check(is_equal_approx(entry.player.current_animation_position, length * .25), kind + " native distance samples quarter stride")
		var paused := bones(entry)
		data[1] = 4.3
		units._sync_enemies([data])
		check(bones(entry) == paused, kind + " paused bones ignore display interpolation")
		runtime.enemies[str(id)].distanceTravelled = stride * 48.0 * .5
		motion.observe_native(runtime, 1.1, Vector2i(8, 10))
		units.configure(1.1, Vector2i(8, 10), {})
		units._sync_enemies([data])
		check(is_equal_approx(entry.player.current_animation_position, length * .5), kind + " speed/slow follows traveled distance")
		check(bones(entry) != paused, kind + " walk moves bones")
		var facing: float = entry.root.rotation.y
		data[3] = PI / 2.0
		units._sync_enemies([data])
		check(is_equal_approx(entry.root.rotation.y, facing), kind + " turn begins without snap")
		units.configure(1.16, Vector2i(8, 10), {})
		units._sync_enemies([data])
		check(entry.root.rotation.y < facing and entry.root.rotation.y > 0.0, kind + " corner uses combat clock")
		data.append({"teleportSerial":1})
		units._sync_enemies([data])
		var phase: float = entry.player.current_animation_position
		data[14].teleportSerial = 2
		data[3] = PI
		motion.distances[id] += stride * 3.25
		units._sync_enemies([data])
		check(is_equal_approx(entry.player.current_animation_position, phase), kind + " teleport preserves phase")
		check(is_equal_approx(entry.root.rotation.y, -PI/2.0), kind + " teleport snaps correct exit facing")
		# Restore the same live entry, including a lower portal serial. It must
		# sample restored native distance rather than preserve a future gait.
		runtime.enemies[str(id)].distanceTravelled = stride * 48.0 * .1
		data[14].teleportSerial = 0
		motion.observe_native(runtime, .5, Vector2i(8, 10))
		units.configure(.5, Vector2i(8, 10), {})
		units._sync_enemies([data])
		check(is_equal_approx(entry.player.current_animation_position, length * .1), kind + " rewind discards future teleport offset on surviving rig")
		runtime.epoch += 1
		runtime.enemies[str(id)].distanceTravelled = 0.0
		motion.observe_native(runtime, 3.0, Vector2i(8, 10))
		units.configure(3.0, Vector2i(8, 10), {})
		units._sync_enemies([data])
		check(is_equal_approx(entry.player.current_animation_position, 0.0), kind + " epoch reset clears surviving rig motion history")
		data[8] = true; data[9] = true
		units._sync_enemies([data])
		check(entry.burn.visible and entry.frost.visible, kind + " burn and frost coexist")
		check(entry.burn.get_child(0).mesh == load("res://presentation/stage_resources.gd").load_resource(Status.MESHES.boss.EnemyBurn[0]), kind + " aliases share boss status geometry")
		data[8] = false; data[9] = false
		units._sync_enemies([data])
		check(not entry.burn.visible and not entry.frost.visible, kind + " status expires")
		runtime.events = [{"id": index+1, "kind":"kill","enemyId":id,"x":0.0,"y":0.0}]
		motion.observe_native(runtime, 3.1, Vector2i(8, 10))
		check(motion.deaths.has(id), kind + " kill creates its own authored boss corpse")
		if motion.deaths.has(id):
			check(motion.deaths[id].clip == "BossDeath", kind + " death selects its own clip")
		var old_root: Node3D = entry.root
		units._sync_enemies([])
		check(not is_instance_valid(old_root) and not motion.walkers.has(id), kind + " kill/despawn frees living rig and status")
		check(motion.deaths.has(id), kind + " corpse survives living actor removal")
		runtime.epoch += 1
		runtime.events.clear()
		runtime.enemies.clear()
		motion.observe_native(runtime, 0.0, Vector2i(8, 10))
		units.configure(0.0, Vector2i(8, 10), {})
		units._sync_enemies([data])
		check(is_equal_approx(units.enemies[id].player.current_animation_position, 0.0), kind + " new epoch starts at initial gait")
		units.clear()
	world.free()
	print("BOSS_PRESENTATION failures=", failures)
	quit(0 if failures.is_empty() else 1)
