extends RefCounted
## Waits for finite UI tweens to finish instead of guessing their duration in
## wall time. Entrances may start a few frames late (after layout settles), so
## the UI counts as settled only after several consecutive frames without one.
const IDLE_FRAMES := 4

static func finished(tree: SceneTree, frame_limit := 600) -> void:
	var idle := 0
	for i in frame_limit:
		await tree.process_frame
		if tree.get_processed_tweens().any(func(tween: Tween) -> bool: return tween.is_running()):
			idle = 0
		else:
			idle += 1
			if idle >= IDLE_FRAMES: return
