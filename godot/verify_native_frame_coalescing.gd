extends SceneTree
## Real app commands and battlefield consumers; persistence/auth are isolated.
const Burst = preload("res://effects/gem_equip_burst.gd")
class App extends "res://app/app_lifecycle.gd":
	func _ready() -> void:
		scene = get_parent()
		startup_blocked = false
		in_lobby = false
	func persist_progression() -> bool: return true
	func request_checkpoint() -> bool: return true
	func _pending_gem_reroll() -> bool: return false
class RewardMode extends RefCounted:
	var active := true
	var pending_gem := "attackSpeed"
	func targeting() -> bool: return active
class RewardHud extends Control:
	var rewards = RewardMode.new()
	func refresh() -> void: pass
	func battlefield_rect() -> Rect2: return Rect2()
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func selected_ids(scene) -> Array:
	var ids: Array = []
	for row in scene._presentation_nodes.selection._frame.get("turrets", []):
		if row.get("selected", false): ids.append(int(row.id))
	return ids
func burst_count(scene, id: int) -> int:
	if not scene.turrets.has(id): return 0
	var count := 0
	for child in scene.turrets[id].root.get_children():
		if child.get_script() == Burst: count += 1
	return count
func flush_once(scene, before: int, label: String) -> void:
	var runtime: String = JSON.stringify(scene.combat_runtime.snapshot())
	scene._report_presentation()
	check(scene.received_frames == before + 1, label + " applies exactly one frame")
	check(JSON.stringify(scene.combat_runtime.snapshot()) == runtime, label + " does not mutate combat")
	scene._report_presentation()
	check(scene.received_frames == before + 1, label + " clean report does not resubmit")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.app_mode = false
	root.add_child(scene)
	# Initialize the prepared renderer without invoking formal boot/auth setup.
	scene.app_mode = true
	scene.set_process(false)
	# Manual reports make headless execution independent of frame_pre_draw support.
	if RenderingServer.frame_pre_draw.is_connected(scene._report_presentation):
		RenderingServer.frame_pre_draw.disconnect(scene._report_presentation)
	var app := App.new()
	app.ui_enabled = false
	scene.session_controller = app
	scene.add_child(app)
	app.set_process(false)
	scene.options.presentation_groups = ["selection", "effects", "labels"]
	scene.options.turret_levels = true
	check(app.catalog.load_catalog() and app.run_domain.growth.load_catalog(), "catalog loaded")
	check(app.enter_stage(0, {}, {"paused":true}), "paused native stage entered")
	scene._report_presentation()
	app.run_domain.state.gold = 100000
	var map: Dictionary = app.stage_map(0)
	var tiles: Array[Vector2i] = []
	for index in map.tiles.size():
		if map.tiles[index] == "build": tiles.append(Vector2i(index % int(map.columns), index / int(map.columns)))
	check(tiles.size() >= 3, "three build tiles available")
	if tiles.size() < 3: scene.free(); quit(1); return
	var before: int = scene.received_frames
	app.board_tap(tiles[0])
	app.board_tap(tiles[1])
	for repeat in 3: app.refresh_selection()
	scene._process(0.0)
	check(scene.received_frames == before, "selection requests do not eagerly apply")
	flush_once(scene, before, "paused selection")
	check(scene._build_preview.root.position.x == float(tiles[1].x) + 0.5 - scene.columns / 2.0, "latest build preview position wins")
	check(scene._presentation_nodes.selection._show_all_ranges, "build selection shows all ranges")
	before = scene.received_frames
	check(app.apply_run_command({"kind":"build", "x":tiles[1].x, "y":tiles[1].y, "type":"arrow"}), "build accepted")
	var id: int = app.run_domain.state.turrets[0].id
	app.run_domain.state.gemInventory = {"attackSpeed":1}
	check(app.apply_run_command({"kind":"equipGem", "id":id, "slot":0, "type":"attackSpeed"}), "same render equip accepted")
	check(not scene.turrets.has(id) and scene.received_frames == before, "new model waits for render flush")
	flush_once(scene, before, "build and equip")
	check(scene.turrets.has(id) and burst_count(scene, id) == 1, "new model receives equip burst once")
	check(scene.turrets[id].has("gem_orbit") and scene.turrets[id].gem_orbit.visible, "new model receives gem orbit")
	check(scene._build_preview.is_empty() and selected_ids(scene) == [id], "built model replaces preview and stays selected")
	before = scene.received_frames
	app.selection_view.level_preview = true
	app.refresh_selection()
	check(app.selected_run_command("level"), "level accepted while paused")
	app.refresh_selection()
	flush_once(scene, before, "upgrade")
	check(scene.turrets[id].level == 2 and selected_ids(scene) == [id], "upgraded model and selection agree")
	check(scene._presentation_nodes.selection._frame.turrets[0].has("previewRange"), "next level range preview retained")
	check(burst_count(scene, id) == 1, "upgrade does not replay equipment receipt")
	before = scene.received_frames
	check(app.selected_run_command("removeGem", {"slot":0}), "remove gem accepted")
	app.selection_view.level_preview = false
	app.refresh_selection()
	flush_once(scene, before, "gem removal")
	check(not scene.turrets[id].gem_orbit.visible and burst_count(scene, id) == 1, "gem removal clears orbit without new cue")
	var reward_hud := RewardHud.new()
	app.hud = reward_hud
	before = scene.received_frames
	app.refresh_selection()
	app.refresh_selection()
	flush_once(scene, before, "reward targeting")
	check(scene._presentation_nodes.selection.reward_targeting() and not scene._presentation_nodes.selection._frame.rewardTargets.is_empty(), "reward targets reach renderer while paused")
	reward_hud.rewards.active = false
	before = scene.received_frames
	app.refresh_selection()
	flush_once(scene, before, "reward cancellation")
	check(not scene._presentation_nodes.selection.reward_targeting(), "reward cancellation clears dim state")
	app.hud = null
	reward_hud.free()
	before = scene.received_frames
	check(app.selected_run_command("sell"), "sale accepted while paused")
	app.refresh_selection()
	flush_once(scene, before, "sale")
	check(not scene.turrets.has(id) and selected_ids(scene).is_empty(), "sale removes model and selected turret")
	before = scene.received_frames
	scene.set_battle_visible(false)
	app.board_tap(tiles[0])
	app.board_tap(tiles[2])
	scene._report_presentation()
	check(scene.received_frames == before, "hidden battlefield does not apply queued frames")
	scene.set_battle_visible(true)
	flush_once(scene, before, "hidden return")
	check(scene._build_preview.root.position.x == float(tiles[2].x) + 0.5 - scene.columns / 2.0, "hidden return uses latest selection")
	before = scene.received_frames
	scene.begin_deferred_battle_presentation()
	app.board_tap(tiles[0])
	scene._report_presentation()
	check(scene.received_frames == before, "deferred battlefield does not apply queued frames")
	scene._battle_deferred = false
	scene.set_battle_visible(true)
	flush_once(scene, before, "deferred return")
	# The real render clock samples monotonic time, independently of engine delta.
	var now_usec := [1000000]
	scene._session_now_usec = func(): return now_usec[0]
	check(app.command([], {"paused":false}), "native simulation resumed")
	scene._process(0.0)
	now_usec[0] += 16667
	before = scene.received_frames
	scene._process(0.0)
	app.board_tap(tiles[1])
	check(scene.received_frames == before and scene.combat_runtime.simulation_tick > 0, "simulation and later selection only request a frame")
	flush_once(scene, before, "simulation plus later selection")
	check(scene._build_preview.root.position.x == float(tiles[1].x) + 0.5 - scene.columns / 2.0, "selection after parent process reaches current render")
	check(app.command([], {"paused":true}), "native simulation paused again")
	# Explicit reset must invalidate both a pending selection and its receipt.
	app.refresh_selection()
	scene.play_gem_equip_burst(id, "attackSpeed")
	var next_epoch: int = app.epoch + 1
	scene.apply_frame({"reset":true, "sceneEpoch":next_epoch})
	check(scene.combat_base_frame.is_empty() and not scene._native_frame_pending and scene._pending_gem_bursts.is_empty(), "reset clears queued frame and equipment receipts")
	before = scene.received_frames
	scene._report_presentation()
	check(scene.received_frames == before and scene.turrets.is_empty() and scene.last_frame.is_empty(), "report after reset cannot revive old state")
	check(app.enter_stage(0, {}, {"paused":true}), "replacement stage entered after reset")
	before = scene.received_frames
	app.refresh_selection()
	flush_once(scene, before, "replacement stage")
	check(scene.last_frame.sceneEpoch == app.epoch and scene.turrets.is_empty(), "replacement stage uses new epoch without stale models")
	# Drain callbacks queued by earlier manual process calls before a fresh input.
	await process_frame
	# Input/physics only accumulate requests; the render process owns the flush.
	before = scene.received_frames
	var runtime: String = JSON.stringify(scene.combat_runtime.snapshot())
	app.board_tap(tiles[0])
	app.board_tap(tiles[2])
	app.refresh_selection()
	check(scene._native_frame_pending and scene.received_frames == before, "idle requests stay queued within callback")
	await physics_frame
	check(scene._native_frame_pending and scene.received_frames == before, "input requests do not flush before render process")
	scene._process(0.0)
	await process_frame
	check(not scene._native_frame_pending and scene.received_frames == before + 1, "idle queue automatically applies multiple requests once")
	check(scene._build_preview.root.position.x == float(tiles[2].x) + 0.5 - scene.columns / 2.0, "automatic idle flush uses latest selection")
	check(JSON.stringify(scene.combat_runtime.snapshot()) == runtime, "automatic idle flush does not mutate combat")
	scene.free()
	print("NATIVE_FRAME_COALESCING checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
