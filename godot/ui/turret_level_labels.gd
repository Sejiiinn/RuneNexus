extends CanvasLayer

## 포탑과 같은 Godot 프레임의 화면 정면 배지. 그림은 기존 Flutter 배지를 재사용한다.
const ATLAS = preload("res://assets/ui/turret_levels.png")
const ATLAS_PIXELS_PER_TILE := 256.0
var badges := {}


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


func update(camera: Camera3D, turrets: Dictionary, enabled: bool) -> void:
	visible = enabled
	for id in badges.keys():
		if not turrets.has(id):
			badges[id].free()
			badges.erase(id)
	if not enabled:
		return
	var pixels_per_tile := camera.unproject_position(Vector3.RIGHT).distance_to(camera.unproject_position(Vector3.ZERO))
	for id in turrets:
		var entry: Dictionary = turrets[id]
		var root: Node3D = entry["root"]
		if not badges.has(id):
			var badge := Sprite2D.new()
			badge.texture = ATLAS
			badge.hframes = 10
			badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(badge)
			badges[id] = badge
		var badge: Sprite2D = badges[id]
		badge.visible = root.is_visible_in_tree() and not camera.is_position_behind(root.global_position)
		badge.frame = clampi(int(entry.get("level", 1)), 1, 10) - 1
		badge.scale = Vector2.ONE * pixels_per_tile / ATLAS_PIXELS_PER_TILE
		var bounds: AABB = entry["level_bounds"]
		var screen := Rect2(camera.unproject_position(root.global_transform * bounds.position), Vector2.ZERO)
		for corner in range(1, 8):
			screen = screen.expand(camera.unproject_position(root.global_transform * bounds.get_endpoint(corner)))
		# 배지 중심을 고정 받침의 하단보다 살짝 안쪽에 붙인다.
		badge.position = Vector2(screen.get_center().x, screen.end.y - pixels_per_tile * 0.02)
