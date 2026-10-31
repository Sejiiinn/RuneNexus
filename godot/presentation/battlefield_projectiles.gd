extends RefCounted
## Owns projectiles, impact effects, and reusable effect pools.
signal failure(message: String)

const Impact = preload("res://effects/flipbook_impact.gd")
const SniperBlast = preload("res://effects/sniper_energy_blast.gd")
const VenomSplash = preload("res://effects/venom_splash.gd")
const SNIPER_VARIANT := "sniperEnergy"
const VENOM_VARIANT := "venom"
const IMPACT_LIGHT_COLORS := {"": Color(1.0, 0.42, 0.08), SNIPER_VARIANT: Color(0.32, 0.86, 1.0), VENOM_VARIANT: Color(0.3, 0.9, 0.4)}
const BallisticProjectile = preload("res://effects/ballistic_projectile.gd")
const RunicFire = preload("res://effects/runic_fire.gd")
const VenomProjectile = preload("res://effects/venom_projectile.gd")
const FrameRows = preload("res://presentation/frame_rows.gd")
const PROJECTILE_COLORS := {
	"arrow": Color("ffe3a3"), "cannon": Color("ffb261"), "magic": Color("ff8528"),
	"frost": Color("94e6ff"), "sniper": Color("ffeec4"), "lightning": Color("c7d8ff"),
	"poison": Color("a6ff3a"),
}

var world: Node3D
var camera: Camera3D
var projectiles := {}
var impacts := {}
var impact_pool: Array[Node3D] = []
var sniper_blast_pool: Array[Node3D] = []
var venom_splash_pool: Array[Node3D] = []
var impact_lights: Array[OmniLight3D] = []
var _projectile_meshes := {}
var _ballistic_pool := {"arrow": [], "cannon": []}
var _fire_projectile_pool: Array[Node3D] = []
var _generic_projectile_pool := {"sniper": [], "frost": [], "poison": []}
var _time := 0.0
var columns := 8
var rows := 10
var options := {"volume": true}


func _init(world_root: Node3D, battlefield_camera: Camera3D) -> void:
	world = world_root
	camera = battlefield_camera


func initialize() -> bool:
	# A lobby may construct the presenter, but battle fields wait for a stage.
	return true


## Shared by cannon, explosion-sniper and venom blasts.
func _ensure_lights() -> void:
	if not impact_lights.is_empty(): return
	for index in range(4):
		var light := OmniLight3D.new()
		light.light_color = IMPACT_LIGHT_COLORS[""]
		light.light_energy = 0.0
		light.visible = false
		world.add_child(light)
		impact_lights.append(light)


func configure_stage(tower_types: Array) -> bool:
	clear(true)
	for kind: String in _ballistic_pool:
		if not kind in tower_types: _free_pool(_ballistic_pool[kind])
	for kind: String in _generic_projectile_pool:
		if not kind in tower_types: _free_pool(_generic_projectile_pool[kind])
	if not "magic" in tower_types: _free_pool(_fire_projectile_pool)
	for kind: String in _projectile_meshes.keys():
		if not kind in tower_types: _projectile_meshes.erase(kind)
	if not "sniper" in tower_types: _free_pool(sniper_blast_pool)
	if not "poison" in tower_types: _free_pool(venom_splash_pool)
	if "cannon" in tower_types:
		_ensure_lights()
		return true
	_free_pool(impact_pool)
	if not "sniper" in tower_types and not "poison" in tower_types:
		for light in impact_lights: light.free()
		impact_lights.clear()
	return true


func _free_pool(pool: Array) -> void:
	for effect: Node3D in pool: effect.free()
	pool.clear()


func configure(time: float, map_size: Vector2i, frame_options: Dictionary) -> void:
	_time = time
	columns = map_size.x
	rows = map_size.y
	options = frame_options


func adopt_prepared(source) -> void:
	for kind: String in _ballistic_pool:
		_adopt_pool(source._ballistic_pool[kind], _ballistic_pool[kind])
	for kind: String in _generic_projectile_pool:
		_adopt_pool(source._generic_projectile_pool[kind], _generic_projectile_pool[kind])
	_adopt_pool(source._fire_projectile_pool, _fire_projectile_pool)
	_adopt_pool(source.impact_pool, impact_pool)
	_adopt_pool(source.sniper_blast_pool, sniper_blast_pool)
	_adopt_pool(source.venom_splash_pool, venom_splash_pool)
	_projectile_meshes.merge(source._projectile_meshes)


func _adopt_pool(source: Array, destination: Array) -> void:
	while not source.is_empty():
		var effect: Node3D = source.pop_back()
		if destination.size() >= 2:
			effect.free()
			continue
		effect.reparent(world, false)
		destination.append(effect)


func clear(keep_prepared: bool = false) -> void:
	if keep_prepared:
		# A bounded reserve survives app stage/epoch resets. Never retain old
		# projectile metadata, ages, transforms, emitting tails, or impact lights.
		_sync_projectiles([], {})
		_update_impacts([])
		for pool: Array in _ballistic_pool.values() + _generic_projectile_pool.values() + [_fire_projectile_pool, impact_pool, sniper_blast_pool, venom_splash_pool]:
			while pool.size() > 2:
				pool.pop_back().free()
			for effect: Node3D in pool:
				if effect.has_method("reset"): effect.reset()
				effect.visible = false
				effect.transform = Transform3D.IDENTITY
		return
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
	_free_pool(sniper_blast_pool)
	_free_pool(venom_splash_pool)
	for light in impact_lights:
		light.light_energy = 0.0
		light.visible = false
	_projectile_meshes.clear()


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
	if type == "poison":
		return VenomProjectile.new()
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
	for row: FrameRows.Projectile in FrameRows.rows("projectiles", units):
		var id := row.id
		var type := row.type
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
			_update_fire_projectile(projectiles[id], row, turrets)
			continue
		if root is VenomProjectile:
			var owner: Dictionary = turrets.get(row.owner_id, {}) if row.has_owner else {}
			root.size_scale = VenomProjectile.VENOM_POOL_SCALE if bool(owner.get("venom_pool", false)) else 1.0
			root.update_flight(row, Vector3(-columns / 2.0, 0.0, -rows / 2.0), owner.get("shot_pose") if int(owner.get("last_shot", -1)) == row.shot else null)
			continue
		if root is BallisticProjectile:
			var pose = null
			if row.has_launch and row.has_owner and not row.chained:
				var owner: Dictionary = turrets.get(row.owner_id, {})
				if int(owner.get("last_shot", -1)) == row.shot:
					pose = owner.get("shot_pose")
			root.update_flight(row, _time, Vector3(-columns / 2.0, 0.0, -rows / 2.0), pose)
			root.update_camera(camera)
			continue
		root.position = Vector3(row.x - columns / 2.0, 0.56 if type == "cannon" else 0.45, row.y - rows / 2.0)
		root.rotation.y = PI / 2.0 - atan2(row.direction_y, row.direction_x)
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
				if projectile.has_method("reset"): projectile.reset()
				projectile.visible = false
				projectile.transform = Transform3D.IDENTITY
				_generic_projectile_pool[type].append(projectile)
			else:
				projectile.free()
			projectiles.erase(id)


func _update_fire_projectile(entry: Dictionary, row: FrameRows.Projectile, turrets: Dictionary) -> void:
	var root: Node3D = entry["root"]
	var time := _time
	var map_offset := Vector3(-columns / 2.0, 0.0, -rows / 2.0)
	var point := Vector3(row.x, 0.45, row.y) + map_offset
	var direction := Vector3(row.direction_x, 0.0, row.direction_y).normalized()
	if direction.length_squared() < 0.5:
		direction = Vector3.BACK
	var metadata := row.has_launch
	var finished_at := row.finished_at
	var finished := finished_at >= 0.0
	if time < float(entry.get("last_time", -INF)):
		root.reset()
		entry.erase("launch_position")
	entry["last_time"] = time
	if not entry.has("launch_position"):
		var launch := point - direction * 0.30
		if metadata:
			launch = Vector3(row.start_x, 0.45, row.start_y) + map_offset
			if not row.chained:
				var owner: Dictionary = turrets.get(row.owner_id, {}) if row.has_owner else {}
				var pose = owner.get("shot_pose")
				if int(owner.get("last_shot", -1)) == row.shot and pose is Transform3D:
					launch = pose.origin
				# magic의 origin에는 이미 Dart 화구 오프셋이 포함된다.
		entry["launch_position"] = launch
	if finished and row.has_end:
		point.x = row.end_x + map_offset.x
		point.z = row.end_y + map_offset.z
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
	var rows_list := FrameRows.rows("impacts", units)
	if not rows_list.is_empty(): _ensure_lights()
	var alive := {}
	for light in impact_lights:
		light.light_energy = 0.0
	var cannon_lights: Array = []
	var sniper_lights: Array = []
	var venom_lights: Array = []
	for row: FrameRows.Impact in rows_list:
		var id := row.id
		alive[id] = true
		if not impacts.has(id):
			var effect: Node3D
			if row.variant == SNIPER_VARIANT:
				if sniper_blast_pool.is_empty():
					effect = SniperBlast.new()
					world.add_child(effect)
				else:
					effect = sniper_blast_pool.pop_back()
			elif row.variant == VENOM_VARIANT:
				if venom_splash_pool.is_empty():
					effect = VenomSplash.new()
					world.add_child(effect)
				else:
					effect = venom_splash_pool.pop_back()
			elif impact_pool.is_empty():
				effect = Impact.new()
				world.add_child(effect)
				effect.configure()
			else:
				effect = impact_pool.pop_back()
			impacts[id] = effect
		var effect: Node3D = impacts[id]
		effect.visible = bool(options["volume"])
		effect.position = Vector3(row.x - columns / 2.0, 0, row.y - rows / 2.0)
		if effect.visible:
			if effect is VenomSplash: effect.lifetime = row.duration
			effect.update_impact(row.progress, row.radius, id, camera)
			if row.variant == SNIPER_VARIANT:
				if row.progress < 0.4: sniper_lights.append([effect, row])
			elif row.variant == VENOM_VARIANT:
				if row.progress < 0.22: venom_lights.append([effect, row])
			elif row.progress < 0.28:
				cannon_lights.append([effect, row])
	# Cannon blasts keep their lights first; explosion-sniper and venom splashes use what is left.
	var light_index := 0
	for request: Array in cannon_lights + sniper_lights + venom_lights:
		if light_index >= impact_lights.size(): break
		var effect: Node3D = request[0]
		var row: FrameRows.Impact = request[1]
		var sniper: bool = row.variant == SNIPER_VARIANT
		var venom: bool = row.variant == VENOM_VARIANT
		var light := impact_lights[light_index]
		light.position = effect.position + Vector3(0, 0.3 + row.radius * 0.12, 0)
		light.light_color = IMPACT_LIGHT_COLORS[row.variant if sniper or venom else ""]
		if sniper or venom:
			# The sniper light stays near its splash radius and fades with the flash.
			light.omni_range = row.radius * (1.8 if sniper else 3.0)
			light.light_energy = (1.4 if sniper else 0.45) * pow(1.0 - row.progress / (0.4 if sniper else 0.22), 2)
		else:
			# 대포 섬광: 착탄 프레임부터 절반 밝기로 켜져 0.03초에 최대, 0.25초까지 지수 감소, 반경 약 1.7배.
			var age: float = row.progress * Impact.DURATION
			light.omni_range = row.radius * 1.714
			light.light_energy = 4.5 * (0.5 + 0.5 * age / 0.03 if age < 0.03 else exp(-(age - 0.03) * 14.0))
		light_index += 1
	# Unused pool lights add nothing but still occupy per-object light lists.
	for light in impact_lights:
		light.visible = light.light_energy > 0.0
	for id in impacts.keys():
		if not alive.has(id):
			var effect: Node3D = impacts[id]
			effect.visible = false
			(sniper_blast_pool if effect is SniperBlast else (venom_splash_pool if effect is VenomSplash else impact_pool)).append(effect)
			impacts.erase(id)
