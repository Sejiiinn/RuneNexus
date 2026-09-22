extends "res://session/session_controller.gd"
## Development toolbar and explicit legacy fixture; never inherited by the app.
var content_enabled := true
var run_controls
var turret_button: Button
var wave_button: Button
var fixture: Dictionary
var status: Label
var panel: HFlowContainer
var next_id := 1

func is_content_session() -> bool:
	return content_enabled

func _ready() -> void:
	scene = get_parent()
	scene.options.presentation_groups = ["labels","effects","selection"]
	if "--session-fixture" in OS.get_cmdline_user_args(): content_enabled = false
	if not content_enabled:
		fixture = JSON.parse_string(FileAccess.get_file_as_string("res://session/standalone_fixture.json"))
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	panel = HFlowContainer.new()
	panel.size.x = get_viewport().get_visible_rect().size.x - 24.0
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	for spec in [["Stage", enter_next], ["Build", build_selected], ["Start", start_wave], ["Pause", toggle_pause], ["1x/4x", toggle_speed], ["Camera", toggle_camera], ["Save", save_session], ["Load", load_session], ["Exit", exit_stage]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		panel.add_child(button)
	if content_enabled:
		turret_button = Button.new()
		turret_button.text = "Tower: arrow"
		turret_button.pressed.connect(cycle_turret)
		panel.add_child(turret_button)
		wave_button = Button.new()
		wave_button.text = "Wave +"
		wave_button.pressed.connect(cycle_wave)
		panel.add_child(wave_button)
	status = Label.new()
	status.position = Vector2(14, 54)
	status.size.x = get_viewport().get_visible_rect().size.x - 28.0
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)
	if content_enabled and not catalog.load_catalog():
		checkpoint.message = catalog.error
		return
	enter_stage(0)
	if content_enabled:
		run_controls = load("res://session/run_controls.gd").new()
		run_controls.app = self
		layer.add_child(run_controls)

func stage_count() -> int:
	return catalog.stage_count() if content_enabled else fixture.stages.size()

func stage_source(index: int) -> Dictionary:
	return catalog.stage(index) if content_enabled else fixture.stages[index]

func cycle_turret() -> void:
	if catalog.stage_count() == 0: return
	var types: Array = catalog.data.turrets.keys()
	turret_type = types[(types.find(turret_type) + 1) % types.size()]
	turret_button.text = "Tower: " + turret_type
	if selected.x >= 0: board_tap(selected)

func cycle_wave() -> void:
	if not scene._native_combat.active or scene._native_combat.wave.active: return
	if run_domain.state.get("phase") != "preparation": return
	var total: int = stage_source(stage).waves.size()
	var completed: int = run_domain.state.get("completedRounds", 0)
	if completed >= total: return
	next_round = completed + (next_round - completed + 1) % (total - completed)


func enter_stage(index: int, bootstrap: Dictionary = {}, session_state: Dictionary = {}, restored_state: Dictionary = {}) -> void:
	if index < 0 or index >= stage_count(): return
	next_id = 1
	super.enter_stage(index, bootstrap, session_state, restored_state)

func build_selected() -> void:
	if selected.x < 0 or not scene._native_combat.active: return
	if content_enabled:
		super.build_selected()
		return
	var map: Dictionary = stage_source(stage).map
	if selected.x >= int(map.columns) or selected.y < 0 or selected.y >= int(map.rows): return
	if map.tiles[selected.y * int(map.columns) + selected.x] != "build": return
	var runtime = scene._native_combat
	var position := [runtime.origin.x + (selected.x + 0.5) * runtime.tile_size, runtime.origin.y + (selected.y + 0.5) * runtime.tile_size]
	for turret in scene._native_combat.turrets.values():
		if turret.position == position: return
	var stats: Dictionary = fixture.turret.duplicate(true)
	stats.boardDistanceScale = 1.0 / 48.0
	command([{"kind":"turret","turret":{"id":next_id,"position":position,"statInput":stats,"state":{"x":selected.x,"y":selected.y}}}])
	next_id += 1
	scene._native_combat_base_frame.buildPreview = null

func start_wave() -> void:
	if content_enabled:
		super.start_wave()
		return
	if not scene._native_combat.active or scene._native_combat.defense.failed: return
	if scene._native_combat.wave.active: return
	var path: Array = fixture.stages[stage].path
	var queue: Array = []
	for index in range(12):
		queue.append({"delay":index*0.6,"enemyType":"normal","enemy":checkpoint.enemy_configuration(path,index+1)})
	if scene._native_combat.wave.active: return
	command([{"kind":"waveStart","wave":{"id":scene._native_combat.wave.id+1,"active":true,"spawnQueue":queue}}],{"phase":"wave","paused":false})

func _process(delta: float) -> void:
	super._process(delta)
	var runtime = scene._native_combat
	if not status.is_visible_in_tree(): return
	status.text = "Stage %d | %s | %.1fs | HP %.1f | selected %s" % [stage+1, runtime.session.get("phase","ended"),runtime.clock,runtime.defense.hp,selected] + " | " + checkpoint.message
	if content_enabled:
		var following := str(next_round + 1) if catalog.stage_count() > stage and next_round < catalog.data.stages[stage].waves.size() else "done"
		status.text = "Stage %d | Wave %d | %s | HP %.1f | next %s | %s" % [stage+1, runtime.wave.id, runtime.session.get("phase", "ended"), runtime.defense.hp, following, turret_type]
		if not run_domain.state.is_empty():
			status.text += "\nGold %d | Shards %d | run commands active; local v2 save" % [run_domain.state.gold, run_domain.state.gemShards]
		if not checkpoint.message.is_empty(): status.text += "\n" + checkpoint.message
