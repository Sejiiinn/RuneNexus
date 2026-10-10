extends SceneTree
## Actual main battlefield + BattleHud, isolated saves, no network.
## Run with an imported project and RUNE_CH3_CAPTURE_DIR=/absolute/directory.
## Compatibility renders are desktop evidence, not Android certification.
const Enemy = preload("res://combat/native_enemy_state.gd")
var scene
var app
var directory := ""
var failures: Array[String] = []
var report: Array = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	if not value and label not in failures:
		failures.append(label)
		push_error(label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "capture " + label)
	print("CH3_CAPTURE ", label)

func check_modal_routes(wave: Dictionary) -> void:
	for frame in range(2): await process_frame
	var expected := 0
	for group: Dictionary in wave.get("routeGroups",[]):
		if not str(group.get("routeLabel", "")).is_empty(): expected += 1
	var actual := 0
	for label: Label in app.hud.modal.find_children("*","Label",true,false):
		if label.text.begins_with("묶음 "):
			actual += 1
			check(label.size.x <= root.get_visible_rect().size.x,"group route wraps within viewport")
	check(actual == expected,"every group including boss has a route label")
	check(app.hud.modal_panel.size.x <= root.get_visible_rect().size.x,"modal fits viewport width")

func press_selected_portal_summary() -> bool:
	var title: String = app.hud.menu_panel._portal_title()
	for button: Button in app.hud.body.find_children("*","Button",true,false):
		if button.text.begins_with(title + "\n"):
			check(not button.disabled,"selected portal summary enabled before wave")
			button.pressed.emit()
			return true
	check(false,"selected portal summary button exists")
	return false

func check_selected_portal_modal() -> Button:
	var title: String = app.hud.menu_panel._portal_title()
	var header: HBoxContainer = app.hud.modal_body.get_child(0)
	var title_seen := false
	var close: Button
	for child in header.get_children():
		if child is Label and child.text.begins_with(title + " · "): title_seen = true
		if child is Button and child.text == "×": close = child
	check(title_seen,"modal title identifies the selected actual spawn")
	check(close != null,"selected portal close button exists")
	if close != null:
		var bounds: Rect2 = close.get_global_rect()
		var viewport: Rect2 = app.hud.get_viewport_rect()
		check(close.is_visible_in_tree() and viewport.encloses(bounds),"selected portal close control visible within viewport")
		check(app.hud.modal_scroll.get_global_rect().encloses(bounds),"long portal title does not clip close control")
	return close

func exercise_selected_portals(map: Dictionary,wave: Dictionary,stage_id: int) -> void:
	var portal_number := 0
	for tile_index in range(map.tiles.size()):
		if map.tiles[tile_index] != "spawn": continue
		portal_number += 1
		app.board_tap(Vector2i(tile_index % int(map.columns),tile_index / int(map.columns)))
		await process_frame
		if not press_selected_portal_summary(): continue
		await check_modal_routes(wave)
		var close := check_selected_portal_modal()
		await capture("stage-%d-selected-portal-%d" % [stage_id,portal_number])
		if close == null: app.hud.close_modal(); continue
		close.pressed.emit()
		check(not app.hud.modal_active(),"selected portal closes through visible control")
		await process_frame
		if not press_selected_portal_summary(): continue
		await check_modal_routes(wave)
		close = check_selected_portal_modal()
		check(app.hud.modal_active(),"selected portal can reopen after closing")
		if close != null: close.pressed.emit()
		else: app.hud.close_modal()

func present() -> void:
	scene._apply_frame(scene._native_combat_base_frame)
	app.hud.refresh()

func run() -> void:
	directory = OS.get_environment("RUNE_CH3_CAPTURE_DIR")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../chapter-three-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(440, 900)
	root.content_scale_size = Vector2i(440, 760)
	scene = load("res://main.gd").new()
	scene._app_mode = true
	root.add_child(scene)
	app = scene._standalone_session
	var narrow := "--narrow-modals" in OS.get_cmdline_user_args()
	var guides_only := "--guides-only" in OS.get_cmdline_user_args()
	if narrow:
		root.size = Vector2i(320,900)
		root.content_scale_size = Vector2i(320,760)
	# Remove deferred network services before yielding to their startup.
	var services = app.services
	app.services = null
	if services != null: services.free()
	app.set_process(false)
	scene.set_process(false)
	app.checkpoint = load("res://session/session_checkpoint.gd").new(directory.path_join("isolated-save"))
	app.checkpoint.allow_progression_only = true
	check(app.retry_load(), "isolated startup")
	app.progression_inputs = {"clearedStageNumbers":range(1,31)}
	for stage_id in ([26,28,30] if guides_only else ([28,30] if narrow else [26,27,28,29,30])):
		var index: int = app.catalog.stage_index(stage_id)
		check(index >= 0, "catalog stage " + str(stage_id))
		if index < 0: continue
		scene._native_combat.active = false
		app.run_domain.state.clear()
		check(await app.start_stage(index), "enter stage " + str(stage_id))
		if app.in_lobby: continue
		var map: Dictionary = app.catalog.stage_map(index)
		var expected_portals: int = map.tiles.count("spawn")
		check(scene._environment._portals.size() == expected_portals, "all actual spawn portals " + str(stage_id))
		check(scene._path_guide.mesh_instance.mesh != null, "route guide " + str(stage_id))
		present()
		await capture("stage-%d-overview" % stage_id)
		if guides_only:
			scene._path_guide.update_time(2.0)
			await capture("stage-%d-origin-guides" % stage_id)
			if stage_id == 30:
				# Supplemental close view uses the actual camera + battlefield,
				# preserving the full-board original capture above.
				var original_transform: Transform3D = scene.camera.transform
				var original_size: float = scene.camera.size
				var original_offsets := Vector2(scene.camera.h_offset,scene.camera.v_offset)
				scene.camera.size = 5.5
				scene.camera.h_offset = 0.0
				scene.camera.v_offset = 0.0
				scene.camera.position += Vector3(3.0,0.0,2.0)
				await capture("stage-30-shared-guides-close")
				scene.camera.transform = original_transform
				scene.camera.size = original_size
				scene.camera.h_offset = original_offsets.x
				scene.camera.v_offset = original_offsets.y
			app.run_domain.state.completedRounds = app.catalog.wave_count(index)-1
			app.hud.refresh()
			app.hud.menu_panel._portal_details(app.catalog.wave_summary(index,app.catalog.wave_count(index)-1),app.catalog.wave_count(index)-1)
			await check_modal_routes(app.catalog.wave_summary(index,app.catalog.wave_count(index)-1))
			await capture("stage-%d-origin-legend" % stage_id)
			app.hud.close_modal()
			report.append({"stage":stage_id,"guideOnly":true,"spawnPortals":expected_portals,"routeCount":map.get("routes",[]).size(),"guideTime":2.0})
			continue
		# The final wave includes the boss and any grouped routes in real content.
		var last: int = app.catalog.wave_count(index)-1
		app.run_domain.state.completedRounds = last
		app.next_round = last
		app.hud.refresh()
		var summary: Dictionary = app.catalog.wave_summary(index,last)
		if narrow: await exercise_selected_portals(map,summary,stage_id)
		app.hud.menu_panel._portal_details(summary,last)
		check(app.hud.modal != null, "prewave modal " + str(stage_id))
		await check_modal_routes(summary)
		await capture("stage-%d-boss-prewave" % stage_id)
		if narrow:
			app.hud.modal_scroll.scroll_vertical = int(app.hud.modal_scroll.get_v_scroll_bar().max_value)
			await capture("stage-%d-boss-prewave-bottom" % stage_id)
		app.hud.close_modal()
		var selected_wave := 0
		var expected_routes := 1
		for wave_index in range(app.catalog.wave_count(index)):
			var ids := {}
			for group: Dictionary in app.catalog.wave_summary(index,wave_index).get("routeGroups",[]):
				ids[str(group.get("routeId","default"))] = true
			if ids.size() > expected_routes:
				expected_routes = ids.size()
				selected_wave = wave_index
		app.run_domain.state.completedRounds = selected_wave
		app.next_round = selected_wave
		app.hud.refresh()
		app.hud.menu_panel._portal_details(app.catalog.wave_summary(index,selected_wave),selected_wave)
		await check_modal_routes(app.catalog.wave_summary(index,selected_wave))
		await capture("stage-%d-route-prewave" % stage_id)
		app.hud.close_modal()
		if narrow:
			report.append({"stage":stage_id,"narrowModal":true,"selectedPortals":expected_portals})
			continue
		app.start_wave()
		var runtime = scene._native_combat
		# Test-only core budget lets the real schedule complete without towers.
		runtime.defense.hp = 1000000.0
		runtime.defense.max_hp = 1000000.0
		var seen_routes := {}
		var teleports := {}
		var entrances := {}
		var steps := 0
		while steps < 1200:
			if stage_id == 27:
				for enemy: Dictionary in runtime.enemies.values():
					if enemy.hp <= 0 or enemy.arrived: continue
					for pair: Dictionary in map.get("teleportPairs",[]):
						var entry_cell: Array = pair.entrance
						var entry_point := Vector2(float(entry_cell[0])+0.5,float(entry_cell[1])+0.5)*float(runtime.tile_size)
						var key := str(pair.get("color",entry_cell))
						if not entrances.has(key) and Vector2(enemy.x,enemy.y).distance_to(entry_point) < float(enemy.speed)*0.2:
							entrances[key] = true
							await capture("stage-%d-teleport-%s-entry" % [stage_id,key])
			runtime.advance_session(0.1)
			present()
			for enemy: Dictionary in runtime.enemies.values():
				if enemy.hp <= 0 or enemy.arrived: continue
				if scene._units.enemies.has(int(enemy.id)):
					var rendered: Vector3 = scene._units.enemies[int(enemy.id)].root.position
					var offset: Vector2 = runtime._visual_enemy_offset(enemy)
					var expected := Vector3((float(enemy.x)+offset.x)/float(runtime.tile_size)-float(map.columns)/2.0,0.0,(float(enemy.y)+offset.y)/float(runtime.tile_size)-float(map.rows)/2.0)
					check(Vector2(rendered.x,rendered.z).is_equal_approx(Vector2(expected.x,expected.z)),"rendered actor follows native route without interpolation")
				var route := str(enemy.get("routeId", "default"))
				if not seen_routes.has(route):
					seen_routes[route] = true
					await capture("stage-%d-route-%s" % [stage_id,route])
				var serial := int(enemy.get("teleportSerial",0))
				if serial > 0 and not teleports.has(serial):
					teleports[serial] = true
					await capture("stage-%d-teleport-%d-exit" % [stage_id,serial])
				var logical := Vector2(float(enemy.x),float(enemy.y)) / float(runtime.tile_size)
				var cell := Vector2i(floori(logical.x),floori(logical.y))
				if cell.x >= 0 and cell.y >= 0 and cell.x < int(map.columns) and cell.y < int(map.rows):
					check(map.tiles[cell.y * int(map.columns) + cell.x] != "blocked", "enemy avoids void")
			steps += 1
			if steps == 35: await capture("stage-%d-moving" % stage_id)
			var has_death_actor: bool = runtime.enemies.values().any(func(e): return e.hp > 0 and not e.arrived and str(e.type) in ["normal","fast","tank","boss","shieldBoss","forgeBoss"])
			if steps > 35 and has_death_actor and seen_routes.size() >= expected_routes and (stage_id != 27 or teleports.size() == map.get("teleportPairs",[]).size()): break
		check(seen_routes.size() >= expected_routes, "all group routes spawned " + str(stage_id))
		# Kill an actual spawned actor through the native damage/event path.
		var killed := false
		var death_id := -1
		var death_kind := ""
		for enemy: Dictionary in runtime.enemies.values():
			if enemy.hp <= 0 or enemy.arrived or str(enemy.type) not in ["normal","fast","tank","boss","shieldBoss","forgeBoss"]: continue
			death_id = int(enemy.id)
			death_kind = str(enemy.type)
			var result: Dictionary = Enemy.apply_hit(enemy,{"damage":1.0e12,"ignoreArmorReduction":true})
			runtime._collect(result.events)
			killed = bool(result.killed)
			break
		check(killed, "actual actor death " + str(stage_id))
		# Consume the native kill exactly as the live session does, before rendering.
		app.command()
		present()
		var motion = scene._units._guardian_preview
		check(not runtime.enemies.has(str(death_id)),"dead native actor ACKed " + str(stage_id))
		check(motion.deaths.has(death_id),"ACKed actor retained for visible death " + str(stage_id))
		var lifetime := 0.55 if death_kind == "fast" else (2.95 if death_kind == "tank" else (1.85 if death_kind == "normal" else 2.75))
		var born: float = runtime.clock
		var initial_position := -1.0
		if motion.deaths.has(death_id): initial_position = motion.deaths[death_id].player.current_animation_position
		for age in [0.2,lifetime-0.17,lifetime+0.15]:
			while runtime.clock < born + age - 0.01:
				var before: float = runtime.clock
				runtime.advance_session(0.05)
				present()
				if runtime.clock <= before: break
			if age == 0.2:
				check(motion.deaths.has(death_id),"death remains during collapse " + str(stage_id))
				if motion.deaths.has(death_id): check(motion.deaths[death_id].player.current_animation_position > initial_position,"authored death clip advances " + str(stage_id))
			elif age < lifetime and motion.deaths.has(death_id):
				var entry: Dictionary = motion.deaths[death_id]
				var bodies: Array = entry.get("death_bodies",entry.get("boss_bodies",[]))
				check(not bodies.is_empty(),"death fade bodies " + str(stage_id))
				if not bodies.is_empty():
					var opacity: float = bodies[0].get_instance_shader_parameter("death_opacity")
					check(opacity > 0.0 and opacity < 1.0,"corpse fades before removal " + str(stage_id))
			else:
				check(not motion.deaths.has(death_id),"death cleans up after lifetime " + str(stage_id))
			await capture("stage-%d-death-age-%.2f" % [stage_id,age])
		report.append({"stage":stage_id,"spawnPortals":expected_portals,"routesSeen":seen_routes.keys(),"teleportsSeen":teleports.keys(),"death":killed,"deathKind":death_kind,"deathRemoved":not motion.deaths.has(death_id)})

	var file := FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"stages":report,"failures":failures},"  "))
	print("CH3_ROUTES_RENDER failures=",failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
