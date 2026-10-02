extends RefCounted
## Authored guardian, hound and tank motion. Reads combat state; never changes it.
signal failure(message: String)

const WALK_PATH := "res://assets/enemies/normal.glb"
const TANK_PATH := "res://assets/enemies/tank.glb"
const TANK_DEATH_PATH := "res://assets/enemies/tank_death.glb"
const TankDeath = preload("res://effects/tank_death.gd")
const TANK_NUCLEUS_SHADER = preload("res://effects/tank_amber_nucleus.gdshader")
const HoundDeath = preload("res://effects/hound_death.gd")
const FAST_DEATH_PATH := "res://assets/enemies/fast_death.glb"
const FAST_DEATH_SECONDS := 0.55
const DEATH_PATH := "res://assets/enemies/normal_death.glb"
const NORMAL_VISUAL_SCALE := 1.15
const FAST_VISUAL_SCALE := 0.90
# Keep content's .65 presentation size, while the authored geometry uses the
# normal .55 reference with the same common 1.15 display enlargement.
const TANK_VISUAL_SCALE := (0.55 / 0.65) * NORMAL_VISUAL_SCALE
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
var _tank_scene: PackedScene
var _tank_death_scene: PackedScene
var _tank_core_materials := {}
var _tank_head_bounds := AABB()
var _tank_head_bounds_ready := false
var _death_scene: PackedScene
var _fast_death_scene: PackedScene
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
	if kind == "tank": _prepare_tank_core(model)
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
	# seek(update=true) applies the pose immediately, including manual players.
	player.seek(0.0, true)
	var entry := {"root": root, "type": kind, "guardian_preview": true,
		"player": player, "clip": clip, "distance": 0.0, "last_time": -INF}
	if kind == "tank": _prepare_tank_label(entry, model)
	return entry


func _prepare_tank_label(entry: Dictionary, model: Node3D) -> void:
	# Cache the authored head's rigid bind bounds once. Its current bone pose
	# supplies the visual bar anchor without changing native size/stats payloads.
	for body: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if body.skin == null or body.get_active_material(0).resource_name != "Tank_WeatheredStone_PBR": continue
		var skeleton := body.get_node(body.skeleton) as Skeleton3D
		var head := skeleton.find_bone("head")
		if head < 0: return
		entry.label_skeleton = skeleton
		entry.label_bone = head
		if not _tank_head_bounds_ready:
			var arrays := body.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for index in range(vertices.size()):
				var bind := bones[index * 4]
				if weights[index * 4] < 0.5: continue
				var bone := body.skin.get_bind_bone(bind)
				if bone < 0: bone = skeleton.find_bone(body.skin.get_bind_name(bind))
				if bone != head: continue
				var point := body.skin.get_bind_pose(bind) * vertices[index]
				if not _tank_head_bounds_ready:
					_tank_head_bounds = AABB(point, Vector3.ZERO)
					_tank_head_bounds_ready = true
				else: _tank_head_bounds = _tank_head_bounds.expand(point)
		entry.label_bounds = _tank_head_bounds
		return


func _prepare_tank_core(model: Node3D) -> void:
	# glTF transmission is imported as realtime transparency. Suppress the tiny
	# white specular hotspot that hid the amber volume at battlefield pixel size.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null or not original.resource_name.begins_with("Tank_Amber"): continue
			if not _tank_core_materials.has(original):
				var amber: Material
				if original.resource_name == "Tank_AmberNucleus_crystal":
					var nucleus := ShaderMaterial.new()
					nucleus.shader = TANK_NUCLEUS_SHADER
					nucleus.resource_name = original.resource_name
					amber = nucleus
				else:
					var shell := original.duplicate() as StandardMaterial3D
					shell.metallic_specular = 0.06
					shell.roughness = 0.20
					amber = shell
				_tank_core_materials[original] = amber
			mesh.set_surface_override_material(surface, _tank_core_materials[original])


func new_walker(kind: String = "normal") -> Dictionary:
	if kind == "tank":
		if _tank_death_scene == null:
			_tank_death_scene = load(TANK_DEATH_PATH) as PackedScene
		if _tank_scene == null:
			_tank_scene = load(TANK_PATH) as PackedScene
		if _tank_scene == null:
			failure.emit("탱커 GLB를 불러오지 못했습니다.")
			return {}
		return _instantiate(_tank_scene, 0.0, kind)
	if kind == "fast":
		# Load before combat kills, rather than importing the corpse on impact.
		if _fast_death_scene == null:
			_fast_death_scene = load(FAST_DEATH_PATH) as PackedScene
		if _run_scene == null:
			_run_scene = load(RUN_PATH) as PackedScene
		if _run_scene == null:
			failure.emit("빠른 룬 하운드 GLB를 불러오지 못했습니다.")
			return {}
		return _instantiate(_run_scene, 0.0, kind)
	return _instantiate(_walk_scene, 0.0) if prepare() else {}


static func visual_scale(kind: String) -> float:
	if kind == "tank": return TANK_VISUAL_SCALE
	return FAST_VISUAL_SCALE if kind == "fast" else NORMAL_VISUAL_SCALE


func update_walker(entry: Dictionary, data: Array, time: float) -> void:
	var logical := Vector2(float(data[12]), float(data[13])) if data.size() > 13 else Vector2(float(data[1]), float(data[2]))
	var id := int(data[0])
	var teleported := false
	if data.size() > 14 and data[14] is Dictionary and data[14].has("teleportSerial"):
		var serial := int(data[14]["teleportSerial"])
		teleported = entry.has("teleport_serial") and serial != int(entry.teleport_serial)
		if teleported:
			# A path skip is not a stride. Preserve the current gait phase and snap
			# body facing at the exit instead of easing across an unrelated corner.
			entry.erase("turn_target")
			if distances.has(id):
				entry.teleport_distance_offset = float(distances[id]) - float(entry.distance)
		entry.teleport_serial = serial
	else:
		entry.erase("teleport_serial")
		entry.erase("teleport_distance_offset")
	walkers[id] = entry
	update_facing(entry, PI / 2.0 - float(data[3]), time)
	if distances.has(id):
		entry.distance = float(distances[id]) - float(entry.get("teleport_distance_offset", 0.0))
	elif teleported:
		pass
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
		if enemy.is_empty(): continue
		var kind: String = enemy.get("type", "normal")
		if kind not in ["normal", "fast", "tank"]: continue
		if kind == "tank" and _tank_death_scene == null:
			_tank_death_scene = load(TANK_DEATH_PATH) as PackedScene
			if _tank_death_scene == null:
				failure.emit("탱커 사망 GLB를 불러오지 못했습니다.")
				continue
		if kind == "fast" and _fast_death_scene == null:
			_fast_death_scene = load(FAST_DEATH_PATH) as PackedScene
			if _fast_death_scene == null:
				failure.emit("빠른 룬 하운드 사망 GLB를 불러오지 못했습니다.")
				continue
		var corpse := _tank_death_scene if kind == "tank" else (_fast_death_scene if kind == "fast" else _death_scene)
		var entry := _instantiate(corpse, DEATH_FLOOR if kind == "normal" else 0.0, kind)
		if entry.is_empty(): continue
		var point: Vector2 = (Vector2(float(event.x), float(event.y)) - runtime.origin + runtime._visual_enemy_offset(enemy)) / runtime.tile_size
		entry.root.position = Vector3(point.x - map_size.x / 2.0, 0.0, point.y - map_size.y / 2.0)
		# Keep the last visible body direction if death interrupts a turn.
		var walker: Dictionary = walkers.get(id, {})
		entry.root.rotation.y = walker.root.rotation.y if not walker.is_empty() and is_instance_valid(walker.root) else PI / 2.0 - float(enemy.facingAngle)
		var scale_factor := visual_scale(kind)
		entry.root.scale = Vector3.ONE * float(enemy.get("presentationScale", 0.48 if kind == "fast" else 0.55)) * scale_factor
		if kind == "fast": HoundDeath.attach(entry)
		if kind == "tank":
			if not walker.is_empty() and is_instance_valid(walker.root):
				entry.root.position = walker.root.position
				entry.root.scale = walker.root.scale
			TankDeath.attach(entry, walker)
		entry.born = time
		deaths[id] = entry
	update_deaths(time)


func update_deaths(time: float) -> void:
	for id in deaths.keys():
		var entry: Dictionary = deaths[id]
		var age := time - float(entry.born)
		var duration := TankDeath.LIFETIME if entry.type == "tank" else (FAST_DEATH_SECONDS if entry.type == "fast" else DEATH_SECONDS)
		if age < 0.0 or age >= duration:
			entry.root.free()
			deaths.erase(id)
			continue
		entry.player.seek(minf(age, TankDeath.COLLAPSE) if entry.type == "tank" else age, true)
		if entry.type == "fast": HoundDeath.sample(entry, age)
		if entry.type == "tank": TankDeath.sample(entry, age)
