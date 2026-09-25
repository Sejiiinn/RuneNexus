extends RefCounted
## Owns projectiles, explosion fields, and reusable effect pools.
signal failure(message: String)

const Impact = preload("res://effects/godot_impact.gd")
const FieldCache = preload("res://effects/field_cache.gd")
const BallisticProjectile = preload("res://effects/ballistic_projectile.gd")
const RunicFire = preload("res://effects/runic_fire.gd")
const PROJECTILE_COLORS := {
	"arrow": Color("ffe3a3"), "cannon": Color("ffb261"), "magic": Color("ff8528"),
	"frost": Color("94e6ff"), "sniper": Color("ffeec4"), "lightning": Color("c7d8ff"),
}

var world: Node3D
var camera: Camera3D
var projectiles := {}
var impacts := {}
var impact_pool: Array[Node3D] = []
var impact_lights: Array[OmniLight3D] = []
var field: Dictionary
var _projectile_meshes := {}
var _ballistic_pool := {"arrow": [], "cannon": []}
var _fire_projectile_pool: Array[Node3D] = []
var _generic_projectile_pool := {"sniper": [], "frost": []}
var _time := 0.0
var columns := 8
var rows := 10
var options := {"volume": true}


func _init(world_root: Node3D, battlefield_camera: Camera3D) -> void:
	world = world_root
	camera = battlefield_camera


func initialize() -> bool:
	for index in range(4):
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.42, 0.08)
		light.light_energy = 0.0
		world.add_child(light)
		impact_lights.append(light)
	field = FieldCache.load_shared()
	if field.is_empty():
		failure.emit("폭발 필드 캐시를 불러오지 못했습니다.")
		return false
	return true


func configure(time: float, map_size: Vector2i, frame_options: Dictionary) -> void:
	_time = time
	columns = map_size.x
	rows = map_size.y
	options = frame_options


func clear() -> void:
	for entry: Dictionary in projectiles.values():
		entry["root"].free()
	projectiles.clear()
	for pool: Array in _ballistic_pool.values() + _generic_projectile_pool.values():
		for projectile: Node3D in pool:
			projectile.free()
		pool.clear()
	for projectile: Node3D in _fire_projectile_pool:
		projectile.free()
	_fire_projectile_pool.clear()
	for effect: Node3D in impacts.values():
		effect.free()
	impacts.clear()
	for effect in impact_pool:
		effect.free()
	impact_pool.clear()
	for light in impact_lights:
		light.light_energy = 0.0


func camera_changed() -> void:
	for effect: Node3D in impacts.values():
		if effect.visible:
			effect.update_camera(camera)
	for entry: Dictionary in projectiles.values():
		if entry["root"] is BallisticProjectile and entry["root"].visible:
			entry["root"].update_camera(camera)


func _new_projectile(type: String) -> Node3D:
	if _generic_projectile_pool.has(type) and not _generic_projectile_pool[type].is_empty():
		var reused: Node3D = _generic_projectile_pool[type].pop_back()
		reused.visible = true
		return reused
	if type == "magic":
		if not _fire_projectile_pool.is_empty():
			return _fire_projectile_pool.pop_back()
		return RunicFire.new(true)
	if _ballistic_pool.has(type):
		var pool: Array = _ballistic_pool[type]
		if not pool.is_empty():
			return pool.pop_back()
		return BallisticProjectile.new(type)
	if not _projectile_meshes.has(type):
		var heavy := type == "cannon"
		var ballistic := type in ["cannon", "arrow", "sniper"]
		var radius := 0.028 if heavy else (0.011 if type == "sniper" else 0.009)
		var length := 0.13 if heavy else 0.075
		var material := StandardMaterial3D.new()
		if ballistic:
			material.albedo_color = Color("45494d") if heavy else Color("c8a269")
			material.metallic = 0.5 if heavy else 0.72
			material.roughness = 0.65 if heavy else 0.42
		else:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = PROJECTILE_COLORS[type]
		var body := CylinderMesh.new()
		body.top_radius = radius
		body.bottom_radius = radius
		body.height = length
		body.radial_segments = 8
		body.material = material
		var nose := CylinderMesh.new()
		nose.top_radius = 0.0
		nose.bottom_radius = radius
		nose.height = length * 0.32
		nose.radial_segments = 8
		nose.material = material
		var tracer_length := 0.10 if heavy else 0.13
		var tracer := CylinderMesh.new()
		tracer.top_radius = 0.007 if heavy else 0.0035
		tracer.bottom_radius = 0.002 if heavy else 0.0015
		tracer.height = tracer_length
		tracer.radial_segments = 5
		var tracer_material := StandardMaterial3D.new()
		tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var color: Color = PROJECTILE_COLORS[type]
		color.a = 0.32 if heavy else 0.55
		tracer_material.albedo_color = color
		tracer.material = tracer_material
		_projectile_meshes[type] = {"meshes": [body, nose, tracer], "z": [0.0, length * 0.66, -(length + tracer_length) / 2.0]}
	var root := Node3D.new()
	root.name = "Projectile_" + type
	var template: Dictionary = _projectile_meshes[type]
	for index in range(3):
		var mesh := MeshInstance3D.new()
		mesh.mesh = template["meshes"][index]
		mesh.rotation.x = PI / 2.0
		mesh.position.z = float(template["z"][index])
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
	return root


func _sync_projectiles(units: Array, turrets: Dictionary) -> void:
	var alive := {}
	for data: Array in units:
		var id := int(data[0])
		var type := str(data[5]) if data.size() > 5 else "cannon"
		if not PROJECTILE_COLORS.has(type):
			failure.emit("지원하지 않는 탄환: %s" % type)
			continue
		alive[id] = true
		if projectiles.has(id) and projectiles[id]["type"] != type:
			projectiles[id]["root"].free()
			projectiles.erase(id)
		if not projectiles.has(id):
			var model := _new_projectile(type)
			if not model.is_inside_tree():
				world.add_child(model)
			projectiles[id] = {"root": model, "type": type}
		var root: Node3D = projectiles[id]["root"]
		if type == "magic":
			_update_fire_projectile(projectiles[id], data, turrets)
			continue
		if root is BallisticProjectile:
			var pose = null
			if data.size() >= 12 and data[8] != null and not bool(data[10]):
				var owner: Dictionary = turrets.get(int(data[8]), {})
				if int(owner.get("last_shot", -1)) == int(data[9]):
					pose = owner.get("shot_pose")
			root.update_flight(data, _time, Vector3(-columns / 2.0, 0.0, -rows / 2.0), pose)
			root.update_camera(camera)
			continue
		root.position = Vector3(float(data[1]) - columns / 2.0, 0.56 if type == "cannon" else 0.45, float(data[2]) - rows / 2.0)
		root.rotation.y = PI / 2.0 - atan2(float(data[4]), float(data[3]))
	for id in projectiles.keys():
		if not alive.has(id):
			var projectile: Node3D = projectiles[id]["root"]
			var type: String = projectiles[id]["type"]
			if type == "magic" and _fire_projectile_pool.size() < 64:
				projectile.reset()
				_fire_projectile_pool.append(projectile)
			elif projectile is BallisticProjectile and _ballistic_pool[type].size() < 64:
				projectile.reset()
				_ballistic_pool[type].append(projectile)
			elif _generic_projectile_pool.has(type) and _generic_projectile_pool[type].size() < 64:
				projectile.visible = false
				projectile.transform = Transform3D.IDENTITY
				_generic_projectile_pool[type].append(projectile)
			else:
				projectile.free()
			projectiles.erase(id)


func _update_fire_projectile(entry: Dictionary, data: Array, turrets: Dictionary) -> void:
	var root: Node3D = entry["root"]
	var time := _time
	var map_offset := Vector3(-columns / 2.0, 0.0, -rows / 2.0)
	var point := Vector3(float(data[1]), 0.45, float(data[2])) + map_offset
	var direction := Vector3(float(data[3]), 0.0, float(data[4])).normalized()
	if direction.length_squared() < 0.5:
		direction = Vector3.BACK
	var metadata := data.size() >= 12
	var finished_at := float(data[11]) if metadata else -1.0
	var finished := finished_at >= 0.0
	if time < float(entry.get("last_time", -INF)):
		root.reset()
		entry.erase("launch_position")
	entry["last_time"] = time
	if not entry.has("launch_position"):
		var launch := point - direction * 0.30
		if metadata:
			launch = Vector3(float(data[6]), 0.45, float(data[7])) + map_offset
			if not bool(data[10]):
				var owner: Dictionary = turrets.get(int(data[8]), {}) if data[8] != null else {}
				var pose = owner.get("shot_pose")
				if int(owner.get("last_shot", -1)) == int(data[9]) and pose is Transform3D:
					launch = pose.origin
				# magic의 origin에는 이미 Dart 화구 오프셋이 포함된다.
		entry["launch_position"] = launch
	if finished and data.size() >= 14 and data[12] != null and data[13] != null:
		point.x = float(data[12]) + map_offset.x
		point.z = float(data[13]) + map_offset.z
	var offset: Vector3 = point - entry["launch_position"]
	var travelled := offset.dot(direction)
	if travelled > 0.01:
		direction = offset.normalized()
	var right := Vector3.UP.cross(direction).normalized()
	root.global_transform = Transform3D(Basis(right, direction.cross(right), direction), point)
	var age := fposmod(time - finished_at, 1200.0) if finished else 0.0
	var opacity := pow(clampf(1.0 - age / 0.14, 0.0, 1.0), 1.4) if finished else 1.0
	# 전투 좌표·명중 시점은 그대로 두고 종료 후 짧은 잔불만 표시한다.
	root.update_projectile(time, not finished and travelled > 0.01, opacity if travelled > 0.01 else 0.0)


func _update_impacts(units: Array) -> void:
	var alive := {}
	for light in impact_lights:
		light.light_energy = 0.0
	var light_index := 0
	for data: Array in units:
		var id := int(data[0])
		alive[id] = true
		if not impacts.has(id):
			var effect: Node3D
			if impact_pool.is_empty():
				effect = Impact.new()
				world.add_child(effect)
				effect.configure(field["texture"], field["manifest"])
			else:
				effect = impact_pool.pop_back()
			impacts[id] = effect
		var effect: Node3D = impacts[id]
		effect.visible = bool(options["volume"])
		effect.position = Vector3(float(data[1]) - columns / 2.0, 0, float(data[2]) - rows / 2.0)
		if effect.visible:
			effect.update_impact(float(data[4]), float(data[3]), id, camera)
			if float(data[4]) < 0.68 and light_index < impact_lights.size():
				var light := impact_lights[light_index]
				light.position = effect.position + Vector3(0, 0.3 + float(data[3]) * 0.12, 0)
				light.omni_range = float(data[3]) * 3.2
				light.light_energy = 1.6 * pow(1.0 - float(data[4]) / 0.68, 2)
				light_index += 1
	for id in impacts.keys():
		if not alive.has(id):
			var effect: Node3D = impacts[id]
			effect.visible = false
			impact_pool.append(effect)
			impacts.erase(id)
