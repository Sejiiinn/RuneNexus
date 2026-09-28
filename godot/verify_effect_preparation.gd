extends SceneTree
## Full prepared project required, as with verify_projectiles/verify_frost_charge.
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var before: Dictionary = scene.last_frame.duplicate(true)
	var rng_state: int = scene._native_combat.rng.state
	var field: Texture3D = scene.field.texture
	check(await scene.prepare_effects(), "Effect preparation succeeds")
	check(scene.effects_prepared and not scene._effects_preparing, "Readiness follows complete preparation")
	check(scene.last_frame == before and scene._native_combat.rng.state == rng_state, "Presentation preparation preserves frame and combat RNG")
	check(scene.field.texture == field, "Large impact field is reused")
	for kind in ["normal", "fast", "tank"]:
		var data := [10,4.0,5.0,0.0,0.0,1.0,0.0,kind,false,false]
		scene._sync_enemies([data])
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
	var renderer = scene._projectile_renderer
	check(renderer._ballistic_pool.cannon.size() == 2 and renderer._fire_projectile_pool.size() == 2 and renderer.impact_pool.size() == 2, "Only two instances per prepared pool")
	var cannon = renderer._ballistic_pool.cannon.back()
	var fire = renderer._fire_projectile_pool.back()
	var impact = renderer.impact_pool.back()
	check(await scene.prepare_effects(), "Repeated readiness request is idempotent")
	check(renderer._ballistic_pool.cannon.back() == cannon, "Repeated preparation preserves ready instances")
	scene._clear_scene()
	check(renderer._ballistic_pool.cannon.back() == cannon and renderer._fire_projectile_pool.back() == fire and renderer.impact_pool.back() == impact, "Epoch reset preserves bounded reserve")
	check(not cannon.visible and not fire.visible and not impact.visible, "Ready effects stay invisible")
	for emitter in fire._particles:
		check(not emitter.visible and not emitter.emitting and fire._particle_tails[emitter] == 0.0, "No warmup particle tail survives")
	scene.last_frame.time = 0.0
	scene._sync_projectiles([[20,3.7,5.0,1.0,0.0,"cannon",3.0,5.0,null,1,false,-1.0,null,null], [21,4.7,5.0,1.0,0.0,"magic",4.0,5.0,null,1,false,-1.0,null,null]])
	scene._update_impacts([[30,3.0,5.0,.8,.05]])
	check(scene.projectiles[20].root == cannon and scene.projectiles[21].root == fire and scene.impacts[30] == impact, "First real effects consume prepared instances")
	check(cannon.initialized and fire._last_time == 0.0, "First shot starts on real combat clock")
	scene._clear_scene()
	check(scene.projectiles.is_empty() and scene.impacts.is_empty(), "Reset clears all gameplay identities")
	check(renderer._ballistic_pool.cannon.size() == 2 and renderer._fire_projectile_pool.size() == 2 and renderer.impact_pool.size() == 2, "Active first effects return to bounded reserve")
	for light in renderer.impact_lights: check(light.light_energy == 0.0, "Reset clears impact lights")
	renderer.clear()
	check(renderer._ballistic_pool.cannon.is_empty() and renderer._fire_projectile_pool.is_empty() and renderer.impact_pool.is_empty(), "Full teardown still releases all effects")
	scene.free()
	var cancelled = load("res://main.tscn").instantiate()
	root.add_child(cancelled)
	cancelled.set_process(false)
	var cancelled_ref: WeakRef = weakref(cancelled)
	cancelled.prepare_effects()
	cancelled.queue_free()
	await process_frame
	await process_frame
	check(cancelled_ref.get_ref() == null, "Cancelling preparation releases its game and viewport")
	var retry = load("res://main.tscn").instantiate()
	root.add_child(retry)
	retry.set_process(false)
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
