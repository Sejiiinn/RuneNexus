extends RefCounted
## In-memory application domain adapter. Persistent/online settlement is separate.
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
var growth = Growth.new()
var service
var state: Dictionary = {}
var error := ""
var event_ack := 0
var epoch := -1

func initialize(catalog, progression: Dictionary, stage_index: int, scene_epoch: int) -> bool:
	if not growth.load_catalog():
		error = growth.error
		return false
	service = Commands.new(catalog, growth)
	state = service.initial_state(progression, stage_index)
	epoch = scene_epoch
	event_ack = 0
	error = ""
	return not state.is_empty()

func selected_id(tile: Vector2i) -> int:
	for turret in state.get("turrets", []):
		if int(turret.x) == tile.x and int(turret.y) == tile.y: return int(turret.id)
	return -1

func apply(command: Dictionary) -> Dictionary:
	var result: Dictionary = service.apply(state, command)
	if result.get("ok", false):
		state = result.state
		error = ""
	else:
		error = str(result.get("error", "Command rejected"))
	return result

func collect(runtime) -> Dictionary:
	if runtime.epoch != epoch: return {"ok": false, "commands": []}
	var commands: Array = []
	for event in runtime.events:
		if int(event.id) <= event_ack: continue
		var result: Dictionary = {"ok": true}
		match str(event.kind):
			"kill":
				var enemy: Dictionary = runtime.enemies.get(str(event.enemyId), {})
				if enemy.is_empty():
					error = "Missing enemy for reward; event retained"
					return {"ok": false, "commands": commands}
				result = service.award_kill(state, enemy)
			"waveCompleted":
				if runtime.defense.hp > 0:
					result = service.complete_wave(state, int(event.waveId))
			"coreDefeated":
				state.phase = "coreDestruction"
		if not result.get("ok", false):
			error = str(result.get("error", "Event rejected; retained"))
			return {"ok": false, "commands": commands}
		if result.has("state"): state = result.state
		commands.append_array(result.get("commands", []))
		# Advance only after the corresponding application state was updated.
		event_ack = int(event.id)
	if runtime.session.get("phase") == "failure": state.phase = "failure"
	return {"ok": true, "commands": commands}
