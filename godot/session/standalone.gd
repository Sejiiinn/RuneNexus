extends Node
## Migration smoke application; production account/economy remain separate.
## Fixture was extracted from game_stage_maps.dart and turret_stat_calculation.json.
var scene: Node3D
var fixture: Dictionary
var stage := 0
var epoch := 1000
var selected := Vector2i(-1, -1)
var status: Label
var panel: HBoxContainer
var next_id := 1
var checkpoint = preload("res://session/session_checkpoint.gd").new()

func _ready() -> void:
	scene = get_parent()
	scene.options.presentation_groups = ["labels","effects","selection"]
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://session/standalone_fixture.json"))
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	panel = HBoxContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	for spec in [["Stage", enter_next], ["Build", build_selected], ["Start", start_wave], ["Pause", toggle_pause], ["1x/4x", toggle_speed], ["Camera", toggle_camera], ["Save", save_session], ["Load", load_session], ["Exit", exit_stage]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		panel.add_child(button)
	status = Label.new()
	status.position = Vector2(14, 54)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)
	enter_stage(0)

func enter_next() -> void:
	enter_stage((stage + 1) % fixture.stages.size())

func enter_stage(index: int, bootstrap: Dictionary = {}, session_state: Dictionary = {}) -> void:
	stage = index
	epoch += 1
	next_id = 1
	selected = Vector2i(-1, -1)
	scene._apply_frame({"reset":true,"sceneEpoch":epoch})
	var source: Dictionary = fixture.stages[stage]
	var frame := {"seq":0,"sceneEpoch":epoch,"mapRevision":stage,"map":source.map.duplicate(true),"time":0.0,"turrets":[],"enemies":[],"projectiles":[],"impacts":[],"presentation":{"effects":{},"labels":{}}}
	scene._apply_frame(frame)
	scene._native_combat_base_frame = frame
	var initial := {"path":source.path,"tileSize":1.0,"boardDistanceScale":1.0/48.0,"defense":{"config":{"maxHp":100.0}}}
	initial.merge(bootstrap, true)
	var control := {"clock":"godot","phase":"preparation","paused":false,"speed":1.0}
	control.merge(session_state, true)
	scene._native_combat.process_command({"epoch":epoch,"sequence":0,"session":control,"bootstrap":initial})

func command(commands: Array = [], patch: Dictionary = {}) -> void:
	scene._native_combat.process_command({"epoch":epoch,"sequence":scene._native_combat.sequence+1,"ackEvent":scene._native_combat.event_id,"commands":commands,"session":patch})

func board_tap(tile: Vector2i) -> void:
	selected = tile
	if tile.x < 0:
		scene._native_combat_base_frame.buildPreview = null
		return
	scene._native_combat_base_frame.buildPreview = [-1,tile.x + 0.5,tile.y + 0.5,0,0,0,"arrow"]

func build_selected() -> void:
	if selected.x < 0 or not scene._native_combat.active: return
	var map: Dictionary = fixture.stages[stage].map
	if map.tiles[selected.y * int(map.columns) + selected.x] != "build": return
	var position := [selected.x + 0.5, selected.y + 0.5]
	for turret in scene._native_combat.turrets.values():
		if turret.position == position: return
	var stats: Dictionary = fixture.turret.duplicate(true)
	stats.boardDistanceScale = 1.0 / 48.0
	command([{"kind":"turret","turret":{"id":next_id,"position":position,"statInput":stats,"state":{"x":selected.x,"y":selected.y}}}])
	next_id += 1
	scene._native_combat_base_frame.buildPreview = null

func start_wave() -> void:
	if not scene._native_combat.active or scene._native_combat.defense.failed: return
	var path: Array = fixture.stages[stage].path
	var queue: Array = []
	for index in range(12):
		queue.append({"delay":index*0.6,"enemyType":"normal","enemy":checkpoint.enemy_configuration(path,index+1)})
	if scene._native_combat.wave.active: return
	command([{"kind":"waveStart","wave":{"id":scene._native_combat.wave.id+1,"active":true,"spawnQueue":queue}}],{"phase":"wave","paused":false})

func toggle_pause() -> void:
	command([], {"paused":not bool(scene._native_combat.session.get("paused",false))})

func toggle_speed() -> void:
	command([], {"speed":4.0 if float(scene._native_combat.session.get("speed",1)) == 1 else 1.0})

func toggle_camera() -> void:
	scene.options.camera = "drone" if scene.options.camera == "angled" else "angled"
	scene._apply_options()

func save_session() -> void:
	checkpoint.save_session(self)

func load_session() -> void:
	checkpoint.load_session(self)

func exit_stage() -> void:
	epoch += 1
	scene._apply_frame({"reset":true,"sceneEpoch":epoch})

func _process(_delta: float) -> void:
	var runtime = scene._native_combat
	status.text = "Stage %d | %s | %.1fs | HP %.1f | selected %s" % [stage+1, runtime.session.get("phase","ended"),runtime.clock,runtime.defense.hp,selected] + " | " + checkpoint.message
