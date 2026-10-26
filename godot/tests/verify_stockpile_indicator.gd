extends SceneTree
const FrameRows = preload("res://presentation/frame_rows.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(condition: bool,message: String) -> void:
	if not condition: failures.append(message)
func run() -> void:
	root.content_scale_size = Vector2i(440,760)
	root.size = Vector2i(440,900)
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.options.turret_levels = true
	var frame: Dictionary = FrameRows.serialized(scene.last_frame.duplicate(true))
	var first: Array = frame.turrets[0]
	frame.enemies = []
	frame.turrets = [first]
	first[6] = "sniper"
	first[7] = 11
	if first.size()<9: first.append({})
	first[8] = {"stockpileEnabled":true,"stockpileCharges":2,"stockpileIdleElapsed":0.5,"stockpileChargeInterval":2.0}
	scene.options.zoom = 1.6
	scene.apply_frame(frame)
	scene.apply_options()
	scene._report_presentation()
	var id := int(first[0])
	var overlay = scene._stockpile_indicator
	check(overlay.indicators.has(id),"production turret receives stockpile state")
	check(overlay.indicators[id].charges==2 and overlay.indicators[id].visible,"two charges show two dots")
	check(scene._turret_level_labels.badges[id].level==11,"real Lv11 label state")
	var roundtrip := FrameRows.Turret.from_array(first).to_array()
	check(roundtrip[8]==first[8],"frame extension roundtrip retains stockpile state")
	var position: Vector2 = overlay.indicators[id].position
	frame.turrets[0][3] += 1.0
	scene.apply_frame(frame)
	scene._report_presentation()
	check(overlay.indicators[id].position==position,"indicator anchor ignores aim rotation")
	scene.options.turret_levels = false
	scene._report_presentation()
	check(overlay.visible and overlay.indicators[id].visible,"stockpile independent of level-label preference")
	for count in [1,0,2]:
		frame.turrets[0][8].stockpileCharges = count
		scene.apply_frame(frame)
		scene._report_presentation()
		check(overlay.indicators[id].charges==count,"live charge count %d" % count)
		check(overlay.indicators[id].visible==(count>0),"zero hides all dots")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var path := OS.get_environment("RUNE_TREE_CAPTURE_DIR")
			if not path.is_empty():
				DirAccess.make_dir_recursive_absolute(path)
				root.get_texture().get_image().save_png(path.path_join("stockpile-%d.png" % count))
	var before_hidden: Vector2 = overlay.indicators[id].position
	frame.turrets[0][8].stockpileCharges = 0
	scene.apply_frame(frame); scene._report_presentation()
	scene.camera.position.x += 1.0
	scene._report_presentation()
	frame.turrets[0][8].stockpileCharges = 2
	scene.apply_frame(frame); scene._report_presentation()
	check(overlay.indicators[id].position!=before_hidden,"hidden charge interval invalidates projection for camera changes")
	frame.turrets.remove_at(0)
	scene.apply_frame(frame)
	scene._report_presentation()
	check(not overlay.indicators.has(id),"sold turret clears indicator")
	scene.apply_frame({"reset":true})
	check(overlay.indicators.is_empty(),"stage reset clears indicators")
	print("STOCKPILE_INDICATOR failures=",failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
