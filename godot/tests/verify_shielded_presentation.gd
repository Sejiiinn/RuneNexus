extends SceneTree
const Units = preload("res://presentation/battlefield_units.gd")
const Rows = preload("res://presentation/frame_rows.gd")
const Native = preload("res://combat/native_combat_runtime.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
const Surface = preload("res://effects/sniper_target_surface.gd")
const Status = preload("res://effects/shielded_status.gd")
const Shielded = preload("res://presentation/shielded_presentation.gd")
# Measured central emissive front-face normal in the adopted mesh coordinates;
# the light anchor's +Z position does not identify this authored surface plane.
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
func poses(entry: Dictionary) -> Array:
	var result := []
	for body: MeshInstance3D in entry.parts: result.append(body.global_transform)
	return result
func same_poses(a: Array, b: Array) -> bool:
	for index in range(a.size()):
		if not a[index].is_equal_approx(b[index]): return false
	return true
func rune_forward(entry: Dictionary) -> Vector3:
	var normal: Vector3 = entry.parts[0].global_basis * RUNE_FRONT_NORMAL
	return Vector3(normal.x, 0.0, normal.z).normalized()
func run() -> void:
	var legacy := Rows.Enemy.from_array([1,3.0,4.0,0,0,.59,0,"shielded"])
	check(not legacy.has_shield and not legacy.has_logical, "legacy row has no shield or logical position")
	legacy.has_shield = true; legacy.shield = 50; legacy.max_shield = 100
	var roundtrip := Rows.Enemy.from_array(legacy.to_array())
	check(roundtrip.has_shield and not roundtrip.has_logical and roundtrip.x == 3.0 and roundtrip.shield == 50, "shield-only extension roundtrip preserves absent logical fields")
	roundtrip.teleport_serial = 3
	var teleported := Rows.Enemy.from_array(roundtrip.to_array())
	check(teleported.teleport_serial == 3 and teleported.shield == 50, "teleport and shield share optional extension")
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera)
	var units := Units.new(world, camera)
	var runtime := Native.new()
	check(runtime.start(1, {"path":[[0.0,0.0],[8.0,0.0]],"tileSize":1.0,"enemies":[
		{"id":1,"type":"shielded","maxHp":100.0,"maxShield":100.0,"shield":100.0,"shieldRegenRate":.04,"presentationScale":.59},
		{"id":2,"type":"shielded","maxHp":100.0,"maxShield":100.0,"shield":50.0,"shieldRegenRate":.04,"presentationScale":.59}]}, {}) == "", "native shield fixture starts")
	units.configure(0.0, Vector2i(8,10), {})
	units._sync_enemies(runtime.decorate_frame({}).enemies)
	var entry: Dictionary = units.enemies[1]
	check(entry.parts.size() == 6 and entry.rune_lights.size() == 2, "six authored meshes and two rune lights load")
	if entry.parts.size() != 6 or entry.player == null:
		units.clear(); world.free(); quit(1); return
	var clip: Animation = entry.player.get_animation("Idle")
	print("SHIELDED_IDLE length=",clip.length," tracks=",clip.get_track_count()," first=",clip.track_get_key_time(0,0))
	check(is_equal_approx(clip.length,24.0), "authored Idle period is exactly 24 seconds")
	check(entry.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "Idle has no engine wall clock")
	check(entry.shield_shell.get_instance_shader_parameter("shield_ratio") == 1.0 and units.enemies[2].shield_shell.get_instance_shader_parameter("shield_ratio") == .5, "two enemies have independent shield opacity")
	check(entry.shield_shell.material_override == units.enemies[2].shield_shell.material_override, "shield material and geometry are shared")
	check(is_equal_approx(entry.root.scale.x,.59*Shielded.VISUAL_SCALE), "shielded display grows 1.5x without changing native scale")
	var shell_triangles: int = entry.shield_shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
	print("SHIELDED_TRIANGLES body=9757 shell=",shell_triangles," total=",9757+shell_triangles)
	check(9757+shell_triangles <= 10000, "original body plus shield shell stays below 10000 triangles")
	for light: OmniLight3D in entry.rune_lights: check(light.light_energy > 0 and is_equal_approx(light.omni_range,.4*Shielded.VISUAL_SCALE) and not light.shadow_enabled, "rune light coverage follows visual size without additional lights")
	var row: Rows.Enemy = runtime.decorate_frame({}).enemies[0]
	var start := poses(entry)
	var authored: Node3D = load(Shielded.MODEL).instantiate(); world.add_child(authored)
	var authored_player: AnimationPlayer = authored.find_child("AnimationPlayer",true,false)
	authored_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	authored_player.play("Idle")
	for time in [1.0, 3.5, 7.0]:
		units.configure(time,Vector2i(8,10),{})
		units._sync_enemies([row])
		var pose := poses(entry)
		var body_axis: Vector3 = (entry.parts[0].global_basis * Shielded.BODY_LONG_AXIS).normalized()
		check(body_axis.dot(Vector3.UP) > .99999, "central body stays upright while the original ring/stones animate "+str(time))
		check((entry.parts[0].global_transform*entry.parts[0].mesh.get_aabb()).position.y > 0.0, "upright body keeps floating clearance "+str(time))
		check(not same_poses(start,pose), "Idle animates on combat clock "+str(time))
		authored_player.seek(time,true)
		Shielded._upright_body(authored.find_child("BodyPivot",true,false))
		for part in range(6):
			var calibrated_local: Transform3D = entry.model.global_transform.affine_inverse() * entry.parts[part].global_transform
			var original: MeshInstance3D = authored.find_child(Shielded.PART_NAMES[part],true,false)
			check(calibrated_local.is_equal_approx(authored.global_transform.affine_inverse()*original.global_transform), "common front calibration preserves original Idle assembly relation "+str(part)+"/"+str(time))
		units._sync_enemies([row])
		check(same_poses(pose,poses(entry)), "pause resampling never accumulates "+str(time))
	units.configure(0.0,Vector2i(8,10),{})
	units._sync_enemies([row])
	check(same_poses(start,poses(entry)), "rewind restores exact body/ring/stone poses")
	authored.free()
	for facing in [0.0, PI / 2.0, PI, -PI / 2.0, .8]:
		row.facing = facing
		for time in [0.0, 3.5, 12.0, 23.9]:
			units.configure(time, Vector2i(8,10), {})
			units._sync_enemies([row])
			check(rune_forward(entry).dot(Vector3(cos(facing),0,sin(facing))) > .99999, "actual front rune faces native travel at heading/time "+str(facing)+"/"+str(time))
	for ratio in [1.0,.5,.05,0.0]:
		runtime.enemies["1"].shield = ratio*100.0
		units._sync_enemies(runtime.decorate_frame({}).enemies)
		check(is_equal_approx(float(entry.shield_shell.get_instance_shader_parameter("shield_ratio")),ratio) and entry.shield_shell.visible == (ratio>0.0), "shield fade tracks actual remaining amount "+str(ratio))
	runtime.enemies["1"].shield = 50.0
	Enemy.step(runtime.enemies["1"],1.0)
	units._sync_enemies(runtime.decorate_frame({}).enemies)
	check(is_equal_approx(float(entry.shield_shell.get_instance_shader_parameter("shield_ratio")),.54), "unbroken shield regeneration is reflected")
	Enemy.apply_hit(runtime.enemies["1"],{"damage":1000.0})
	check(runtime.enemies["1"].shieldBroken, "actual hit breaks shield")
	Enemy.step(runtime.enemies["1"],1.0)
	check(runtime.enemies["1"].shield == 0.0, "broken shield never visually regenerates")
	row.shield = 50; row.max_shield = 100; row.has_shield = true
	row.burning = true; row.slowed = true
	row.x = 4.3; row.y = 5.7; row.scale = .8; row.facing = 1.25
	units.configure(2.25,Vector2i(8,10),{})
	units._sync_enemies([row])
	check((entry.parts[0].global_basis*Shielded.BODY_LONG_AXIS).normalized().dot(Vector3.UP) > .99999, "central upright pose survives native facing and display scale changes")
	check(entry.burn.get_child_count() == 1 and entry.frost.get_child_count() == 2, "moving statuses preserve three shared draw batches")
	var before := poses(entry)
	var skeleton: Skeleton3D = entry.status_skeleton
	for index in range(6):
		check((entry.root.global_transform*skeleton.get_bone_global_pose(index)).is_equal_approx(before[index]), "status skin follows actual moving part without double scale "+str(index))
	var target := Surface.new(entry.root,"shielded")
	target.update_pose(1)
	check(target.pieces.size() == 6, "target geometry excludes shield shell and status meshes")
	check(target.first_hit(target.body_center()+Vector3(0,0,2),target.body_center()).is_finite(), "target ray still hits actual moving body")
	var burn: Node3D = entry.burn
	var frost: Node3D = entry.frost
	row.burning = false; row.slowed = false
	units._sync_enemies([row])
	check(not burn.visible and not frost.visible, "status expiry restores the body")
	row.burning = true; row.slowed = true
	units._sync_enemies([row])
	check(entry.burn == burn and entry.frost == frost, "status reapplication reuses cached batches")
	units._sync_enemies([])
	check(not is_instance_valid(burn) and not is_instance_valid(skeleton), "enemy removal releases all live status nodes")
	units.clear(); world.free()
	Status.retain_stage([],[])
	check(Status._surfaces.is_empty() and Status._meshes.is_empty() and Status._materials.is_empty(), "stage exit releases new status caches")
	directory = OS.get_environment("RUNE_SHIELDED_CAPTURE_DIR")
	if not directory.is_empty() and DisplayServer.get_name() != "headless": await visual_app()
	print("SHIELDED_PRESENTATION checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	for frame in range(2): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label+".png")) == OK,"capture "+label)

func advance_visual_session(runtime, delta: float) -> void:
	var before: float = runtime.effect_time
	runtime.advance_session(delta)
	check(runtime.effect_time > before and is_equal_approx(runtime.clock,runtime.effect_time), "visual fixture advances the official combat and presentation clock together")

func visual_app() -> void:
	var facing_review := "--facing-review" in OS.get_cmdline_user_args()
	var upright_only := facing_review or "--upright-poses" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(440,900)
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
	check(app.retry_load(),"isolated offline app startup")
	app.progression_inputs.unlockedStageIds = [1,10]
	check(await app.start_stage(app.catalog.stage_index(10)),"actual Stage10 app preparation")
	app.hud.start.pressed.emit()
	check(scene.combat_runtime.wave.active,"actual HUD Start spawns compiled wave")
	scene.set_process(false)
	app.set_process(false)
	for step in range(480): advance_visual_session(scene.combat_runtime,1.0/60.0)
	app.command([], {"paused":true})
	var first: Dictionary = {}
	for enemy: Dictionary in scene.combat_runtime.enemies.values():
		if enemy.type == "shielded": first = enemy; break
	check(not first.is_empty(),"real wave produced shielded enemies")
	if first.is_empty(): scene.free(); return
	for ratio in ([1.0] if upright_only else [1.0,.5,.05,0.0]):
		first.shield = first.maxShield*ratio
		scene.apply_frame(scene.combat_base_frame)
		app.hud.refresh()
		await capture("game-shield-%03d" % int(ratio*100))
	app.toggle_camera()
	if scene.camera_transition != null and scene.camera_transition.is_running(): await scene.camera_transition.finished
	scene._session_input.set_zoom(2.5)
	scene.apply_frame(scene.combat_base_frame)
	var target: Node3D = scene.enemies[int(first.id)].root
	var point: Vector2 = scene.camera.unproject_position(target.global_position+Vector3(0,.28,0))
	scene._session_input.pan = ((Vector2(220,310)-point)/Vector2(440,900)).clamp(Vector2(-.75,-.75),Vector2(.75,.75))
	for ratio in ([1.0] if upright_only else [1.0,.5,0.0]):
		first.shield = first.maxShield*ratio
		scene.apply_frame(scene.combat_base_frame)
		await capture("drone-zoom-shield-%03d" % int(ratio*100))
	if not upright_only:
		for light: OmniLight3D in scene.enemies[int(first.id)].rune_lights: light.visible = false
		await capture("drone-rune-lights-off")
		for light: OmniLight3D in scene.enemies[int(first.id)].rune_lights: light.visible = true
		await capture("drone-rune-lights-on")
		Enemy.add_burn(first,{"damagePerSecond":1.0,"duration":2.0})
		Enemy.add_slow(first,.5,2.0)
		scene.apply_frame(scene.combat_base_frame)
		await capture("drone-burn-frost")
		first.burnInstances.clear()
		first.slowInstances.clear()
	if "--still-only" in OS.get_cmdline_user_args(): scene.free(); await process_frame; return
	first.shield = first.maxShield
	app.toggle_camera()
	if scene.camera_transition != null and scene.camera_transition.is_running(): await scene.camera_transition.finished
	scene._session_input.set_zoom(1.8 if upright_only else 1.5)
	scene._session_input.pan = Vector2.ZERO
	app.command([], {"paused":false})
	var motion_trace: Array = []
	var normal_id := -1
	for enemy: Dictionary in scene.combat_runtime.enemies.values():
		if enemy.type == "normal": normal_id = int(enemy.id); break
	var turn_count := 0
	var last_facing := INF
	var last_turn := -INF
	var min_dot := 1.0
	var captured_facings := {}
	var shielded_facings := {}
	var min_shielded_dot := 1.0
	var ring_start: Quaternion = scene.enemies[int(first.id)].parts[1].get_parent().quaternion
	for frame in range(200 if facing_review else (80 if upright_only else 240)):
		if not upright_only and frame < 80 and first.shield > 0.0:
			Enemy.apply_hit(first,{"damage":first.maxShield/80.0 + first.maxShield*first.shieldRegenRate/20.0})
		advance_visual_session(scene.combat_runtime,1.0/20.0)
		scene.apply_frame(scene.combat_base_frame)
		app.hud.refresh()
		await capture("motion-%03d" % frame)
		if facing_review:
			var runtime = scene.combat_runtime
			var normal: Dictionary = runtime.enemies[str(normal_id)]
			var walker: Dictionary = scene.enemies[normal_id]
			var facing: float = normal.facingAngle
			if not is_equal_approx(facing,last_facing):
				if is_finite(last_facing): turn_count += 1
				last_facing = facing; last_turn = runtime.effect_time
			var forward: Vector3 = walker.root.global_basis.z.normalized()
			var dot := forward.dot(Vector3(cos(facing),0,sin(facing)))
			if runtime.effect_time-last_turn >= .16:
				min_dot = minf(min_dot,dot)
				check(dot > .999, "normal completes its corner turn toward actual native travel")
				var facing_key := str(snappedf(facing,.001))
				if not captured_facings.has(facing_key) and captured_facings.size() < 3:
					captured_facings[facing_key] = true
					await capture("normal-direction-%d" % captured_facings.size())
			var shielded: Dictionary = scene.enemies[int(first.id)]
			var spins := []
			for part in range(2,6):
				var q: Quaternion = shielded.parts[part].get_parent().quaternion
				spins.append([q.x,q.y,q.z,q.w])
			check(is_equal_approx(shielded.player.current_animation_position,fposmod(runtime.effect_time,24.0)), "shield Idle samples the same progressing native clock")
			check((shielded.parts[0].global_basis*Shielded.BODY_LONG_AXIS).normalized().dot(Vector3.UP) > .99999,"shielded stays upright during actual movement and yaw")
			var shielded_forward := rune_forward(shielded)
			var shielded_facing: float = first.facingAngle
			var shielded_dot := shielded_forward.dot(Vector3(cos(shielded_facing),0,sin(shielded_facing)))
			min_shielded_dot = minf(min_shielded_dot,shielded_dot)
			shielded_facings[str(snappedf(shielded_facing,.001))] = true
			check(shielded_dot > .99999, "shielded actual front rune faces native travel while moving and turning")
			motion_trace.append({"frame":frame,"clock":runtime.clock,"effectTime":runtime.effect_time,"normalId":normal_id,"normalPosition":[normal.x,normal.y],"normalFacing":facing,"normalYaw":walker.root.rotation.y,"normalForward":[forward.x,forward.y,forward.z],"settled":runtime.effect_time-last_turn>=.16,"forwardDot":dot,"walkPhase":walker.player.current_animation_position,"shieldedId":first.id,"shieldedFacing":shielded_facing,"shieldedForward":[shielded_forward.x,shielded_forward.y,shielded_forward.z],"shieldedForwardDot":shielded_dot,"shieldIdle":shielded.player.current_animation_position,"stoneQuaternions":spins})
	if facing_review:
		check(turn_count >= 2,"actual Stage10 normal passes at least two corners in the final video")
		check(shielded_facings.size() >= 3,"actual Stage10 shielded passes at least two corners in the final video")
		var ring_end: Quaternion = scene.enemies[int(first.id)].parts[1].get_parent().quaternion
		check(absf(ring_start.dot(ring_end)) < .99,"shield ring rotates on the official session clock")
		var record := {"entrypoint":"NativeCombatRuntime.advance_session","turns":turn_count,"shieldedHeadings":shielded_facings.size(),"minimumShieldedForwardDot":min_shielded_dot,"minimumSettledForwardDot":min_dot,"samples":motion_trace}
		var output := FileAccess.open(directory.path_join("facing-trace.json"),FileAccess.WRITE)
		output.store_string(JSON.stringify(record)); output.close()
		print("FACING_REVIEW turns=",turn_count," settledDot=",min_dot," clock=",scene.combat_runtime.clock," effectTime=",scene.combat_runtime.effect_time)
	scene.free()
	await process_frame
