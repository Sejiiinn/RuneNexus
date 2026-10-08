extends RefCounted
## Owns battlefield actor models and their frame-driven weapon/status visuals.
signal failure(message: String)

const StageResources = preload("res://presentation/stage_resources.gd")
const GemOrbit = preload("res://effects/gem_orbit.gd")
const Placement = preload("res://presentation/turret_placement.gd")
const PlacementDust = preload("res://effects/placement_dust.gd")
const TurretLevelLabels = preload("res://ui/turret_level_labels.gd")
const WeaponAtlas = preload("res://effects/weapon_atlas.gd")
const SniperVfx = preload("res://effects/sniper_vfx.gd")
const SniperTargetSurface = preload("res://effects/sniper_target_surface.gd")
const MachineGunMuzzle = preload("res://effects/machinegun_muzzle.gd")
const RunicFire = preload("res://effects/runic_fire.gd")
const FrostTower = preload("res://effects/frost_tower.gd")
const LightningCollar = preload("res://effects/lightning_collar.gdshader")
const EnemyFrost = preload("res://effects/enemy_frost.gd")
const EnemyBurn = preload("res://effects/enemy_burn.gd")
const GuardianPreview = preload("res://presentation/guardian_preview.gd")
const TURRET_MODELS := {
	"arrow": "res://assets/turrets/arrow.glb",
	"cannon": "res://assets/turrets/cannon.glb",
	"magic": "res://assets/turrets/magic.glb",
	"frost": "res://assets/turrets/frost.glb",
	"sniper": "res://assets/turrets/sniper.glb",
	"lightning": "res://assets/turrets/lightning.glb",
}
const ENEMY_MODELS := {
	"normal": "res://assets/enemies/normal.glb",
	"armored": "res://assets/enemies/armored.glb",
	"shielded": "res://assets/enemies/shielded.glb",
	"fast": "res://assets/enemies/fast.glb",
	"tank": "res://assets/enemies/tank.glb",
	"boss": "res://assets/enemies/boss.glb",
	# 실드/HP/상태 표시는 실제 프레임을 유지하고 기존 보스 본체를 공유한다.
	"shieldBoss": "res://assets/enemies/boss.glb",
	"forgeBoss": "res://assets/enemies/boss.glb",
}

var world: Node3D
var camera: Camera3D
var turrets := {}
# Changes only when the rendered turret roots change.
var turret_revision := 0
var enemies := {}
var _gem_selection_revision := -1
var _gem_turret_revision := -1
var _gem_selection: Dictionary = {}
var _gem_orbits: Array[Node3D] = []
var _build_preview := {}
var _placements := Placement.new()
var _placement_dust: PlacementDust
var _time := 0.0
var columns := 8
var rows := 10
var options := {"volume": true}
var _sniper_pose_revision := 0
var _guardian_preview: GuardianPreview



func _init(world_root: Node3D, battlefield_camera: Camera3D) -> void:
	world = world_root
	camera = battlefield_camera
	_guardian_preview = GuardianPreview.new(world)
	_guardian_preview.failure.connect(_forward_guardian_failure)
	_placement_dust = PlacementDust.new()
	_placement_dust.camera = camera
	world.add_child(_placement_dust)
	_placements.began.connect(_placement_dust.begin_cue)
	_placements.ended.connect(_placement_dust.cancel_build)


func _forward_guardian_failure(message: String) -> void:
	failure.emit(message)


func configure(time: float, map_size: Vector2i, frame_options: Dictionary) -> void:
	_time = time
	columns = map_size.x
	rows = map_size.y
	_placement_dust.map_size = map_size
	options = frame_options



func clear() -> void:
	_placements.clear()
	_guardian_preview.clear()
	_gem_selection_revision = -1
	_gem_turret_revision = -1
	_gem_selection = {}
	_gem_orbits.clear()
	if not turrets.is_empty():
		turret_revision += 1
	for collection: Dictionary in [turrets, enemies]:
		for entry: Dictionary in collection.values():
			entry["root"].free()
		collection.clear()
	if not _build_preview.is_empty():
		_build_preview["root"].free()
		_build_preview.clear()


# Static equipment is relayed only on selection/root changes; animation uses
# the authoritative combat clock, including pause, speed and rewind.
func sync_gem_orbits(selection: Dictionary, revision: int, time: float) -> void:
	if revision < 0 or revision != _gem_selection_revision or turret_revision != _gem_turret_revision or not is_same(selection, _gem_selection):
		_gem_selection_revision = revision
		_gem_turret_revision = turret_revision
		_gem_selection = selection
		_gem_orbits.clear()
		var colors_by_id := {}
		for data: Dictionary in selection.get("turrets", []):
			colors_by_id[int(data.get("id", -1))] = data.get("orbitGemColors", [])
		for id in turrets:
			var entry: Dictionary = turrets[id]
			var colors: Array = colors_by_id.get(int(id), [])
			if not colors.is_empty() and not entry.has("gem_orbit"):
				var orbit := GemOrbit.new()
				# Reward silhouettes must not turn translucent trails into opaque holes.
				orbit.set_meta("exclude_selection_mask", true)
				entry["root"].add_child(orbit)
				entry["gem_orbit"] = orbit
			if entry.has("gem_orbit"):
				entry["gem_orbit"].configure(colors)
				if not colors.is_empty(): _gem_orbits.append(entry["gem_orbit"])
	for orbit in _gem_orbits:
		orbit.update_time(time)


func camera_changed() -> void:
	for entry: Dictionary in turrets.values():
		_update_weapon_camera(entry)


func enemy_label_tops() -> Dictionary:
	var tops := {}
	for id in enemies:
		var entry: Dictionary = enemies[id]
		if not entry.has("label_bounds"): continue
		var skeleton: Skeleton3D = entry.label_skeleton
		var pose := skeleton.global_transform * skeleton.get_bone_global_pose(int(entry.label_bone))
		var bounds: AABB = entry.label_bounds
		var top := INF
		for corner in range(8):
			top = minf(top, camera.unproject_position(pose * bounds.get_endpoint(corner)).y)
		tops[id] = top
	return tops


func _prepare_vertex_colors(model: Node) -> void:
	# GLB COLOR_0 보존: 일부 다중 primitive 재질의 누락된 사용 플래그 보정.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var colors = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var material := mesh.get_active_material(surface)
			if colors != null and not colors.is_empty() and material is StandardMaterial3D:
				material.vertex_color_use_as_albedo = true


func _new_turret(type: String) -> Dictionary:
	var root: Node3D = (StageResources.load_resource(TURRET_MODELS[type]) as PackedScene).instantiate()
	if type == "lightning":
		root.scale *= 0.9
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
	if type == "lightning":
		entry["lightning_glow"] = _lightning_materials(root)
		return entry
	if type == "sniper":
		var effect := SniperVfx.new()
		root.add_child(effect)
		effect.configure(barrel,muzzle)
		entry["sniper_effect"] = effect
		entry["aim_state"] = {}
		return entry
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


func _lightning_materials(root: Node3D) -> Array:
	var copies := {}
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null or not (source.resource_name.begins_with("08 |") or source.resource_name.begins_with("06 |") or source.resource_name.begins_with("07 |")): continue
			var key := source.get_instance_id()
			if not copies.has(key):
				if source.resource_name.begins_with("08 |"):
					var material := ShaderMaterial.new()
					material.shader = LightningCollar
					material.set_shader_parameter("base_color", source.albedo_color)
					material.set_shader_parameter("emission_color", source.emission)
					material.set_shader_parameter("metallic", source.metallic)
					material.set_shader_parameter("roughness", source.roughness)
					copies[key] = material
				else:
					copies[key] = source.duplicate()
			mesh.set_surface_override_material(surface, copies[key])
	return copies.values()


func _sync_turrets(units: Array) -> void:
	var membership_changed := false
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
			_placements.remove(id)
			turrets[id]["root"].free()
			turrets.erase(id)
		if not turrets.has(id):
			turrets[id] = _new_turret(type)
			membership_changed = true
		var entry: Dictionary = turrets[id]
		entry["root"].visible = not (type == "magic" and options.get("runic_fire_mode", "all") == "no_model")
		entry["level"] = int(data[7]) if data.size() > 7 else 1
		entry["root"].position = Vector3(float(data[1]) - columns / 2.0, 0.0, float(data[2]) - rows / 2.0)
		_placements.apply_entry(id,entry,columns,rows)
		entry["head"].rotation.y = 0.0 if type == "frost" else PI / 2.0 - float(data[3])
		if type == "frost":
			var state: Dictionary = data[8] if data.size() > 8 and data[8] is Dictionary else {}
			entry["frost_effect"].update_state(_time, int(data[4]), float(data[5]), state, bool(options["volume"]), frost_lights < 4)
			frost_lights += 1
		else:
			if type == "sniper":
				entry["aim_state"] = data[8] if data.size()>8 and data[8] is Dictionary else {}
			_update_fire(entry, int(data[4]), float(data[5]))
	for id in turrets.keys():
		if not alive.has(id):
			_placements.remove(int(id))
			turrets[id]["root"].free()
			turrets.erase(id)
			membership_changed = true
	if membership_changed:
		turret_revision += 1

func confirm_placement(id: int, type: String, x: int, y: int) -> void:
	_placements.queue_build(id,type,x,y)

func update_placements() -> void:
	_placements.update(turrets,columns,rows)
	_placement_dust.update_time()

func cancel_placement(id: int) -> void:
	_placements.remove(id)

func clear_placements() -> void:
	_placements.clear()
	_placement_dust.clear()


func _update_fire(entry: Dictionary, shot_sequence: int, feedback: float) -> void:
	var time := _time
	if entry["type"] == "lightning":
		# Electrical release is driven by native charge/chain events, without gun smoke or recoil.
		entry["barrel"].position.z = float(entry["barrel_rest_z"])
		entry["last_shot"] = shot_sequence
		entry["last_time"] = time
		return
	if time < float(entry["last_time"]):
		entry["fire_start"] = -INF
		entry["smoke_starts"] = [-INF, -INF]
		if entry.has("muzzle_effect"):
			entry["muzzle_effect"].reset()
		if entry.has("fire_effect"):
			entry["fire_effect"].reset()
			entry["last_shot"] = -1
			entry.erase("shot_pose")
		if entry.has("sniper_effect"):
			entry["sniper_effect"].reset()
			entry["last_shot"] = shot_sequence
	var previous := int(entry["last_shot"])
	var fired := (previous >= 0 and previous != shot_sequence) or (previous < 0 and shot_sequence > 0 and feedback > 0.0)
	if entry.has("sniper_effect"):
		fired = previous >= 0 and shot_sequence > previous
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
	if entry.has("sniper_effect"):
		entry["sniper_effect"].update_flash(age)
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
	if entry.has("fire_effect") or entry.has("sniper_effect"):
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


func sync_guardian_events(runtime) -> void:
	_guardian_preview.observe_native(runtime, _time, Vector2i(columns, rows))


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
		var preview := type in ["normal", "fast", "tank"] or type in GuardianPreview.BOSS_KINDS
		if enemies.has(id) and (enemies[id]["type"] != type or bool(enemies[id].get("guardian_preview", false)) != preview):
			enemies[id]["root"].free()
			enemies.erase(id)
		if not enemies.has(id):
			if preview:
				var entry: Dictionary = _guardian_preview.new_walker(type)
				if entry.is_empty(): continue
				enemies[id] = entry
			else:
				var model: Node3D = (StageResources.load_resource(ENEMY_MODELS[type]) as PackedScene).instantiate()
				_prepare_vertex_colors(model)
				world.add_child(model)
				enemies[id] = {"root": model, "type": type}
		var root: Node3D = enemies[id]["root"]
		if preview:
			# The authored rig supplies grounded motion and body-only turning.
			root.position = Vector3(float(data[1]) - columns / 2.0, 0.0, float(data[2]) - rows / 2.0)
			var visual_scale := GuardianPreview.visual_scale(type)
			root.scale = Vector3.ONE * float(data[5]) * visual_scale
			_guardian_preview.update_walker(enemies[id], data, time)
			EnemyFrost.apply(enemies[id], data.size() > 9 and bool(data[9]))
			EnemyBurn.apply(enemies[id], data.size() > 8 and bool(data[8]) and bool(options.get("burn_effects", true)), time)
			continue
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
			_guardian_preview.forget_walker(id)
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


# Called after enemy poses/teleports are current; no previous-frame target position.
func sync_sniper_aim() -> void:
	_sniper_pose_revision += 1
	for entry: Dictionary in turrets.values():
		if not entry.has("sniper_effect"): continue
		var effect: SniperVfx=entry.sniper_effect
		var state: Dictionary=entry.aim_state
		var target: Dictionary=enemies.get(int(state.get("aimTargetId",-1)),{})
		if not bool(state.get("aimActive",false)) or target.is_empty():
			effect.hide_aim();continue
		if not target.has("sniper_surface"):
			target.sniper_surface=SniperTargetSurface.new(target.root, str(target.get("type", "")))
		var surface: SniperTargetSurface=target.sniper_surface
		surface.update_pose(_sniper_pose_revision)
		var from: Vector3=entry.barrel.to_global(SniperVfx.LENS_ORIGIN)
		effect.show_aim(surface.first_hit(from,surface.aim_point()),float(state.get("aimRatio",0.0)),_time)


func retain_stage(enemy_types: Array) -> void:
	_guardian_preview.retain_stage(enemy_types)
