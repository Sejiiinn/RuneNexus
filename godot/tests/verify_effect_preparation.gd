extends SceneTree
## Full prepared project required, as with verify_projectiles/verify_frost_charge.
const Preparation = preload("res://presentation/effect_preparation.gd")
const Resources = preload("res://presentation/stage_resources.gd")
const ALL_ENEMIES := ["normal", "fast", "armored", "shielded", "tank", "boss", "shieldBoss", "forgeBoss"]
const ALL_TOWERS := ["arrow", "cannon", "magic", "frost", "sniper", "lightning"]
const NormalDeath = preload("res://effects/normal_death.gd")
const HoundDeath = preload("res://effects/hound_death.gd")
const TankDeath = preload("res://effects/tank_death.gd")
const BossDeath = preload("res://effects/boss_death.gd")

class CountingMotion extends "res://presentation/guardian_preview.gd":
	var cold_boss_labels := 0
	var cold_tank_labels := 0
	func _prepare_tank_label(entry: Dictionary, model: Node3D) -> void:
		if not _tank_head_bounds_ready: cold_tank_labels += 1
		super._prepare_tank_label(entry, model)
	func _prepare_boss_label(entry: Dictionary, model: Node3D) -> void:
		if not _boss_head_bounds_ready: cold_boss_labels += 1
		super._prepare_boss_label(entry, model)

class InterruptedPreparation extends "res://presentation/effect_preparation.gd":
	var destination: Node3D
	var cancel_generation := false
	var interrupted := false
	func _draw() -> void:
		# Interrupt after the authored boss and its label bounds really exist,
		# before the success handoff. Failed and cancelled rehearsals must not
		# seed the actual presentation, even when they finished this CPU work.
		if not interrupted and get_child_count() > 0:
			for player: AnimationPlayer in get_child(0).find_children("*", "AnimationPlayer", true, false):
				if not player.has_animation("HeavyWalk"): continue
				interrupted = true
				if cancel_generation: destination._stage_preparation_generation += 1
				else: _failed = true
		await super._draw()

var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	select_fixture(scene)
	scene._units._guardian_preview = CountingMotion.new(scene.world)
	scene._units._guardian_preview.failure.connect(scene._units._forward_guardian_failure)
	var motion: CountingMotion = scene._units._guardian_preview
	var before: Dictionary = scene.last_frame.duplicate(true)
	var rng_state: int = scene.combat_runtime.rng.state
	var field: Texture3D = scene.field.texture
	check(await scene.prepare_effects(), "Effect preparation succeeds")
	check(scene.effects_prepared and not scene._effects_preparing, "Readiness follows complete preparation")
	check(scene.last_frame == before and scene.combat_runtime.rng.state == rng_state, "Presentation preparation preserves frame and combat RNG")
	check(scene.field.texture == field, "Large impact field is reused")
	check(motion._boss_head_bounds_ready and motion._boss_scene == null, "Successful rehearsal transfers boss bounds without retaining its scene or rig")
	# The first kill of each species reuses the corpse materials its rehearsal compiled.
	check(not NormalDeath._materials.is_empty() and not HoundDeath._body_materials.is_empty() and HoundDeath._material != null, "Rehearsal prepares normal and hound corpse materials")
	check(not TankDeath._materials.is_empty() and not BossDeath._materials.is_empty() and BossDeath._chip_material != null, "Rehearsal prepares tank and boss corpse materials")
	check(motion.deaths.is_empty() and motion.walkers.is_empty(), "Rehearsed corpses never enter the live death journal")
	var prepared_bounds: AABB = motion._boss_head_bounds
	check(motion._tank_head_bounds_ready and motion._tank_scene == null, "Successful rehearsal transfers tank bounds without retaining its scene or rig")
	var prepared_tank_bounds: AABB = motion._tank_head_bounds
	var prepared_id: int = motion._boss_head_bounds_scene_id
	for kind in ["normal", "fast", "tank", "boss", "shieldBoss", "forgeBoss"]:
		var data := [10,4.0,5.0,0.0,0.0,1.0,0.0,kind,false,false]
		scene._sync_enemies([data])
		if kind in ["boss", "shieldBoss", "forgeBoss"]:
			check(scene.enemies[10].label_bounds == prepared_bounds and motion._boss_head_bounds_scene_id == prepared_id, "First actual boss retains exact prepared bounds: " + kind)
			check(motion.cold_boss_labels == 0, "First actual boss skips vertex/bone bounds traversal: " + kind)
			check(scene.enemies[10].label_skeleton.is_inside_tree(), "Actual boss binds its own live skeleton: " + kind)
		if kind == "tank":
			check(scene.enemies[10].label_bounds == prepared_tank_bounds and motion.cold_tank_labels == 0, "First actual tank retains prepared bounds and skips vertex traversal")
			check(scene.enemies[10].label_skeleton.is_inside_tree(), "Actual tank binds its own live skeleton")
		check(not scene.enemies[10].has("burn") and not scene.enemies[10].has("frost"), "Prepared status resources never attach to an unaffected enemy: " + kind)
		data[8] = true; data[9] = true
		scene._sync_enemies([data])
		check(scene.enemies[10].burn.visible and scene.enemies[10].frost.visible, "First actual status attaches both prepared variants: " + kind)
		data[8] = false; data[9] = false
		scene._sync_enemies([data])
		check(not scene.enemies[10].burn.visible and not scene.enemies[10].frost.visible, "Status expiry leaves no rehearsal residue: " + kind)
		for body: Array in scene.enemies[10].frost_bodies:
			check(body[0].get_surface_override_material(body[1]) == body[2], "Expired frost restores original material: " + kind)
	scene._sync_enemies([])
	# Each rehearsed boss age must actually show the debris that its first kill draws.
	var corpse: Dictionary = motion.rehearse_death("boss")
	var ages: Array = motion.rehearsal_ages("boss")
	var shown := []
	for age: float in ages:
		motion.sample_death(corpse, age)
		shown.append(corpse.death_chips.any(func(chip): return chip.mesh.visible) and corpse.death_puffs.any(func(puff): return puff.mesh.visible))
	check(shown.count(true) == 1 and not shown[0], "Boss rehearsal includes one chip and dust age after the opening body")
	corpse.root.free()
	check(motion.deaths.is_empty(), "Boss rehearsal probe leaves no live death")
	var renderer = scene._projectile_renderer
	check(renderer._ballistic_pool.cannon.size() == 2 and renderer._fire_projectile_pool.size() == 2 and renderer.impact_pool.size() == 2, "Only two instances per prepared pool")
	var cannon = renderer._ballistic_pool.cannon.back()
	var fire = renderer._fire_projectile_pool.back()
	var impact = renderer.impact_pool.back()
	check(renderer.sniper_blast_pool.size() == 1 and not renderer.sniper_blast_pool[0].visible, "Explosion sniper blast is prepared once and hidden")
	var sniper_blast = renderer.sniper_blast_pool.back()
	check(await scene.prepare_effects(), "Repeated readiness request is idempotent")
	check(renderer._ballistic_pool.cannon.back() == cannon, "Repeated preparation preserves ready instances")
	scene._clear_scene()
	check(motion._boss_head_bounds_ready and motion._boss_head_bounds == prepared_bounds, "Epoch reset preserves prepared immutable boss bounds")
	check(renderer._ballistic_pool.cannon.back() == cannon and renderer._fire_projectile_pool.back() == fire and renderer.impact_pool.back() == impact, "Epoch reset preserves bounded reserve")
	check(not cannon.visible and not fire.visible and not impact.visible, "Ready effects stay invisible")
	for emitter in fire._particles:
		check(not emitter.visible and not emitter.emitting and fire._particle_tails[emitter] == 0.0, "No warmup particle tail survives")
	scene.last_frame.time = 0.0
	scene._sync_projectiles([[20,3.7,5.0,1.0,0.0,"cannon",3.0,5.0,null,1,false,-1.0,null,null], [21,4.7,5.0,1.0,0.0,"magic",4.0,5.0,null,1,false,-1.0,null,null]])
	scene._update_impacts([[30,3.0,5.0,.8,.05],[33,5.0,5.0,.9,.05,"sniperEnergy"]])
	check(scene.projectiles[20].root == cannon and scene.projectiles[21].root == fire and scene.impacts[30] == impact and scene.impacts[33] == sniper_blast, "First real effects consume prepared instances")
	check(cannon.initialized and fire._last_time == 0.0, "First shot starts on real combat clock")
	scene._clear_scene()
	check(scene.projectiles.is_empty() and scene.impacts.is_empty(), "Reset clears all gameplay identities")
	check(renderer._ballistic_pool.cannon.size() == 2 and renderer._fire_projectile_pool.size() == 2 and renderer.impact_pool.size() == 2 and renderer.sniper_blast_pool == [sniper_blast], "Active first effects return to bounded reserve")
	for light in renderer.impact_lights: check(light.light_energy == 0.0, "Reset clears impact lights")
	renderer.clear()
	check(renderer._ballistic_pool.cannon.is_empty() and renderer._fire_projectile_pool.is_empty() and renderer.impact_pool.is_empty() and renderer.sniper_blast_pool.is_empty(), "Full teardown still releases all effects")
	for cancel_generation: bool in [false, true]:
		scene._units.retain_stage([])
		var interrupted := InterruptedPreparation.new()
		interrupted.destination = scene
		interrupted.cancel_generation = cancel_generation
		scene.add_child(interrupted)
		check(not await interrupted.prepare(scene, {"enemy_types": ["boss"], "tower_types": []}), "Rehearsal aborts after boss bounds calculation, cancellation=" + str(cancel_generation))
		check(interrupted.interrupted and interrupted.get_child_count() == 0, "Aborted boss rehearsal releases its realized viewport")
		check(not motion._boss_head_bounds_ready and motion._boss_head_bounds_scene_id == 0, "Aborted boss rehearsal cannot transfer computed bounds")
		interrupted.free()
	scene.free()
	var cancelled = load("res://main.tscn").instantiate()
	root.add_child(cancelled)
	cancelled.set_process(false)
	select_fixture(cancelled)
	var cancelled_ref: WeakRef = weakref(cancelled)
	cancelled.prepare_effects()
	cancelled.queue_free()
	await process_frame
	await process_frame
	check(cancelled_ref.get_ref() == null, "Cancelling preparation releases its game and viewport")
	var retry = load("res://main.tscn").instantiate()
	root.add_child(retry)
	retry.set_process(false)
	select_fixture(retry)
	var outcomes: Array = []
	prepare_again(retry, outcomes)
	prepare_again(retry, outcomes)
	await retry.effects_preparation_finished
	await process_frame
	check(outcomes == [true, true] and retry.impact_pool.size() == 2, "Concurrent readiness requests share one preparation after cancellation")
	retry.free()
	print("EFFECT_PREPARATION failures=", failures)
	quit(0 if failures.is_empty() else 1)

func prepare_again(scene, outcomes: Array) -> void:
	outcomes.append(await scene.prepare_effects())


func select_fixture(scene) -> void:
	# This fixture deliberately exercises every species/weapon. App stages pass
	# their own selected manifest instead of globally warming this full list.
	scene._stage_manifest = {"enemy_types": ALL_ENEMIES.duplicate(), "tower_types": ALL_TOWERS.duplicate()}
	check(Resources.prepare(Preparation.resource_paths(ALL_ENEMIES, ALL_TOWERS)), "Fixture resources resolve")
	check(scene._projectile_renderer.configure_stage(ALL_TOWERS), "Fixture cannon field prepares")
