extends CanvasLayer
## Combat-state adornment in screen pixels, matching the approved 4px dots.
## Kept separate from optional level labels: disabling labels cannot hide charges.
const FrameRows = preload("res://presentation/frame_rows.gd")
var indicators := {}
var _poses := {}
var _camera_key: Array = []

class Dots extends Node2D:
	var charges := 0:
		set(value):
			if charges == value: return
			charges = clampi(value,0,2)
			queue_redraw()
	func _draw() -> void:
		for index in charges:
			var center := Vector2((float(index)-float(charges-1)/2)*6.0,0)
			# Small black Gaussian edge: radius 2.6, sigma 0.6, opacity 0.78.
			for ring in range(12,0,-1):
				var radius := 2.0+float(ring)*0.1
				var alpha := 0.78*exp(-pow((radius-2.0)/0.6,2)/2)*0.18
				draw_circle(center,radius,Color(0,0,0,alpha))
			draw_circle(center,2.0,Color("dfc367"),true,-1,true)

func clear() -> void:
	for indicator in indicators.values(): indicator.free()
	indicators.clear()
	_poses.clear()
	_camera_key.clear()

func update(camera: Camera3D,turrets: Dictionary,enabled: bool) -> void:
	visible = enabled
	for id in indicators.keys():
		if not turrets.has(id):
			indicators[id].free()
			indicators.erase(id)
			_poses.erase(id)
	if not enabled: return
	var camera_key := [camera.get_camera_transform(),camera.get_camera_projection(),camera.get_viewport().get_visible_rect()]
	var changed := camera_key != _camera_key
	_camera_key = camera_key
	for id in turrets:
		var entry: Dictionary = turrets[id]
		var count := clampi(int(entry.get("stockpileCharges",0)),0,2) if bool(entry.get("stockpileEnabled",false)) else 0
		if not indicators.has(id):
			if count==0: continue
			var created := Dots.new()
			add_child(created)
			indicators[id] = created
		var indicator: Dots = indicators[id]
		var root: Node3D = entry.root
		indicator.charges = count
		indicator.visible = count>0 and root.is_visible_in_tree() and not camera.is_position_behind(root.global_position)
		if not indicator.visible:
			_poses.erase(id)
			continue
		var bounds: AABB = entry.get("stockpile_bounds",entry.level_bounds)
		var pose := [root.global_transform,bounds]
		if not changed and _poses.get(id,[]) == pose: continue
		_poses[id] = pose
		var top := INF
		for corner in 8:
			top = minf(top,camera.unproject_position(root.global_transform*bounds.get_endpoint(corner)).y)
		var center: Vector2 = camera.unproject_position(root.global_transform*bounds.get_center())
		indicator.position = Vector2(center.x,top-12.0)
