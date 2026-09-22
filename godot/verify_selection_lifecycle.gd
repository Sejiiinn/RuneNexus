extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _verify() -> void:
	var overlay = load("res://ui/battlefield_selection.gd").new()
	root.add_child(overlay)
	await process_frame
	var turret := {"position": [2.5, 3.5], "level": 8, "phaseOrigin": -0.25,
		"gemColors": [0xff00aaff], "range": 3.0, "selected": true}
	var state := {"logicalTileSize": 48.0, "visualScale": 1.0,
		"rewardTargeting": false, "turrets": [turret], "tiles": [], "rewardTargets": []}
	overlay.apply_frame({"revision": 1, "state": state, "clock": 2.0, "time": 10.0,
		"aim": [[0, 4.0, 5.0, 0.5]], "viewport": [480, 800]})
	_check(overlay.has_frame() and overlay.selection_revision == 1, "Static state not applied")
	_check(is_equal_approx(overlay.animation_phase(turret), 0.65), "Initial phase changed")
	overlay.apply_frame({"revision": 1, "clock": 6.0, "time": 11.0, "aim": [], "viewport": [600, 900]})
	_check(is_equal_approx(overlay.animation_phase(turret), 2.45), "4x combat clock phase")
	_check(overlay._frame["turrets"][0] == turret, "Static state lost without retransmission")
	_check(overlay._frame["viewport"] == [600, 900] and overlay._aim.is_empty(), "Resize / cleared aim retained stale values")
	overlay.apply_frame({"revision": 1, "clock": 6.0, "time": 12.0})
	_check(is_equal_approx(overlay.animation_phase(turret), 2.45), "Pause advances phase")
	state["rewardTargeting"] = true
	state["rewardTargets"] = [{"position": [2.5, 3.5], "requiresReplacement": true}]
	overlay.apply_frame({"revision": 2, "state": state, "clock": 6.0, "time": 13.0})
	_check(overlay.reward_targeting(), "Reward state not applied")
	_check(is_equal_approx(overlay.animation_phase(turret), 2.45), "Reward resets phase")
	overlay.clear()
	overlay.apply_frame({"revision": 2, "clock": 6.0})
	_check(not overlay.has_frame() and overlay.selection_revision == -1, "Lost cache falsely owns selection")
	overlay.apply_frame({"revision": 2, "state": state, "clock": 6.0})
	_check(overlay.has_frame() and is_equal_approx(overlay.animation_phase(turret), 2.45), "Reconnect phase changed")
	overlay.apply_frame({"turrets": [{"animationPhase": 1.2}], "time": 5.0})
	_check(overlay.selection_revision == -1 and is_equal_approx(overlay.animation_phase({"animationPhase": 1.2}), 1.2), "Legacy snapshot rejected")
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0,10,10)
	camera.look_at(Vector3.ZERO)
	state.rewardTargeting = false
	state.aimKey = "id"
	state.turrets[0].id = 42
	overlay.apply_frame({"revision":3,"state":state,"clock":6.0,"aim":[[42,4.0,5.0,0.5]]})
	overlay.present(camera, Vector2(8,8), world)
	_check(overlay._aim_for(turret,0).size() == 4, "Stable ID aim looked up array index")
	var static_redraws: int = overlay._static_redraws
	var dynamic_redraws: int = overlay._dynamic_redraws
	overlay.apply_frame({"revision":3,"clock":6.0,"aim":[[42,4.0,5.0,0.5]]})
	overlay.present(camera,Vector2(8,8),world)
	_check(overlay._static_redraws == static_redraws and overlay._dynamic_redraws == dynamic_redraws,"Paused selection redrew unchanged layers")
	overlay.apply_frame({"revision":3,"clock":10.0,"aim":[[42,4.0,5.0,0.5]]})
	overlay.present(camera,Vector2(8,8),world)
	_check(overlay._static_redraws == static_redraws and overlay._dynamic_redraws > dynamic_redraws,"Animated ornaments rebuilt static commands")
	world.position.x += 0.01
	overlay.present(camera,Vector2(8,8),world)
	_check(overlay._static_redraws > static_redraws,"World shake failed to invalidate static projection")
	state.preserveLegacyOrnaments = true
	state.turrets[0].gemColors = []
	state.turrets[0].erase("phaseOrigin")
	overlay.apply_frame({"revision":4,"state":state,"aim":[[42,4.0,5.0,0.5]]},true)
	overlay.present(camera,Vector2(8,8),world)
	_check(overlay._aim.is_empty() and overlay._layers.size() == 1,"Standalone optimization enabled new animated ornaments")
	_check(not state.has("viewport"),"Renderer mutated shared state")
	overlay.clear()
	_check(state.turrets.size() == 1,"Renderer clear mutated shared state")
	world.free()
	camera.free()
	overlay.queue_free()
	await process_frame
	print("Selection lifecycle verification failures: ", failures)
	quit(0 if failures == 0 else 1)
