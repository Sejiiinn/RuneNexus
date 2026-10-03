extends RefCounted
## Adapts authoritative visual-event snapshots to pooled spatial lightning.
## Presentation only: never advances combat, rolls RNG, or applies damage.
const Lightning = preload("res://effects/lightning_attack.gd")
const TargetSurface = preload("res://effects/sniper_target_surface.gd")
const EffectFormat = preload("res://combat/effect_presentation.gd")
const MAX_IDLE_POOL := 32
const MAX_LIGHTS := 3
var world: Node3D
var active := {}
var pool: Array[Node3D] = []
var lights: Array[OmniLight3D] = []
var _pose_revision := 0
var _last_glow := {}
var _anchors := {}

func _init(parent_world: Node3D) -> void:
	world = parent_world

static func handles(effect: Dictionary) -> bool:
	# Explicit native ownership avoids reinterpreting old generic Canvas fixtures.
	return EffectFormat.is_spatial_lightning(effect)

func _acquire(id: int) -> Node3D:
	if active.has(id): return active[id]
	var effect: Node3D = pool.pop_back() if not pool.is_empty() else Lightning.new()
	if effect.get_parent() == null:
		world.add_child(effect)
		effect.set_meta("exclude_selection_mask", true)
	active[id] = effect
	return effect

func _release(id: int) -> void:
	var effect: Node3D = active[id]
	active.erase(id)
	_anchors.erase(id)
	effect.reset()
	if pool.size() < MAX_IDLE_POOL: pool.append(effect)
	else: effect.free()

func _position(point: Array, map_size: Vector2, height := .35) -> Vector3:
	return world.to_global(Vector3(float(point[0]) - map_size.x / 2.0, height, float(point[1]) - map_size.y / 2.0))

func _surface(id: int, enemies: Dictionary):
	var entry: Dictionary = enemies.get(id, {})
	if entry.is_empty() or not is_instance_valid(entry.get("root")): return null
	if not entry.has("lightning_surface"):
		entry["lightning_surface"] = TargetSurface.new(entry.root)
	var surface = entry.lightning_surface
	surface.update_pose(_pose_revision)
	return surface

func _contact(id: int, from: Vector3, fallback: Vector3, enemies: Dictionary) -> Vector3:
	var surface = _surface(id, enemies)
	if surface == null: return fallback
	var toward: Vector3 = surface.aim_point()
	var hit: Vector3 = surface.first_hit(from, toward)
	if not hit.is_finite(): hit = surface.first_hit(from, surface.head_center())
	if not hit.is_finite(): hit = surface.first_hit(from, surface.body_center())
	return hit if hit.is_finite() else toward

func _charge_pose(entry: Dictionary) -> Transform3D:
	var muzzle: Node3D = entry.muzzle
	var pose := muzzle.global_transform.orthonormalized()
	# Approved Blender charge center relative to the exported runtime muzzle.
	pose.origin = muzzle.to_global(Vector3(0, .034, .274))
	return pose

func _update_glow(turrets: Dictionary, values: Dictionary) -> void:
	for id in turrets:
		var entry: Dictionary = turrets[id]
		if entry.get("type") != "lightning": continue
		var strength := float(values.get(id, 0.0))
		var previous: Dictionary = _last_glow.get(id, {})
		var root_id: int = entry.root.get_instance_id()
		if int(previous.get("root", -1)) == root_id and is_equal_approx(float(previous.get("value", -1.0)), strength): continue
		_last_glow[id] = {"root":root_id, "value":strength}
		for material in entry.get("lightning_glow", []):
			if material is ShaderMaterial:
				material.set_shader_parameter("charge", strength)
			elif material is StandardMaterial3D:
				material.emission_energy_multiplier = .24 + strength * 2.1
	for id in _last_glow.keys():
		if not turrets.has(id): _last_glow.erase(id)

func _offer_light(samples: Array, point: Vector3, energy: float, reach: float, priority: float) -> void:
	if energy <= .01: return
	var sample := [point, energy, reach, priority]
	# Avoid stacking several bright lamps on one enemy when chains overlap.
	for index in samples.size():
		if point.distance_squared_to(samples[index][0]) < .36:
			if float(samples[index][3]) >= priority: return
			samples.remove_at(index)
			break
	var insert_at := samples.size()
	for index in samples.size():
		if priority > float(samples[index][3]):
			insert_at = index
			break
	if insert_at >= MAX_LIGHTS: return
	samples.insert(insert_at, sample)
	if samples.size() > MAX_LIGHTS: samples.pop_back()

func _update_lights(samples: Array, enabled: bool) -> void:
	# Three shared shadowless lamps across the whole battlefield, not per shot.
	# New impacts take priority over source/charge illumination.
	if enabled and not samples.is_empty() and lights.is_empty():
		for index in MAX_LIGHTS:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(.52, .46, 1.0)
			lamp.omni_attenuation = 1.3
			lamp.shadow_enabled = false
			world.add_child(lamp)
			lights.append(lamp)
	for index in lights.size():
		var lamp: OmniLight3D = lights[index]
		lamp.visible = enabled and index < samples.size()
		if lamp.visible:
			lamp.global_position = samples[index][0]
			lamp.force_update_transform()
			lamp.light_energy = float(samples[index][1])
			lamp.omni_range = float(samples[index][2])

func present(items: Array, turrets: Dictionary, enemies: Dictionary, map_size: Vector2, enabled: bool, volume_enabled: bool) -> void:
	_pose_revision += 1
	var alive := {}
	var glow := {}
	var light_samples: Array = []
	if enabled:
		for item: Dictionary in items:
			if not handles(item): continue
			var kind := str(item.get("kind", ""))
			# Each native chain owns its impact; suppress the duplicate Canvas impact.
			if kind == "impact": continue
			var duration := maxf(.001, float(item.get("duration", .28)))
			var age := float(item.get("age", 0.0))
			if age < 0 or age >= duration: continue
			var owner := int(item.get("ownerId", -1))
			var entry: Dictionary = turrets.get(owner, {})
			var id := int(item.get("id", -1))
			if id < 0: continue
			if kind == "charge":
				if entry.is_empty() or entry.get("type") != "lightning": continue
				var effect := _acquire(id)
				var pose := _charge_pose(entry)
				var muzzle: Node3D = entry.muzzle
				var electrodes := PackedVector3Array([muzzle.to_global(Vector3(-.213, 0, 0)), muzzle.to_global(Vector3(.213, 0, 0))])
				if effect.has_method("set_volume_enabled"): effect.set_volume_enabled(volume_enabled)
				effect.sample_charge(pose, age, duration, id, electrodes)
				alive[id] = true
				glow[owner] = maxf(float(glow.get(owner, 0)), clampf(age / duration, 0, 1))
				_offer_light(light_samples, pose.origin, .30 + .85 * age / duration, 1.05, age / duration)
			else:
				var points: Array = item.get("points", [])
				if points.size() < 2: continue
				var source := _position(points[0], map_size)
				var target := _position(points[-1], map_size)
				var source_id := int(item.get("sourceTargetId", -1))
				var previous: Dictionary = _anchors.get(id, {})
				var owner_root := int(previous.get("owner_root", -1))
				if source_id < 0:
					if entry.get("type", "") == "lightning" and (previous.is_empty() or owner_root == entry.root.get_instance_id()):
						source = _charge_pose(entry).origin
						owner_root = entry.root.get_instance_id()
					elif previous.has("source"):
						source = world.to_global(previous.source)
					else:
						# A coalesced event with no remaining owner has no real muzzle.
						continue
				var ids: Array = item.get("targetIds", [])
				var target_id := int(ids[-1]) if not ids.is_empty() else -1
				if previous.has("target") and not enemies.has(target_id): target = world.to_global(previous.target)
				target = _contact(target_id, source, target, enemies)
				if source_id >= 0:
					if previous.has("source") and not enemies.has(source_id): source = world.to_global(previous.source)
					source = _contact(source_id, target, source, enemies)
				var effect := _acquire(id)
				if effect.has_method("set_volume_enabled"): effect.set_volume_enabled(volume_enabled)
				effect.sample_discharge(source, target, age, duration, id, .95 if source_id >= 0 else 1.0)
				alive[id] = true
				_anchors[id] = {"source":world.to_local(source), "target":world.to_local(target), "owner_root":owner_root}
				var progress := age / duration
				var flash := pow(maxf(0.0, 1.0 - progress), 1.8)
				# Move the lamp outside the contact surface so it illuminates the
				# enemy, its neighbors and the ground, not the interior of a mesh.
				var incoming := (source - target).normalized()
				var impact_light := target + incoming * .16 + Vector3.UP * .12
				_offer_light(light_samples, impact_light, 4.8 * flash, 1.65, 100.0 + flash)
				if source_id < 0:
					glow[owner] = maxf(float(glow.get(owner, 0)), maxf(0, 1 - age / .18))
					_offer_light(light_samples, source, 2.7 * flash, 1.35, 10.0 + flash)
	for id in active.keys():
		if not alive.has(id): _release(id)
	_update_glow(turrets, glow)
	_update_lights(light_samples, enabled and volume_enabled)

func clear() -> void:
	for effect in active.values():
		if is_instance_valid(effect): effect.free()
	active.clear()
	for effect in pool:
		if is_instance_valid(effect): effect.free()
	pool.clear()
	for lamp in lights:
		if is_instance_valid(lamp): lamp.free()
	lights.clear()
	_last_glow.clear()
	_anchors.clear()
