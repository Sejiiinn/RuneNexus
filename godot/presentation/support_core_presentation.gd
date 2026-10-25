extends RefCounted
## Support core models, their connection beams and strengthened-turret base
## marks. Rebuilds only when cores, turret tiles or the build preview change;
## per frame it advances one shared shader clock and the floating crystals.
const StageResources = preload("res://presentation/stage_resources.gd")
const SupportCore = preload("res://app/support_core_rules.gd")
const MODEL := "res://assets/turrets/support_core.glb"
const LINK_SHADER = preload("res://effects/support_core_link.gdshader")
const MARK_SHADER = preload("res://effects/support_core_mark.gdshader")
const CRYSTAL_SHADER = preload("res://effects/support_core_crystal.gdshader")
const CRYSTAL_BOB := 0.012
## Beam leaves the cap pane (tile edge side of the core) and lands at the turret foot.
const LINK_START := 0.30
const LINK_END := 0.88
const LINK_HEIGHTS := Vector2(0.095, 0.035)
const LINK_WIDTH := 0.2
## One energy packet per period travels each link; connected arms flash as it
## leaves and the turret ring ripples as it lands (shared by both shaders).
const LINK_PERIOD := 1.4
const ARM_FLASH := 1.3
## Unlit arm glass and channels: dark teal-black, so only connected arms glow.
const ARM_OFF := {"Runes |": Color(0.02, 0.045, 0.05), "Crystal | cap panes": Color(0.03, 0.07, 0.08)}
const GLOW_ENERGY := {"Runes |": 1.8, "Crown |": 1.8, "Crystal | cap panes": 2.0, "Crystal | floating heart": 2.6}
## The floating crystal's shell and shards are clear gem glass (the GLB carries a
## plain fallback); its girdle and lower facets glow less than the crown facets.
const GEM := {"Crystal | floating core sides": {"body_glow": 0.18, "rim_energy": 1.0}, "Crystal | floating core": {}}
## A connected core's crystal heart flares with each packet launch, a little
## stronger than the arms; an unconnected core's heart stays steady.
const HEART := "Crystal | floating heart"
const HEART_FLASH := 1.6

var world: Node3D
var cores := {}
var _links: Array[Node3D] = []
var _marks: Array[Node3D] = []
var _preview: Node3D
var _key: Array = []
var _link_material := ShaderMaterial.new()
var _preview_link_material := ShaderMaterial.new()
var _mark_material := ShaderMaterial.new()
var _link_mesh: ArrayMesh
# Per mesh resource: [surface, grid side] of each arm glow surface.
var _arm_surfaces := {}
# Lit arm material instance id -> its unlit copy.
var _arm_off := {}
# Lit arm material instance id -> [material, resting emission energy].
var _arm_lit := {}
var _gem_materials := {}
# Shared crystal heart material instance id -> its flaring copy for connected cores.
var _heart_flare := {}
# Flaring copy -> resting emission energy.
var _hearts := {}

func _init(world_root: Node3D) -> void:
	world = world_root
	_link_material.shader = LINK_SHADER
	_preview_link_material.shader = LINK_SHADER
	_preview_link_material.set_shader_parameter("intensity", 0.7)
	_mark_material.shader = MARK_SHADER
	for material in [_link_material, _preview_link_material, _mark_material]:
		material.set_shader_parameter("period", LINK_PERIOD)

func clear() -> void:
	for entry: Dictionary in cores.values(): entry.root.free()
	cores.clear()
	_clear_links()
	if is_instance_valid(_preview): _preview.free()
	_preview = null
	_key = []

func _clear_links() -> void:
	for node in _links + _marks:
		if is_instance_valid(node): node.free()
	_links.clear()
	_marks.clear()

## state: run state (supportCores, turrets). preview: tile of a support core
## build preview, or null.
func sync(state: Dictionary, preview: Variant, map_size: Vector2i, time: float) -> void:
	var placed := SupportCore.cores(state)
	var turrets: Array = []
	for turret in state.get("turrets", []): turrets.append([int(turret.id), int(turret.x), int(turret.y)])
	var key := [placed, turrets, preview, map_size]
	if key != _key:
		_key = key.duplicate(true)
		_rebuild(state, placed, preview, map_size)
	for material in [_link_material, _preview_link_material, _mark_material]:
		material.set_shader_parameter("battle_time", time)
	var launch := exp(-fposmod(time / LINK_PERIOD, 1.0) * 6.0)
	for lit: Array in _arm_lit.values():
		lit[0].emission_energy_multiplier = float(lit[1]) * (1.0 + ARM_FLASH * launch)
	for heart: StandardMaterial3D in _hearts:
		heart.emission_energy_multiplier = float(_hearts[heart]) * (1.0 + HEART_FLASH * launch)
	for entry: Dictionary in cores.values(): _animate(entry, time)
	if is_instance_valid(_preview):
		_preview.position.y = 0.10 + sin(time * 3.0) * 0.02
		_animate(_preview.get_meta("entry"), time)

func _animate(entry: Dictionary, time: float) -> void:
	var crystal: Node3D = entry.crystal
	if crystal == null: return
	crystal.position.y = float(entry.rest) + sin(time * 1.7) * CRYSTAL_BOB
	crystal.rotation.y = time * 0.6

func _rebuild(state: Dictionary, placed: Array, preview: Variant, map_size: Vector2i) -> void:
	var alive := {}
	for core in placed:
		var tile := Vector2i(int(core.x), int(core.y))
		alive[tile] = true
		if not cores.has(tile):
			var entry := _new_core()
			if entry.is_empty(): continue
			cores[tile] = entry
		cores[tile].root.position = _world(tile, map_size)
	for tile in cores.keys():
		if not alive.has(tile):
			cores[tile].root.free()
			cores.erase(tile)
	_clear_links()
	var sides := {}
	var lit := {}
	for connection in SupportCore.connections(state):
		_add_link(connection[0], connection[1], map_size, _link_material)
		var mask: Vector4 = sides.get(connection[1], Vector4.ZERO)
		sides[connection[1]] = _with_side(mask, connection[0] - connection[1])
		if not lit.has(connection[0]): lit[connection[0]] = {}
		lit[connection[0]][connection[1] - connection[0]] = true
	for tile in sides: _add_mark(tile, sides[tile], map_size)
	for tile in cores: _light_arms(cores[tile], lit.get(tile, {}))
	if is_instance_valid(_preview) and not preview is Vector2i:
		_preview.free()
		_preview = null
	if preview is Vector2i:
		if not is_instance_valid(_preview):
			var entry := _new_core()
			if not entry.is_empty():
				_preview = entry.root
				for mesh: GeometryInstance3D in _preview.find_children("*", "GeometryInstance3D", true, false):
					mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_preview.set_meta("entry", entry)
		if is_instance_valid(_preview):
			var at: Vector3 = _world(preview, map_size)
			_preview.position = Vector3(at.x, _preview.position.y, at.z)
			var would := {}
			for turret in state.get("turrets", []):
				var tile := Vector2i(int(turret.x), int(turret.y))
				if SupportCore.adjacent(preview.x, preview.y, tile.x, tile.y):
					_add_link(preview, tile, map_size, _preview_link_material)
					would[tile - preview] = true
			_light_arms(_preview.get_meta("entry"), would)

func _world(tile: Vector2i, map_size: Vector2i) -> Vector3:
	return Vector3(tile.x + 0.5 - map_size.x / 2.0, 0.0, tile.y + 0.5 - map_size.y / 2.0)

func _new_core() -> Dictionary:
	var packed = StageResources.load_resource(MODEL)
	if not packed is PackedScene:
		push_error("Support core model is missing")
		return {}
	var root: Node3D = packed.instantiate()
	_prepare_glow(root)
	world.add_child(root)
	var crystal: Node3D = root.find_child("core_crystal", true, false)
	return {"root":root, "crystal":crystal, "rest":crystal.position.y if crystal != null else 0.0, "arms":_arms(root), "hearts":_heart_surfaces(root)}

# [mesh, surface, flaring copy] of each crystal heart surface.
func _heart_surfaces(root: Node3D) -> Array:
	var found := []
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material == null or not material.resource_name.begins_with(HEART): continue
			var key := material.get_instance_id()
			if not _heart_flare.has(key):
				var flare := material.duplicate() as StandardMaterial3D
				_heart_flare[key] = flare
				_hearts[flare] = material.emission_energy_multiplier
			found.append([mesh, surface, _heart_flare[key]])
	return found

# Each arm's glow surfaces with the grid side its arm points to (x right, y down).
func _arms(root: Node3D) -> Array:
	var arms := []
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var key := mesh.mesh.get_instance_id()
		if not _arm_surfaces.has(key):
			var pose := Transform3D.IDENTITY
			var node: Node = mesh
			while node != root:
				pose = (node as Node3D).transform * pose
				node = node.get_parent()
			var found := []
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface)
				if material == null or not material.resource_name.contains("| arm "): continue
				var centre := Vector3.ZERO
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices: centre += vertex
				centre = pose * (centre / maxf(1.0, vertices.size()))
				found.append([surface, Vector2i(signi(roundi(centre.x * 4.0)), 0) if absf(centre.x) > absf(centre.z) else Vector2i(0, signi(roundi(centre.z * 4.0)))])
			_arm_surfaces[key] = found
		for arm in _arm_surfaces[key]:
			arms.append({"mesh":mesh, "surface":arm[0], "side":arm[1], "off":_unlit(mesh.get_active_material(arm[0]))})
	return arms

func _unlit(lit: Material) -> Material:
	var key := lit.get_instance_id()
	if not _arm_off.has(key):
		var off := (lit as StandardMaterial3D).duplicate() as StandardMaterial3D
		off.emission_enabled = false
		off.albedo_color = ARM_OFF["Runes |"] if lit.resource_name.begins_with("Runes |") else ARM_OFF["Crystal | cap panes"]
		_arm_off[key] = off
		_arm_lit[key] = [lit, (lit as StandardMaterial3D).emission_energy_multiplier]
	return _arm_off[key]

## Only arms facing a connected turret glow; the rest stay dark.
func _light_arms(entry: Dictionary, sides: Dictionary) -> void:
	for arm: Dictionary in entry.get("arms", []):
		arm.mesh.set_surface_override_material(arm.surface, null if sides.has(arm.side) else arm.off)
	for heart: Array in entry.get("hearts", []):
		heart[0].set_surface_override_material(heart[1], null if sides.is_empty() else heart[2])

# Emission is exported at strength 1; the game lifts it to the concept's glow.
# The imported materials are shared by every instance, so this runs once.
func _prepare_glow(root: Node3D) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material == null or material.has_meta("support_core_glow"): continue
			var gem := _gem(material.resource_name)
			if gem != null:
				mesh.mesh.surface_set_material(surface, gem)
				continue
			var prefix := ""
			for key: String in GLOW_ENERGY:
				if material.resource_name.begins_with(key) and key.length() > prefix.length(): prefix = key
			if prefix.is_empty(): continue
			material.emission_enabled = true
			material.emission_energy_multiplier = float(GLOW_ENERGY[prefix])
			material.set_meta("support_core_glow", true)


func _gem(material_name: String) -> ShaderMaterial:
	var prefix := ""
	for key: String in GEM:
		if material_name.begins_with(key) and key.length() > prefix.length(): prefix = key
	if prefix.is_empty(): return null
	if not _gem_materials.has(prefix):
		var gem := ShaderMaterial.new()
		gem.shader = CRYSTAL_SHADER
		for parameter: String in GEM[prefix]: gem.set_shader_parameter(parameter, GEM[prefix][parameter])
		_gem_materials[prefix] = gem
	return _gem_materials[prefix]

func _with_side(mask: Vector4, toward: Vector2i) -> Vector4:
	if toward.x > 0: mask.x = 1.0
	elif toward.x < 0: mask.y = 1.0
	elif toward.y > 0: mask.z = 1.0
	else: mask.w = 1.0
	return mask

func _add_link(core: Vector2i, turret: Vector2i, map_size: Vector2i, material: ShaderMaterial) -> void:
	var node := MeshInstance3D.new()
	node.name = "SupportCoreLink"
	node.mesh = _link()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("exclude_selection_mask", true)
	var direction := Vector2(turret - core)
	node.position = _world(core, map_size) + Vector3(direction.x, 0.0, direction.y) * LINK_START
	node.rotation.y = atan2(-direction.y, direction.x)
	world.add_child(node)
	_links.append(node)

func _add_mark(tile: Vector2i, sides: Vector4, map_size: Vector2i) -> void:
	var node := MeshInstance3D.new()
	node.name = "SupportCoreMark"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	node.mesh = plane
	node.material_override = _mark_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_instance_shader_parameter("sides", sides)
	node.set_meta("exclude_selection_mask", true)
	node.position = _world(tile, map_size) + Vector3(0.0, 0.025, 0.0)
	world.add_child(node)
	_marks.append(node)

# Two crossed ribbons along +X: one flat, one upright, so the beam keeps its
# width from both the fixed and the drone camera.
func _link() -> ArrayMesh:
	if _link_mesh != null: return _link_mesh
	var length := LINK_END - LINK_START
	var half := LINK_WIDTH * 0.5
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for upright in [false, true]:
		var base := vertices.size()
		for along in [0.0, 1.0]:
			var height: float = lerpf(LINK_HEIGHTS.x, LINK_HEIGHTS.y, along)
			for across in [0.0, 1.0]:
				var offset: float = (float(across) - 0.5) * 2.0 * half
				vertices.append(Vector3(along * length, height + (offset if upright else 0.0), 0.0 if upright else offset))
				uvs.append(Vector2(along, across))
		indices.append_array([base, base + 2, base + 1, base + 1, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_link_mesh = ArrayMesh.new()
	_link_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _link_mesh
