extends RefCounted
## Owns battlefield actor models and their frame-driven weapon/status visuals.
signal failure(message: String)

const TurretLevelLabels = preload("res://ui/turret_level_labels.gd")
const WeaponAtlas = preload("res://effects/weapon_atlas.gd")
const MachineGunMuzzle = preload("res://effects/machinegun_muzzle.gd")
const RunicFire = preload("res://effects/runic_fire.gd")
const FrostTower = preload("res://effects/frost_tower.gd")
const EnemyFrost = preload("res://effects/enemy_frost.gd")
const EnemyBurn = preload("res://effects/enemy_burn.gd")
const TURRET_MODELS := {
	"arrow": preload("res://assets/turrets/arrow.glb"),
	"cannon": preload("res://assets/turrets/cannon.glb"),
	"magic": preload("res://assets/turrets/magic.glb"),
	"frost": preload("res://assets/turrets/frost.glb"),
	"sniper": preload("res://assets/turrets/sniper.glb"),
	"lightning": preload("res://assets/turrets/lightning.glb"),
}
const ENEMY_MODELS := {
	"normal": preload("res://assets/enemies/normal.glb"),
	"armored": preload("res://assets/enemies/armored.glb"),
	"shielded": preload("res://assets/enemies/shielded.glb"),
	"fast": preload("res://assets/enemies/fast.glb"),
	"tank": preload("res://assets/enemies/tank.glb"),
	"boss": preload("res://assets/enemies/boss.glb"),
	# 실드/HP/상태 표시는 실제 프레임을 유지하고 기존 보스 본체를 공유한다.
	"shieldBoss": preload("res://assets/enemies/boss.glb"),
	"forgeBoss": preload("res://assets/enemies/boss.glb"),
}

var world: Node3D
var camera: Camera3D
var turrets := {}
var enemies := {}
var _build_preview := {}
var _time := 0.0
var columns := 8
var rows := 10
var options := {"volume": true}


func _init(world_root: Node3D, battlefield_camera: Camera3D) -> void:
	world = world_root
	camera = battlefield_camera


func configure(time: float, map_size: Vector2i, frame_options: Dictionary) -> void:
	_time = time
	columns = map_size.x
	rows = map_size.y
	options = frame_options


func clear() -> void:
	for collection: Dictionary in [turrets, enemies]:
		for entry: Dictionary in collection.values():
			entry["root"].free()
		collection.clear()
	if not _build_preview.is_empty():
		_build_preview["root"].free()
		_build_preview.clear()


func camera_changed() -> void:
	for entry: Dictionary in turrets.values():
		_update_weapon_camera(entry)


func _prepare_vertex_colors(model: Node) -> void:
	# GLB COLOR_0 보존: 일부 다중 primitive 재질의 누락된 사용 플래그 보정.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var colors = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var material := mesh.get_active_material(surface)
			if colors != null and not colors.is_empty() and material is StandardMaterial3D:
				material.vertex_color_use_as_albedo = true


func _new_turret(type: String) -> Dictionary:
	var root: Node3D = TURRET_MODELS[type].instantiate()
	_prepare_vertex_colors(root)
	world.add_child(root)
	var barrel: Node3D = root.find_child("turret_barrel", true, false)
	var muzzle: Node3D = root.find_child("muzzle", true, false)
	var entry := {
		"root": root, "type": type, "head": root.find_child("turret_head", true, false),
		"barrel": barrel, "muzzle": muzzle, "barrel_rest_z": barrel.position.z,
		"flashes": [], "smokes": [], "smoke_starts": [-INF, -INF],
		"last_shot": -1, "last_time": -INF, "fire_start": -INF, "active_port": 0,
	}
	entry["level_bounds"] = TurretLevelLabels.base_bounds(root, entry["head"], root.transform.affine_inverse())
	if type == "frost":
		var effect := FrostTower.new()
		root.add_child(effect)
		effect.configure(root)
		entry["frost_effect"] = effect
		return entry
	if type == "magic":
		# 발광 홈은 금속 반사광으로 희게 날리지 않고 원본 주황색을 유지한다.
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material != null and material.resource_name.begins_with("Runes |"):
					material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var effect := RunicFire.new(false)
		root.add_child(effect)
		entry["fire_effect"] = effect
		entry["flame_port"] = root.find_child("upper_flame_port", true, false)
		return entry
	if type == "arrow":
		var effect := MachineGunMuzzle.new()
		root.add_child(effect)
		entry["muzzle_effect"] = effect
		return entry
	for index in range(2):
		var flash := WeaponAtlas.new()
		flash.configure(true)
		flash.position.x = (-0.062 if index == 0 else 0.062) if type == "arrow" else 0.0
		flash.position.z = 0.018
		muzzle.add_child(flash)
		entry["flashes"].append(flash)
		var smoke := WeaponAtlas.new()
		smoke.configure(false, Color("697586") if type == "arrow" else Color.WHITE)
		smoke.position.x = flash.position.x
		muzzle.add_child(smoke)
		entry["smokes"].append(smoke)
	return entry


func _sync_turrets(units: Array) -> void:
	var alive := {}
	var frost_lights := 0
	for data: Array in units:
		var id := int(data[0])
		# 구 검수 배열에만 cannon 기본값 사용. 명시된 다른 유형은 대체하지 않음.
		var type := str(data[6]) if data.size() > 6 else "cannon"
		if not TURRET_MODELS.has(type):
			failure.emit("스테이지 1에서 지원하지 않는 포탑: %s" % type)
			continue
		alive[id] = true
		if turrets.has(id) and turrets[id]["type"] != type:
			turrets[id]["root"].free()
			turrets.erase(id)
		if not turrets.has(id):
			turrets[id] = _new_turret(type)
		var entry: Dictionary = turrets[id]
		entry["root"].visible = not (type == "magic" and options.get("runic_fire_mode", "all") == "no_model")
		entry["level"] = int(data[7]) if data.size() > 7 else 1
		entry["root"].position = Vector3(float(data[1]) - columns / 2.0, 0.0, float(data[2]) - rows / 2.0)
		entry["head"].rotation.y = 0.0 if type == "frost" else PI / 2.0 - float(data[3])
		if type == "frost":
			var state: Dictionary = data[8] if data.size() > 8 and data[8] is Dictionary else {}
			entry["frost_effect"].update_state(_time, int(data[4]), float(data[5]), state, bool(options["volume"]), frost_lights < 4)
			frost_lights += 1
		else:
			_update_fire(entry, int(data[4]), float(data[5]))
	for id in turrets.keys():
		if not alive.has(id):
			turrets[id]["root"].free()
			turrets.erase(id)


func _update_fire(entry: Dictionary, shot_sequence: int, feedback: float) -> void:
	var time := _time
	if time < float(entry["last_time"]):
		entry["fire_start"] = -INF
		entry["smoke_starts"] = [-INF, -INF]
		if entry.has("muzzle_effect"):
			entry["muzzle_effect"].reset()
		if entry.has("fire_effect"):
			entry["fire_effect"].reset()
			entry["last_shot"] = -1
			entry.erase("shot_pose")
	var previous := int(entry["last_shot"])
	var fired := (previous >= 0 and previous != shot_sequence) or (previous < 0 and shot_sequence > 0 and feedback > 0.0)
	if fired:
		entry["fire_start"] = time
		entry["active_port"] = posmod(shot_sequence, 2)
		entry["smoke_starts"][entry["active_port"]] = time
	entry["last_shot"] = shot_sequence
	entry["last_time"] = time
	var age := maxf(0.0, time - float(entry["fire_start"]))
	var heavy: bool = entry["type"] == "cannon"
	var machine_gun: bool = entry["type"] == "arrow"
	var duration := 0.11 if heavy else (0.12 if machine_gun else 0.085)
	var recovery := 0.34 if heavy else (0.075 if machine_gun else 0.14)
	var kick := age / 0.018 if age < 0.018 else pow(clampf(1.0 - (age - 0.018) / recovery, 0.0, 1.0), 2.0)
	entry["barrel"].position.z = float(entry["barrel_rest_z"]) - kick * (0.12 if heavy else (0.025 if machine_gun else 0.045))
	if fired and (heavy or machine_gun or entry["type"] == "magic"):
		var muzzle: Node3D = entry["muzzle"]
		var pose := muzzle.global_transform.orthonormalized()
		pose.origin = muzzle.to_global(Vector3((0.062 if int(entry["active_port"]) == 1 else -0.062) if machine_gun else 0.0, 0.0, 0.018))
		entry["shot_pose"] = pose
	if entry.has("fire_effect"):
		if fired:
			entry["fire_effect"].fire(entry["muzzle"], time, shot_sequence)
		entry["fire_effect"].update_turret(entry["flame_port"], entry["muzzle"], time)
		return
	if machine_gun:
		# 최신 조준·반동 위치에서 이번 한 발만 기록. 건너뛴 순번은 재연하지 않음.
		if fired:
			entry["muzzle_effect"].fire(entry["muzzle"], time, shot_sequence)
		entry["muzzle_effect"].update_effect(entry["muzzle"], time, camera)
		return
	for index in range(2):
		var flash: MeshInstance3D = entry["flashes"][index]
		flash.visible = index == int(entry["active_port"]) and age < duration
		if flash.visible:
			var progress := age / duration
			flash.set_frame(floori(progress * 8.0), (1.0 - progress * 0.65) * (0.95 if heavy else 0.8))
			var growth := 0.8 + sin(progress * PI) * 0.35
			flash.display_size = Vector2(0.60 if heavy else (0.90 if machine_gun else 0.26), 0.29 if heavy else (0.70 if machine_gun else 0.18)) * growth
		var smoke: MeshInstance3D = entry["smokes"][index]
		var smoke_age := time - float(entry["smoke_starts"][index])
		var smoke_duration := 0.60 if heavy else (0.65 if machine_gun else 0.36)
		smoke.visible = smoke_age >= 0.0 and smoke_age < smoke_duration
		if smoke.visible:
			var progress := smoke_age / smoke_duration
			var opacity := 0.85 * (1.0 - progress * 0.35) if machine_gun else (0.35 if heavy else 0.17) * (1.0 - progress)
			smoke.set_frame(floori(progress * 8.0), opacity)
			smoke.display_angle = 0.18 * sin(float(index) + progress)
			smoke.position.y = 0.02 + progress * (0.17 if heavy else 0.09)
			smoke.position.z = 0.06 + progress * (0.14 if heavy else 0.07)
			var size := (0.25 if heavy else (0.80 if machine_gun else 0.11)) * (1.0 + progress * 1.4)
			smoke.display_size = Vector2(size, size)
	_update_weapon_camera(entry)


func _update_weapon_camera(entry: Dictionary) -> void:
	if entry.has("fire_effect"):
		return
	if entry.has("muzzle_effect"):
		entry["muzzle_effect"].update_camera(camera)
		return
	var muzzle: Node3D = entry["muzzle"]
	var source := camera.unproject_position(muzzle.global_position)
	var target := camera.unproject_position(muzzle.to_global(Vector3.BACK))
	var direction := target - source
	for flash: MeshInstance3D in entry["flashes"]:
		flash.display_angle = atan2(-direction.y, direction.x)
		flash.update_camera(camera)
	for smoke: MeshInstance3D in entry["smokes"]:
		smoke.update_camera(camera)


func _sync_enemies(units: Array) -> void:
	var time := _time
	# 공통 GPU 입자 시계는 전투 프레임마다 한 번만 전달한다.
	EnemyBurn.set_time(time)
	var alive := {}
	for data: Array in units:
		var id := int(data[0])
		var type := str(data[7]) if data.size() > 7 else "tank"
		if not ENEMY_MODELS.has(type):
			failure.emit("스테이지 1에서 지원하지 않는 적: %s" % type)
			continue
		alive[id] = true
		if enemies.has(id) and enemies[id]["type"] != type:
			enemies[id]["root"].free()
			enemies.erase(id)
		if not enemies.has(id):
			var model: Node3D = ENEMY_MODELS[type].instantiate()
			_prepare_vertex_colors(model)
			world.add_child(model)
			enemies[id] = {"root": model, "type": type}
		var root: Node3D = enemies[id]["root"]
		# 전투 판정의 기존 slowed 필드를 사용하며 부유·회전·크기는 원본 부모를 따른다.
		EnemyFrost.apply(enemies[id], data.size() > 9 and bool(data[9]))
		# Diagnostic A/B switch: visual only; incoming combat burn state stays intact.
		EnemyBurn.apply(enemies[id], data.size() > 8 and bool(data[8]) and bool(options.get("burn_effects", true)), time)
		var hover := 0.025 if type in ["normal", "fast", "shielded"] else 0.008
		root.position = Vector3(float(data[1]) - columns / 2.0, sin(float(data[4])) * hover, float(data[2]) - rows / 2.0)
		root.rotation.y = PI / 2.0 - float(data[3])
		root.scale = Vector3.ONE * float(data[5])
	for id in enemies.keys():
		if not alive.has(id):
			enemies[id]["root"].free()
			enemies.erase(id)


func _sync_build_preview(data) -> void:
	var type := str(data[6]) if data is Array and data.size() > 6 else "cannon"
	if not _build_preview.is_empty() and (data == null or _build_preview["type"] != type):
		_build_preview["root"].free()
		_build_preview.clear()
	if not (data is Array) or data.size() < 6:
		return
	if not TURRET_MODELS.has(type):
		failure.emit("지원하지 않는 건설 미리보기 포탑: %s" % type)
		return
	if _build_preview.is_empty():
		_build_preview = _new_turret(type)
		for mesh: GeometryInstance3D in _build_preview["root"].find_children("*", "GeometryInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_preview["root"].position = Vector3(float(data[1]) - columns / 2.0, 0.10 + sin(_time * 3.0) * 0.02, float(data[2]) - rows / 2.0)
	_build_preview["head"].rotation.y = 0.0 if type == "frost" else PI / 2.0 - float(data[3])
	_build_preview["barrel"].position.z = _build_preview["barrel_rest_z"]
	if _build_preview.has("fire_effect"):
		_build_preview["fire_effect"].update_turret(_build_preview["flame_port"], _build_preview["muzzle"], _time)
