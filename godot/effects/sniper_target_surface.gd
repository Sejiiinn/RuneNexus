extends RefCounted
## Read-only rays against the actual rendered mesh. Authored normal/fast skinning
## is rigid (one bone per triangle); cache per-bone BVHs once, sample bone poses.
static var _geometry := {}
static var _geometry_kinds := {}
const AttachmentKind = preload("res://effects/enemy_attachment_kind.gd")
var pieces: Array = []
var _pose_revision := -1
var _aim_point := Vector3.ZERO
var _head_center := Vector3.ZERO
var _body_center := Vector3.ZERO

func _init(root: Node3D, kind: String = "") -> void:
	for instance: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if instance.mesh == null or instance.has_meta("exclude_selection_mask"): continue
		var skeleton: Skeleton3D = instance.get_node_or_null(instance.skeleton) as Skeleton3D
		var skin: Skin = instance.skin
		var key := instance.mesh.get_instance_id()
		_geometry_kinds[key] = AttachmentKind.resolve(kind)
		if not _geometry.has(key): _geometry[key] = _prepare(instance.mesh, skeleton != null and skin != null)
		for group: Dictionary in _geometry[key]:
			var bind := int(group.bind)
			var bone := -1
			if bind >= 0 and skeleton != null and skin != null:
				bone = skin.get_bind_bone(bind)
				if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(bind))
			pieces.append({"instance":instance,"skeleton":skeleton,"skin":skin,"bind":bind,"bone":bone,"mesh":group.mesh,"bounds":group.bounds,"head":bone>=0 and skeleton.get_bone_name(bone).to_lower()=="head"})

static func _prepare(mesh: Mesh, skinned: bool) -> Array:
	var by_bind := {}
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if skinned else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if skinned else PackedFloat32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		var influences: int = weights.size()/vertices.size() if skinned else 0
		for offset in range(0,count,3):
			var vertex := indices[offset] if not indices.is_empty() else offset
			var bind := -1
			if skinned:
				var strongest := 0
				for influence in range(influences):
					if weights[vertex*influences+influence] > weights[vertex*influences+strongest]: strongest=influence
				bind=bones[vertex*influences+strongest]
			if not by_bind.has(bind): by_bind[bind]=PackedVector3Array()
			var faces: PackedVector3Array=by_bind[bind]
			for corner in range(3): faces.append(vertices[indices[offset+corner] if not indices.is_empty() else offset+corner])
			by_bind[bind]=faces
	var result := []
	for bind in by_bind:
		var faces: PackedVector3Array=by_bind[bind]
		var triangle := TriangleMesh.new();triangle.create_from_faces(faces)
		var bounds := AABB(faces[0],Vector3.ZERO)
		for point in faces: bounds=bounds.expand(point)
		result.append({"bind":bind,"mesh":triangle,"bounds":bounds})
	return result

func _pose(piece: Dictionary) -> Transform3D:
	if int(piece.bone)>=0:
		return piece.skeleton.global_transform * piece.skeleton.get_bone_global_pose(piece.bone) * piece.skin.get_bind_pose(piece.bind)
	return piece.instance.global_transform

func update_pose(revision: int) -> void:
	if revision == _pose_revision: return
	_pose_revision=revision
	var merged := AABB()
	var first := true
	var head_point := Vector3.INF
	var head_center := Vector3.INF
	for piece: Dictionary in pieces:
		piece.pose=_pose(piece)
		piece.inverse=piece.pose.affine_inverse()
		var box: AABB=piece.pose*piece.bounds
		if piece.head:
			head_point=box.position+box.size*Vector3(.5,.72,.5)
			head_center=box.get_center()
		merged=box if first else merged.merge(box);first=false
	_aim_point=head_point if head_point.is_finite() else merged.position+merged.size*Vector3(.5,.80,.5)
	_body_center = merged.get_center()
	_head_center = head_center if head_center.is_finite() else _body_center

func aim_point() -> Vector3:
	return _aim_point

# Optional read-only alternatives for lightning when the high aiming point is
# between ears/open armor. The sniper's existing aim and ray contract is unchanged.
func head_center() -> Vector3:
	return _head_center

func body_center() -> Vector3:
	return _body_center

func first_hit(from: Vector3, toward: Vector3) -> Vector3:
	var direction := (toward-from).normalized()
	var to := toward + direction*2.0
	var nearest := INF
	var point := Vector3.INF
	for piece: Dictionary in pieces:
		if not piece.instance.is_visible_in_tree(): continue
		var pose: Transform3D=piece.pose
		var inverse: Transform3D=piece.inverse
		var a := inverse*from;var b := inverse*to
		var local_direction := (b-a).normalized()
		if piece.bounds.intersects_ray(a,local_direction)==null: continue
		# Segment traversal can miss a shared-edge entry after float32 transform.
		# Ray traversal keeps the nearest face; restrict hits to this target segment.
		var hit: Dictionary = piece.mesh.intersect_ray(a,local_direction)
		if hit.is_empty(): continue
		var world: Vector3 = pose*hit.position
		if from.distance_squared_to(world)>from.distance_squared_to(to): continue
		var distance := from.distance_squared_to(world)
		if distance<nearest: nearest=distance;point=world
	return point-direction*.00025 if point.is_finite() else Vector3.INF


static func retain_stage(enemy_types: Array, tower_types: Array) -> void:
	var kinds := {}
	for kind: String in enemy_types: kinds[AttachmentKind.resolve(kind)] = true
	for key in _geometry.keys():
		if (not "sniper" in tower_types and not "lightning" in tower_types) or not kinds.has(_geometry_kinds.get(key, "")):
			_geometry.erase(key)
			_geometry_kinds.erase(key)
