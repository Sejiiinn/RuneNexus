extends SceneTree
const Labels = preload("res://ui/battlefield_labels.gd")
const Badges = preload("res://ui/turret_level_labels.gd")
const Feedback = preload("res://session/screen_feedback.gd")
var failures := 0
class Runtime extends RefCounted:
	var nexus_alert := 0.0
	var destruction_elapsed := 0.0
	var native := true
	func native_session() -> bool: return native
func _initialize() -> void: call_deferred("verify")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func verify() -> void:
	var scene := Node3D.new(); root.add_child(scene)
	var world := Node3D.new(); scene.add_child(world)
	var camera := Camera3D.new(); scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 12
	camera.position = Vector3(0,10,8); camera.look_at(Vector3.ZERO)
	var labels := Labels.new(); root.add_child(labels)
	var enemy := {"id":1,"position":[4.0,3.0],"size":[26.0,26.0],"hp":40.0,"maxHp":100.0,"armor":30.0,"maxArmor":100.0,"shield":12.0,"maxShield":24.0,"effectTime":0.0,"poisoned":true,"riftMarked":false,"diamondCarrier":true}
	var core := {"position":[4.0,3.0],"progress":0.5,"accent":0xff8ee6ff,"active":false}
	var payload := {"logicalTileSize":48.0,"enemies":[enemy],"core":core}
	labels.apply_frame(payload)
	var label: Node2D = labels.labels[1]
	enemy.hp = 99.0
	check(label.data.hp == 40.0,"Default input snapshot must retain mutation isolation")
	enemy.hp = 40.0
	labels.present(camera,Vector2(8,6),world)
	check(not label.dirty and not label.rift_dirty and not labels.core.dirty,"Visible data flushed")
	labels.apply_frame(payload)
	check(not label.dirty and not label.static_dirty and not label.rift_dirty and not labels.core.dirty,"Unchanged input must not redraw")
	enemy.position = [4.5,3.0]; enemy.effectTime = 1.0
	labels.apply_frame(payload)
	check(not label.dirty and not label.static_dirty and not label.rift_dirty,"Movement and unmarked effect time must not redraw")
	var before: Vector2 = label.position
	labels.present(camera,Vector2(8,6),world)
	check(label.position != before,"Position-only input must project")
	enemy.riftMarked = true
	labels.apply_frame(payload); labels.present(camera,Vector2(8,6),world)
	check(label.rift != null and label.rift.visible,"Rift starts")
	check(label.decoration.get_index() < label.rift.get_index() and label.rift.show_behind_parent and label.decoration.show_behind_parent,"Decoration / rift / bars ordering")
	enemy.effectTime = 2.0
	label.set_data(enemy)
	check(label.rift_dirty and not label.dirty and not label.static_dirty,"Rift animation alone invalidates only rift")
	labels.apply_frame(payload)
	check(not label.rift_dirty and label.rift.data.effectTime == 2.0,"Visible rift queues redraw during apply, before frame_pre_draw")
	enemy.hp = 30.0; core.progress = 0.6
	labels.apply_frame(payload)
	check(not label.dirty and not labels.core.dirty and label.data.hp == 30.0,"Visible health and core queue redraw during apply")
	labels.present(camera,Vector2(8,6),world)
	labels.set_canvas_enabled(false)
	enemy.hp = 20.0; core.progress = 0.75
	labels.apply_frame(payload); labels.present(camera,Vector2(8,6),world)
	check(label.dirty and labels.core.dirty,"Disabled canvas retains pending redraw")
	labels.set_canvas_enabled(true); labels.present(camera,Vector2(8,6),world)
	check(not label.dirty and not labels.core.dirty and label.data.hp == 20.0,"Canvas resume consumes newest data")
	var border: StyleBoxFlat = labels.core.border
	core.progress = 0.9; labels.apply_frame(payload)
	check(labels.core.border == border,"Core style reused across progress")
	enemy.position = [10000.0,10000.0]; enemy.hp = 10.0
	labels.apply_frame(payload); labels.present(camera,Vector2(8,6),world)
	enemy.hp = 9.0
	labels.apply_frame(payload)
	check(not label.visible and label.dirty,"Offscreen label retains dirty state without drawing")
	enemy.position = [4.0,3.0]
	labels.apply_frame(payload); labels.present(camera,Vector2(8,6),world)
	check(label.visible and not label.dirty,"Offscreen return flushes state")
	labels.apply_frame({"enemies":[enemy]}); labels.present(camera,Vector2(8,6),world)
	check(not labels.core.visible,"Missing core hides")
	labels.apply_frame(payload); labels.present(camera,Vector2(8,6),world)
	check(labels.core.visible,"Identical core reappears after absence")
	var rev: int = labels._projection_revision
	labels.present(camera,Vector2(8,6),world)
	check(labels._projection_revision == rev,"Static projection context cached")
	camera.size = 6; labels.present(camera,Vector2(8,6),world)
	check(labels._projection_revision > rev,"Camera projection invalidates cache")
	labels.apply_frame({"enemies":[]})
	check(labels._pool.size() == 1 and not label.visible,"Removed label pooled hidden")
	enemy.id = 2; enemy.riftMarked = false; enemy.poisoned = false; enemy.diamondCarrier = false
	labels.apply_frame(payload,true); labels.present(camera,Vector2(8,6),world)
	check(labels.labels[2] == label and not label.rift.visible and not label.decoration.visible,"Pool reuse resets stale status and ordering")
	check(is_same(label.data,enemy),"Owned snapshot retained without copy")
	var many := []
	for i in 150:
		var item: Dictionary = enemy.duplicate(true); item.id = i + 10; many.append(item)
	labels.apply_frame({"enemies":many}); labels.apply_frame({"enemies":[]})
	check(labels._pool.size() == Labels.MAX_POOLED_LABELS,"Pool bounded")
	labels.clear(); check(labels._pool.is_empty() and labels.labels.is_empty(),"Reset frees pool")
	var badges := Badges.new(); root.add_child(badges)
	var tower := Node3D.new(); world.add_child(tower)
	var towers := {1:{"root":tower,"level":1,"level_bounds":AABB(Vector3(-0.4,0,-0.4),Vector3(0.8,0.5,0.8))}}
	badges.update(camera,towers,true)
	var badge: Sprite2D = badges.badges[1]
	var badge_position := badge.position
	badge.position += Vector2.ONE
	badges.update(camera,towers,true)
	check(badge.position == badge_position + Vector2.ONE,"Static badge does not reproject")
	towers[1].level = 10; badges.update(camera,towers,true)
	check(badge.frame == 9,"Level-only update retains cached projection")
	camera.size = 8; badges.update(camera,towers,true)
	check(badge.position != badge_position + Vector2.ONE,"Camera change reprojects badge")
	tower.hide(); badges.update(camera,towers,true); camera.size = 7; badges.update(camera,towers,true)
	check(not badge.visible and not badges._poses.has(1),"Hidden root skips projection and invalidates pose")
	tower.show(); badges.update(camera,towers,true)
	check(badge.visible and badges._poses.has(1),"Reappearing root projects")
	towers[1].level_bounds.position.x += 1; var position_before := badge.position; badges.update(camera,towers,true)
	check(badge.position != position_before,"Bounds invalidation")
	var old_position := badge.position
	tower.position.x += 1.0; badges.update(camera,towers,true)
	check(badge.position != old_position,"Root transform invalidates projection")
	badges.update(camera,towers,false); check(not badges.visible,"Disabled badge layer hidden")
	camera.size = 9; badges.update(camera,towers,true)
	check(badges.visible and badges._camera_key[1] == camera.get_camera_projection(),"Reenable uses current camera")
	badges.update(camera,{},true); check(badges.badges.is_empty() and badges._poses.is_empty(),"Removal clears cache")
	var feedback := Feedback.new(); root.add_child(feedback)
	var runtime := Runtime.new()
	feedback.update_state(runtime,Vector2(440,760)); check(not feedback.visible,"Zero feedback invisible")
	runtime.nexus_alert = 0.65; feedback.update_state(runtime,Vector2(440,760))
	check(feedback.visible and feedback.material.get_shader_parameter("alert") == 1.0,"Alert restores feedback")
	feedback.material.set_shader_parameter("alert",0.5)
	feedback.update_state(runtime,Vector2(440,760))
	check(feedback.material.get_shader_parameter("alert") == 0.5,"Unchanged uniform is not resent")
	runtime.nexus_alert = 0.0; feedback.update_state(runtime,Vector2(440,760)); check(not feedback.visible,"Alert completion hides feedback")
	runtime.destruction_elapsed = 1.6; feedback.update_state(runtime,Vector2(440,760))
	check(feedback.visible and feedback.material.get_shader_parameter("alert") == 0.0 and feedback.material.get_shader_parameter("fade") == 0.5,"Fade restores and resets stale alert")
	runtime.native = false; feedback.update_state(runtime,Vector2(440,760)); check(not feedback.visible,"Nonnative session hides")
	feedback.free(); badges.free(); labels.free(); scene.free()
	print("Auxiliary display cache verification: %d failures" % failures)
	quit(1 if failures else 0)
