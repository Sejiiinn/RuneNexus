extends SceneTree
## Full imported project required. Verifies CPU geometry readiness and contact
## equivalence only; headless checks do not measure GPU time or gameplay FPS.
const Preparation = preload("res://presentation/effect_preparation.gd")
const Resources = preload("res://presentation/stage_resources.gd")
const Projectiles = preload("res://presentation/battlefield_projectiles.gd")
const Units = preload("res://presentation/battlefield_units.gd")
const Lightning = preload("res://presentation/lightning_presentation.gd")
const Surface = preload("res://effects/sniper_target_surface.gd")
const Manifest = preload("res://presentation/stage_manifest.gd")
const Catalog = preload("res://content/content_catalog.gd")
const GuardianStatus = preload("res://effects/guardian_status.gd")
const ALL_ENEMIES := ["normal", "fast", "armored", "shielded", "tank", "boss", "shieldBoss", "forgeBoss"]
const CONTACT_WEAPONS := ["sniper", "lightning"]
const EPSILON := 0.00001

class Battle extends Node3D:
	var _world_environment := Environment.new()
	var sun := DirectionalLight3D.new()
	var camera := Camera3D.new()
	var world := Node3D.new()
	var _projectile_renderer
	var _stage_manifest := {}
	var _stage_preparation_generation := 0
	var last_frame := {"time": 0.0}
	var units
	var lightning
	var field: Dictionary:
		get: return _projectile_renderer.field
	func _ready() -> void:
		add_child(world)
		add_child(camera)
		add_child(sun)
		_projectile_renderer = Projectiles.new(world, camera)
		units = Units.new(world, camera)
		lightning = Lightning.new(world)

var scene: Battle
var failures: Array[String] = []
var checks := 0
var preparation_refs: Array[WeakRef] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func select(enemies: Array, weapons: Array) -> void:
	scene.units.clear()
	scene.units.retain_stage(enemies)
	scene.lightning.clear()
	var paths := Preparation.resource_paths(enemies, weapons)
	for kind: String in enemies:
		paths.append(Units.ENEMY_MODELS[kind])
		if kind in ["normal", "fast", "tank"]:
			paths.append("res://assets/enemies/%s_death.glb" % kind)
	for kind: String in weapons:
		paths.append(Units.TURRET_MODELS[kind])
	check(Resources.prepare(paths), "selected resource paths resolve")
	scene._stage_preparation_generation += 1
	scene._stage_manifest = {"enemy_types": enemies, "tower_types": weapons}
	check(scene._projectile_renderer.configure_stage(weapons), "selected projectile families configure")
	Preparation.retain_stage(enemies, weapons)
	Resources.retain(paths, "target-geometry-regression")

func prepare() -> bool:
	var preparation := Preparation.new()
	scene.add_child(preparation)
	preparation_refs.append(weakref(preparation))
	var result: bool = await preparation.prepare(scene, scene._stage_manifest)
	check(preparation.get_child_count() == 0, "finished rehearsal releases its viewport")
	preparation.free()
	return result

func prepare_into(outcomes: Array) -> void:
	outcomes.append(await prepare())

func same_point(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < EPSILON if a.is_finite() and b.is_finite() else a == b

func contacts(kind: String) -> Array:
	# Both endpoints are produced by the actual presentation entry points. Moving,
	# turning and scaling these actors also samples several authored skeletal poses.
	scene.units.clear()
	scene.lightning.clear()
	var samples: Array = []
	for pose in 3:
		var time := float(pose) * .23
		var x := 5.0 + float(pose) * .13
		var y := 4.0 + float(pose) * .09
		scene.units.configure(time, Vector2i(8, 10), {"volume": false})
		scene.units._sync_enemies([[91, x, y, float(pose) * .41, float(pose), .7 + float(pose) * .12, 0.0, kind, false, false]])
		scene.units._sync_turrets([
			[71, 2.5, 3.5, 0.0, 0, 0.0, "sniper", 1, {"aimActive": true, "aimTargetId": 91, "aimRatio": .5}],
			[72, 2.5, 4.5, 0.0, 0, 0.0, "lightning", 1],
		])
		scene.units.sync_sniper_aim()
		var target: Dictionary = scene.units.enemies[91]
		var sniper = scene.units.turrets[71].sniper_effect
		check(target.has("sniper_surface"), "%s pose %d reaches actual sniper surface path" % [kind, pose])
		var sniper_point: Vector3 = sniper.line_end if sniper.line.visible else Vector3.INF
		scene.lightning.present([{
			"id": 300, "kind": "chain", "turretType": "lightning", "ownerId": 72,
			"sourceTargetId": -1, "targetIds": [91], "points": [[2.5, 4.5], [x, y]],
			"age": .05, "duration": .28,
		}], scene.units.turrets, scene.units.enemies, Vector2(8, 10), true, false)
		check(target.has("lightning_surface") and scene.lightning.active.has(300), "%s pose %d reaches actual lightning contact path" % [kind, pose])
		var lightning_point: Vector3 = scene.lightning.active[300]._impact.global_position
		check(lightning_point.is_finite(), "%s pose %d lightning contact is finite" % [kind, pose])
		var surface = target.sniper_surface
		var rays: Array = []
		for offset: Vector3 in [Vector3(3, 1.2, 0), Vector3(-2, .8, 2), Vector3(0, 3, -2)]:
			rays.append(surface.first_hit(surface.body_center() + offset, surface.body_center()))
		samples.append([sniper_point, lightning_point, surface.aim_point(), surface.head_center(), surface.body_center()] + rays)
	check(samples.any(func(sample): return sample[0].is_finite()), kind + " includes a real sniper surface contact")
	scene.units.clear()
	scene.lightning.clear()
	return samples

func compare_contacts(cold: Array, warm: Array, kind: String) -> void:
	check(cold.size() == warm.size(), kind + " keeps all sampled poses")
	for pose in cold.size():
		for sample in cold[pose].size():
			check(same_point(cold[pose][sample], warm[pose][sample]), "%s pose %d sample %d cold/warm contact equivalence" % [kind, pose, sample])

func synthetic_fallback() -> void:
	Surface.retain_stage([], [])
	var holder := Node3D.new()
	var mesh := BoxMesh.new()
	var source_ref: WeakRef = weakref(mesh)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	holder.add_child(instance)
	scene.world.add_child(holder)
	var holder_ref: WeakRef = weakref(holder)
	var before: int = Surface.cache_snapshot().builds
	var unexpected = Surface.new(holder, "unexpected-model")
	unexpected.update_pose(1)
	check(Surface.cache_snapshot().builds == before + 1, "unexpected runtime model safely builds on demand")
	check(unexpected.first_hit(Vector3(0, 0, 3), Vector3.ZERO).is_finite(), "unexpected model still provides a real surface hit")
	Surface.prewarm(holder, "another-family")
	check(Surface.cache_snapshot().builds == before + 1, "shared mesh identity reuses its geometry across families")
	Surface.retain_stage(["unexpected-model"], ["sniper"])
	check(Surface.cache_snapshot().count == 1, "retaining one owner preserves a cross-family shared mesh")
	unexpected = null
	holder.free()
	instance = null
	mesh = null
	check(holder_ref.get_ref() == null, "static geometry never pins rehearsal nodes")
	check(source_ref.get_ref() != null, "cached invariant data retains source identity safely")
	Surface.retain_stage([], [])
	check(source_ref.get_ref() == null and Surface.cache_snapshot().count == 0, "eviction releases the last source and its acceleration cache")

func skin_interpretations() -> void:
	var holder := Node3D.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	skeleton.add_bone("head")
	holder.add_child(skeleton)
	var skin := Skin.new()
	skin.add_bind(0, Transform3D.IDENTITY)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(0, 1, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for skinned: bool in [false, true]:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.skeleton = NodePath("../Skeleton")
		if skinned: instance.skin = skin
		holder.add_child(instance)
	scene.world.add_child(holder)
	var before: int = Surface.cache_snapshot().builds
	Surface.prewarm(holder, "interpretations")
	check(Surface.cache_snapshot().builds == before + 2, "same mesh with and without a skin has separate invariant keys")
	var surface = Surface.new(holder, "interpretations")
	check(surface.pieces.size() == 2 and int(surface.pieces[0].bind) == -1 and int(surface.pieces[1].bind) == 0, "warm runtime bindings preserve rigid and skinned interpretations")
	check(Surface.cache_snapshot().builds == before + 2, "runtime reuses both prewarmed interpretations")
	surface = null
	holder.free()
	Surface.retain_stage([], [])

func catalog_manifests() -> void:
	var catalog := Catalog.new()
	check(catalog.load_catalog(), "full production catalog loads")
	if not catalog.is_loaded(): return
	var catalog_kinds := catalog.enemy_types()
	catalog_kinds.sort()
	var tested_kinds := ALL_ENEMIES.duplicate()
	tested_kinds.sort()
	check(catalog_kinds == tested_kinds, "geometry regression covers every catalog enemy kind")
	var waves := 0
	for index in catalog.stage_count():
		# Expanded queues are independent of Manifest's wave_summary traversal.
		var expected := {}
		for wave: Dictionary in catalog.stage(index).waves:
			waves += 1
			for spawn: Dictionary in wave.spawnQueue:
				expected[spawn.enemyType] = true
		var kinds := expected.keys()
		kinds.sort()
		var manifest := Manifest.for_stage(catalog, index,
			{"availableTurretTypes": ["arrow"]}, {"turrets": [{"type": "sniper"}, {"type": "lightning"}]})
		check(manifest.enemy_types == kinds, "stage %d manifest includes the complete spawn roster" % catalog.stage_id(index))
		check(manifest.tower_types == ["arrow", "lightning", "sniper"], "stage %d restored contact weapons remain eligible" % catalog.stage_id(index))
	print("TARGET_GEOMETRY_MANIFEST stages=", catalog.stage_count(), " waves=", waves, " enemy_kinds=", catalog_kinds.size())

func status_transition() -> void:
	select(["normal"], ["magic", "frost", "lightning"])
	check(await prepare(), "mixed-status contact stage prepares")
	var with_status := Surface.cache_snapshot()
	check(with_status.count == 4, "normal body and three authored status meshes are prewarmed")
	var status_refs: Array[WeakRef] = []
	for label: String in ["EnemyBurn", "EnemyFrost"]:
		for path: String in GuardianStatus.MESHES.normal[label]:
			status_refs.append(weakref(Resources.load_resource(path)))
	scene.units.configure(0.0, Vector2i(8, 10), {"volume": false, "burn_effects": true})
	scene.units._sync_enemies([[91, 5.0, 4.0, 0.0, 0.0, .7, 0.0, "normal", true, true]])
	scene.units._sync_turrets([[72, 2.5, 4.5, 0.0, 0, 0.0, "lightning", 1]])
	scene.lightning.present([{
		"id": 300, "kind": "chain", "turretType": "lightning", "ownerId": 72,
		"targetIds": [91], "points": [[2.5, 4.5], [5.0, 4.0]], "age": .05, "duration": .28,
	}], scene.units.turrets, scene.units.enemies, Vector2(8, 10), true, false)
	check(scene.units.enemies[91].has("lightning_surface") and scene.lightning.active.has(300), "first burning/frosted enemy reaches actual contact path")
	check(Surface.cache_snapshot() == with_status, "first status-bearing contact builds zero geometry")
	select(["normal"], ["lightning"])
	var body_only := Surface.cache_snapshot()
	check(body_only.count == 1 and body_only.builds == with_status.builds, "weapon transition keeps the body and evicts status-only geometry")
	check(status_refs.all(func(reference): return reference.get_ref() == null), "removed status weapons release all three cached status mesh sources")
	check(await prepare(), "retained body-only contact stage prepares")
	check(Surface.cache_snapshot() == body_only, "retained body identity needs no geometry rebuild")
	select([], [])

func cancellation_and_error() -> void:
	select(ALL_ENEMIES, ["sniper"])
	Surface.retain_stage([], [])
	var outcomes: Array = []
	prepare_into(outcomes)
	# Cancel after one family was really warmed, rather than before any work.
	for frame in 120:
		if Surface.cache_snapshot().count > 0 or not outcomes.is_empty(): break
		await process_frame
	check(Surface.cache_snapshot().count > 0 and outcomes.is_empty(), "cancellation fixture reaches a partially warmed rehearsal")
	select(["armored"], ["arrow"])
	for frame in 120:
		if not outcomes.is_empty(): break
		await process_frame
	check(outcomes == [false], "generation switch cancels partially warmed preparation")
	check(Surface.cache_snapshot().count == 0, "cancelled old generation cannot re-add geometry to an ineligible stage")
	check(await prepare(), "preparation can retry successfully after cancellation")
	check(Surface.cache_snapshot().count == 0, "ineligible retry stays geometrically cold")
	# Existing explicit error exit: cannon requires the stage-owned field.
	scene._stage_preparation_generation += 1
	scene._stage_manifest = {"enemy_types": ["armored"], "tower_types": ["cannon", "sniper"]}
	check(not await prepare(), "missing cannon field fails preparation cleanly")
	check(Surface.cache_snapshot().count == 0, "error exit adds no target geometry")
	check(preparation_refs.all(func(reference): return reference.get_ref() == null), "success, cancellation and error release all preparation owners")

func run() -> void:
	check(Surface.cache_snapshot().count == 0, "loading scripts leaves target geometry cold")
	scene = Battle.new()
	root.add_child(scene)
	catalog_manifests()
	select(ALL_ENEMIES, ["arrow"])
	var before: int = Surface.cache_snapshot().builds
	check(await prepare(), "weapon-ineligible all-enemy stage prepares")
	check(Surface.cache_snapshot().count == 0 and Surface.cache_snapshot().builds == before, "arrow-only loading constructs no target geometry")
	select(ALL_ENEMIES, CONTACT_WEAPONS)
	var cold := {}
	var cold_contact_usec := 0
	for kind: String in ALL_ENEMIES:
		var started := Time.get_ticks_usec()
		cold[kind] = contacts(kind)
		cold_contact_usec += Time.get_ticks_usec() - started
	var all_count: int = Surface.cache_snapshot().count
	check(all_count > 0, "cold runtime path builds real imported geometry")
	Surface.retain_stage([], [])
	before = Surface.cache_snapshot().builds
	var frame_before := scene.last_frame.duplicate(true)
	check(await prepare(), "all-enemy selected target geometry prepares")
	var prepared := Surface.cache_snapshot()
	check(prepared.count == all_count and prepared.builds - before == all_count, "loading builds each distinct runtime invariant exactly once")
	check(scene.last_frame == frame_before, "target warmup preserves the presentation snapshot")
	var warm_contact_usec := 0
	for kind: String in ALL_ENEMIES:
		var started := Time.get_ticks_usec()
		var warm := contacts(kind)
		warm_contact_usec += Time.get_ticks_usec() - started
		check(Surface.cache_snapshot().builds == prepared.builds, kind + " first actual sniper/lightning contacts build zero geometry")
		compare_contacts(cold[kind], warm, kind)
	print("TARGET_GEOMETRY_PREPARATION invariant_entries=", all_count, " warm_first_contact_builds=", Surface.cache_snapshot().builds - prepared.builds, " kinds=", ALL_ENEMIES.size(), " poses_per_kind=3")
	# One diagnostic sample includes actor/VFX construction and contact work;
	# correctness is asserted by build counts/equivalence, never timing ratios.
	print("TARGET_GEOMETRY_CPU_SAMPLE actor_and_contact_cold_usec=", cold_contact_usec, " actor_and_contact_warm_usec=", warm_contact_usec, " gpu_and_fps_unmeasured=true")
	check(await prepare(), "same stage prepares repeatedly")
	check(Surface.cache_snapshot() == prepared, "repeat preparation reuses bounded invariant cache")
	select(["normal", "shieldBoss"], ["lightning"])
	var overlap := Surface.cache_snapshot()
	check(overlap.count > 0 and overlap.count < all_count, "overlapping stage evicts nonselected enemy geometry")
	check(await prepare(), "lightning-only overlapping stage prepares")
	check(Surface.cache_snapshot() == overlap, "overlap and boss alias preserve warm source identity")
	select(["forgeBoss"], ["sniper"])
	var boss_only := Surface.cache_snapshot()
	check(boss_only.count > 0 and boss_only.count < overlap.count, "boss alias retains only its shared family")
	check(await prepare(), "sniper-only alias stage prepares")
	check(Surface.cache_snapshot() == boss_only, "sniper-only stage reuses the same boss geometry")
	select(["fast"], ["lightning"])
	check(Surface.cache_snapshot().count == 0, "new nonoverlapping family evicts old geometry")
	before = Surface.cache_snapshot().builds
	check(await prepare(), "new family prepares after eviction")
	check(Surface.cache_snapshot().count > 0 and Surface.cache_snapshot().builds > before, "new family builds during loading")
	select(["fast"], ["arrow"])
	check(Surface.cache_snapshot().count == 0, "weapon-ineligible stage releases even overlapping enemy geometry")
	synthetic_fallback()
	skin_interpretations()
	await status_transition()
	await cancellation_and_error()
	scene.units.clear()
	scene.units.retain_stage([])
	scene.lightning.clear()
	scene._projectile_renderer.clear()
	scene.free()
	Preparation.retain_stage([], [])
	Resources.clear()
	check(Surface.cache_snapshot().count == 0, "final teardown is bounded to zero cache entries")
	print("TARGET_GEOMETRY_PREPARATION checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
