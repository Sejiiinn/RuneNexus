extends CanvasLayer
const RuntimeProfile = preload("res://app/runtime_profile.gd")

## 포탑과 같은 Godot 프레임의 화면 정면 배지. 그림은 기존 Flutter 배지를 재사용한다.
const ATLAS = preload("res://assets/ui/turret_levels.png")
const ATLAS_PIXELS_PER_TILE := 256.0
var badges := {}
var _poses := {}
var _camera_key: Array = []
var _pixels_per_tile := 0.0


static func base_bounds(node: Node3D, head: Node3D, parent_pose := Transform3D.IDENTITY) -> AABB:
	var pose: Transform3D = parent_pose * node.transform
	var bounds := AABB(pose.origin, Vector3.ZERO)
	if node is MeshInstance3D:
		bounds = pose * node.get_aabb()
	for child in node.get_children():
		if child is Node3D and child != head:
			bounds = bounds.merge(base_bounds(child, head, pose))
	return bounds


func clear() -> void:
	for badge: Sprite2D in badges.values():
		badge.free()
	badges.clear()
	_poses.clear()
	_camera_key.clear()


func update(camera: Camera3D, turrets: Dictionary, enabled: bool) -> void:
	visible = enabled
	for id in badges.keys():
		if not turrets.has(id):
			badges[id].free()
			badges.erase(id)
			_poses.erase(id)
	if not enabled:
		return
	var camera_key := [camera.get_camera_transform(), camera.get_camera_projection(), camera.get_viewport().get_visible_rect()]
	var camera_changed := camera_key != _camera_key
	if camera_changed:
		_camera_key = camera_key
		_pixels_per_tile = camera.unproject_position(Vector3.RIGHT).distance_to(camera.unproject_position(Vector3.ZERO))
	var pixels_per_tile := _pixels_per_tile
	for id in turrets:
		var entry: Dictionary = turrets[id]
		var root: Node3D = entry["root"]
		if not badges.has(id):
			var badge := Sprite2D.new()
			RuntimeProfile.tag_canvas(badge, "badges")
			badge.texture = ATLAS
			badge.hframes = 10
			badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(badge)
			badges[id] = badge
		var badge: Sprite2D = badges[id]
		badge.visible = root.is_visible_in_tree() and not camera.is_position_behind(root.global_position)
		if not badge.visible:
			_poses.erase(id)
			continue
		badge.frame = clampi(int(entry.get("level", 1)), 1, 10) - 1
		var bounds: AABB = entry["level_bounds"]
		var pose_key := [root.global_transform, bounds]
		if not camera_changed and _poses.get(id, []) == pose_key: continue
		_poses[id] = pose_key
		badge.scale = Vector2.ONE * pixels_per_tile / ATLAS_PIXELS_PER_TILE
		var screen := Rect2(camera.unproject_position(root.global_transform * bounds.position), Vector2.ZERO)
		for corner in range(1, 8):
			screen = screen.expand(camera.unproject_position(root.global_transform * bounds.get_endpoint(corner)))
		# 배지 중심을 고정 받침의 하단보다 살짝 안쪽에 붙인다.
		badge.position = Vector2(screen.get_center().x, screen.end.y - pixels_per_tile * 0.02)
