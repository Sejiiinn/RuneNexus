extends RefCounted
## Authored guardian and hound motion. Reads combat state; never changes it.
signal failure(message: String)

const WALK_PATH := "res://assets/enemies/normal.glb"
const DEATH_PATH := "res://assets/enemies/normal_death.glb"
const NORMAL_VISUAL_SCALE := 1.15
const FAST_VISUAL_SCALE := 0.90
const STRIDE_TILES := 0.284375 * NORMAL_VISUAL_SCALE
const WALK_SECONDS := 26.0 / 60.0
const RUN_PATH := "res://assets/enemies/fast.glb"
const RUN_SECONDS := 34.0 / 60.0
# Scale the authored contact distance with the body; combat speed stays unchanged.
const RUN_STRIDE_TILES := (54.6 / 48.0) * RUN_SECONDS * FAST_VISUAL_SCALE
const DEATH_SECONDS := 0.6
const QUARTER_TURN_SECONDS := 0.12
# V4's normalized mesh retains this floor offset; the new walk has Y=0 feet.
const DEATH_FLOOR := 0.008475561626255512

var _world: Node3D
var _walk_scene: PackedScene
var _run_scene: PackedScene
var _death_scene: PackedScene
var _attempted := false
var _epoch := -1
var _last_time := -INF
var _event_id := 0
var _killed_ids := {}
var distances := {}
var deaths := {}
var walkers := {}


func _init(world: Node3D) -> void:
	_world = world


func prepare() -> bool:
	if _attempted:
		return _walk_scene != null and _death_scene != null
	_attempted = true
	for path: String in [WALK_PATH, DEATH_PATH]:
		if not ResourceLoader.exists(path):
			failure.emit("Guardian 에셋이 없습니다: %s" % path)
			return false
	_walk_scene = load(WALK_PATH) as PackedScene
	_death_scene = load(DEATH_PATH) as PackedScene
	if _walk_scene == null or _death_scene == null:
		failure.emit("Guardian GLB를 불러오지 못했습니다.")
		return false
	return true


func clear() -> void:
	for entry: Dictionary in deaths.values():
		entry.root.free()
	deaths.clear()
	distances.clear()
	walkers.clear()
	_killed_ids.clear()
	_event_id = 0
	_epoch = -1
	_last_time = -INF


func _instantiate(scene: PackedScene, floor_offset: float, kind: String = "normal") -> Dictionary:
	var root := Node3D.new()
	var model := scene.instantiate() as Node3D
	root.add_child(model)
	model.position.y -= floor_offset
	_world.add_child(root)
	var player: AnimationPlayer
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty(): player = players[0] as AnimationPlayer
	if player == null:
		failure.emit("Guardian GLB에 AnimationPlayer가 없습니다.")
		root.free()
		return {}
	var clip := ""
	for candidate: String in player.get_animation_list():
		if candidate != "RESET":
			clip = candidate
			break
	if clip.is_empty():
		failure.emit("Guardian GLB에 애니메이션이 없습니다.")
		root.free()
		return {}
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(clip)
	player.seek(0.0, true)
	player.advance(0.0)
	return {"root": root, "type": kind, "guardian_preview": true,
		"player": player, "clip": clip, "distance": 0.0, "last_time": -INF}


func new_walker(kind: String = "normal") -> Dictionary:
	if kind == "fast":
		if _run_scene == null:
			_run_scene = load(RUN_PATH) as PackedScene
		if _run_scene == null:
			failure.emit("빠른 룬 하운드 GLB를 불러오지 못했습니다.")
			return {}
		return _instantiate(_run_scene, 0.0, kind)
	return _instantiate(_walk_scene, 0.0) if prepare() else {}


func update_walker(entry: Dictionary, data: Array, time: float) -> void:
	var logical := Vector2(float(data[12]), float(data[13])) if data.size() > 13 else Vector2(float(data[1]), float(data[2]))
	var id := int(data[0])
	walkers[id] = entry
	update_facing(entry, PI / 2.0 - float(data[3]), time)
	if distances.has(id):
		entry.distance = float(distances[id])
	elif entry.has("last_position") and time >= float(entry.last_time):
		entry.distance += logical.distance_to(entry.last_position)
	else:
		entry.distance = 0.0
	entry.last_position = logical
	entry.last_time = time
	var stride := RUN_STRIDE_TILES if entry.type == "fast" else STRIDE_TILES
	var seconds := RUN_SECONDS if entry.type == "fast" else WALK_SECONDS
	var phase := fposmod(float(entry.distance), stride) / stride
	entry.player.seek(phase * seconds, true)
	entry.player.advance(0.0)


# A finite ease-out turn, measured only by the combat clock. Retarget from the
# current rendered angle and unwrap across ±PI; logical path/facing stay intact.
func update_facing(entry: Dictionary, target: float, time: float) -> void:
	if not entry.has("turn_target") or time < float(entry.get("turn_last_time", time)):
		entry.root.rotation.y = target
		entry.turn_from = target
		entry.turn_target = target
		entry.turn_started = time
		entry.turn_duration = 0.0
	else:
		_sample_facing(entry, time)
		if absf(wrapf(target - float(entry.turn_target), -PI, PI)) > 0.00001:
			entry.turn_from = entry.root.rotation.y
			var difference := wrapf(target - float(entry.turn_from), -PI, PI)
			entry.turn_target = float(entry.turn_from) + difference
			entry.turn_started = time
			entry.turn_duration = QUARTER_TURN_SECONDS * absf(difference) / (PI / 2.0)
	entry.turn_last_time = time


func _sample_facing(entry: Dictionary, time: float) -> void:
	var duration := float(entry.turn_duration)
	var progress := clampf((time - float(entry.turn_started)) / duration, 0.0, 1.0) if duration > 0.0 else 1.0
	var eased := 1.0 - (1.0 - progress) * (1.0 - progress)
	entry.root.rotation.y = lerpf(float(entry.turn_from), float(entry.turn_target), eased)


func forget_walker(id: int) -> void:
	walkers.erase(id)


func observe_native(runtime, time: float, map_size: Vector2i) -> void:
	if not prepare(): return
	if runtime.epoch != _epoch or time < _last_time:
		var rewound: bool = runtime.epoch == _epoch and time < _last_time
		clear()
		_epoch = runtime.epoch
		# A presentation rewind must not replay the retained old journal.
		if rewound:
			for event: Dictionary in runtime.events:
				_event_id = maxi(_event_id, int(event.id))
	_last_time = time
	distances.clear()
	for enemy: Dictionary in runtime.enemies.values():
		distances[int(enemy.id)] = float(enemy.distanceTravelled) / runtime.tile_size
	for event: Dictionary in runtime.events:
		if int(event.id) <= _event_id: continue
		_event_id = int(event.id)
		if event.get("kind", "") != "kill": continue
		var id := int(event.enemyId)
		if _killed_ids.has(id): continue
		_killed_ids[id] = true
		var enemy: Dictionary = runtime.enemies.get(str(id), {})
		if enemy.is_empty() or enemy.get("type", "normal") != "normal": continue
		var entry := _instantiate(_death_scene, DEATH_FLOOR)
		if entry.is_empty(): continue
		var point: Vector2 = (Vector2(float(event.x), float(event.y)) - runtime.origin + runtime._visual_enemy_offset(enemy)) / runtime.tile_size
		entry.root.position = Vector3(point.x - map_size.x / 2.0, 0.0, point.y - map_size.y / 2.0)
		# Keep the last visible body direction if death interrupts a turn.
		var walker: Dictionary = walkers.get(id, {})
		entry.root.rotation.y = walker.root.rotation.y if not walker.is_empty() and is_instance_valid(walker.root) else PI / 2.0 - float(enemy.facingAngle)
		entry.root.scale = Vector3.ONE * float(enemy.get("presentationScale", 0.55)) * NORMAL_VISUAL_SCALE
		entry.born = time
		deaths[id] = entry
	update_deaths(time)


func update_deaths(time: float) -> void:
	for id in deaths.keys():
		var entry: Dictionary = deaths[id]
		var age := time - float(entry.born)
		if age < 0.0 or age >= DEATH_SECONDS:
			entry.root.free()
			deaths.erase(id)
			continue
		entry.player.seek(age, true)
		entry.player.advance(0.0)
