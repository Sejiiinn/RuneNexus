extends SceneTree
const Fixture = preload("res://verify_battle_hud.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Normalize = preload("res://ui/app_presentation.gd")
const ConfigurationCache = preload("res://ui/hud_configuration_cache.gd")
class CountingCache extends ConfigurationCache:
	var match_calls := 0
	func _matches(state: Dictionary) -> bool:
		match_calls += 1
		return super._matches(state)

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app := Fixture.App.new()
	check(app.catalog.load_catalog(), "catalog")
	check(app.run_domain.initialize(app.catalog, {}, 0, 100), "run")
	root.add_child(app)
	var hud = load("res://ui/battle_hud.gd").new()
	hud.configuration_cache = CountingCache.new()
	hud.app = app
	app.hud = hud
	root.add_child(hud)
	await process_frame
	app.run_domain.state.gold = 10000
	var map: Dictionary = app.catalog.stage(0).map
	for i in range(map.tiles.size()):
		if map.tiles[i] == "build" and app.run_domain.state.turrets.size() < 3:
			app.selected = Vector2i(i % int(map.columns), i / int(map.columns))
			app.build_selected()
	var before: int = hud.configuration_cache.derive_count
	hud.refresh()
	check(hud.configuration_cache.derive_count == before + 1, "DPS derives shared configuration once for three turrets")
	var revision: int = hud.configuration_cache.revision
	var count: int = hud.configuration_cache.derive_count
	var power: float = hud.total_dps
	var body_id: int = hud.body.get_child(0).get_instance_id()
	var panel_style: StyleBox = hud.overlay.get_theme_stylebox("panel")
	for i in range(30):
		app.run_domain.state.gold += 1
		app.run_domain.state.turrets[0].damageDealt = i * 10.0
		app.run_domain.state.progression.dailyQuestProgress = {"killEnemies": i}
		hud.refresh()
	check(hud.configuration_cache.revision == revision, "wallet/damage/quest changes do not invalidate configuration")
	check(hud.configuration_cache.derive_count == count, "cache hits do not derive")
	check(hud.body.get_child(0).get_instance_id() == body_id, "wallet/damage reuse body")
	check(hud.rewards.key is String, "hidden reward panel never constructs a state key")
	check(hud.overlay.get_theme_stylebox("panel") == panel_style, "hidden rewards reuse panel style across wallet refreshes")
	var field: String = app.run_domain.growth.data.permanentUpgrades.fireTraining.get("field", "fireTrainingUpgradeLevel")
	app.run_domain.state.progression[field] = 1
	hud.refresh()
	check(hud.total_dps > power, "progression changes invalidate DPS")
	check(hud.configuration_cache.derive_count == count + 1, "growth refresh derives once")
	_polling_checks(hud,app)
	var runtime := Runtime.new()
	var setup: Dictionary = app.catalog.bootstrap(0)
	setup.enemies = [app.catalog.enemy(0,0,"normal",1)]
	runtime.process_command({"epoch":1,"sequence":0,"bootstrap":setup,"session":{"clock":"godot","phase":"wave","paused":false,"speed":1.0}})
	var base := {"map":{"tiles":["build"]},"presentation":{"labels":{},"selection":{"revision":1,"state":{"turrets":[],"preserveLegacyOrnaments":true}},"effects":{"items":[{"kind":"impact","tileSize":1.0,"radius":0.75,"scale":0.02}],"events":[{"kind":"charge","tileSize":1.0,"scale":0.02}]}}}
	var original := JSON.stringify(base)
	var combat_original := JSON.stringify(runtime.snapshot())
	var first := runtime.decorate_frame(base, true)
	Normalize.normalize(first)
	check(JSON.stringify(base) == original, "optimized decoration/normalization preserves nested static input")
	check(JSON.stringify(runtime.snapshot()) == combat_original, "decoration preserves combat state")
	check(is_same(first.map, base.map), "internal map is shared read-only")
	check(is_same(first.presentation.selection.state, base.presentation.selection.state), "internal static selection is shared read-only")
	var first_copy := JSON.stringify(first)
	runtime.advance_session(0.01)
	Normalize.normalize(runtime.decorate_frame(base, true))
	check(JSON.stringify(first) == first_copy, "subsequent decoration cannot mutate an earlier snapshot")
	var external := runtime.decorate_frame(base)
	external.map.tiles.append("core")
	check(JSON.stringify(base) == original, "public decoration retains isolated snapshot default")
	hud.free()
	app.free()
	await _native_pan_projection_check()
	if failures.is_empty(): print("PASS overlay cache integration: HUD revisions, shared derivation, hidden rewards, growth invalidation, immutable presentation")
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)

func _native_pan_projection_check() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._native_combat.process_command({"epoch":100,"sequence":0,"dt":0,"bootstrap":{"enemies":[],"turrets":[]},"session":{"clock":"godot","phase":"wave","paused":true}})
	scene.last_frame.erase("viewport")
	check(scene._native_combat.native_session(), "pan regression uses the native session camera path")
	var effects: Node2D = scene._presentation_nodes["effects"]
	effects.show()
	effects.set_canvas_enabled(true)
	effects.apply_frame({"generation":100,"items":[{"id":991,"kind":"impact","style":"spark","x":3.5,"y":4.5,"radius":10.0,"tileSize":48.0,"duration":0.28,"age":0.1}]})
	check(effects._effect_nodes.has(991), "pan regression materializes a retained spark surface")
	if effects._effect_nodes.has(991):
		var surface: Node2D = effects._effect_nodes[991]
		for pan: Vector2 in [Vector2(0.22,0.17), Vector2(-0.3,-0.25), Vector2.ZERO]:
			scene._session_input.pan = pan
			# Match production order: base camera first, native pan afterward.
			scene._update_camera()
			var before: Vector2 = surface.geometry_basis.origin
			scene._update_session_presentation()
			var world_point: Vector3 = scene.world.to_global(Vector3(3.5-scene.columns/2.0,0,4.5-scene.rows/2.0))
			var expected: Vector2 = scene.camera.unproject_position(world_point)
			check(surface.geometry_basis.origin.distance_to(expected) < 0.001, "retained spark follows final native pan projection: " + str(pan))
			if pan != Vector2.ZERO:
				check(before.distance_to(expected) > 1.0, "nonzero pan exercises distinct base and final screen positions")
			check(is_equal_approx(surface.effect.age,0.1), "camera pan preserves paused spark age")
	scene.free()


func _polling_checks(hud, app) -> void:
	hud.set_process(false)
	var cache = hud.configuration_cache
	hud.refresh(true)
	var scans: int = cache.match_calls
	var derives: int = cache.derive_count
	for i in range(20): hud._process(0.25)
	check(cache.match_calls == scans, "unchanged timer polls skip configuration scans")
	check(cache.derive_count == derives, "unchanged timer polls reuse derived configuration")
	var revision: int = app.run_domain.state_revision
	app.run_domain.state = app.run_domain.state.duplicate(true)
	app.run_domain.state.gold += 1
	hud.refresh(true)
	check(app.run_domain.state_revision > revision and cache.match_calls == scans+1, "state replacement invalidates polling token")
	check(cache.derive_count == derives, "wallet-only replacement does not rederive configuration")
	scans = cache.match_calls
	var field: String = app.run_domain.growth.data.permanentUpgrades.fireTraining.get("field", "fireTrainingUpgradeLevel")
	app.run_domain.state.progression[field] += 1
	hud.refresh()
	check(cache.match_calls == scans+1 and cache.derive_count == derives+1, "explicit refresh detects direct nested mutation after cached polls")
	var source_id: int = app.run_domain.get_instance_id()
	cache.sync_polled(app.run_domain.state,app.run_domain.growth.data,source_id,app.run_domain.state_revision)
	scans = cache.match_calls
	cache.sync_polled(app.run_domain.state,app.run_domain.growth.data,source_id+1,app.run_domain.state_revision)
	check(cache.match_calls == scans+1, "new owner cannot reuse an equal revision token")
	var saved: Dictionary = app.run_domain.state.duplicate(true)
	revision = app.run_domain.state_revision
	app.run_domain.restore(saved)
	check(app.run_domain.state_revision > revision and not app.run_domain.state.has("state_revision"), "restore advances transient token without changing save schema")
	revision = app.run_domain.state_revision
	app.run_domain.finish(true)
	check(app.run_domain.state_revision > revision, "in-place finish invalidates cleared-stage configuration")
	hud.refresh(true)
	var after_finish: int = cache.derive_count
	app.run_domain.finish(true)
	hud.refresh(true)
	check(cache.derive_count == after_finish, "idempotent finish retains derived cache")
