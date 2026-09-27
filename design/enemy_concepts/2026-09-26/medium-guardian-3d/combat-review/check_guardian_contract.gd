extends SceneTree
## Focused shipping presentation checks against the actual native runtime and GLBs.
const Units = preload("res://presentation/battlefield_units.gd")
const Native = preload("res://combat/native_combat_runtime.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
var failures: Array[String] = []
var checks := 0
var world: Node3D
var camera: Camera3D
var runtime
var units

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ", label)

func sync() -> void:
	units.configure(runtime.effect_time, Vector2i(8,10), {"volume":true})
	units.sync_guardian_events(runtime)
	units._sync_enemies(runtime.decorate_frame({}).enemies)

func pose() -> float:
	return units.enemies[1].player.current_animation_position

func run() -> void:
	world = Node3D.new()
	camera = Camera3D.new()
	root.add_child(world)
	root.add_child(camera)
	var default_units = Units.new(world,camera)
	default_units.configure(0.0,Vector2i(8,10),{"volume":true})
	default_units._sync_enemies([[1,1.5,1.5,0.0,0.0,0.55,0.0,"normal",false,false]])
	check(default_units.enemies[1].get("guardian_preview",false),"default normal uses approved guardian")
	check(default_units._guardian_preview._attempted,"default loads shipping assets")
	var default_weak: WeakRef = weakref(default_units)
	default_units.clear()
	default_units = null
	check(default_weak.get_ref() == null,"default Units RefCounted releases")
	runtime = Native.new()
	runtime.process_command({"epoch":1,"sequence":0,"bootstrap":{"tileSize":48.0,"path":[[0,0],[480,0]],"enemies":[{"id":1,"type":"normal","maxHp":100,"speed":31.5,"presentationScale":0.55}]},"session":{"clock":"godot","phase":"wave","running":true,"speed":1.0}})
	units = Units.new(world,camera)
	sync()
	check(units.enemies[1].get("guardian_preview",false),"native normal uses guardian without opt-in")
	check(is_zero_approx(pose()),"walk starts at distance zero")
	runtime.advance_session(26.0/120.0)
	sync()
	check(abs(pose()-26.0/120.0)<0.00001,"half stride samples half cycle")
	var status_frame: Array = runtime.decorate_frame({}).enemies
	status_frame[0][8] = true
	status_frame[0][9] = true
	units._sync_enemies(status_frame)
	var status_entry: Dictionary = units.enemies[1]
	check(status_entry.burn.visible and status_entry.frost.visible, "guardian shows burn and frost together")
	check(status_entry.frost_bodies.size() == 1 and status_entry.frost_bodies[0][0].skin != null, "frost coat preserves authored skinned mesh")
	check(status_entry.frost.get_child_count() == 2 and status_entry.burn.get_child_count() == 1, "statuses retain three draw groups")
	var body_skin: Skin = status_entry.frost_bodies[0][0].skin
	for effect in status_entry.frost.get_children() + status_entry.burn.get_children():
		check(effect is MeshInstance3D and effect.skin == body_skin and effect.mesh.get_surface_count() == 1, "merged effect shares authored skin and one surface")
	check(status_entry.burn.get_child(0).mesh.surface_get_array_len(0) == 52*4, "all 52 burn particles preserved in merged mesh")
	var burn_arrays: Array = status_entry.burn.get_child(0).mesh.surface_get_arrays(0)
	var rows_seen := {}
	var anchors_seen := {}
	for index in range(0, burn_arrays[Mesh.ARRAY_VERTEX].size(), 4):
		rows_seen[roundi(burn_arrays[Mesh.ARRAY_CUSTOM0][index*4])] = true
		anchors_seen[burn_arrays[Mesh.ARRAY_VERTEX][index]] = true
	check(rows_seen.size() == 52 and rows_seen.has(0) and rows_seen.has(51), "burn retains all 52 distinct source particle rows")
	check(anchors_seen.size() == 52, "burn has 52 distinct baked surface anchors")
	var shard_arrays: Array = status_entry.frost.get_child(0).mesh.surface_get_arrays(0)
	var variants_seen := {}
	for index in range(shard_arrays[Mesh.ARRAY_VERTEX].size()):
		variants_seen[roundi(shard_arrays[Mesh.ARRAY_CUSTOM0][index*4])] = true
	check(variants_seen.size() == 40 and variants_seen.has(39), "all 40 crystal source variants survive offline merge")
	sync()
	check(not status_entry.burn.visible and not status_entry.frost.visible, "cleared combat status hides both effects")
	var before := pose()
	var previous_time: float = runtime.effect_time
	runtime.session.paused = true
	runtime.advance_session(1.0)
	sync()
	check(is_equal_approx(pose(),before) and runtime.effect_time==previous_time,"pause freezes movement and pose")
	runtime.session.paused = false
	runtime.session.speed = 4.0
	runtime.advance_session(26.0/480.0)
	sync()
	check(abs(float(runtime.enemies["1"].distanceTravelled)/48.0-0.284375)<0.00001,"4x reaches exactly one authored stride")
	check(minf(abs(pose()),abs(pose()-26.0/60.0))<0.00001,"one stride wraps walk cycle")
	runtime.session.speed = 1.0
	Enemy.add_slow(runtime.enemies["1"],0.5,2.0)
	runtime.advance_session(0.1)
	sync()
	check(abs(pose()-0.05)<0.00001,"slow scales pose by actual movement")
	check(is_zero_approx(units.enemies[1].root.position.y),"walk has no sine hover")
	var turn_entry: Dictionary = units.enemies[1]
	var turn_helper = units._guardian_preview
	turn_helper.update_facing(turn_entry, 0.0, runtime.effect_time)
	turn_helper.update_facing(turn_entry, 0.0, runtime.effect_time + 0.06)
	var dying_direction: float = turn_entry.root.rotation.y
	check(abs(dying_direction-PI/8.0)<0.00001, "quarter turn eases 75 percent by 0.06 combat seconds")
	var hit: Dictionary = Enemy.apply_hit(runtime.enemies["1"],{"damage":1000.0})
	runtime._collect(hit.events)
	sync()
	var helper = units._guardian_preview
	check(helper.deaths.size()==1 and units.enemies.is_empty(),"actual native kill swaps walk for death")
	var death: Dictionary = helper.deaths[1]
	var death_id: int = death.root.get_instance_id()
	check(abs(death.root.scale.x-0.55)<0.00001,"death retains presentation scale")
	check(abs(death.root.get_child(0).position.y+0.008475561626)<0.000001,"death normalized floor offset is corrected")
	check(abs(death.root.rotation.y-dying_direction)<0.00001,"death retains visible body direction during turn")
	check(abs(death.root.position.x-(float(runtime.enemies["1"].x)/48.0-4.0))<0.00001,"death stays at kill position")
	sync()
	check(helper.deaths.size()==1 and helper.deaths[1].root.get_instance_id()==death_id,"retained journal does not duplicate corpse")
	runtime._emit({"kind":"kill","enemyId":1,"x":runtime.enemies["1"].x,"y":0.0})
	sync()
	check(helper.deaths.size()==1 and helper.deaths[1].root.get_instance_id()==death_id,"duplicate enemy kill ID does not restart corpse")
	runtime.session.paused = true
	runtime.advance_session(1.0)
	sync()
	check(is_zero_approx(death.player.current_animation_position),"pause freezes death animation")
	runtime.session.paused = false
	runtime.session.speed = 4.0
	runtime.advance_session(0.1)
	sync()
	check(abs(death.player.current_animation_position-0.4)<0.00001,"4x advances death by simulation time")
	runtime.advance_session(0.051)
	sync()
	check(helper.deaths.is_empty(),"death removed after 0.6 simulation seconds")
	runtime._emit({"kind":"arrival","enemyId":2,"x":480.0,"y":0.0})
	sync()
	check(helper.deaths.is_empty(),"core arrival never creates a corpse")
	turn_helper = null
	turn_entry.clear()
	status_entry.clear()
	var units_weak: WeakRef = weakref(units)
	var helper_weak: WeakRef = weakref(helper)
	units.clear()
	check(helper.deaths.is_empty() and helper.distances.is_empty() and helper._killed_ids.is_empty(),"clear removes presentation state")
	death.clear()
	helper = null
	units = null
	check(units_weak.get_ref()==null and helper_weak.get_ref()==null,"Units and helper release without signal-reference cycles")
	runtime = null
	world.queue_free()
	camera.queue_free()
	for i in range(3): await process_frame
	var report := {"checks":checks,"failures":failures,"result":"PASS" if failures.is_empty() else "FAIL"}
	print("GUARDIAN_CONTRACT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
