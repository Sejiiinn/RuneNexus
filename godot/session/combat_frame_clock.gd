extends RefCounted
## Monotonic active-frame sampler. Godot's _process delta can cap a real hitch.
## Gate revisions also detect pause/resume pairs with no intervening render.
var sampled_usec: int = -1
var host_revision: int = -1
var control_revision: int = -1

func reset() -> void:
	sampled_usec = -1
	host_revision = -1
	control_revision = -1

func sample(now_usec: int, active: bool, activation: int, control: int = 0) -> float:
	if not active:
		reset()
		return 0.0
	var previous := sampled_usec
	sampled_usec = now_usec
	if previous < 0 or activation != host_revision or control != control_revision or now_usec < previous:
		host_revision = activation
		control_revision = control
		return 0.0
	return float(now_usec - previous) / 1000000.0
