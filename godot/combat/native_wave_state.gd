extends RefCounted
## A prepared spawn schedule is configuration; elapsed time and creation belong here.
var id: int = 0
var active: bool = false
var completed: bool = false
var elapsed: float = 0.0
var queue: Array = []
var next_index: int = 0

func start(raw: Dictionary) -> void:
	id = int(raw.get("id", 0))
	active = bool(raw.get("active", false))
	completed = bool(raw.get("completed", false))
	elapsed = 0.0
	next_index = 0
	queue = raw.get("spawnQueue", []).duplicate(true)
	for request in queue:
		if not request.get("enemy") is Dictionary: continue
		var enemy: Dictionary = request.enemy
		var route_id: String = request.get("routeId",enemy.get("routeId",enemy.get("state",{}).get("routeId","")))
		if not route_id.is_empty():
			request.routeId = route_id
			enemy.routeId = route_id

	# Restore delays are already remaining delays. Never apply the .18 gap again.
	# Concurrent routes can share timestamps. Preserve the compiled tie order so
	# remaining queues still match the deterministic save/resume schedule suffix.
	for index in range(queue.size()): queue[index]._spawnOrder = index
	queue.sort_custom(func(a, b): return int(a._spawnOrder) < int(b._spawnOrder) if float(a.delay) == float(b.delay) else float(a.delay) < float(b.delay))
	for request in queue: request.erase("_spawnOrder")

func advance(dt: float) -> Array:
	var ready: Array = []
	if not active or completed or dt < 0:
		return ready
	elapsed += dt
	while next_index < queue.size() and float(queue[next_index].delay) <= elapsed:
		ready.append(queue[next_index])
		next_index += 1
	return ready

func is_empty() -> bool:
	return next_index >= queue.size()

func finish_if_empty(has_live_enemies: bool) -> bool:
	if not active or completed or not is_empty() or has_live_enemies:
		return false
	completed = true
	active = false
	return true

func cancel() -> void:
	active = false
	queue.clear()
	next_index = 0

func snapshot() -> Dictionary:
	var remaining: Array = []
	for index in range(next_index, queue.size()):
		# Save/mirror contract intentionally excludes prepared enemy configurations.
		remaining.append({"enemyType":queue[index].enemyType,"delay":maxf(0,float(queue[index].delay)-elapsed)})
		var route_id: String = queue[index].get("routeId",queue[index].get("enemy",{}).get("routeId",""))
		if not route_id.is_empty(): remaining[-1].routeId = route_id
	return {"id":id,"active":active,"completed":completed,"spawnQueue":remaining}
