extends RefCounted
## Strong references belong to the current stage only. Godot shares transitive
## mesh/material/texture dependencies for retained resources automatically.
static var _resources: Dictionary = {}
static var _loads := 0
static var _releases := 0
static var _stage_key := ""

static func load_resource(path: String) -> Resource:
	if _resources.has(path): return _resources[path]
	var resource := load(path)
	if resource != null:
		_resources[path] = resource
		_loads += 1
	return resource

# Synchronous fixture/manual-host compatibility. Formal stage entry uses the
# threaded path below only after its loading canvas has drawn.
static func prepare(paths: Array) -> bool:
	# Validate first; a missing destination must not release the current stage.
	for path: String in paths:
		if not ResourceLoader.exists(path): return false
	var previous: Array = _resources.keys()
	for path: String in paths:
		if load_resource(path) == null:
			for added: String in _resources.keys():
				if added not in previous:
					_resources.erase(added)
					_releases += 1
			return false
	return true

static func prepare_threaded(paths: Array, owner: Node, generation: int) -> bool:
	# The caller has drawn the loading canvas before requesting any heavy resource.
	# Request one root at a time, reuse Godot's dependency cache, and never call
	# load_threaded_get() while IN_PROGRESS: that would block the UI thread.
	for path: String in paths:
		if not ResourceLoader.exists(path): return false
	for path: String in paths:
		if not owner.stage_preparation_current(generation): return false
		if _resources.has(path): continue
		if ResourceLoader.load_threaded_request(path, "", false) != OK: return false
		var status := ResourceLoader.load_threaded_get_status(path)
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await owner.get_tree().process_frame
			status = ResourceLoader.load_threaded_get_status(path)
		# Godot has no cancel request. Always collect a completed request, even
		# after Back, then discard it without retaining or changing the run.
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: return false
		# FAILED requests own a user token too. Collect it so retry starts a fresh
		# load instead of reusing the permanently failed token.
		var resource := ResourceLoader.load_threaded_get(path)
		if status != ResourceLoader.THREAD_LOAD_LOADED: return false
		if not owner.stage_preparation_current(generation): return false
		if resource == null: return false
		_resources[path] = resource
		_loads += 1
		await owner.stage_feedback_frame()
	return owner.stage_preparation_current(generation)

static func retain(paths: Array, stage_key: String) -> void:
	for path: String in _resources.keys():
		if path not in paths:
			_resources.erase(path)
			_releases += 1
	_stage_key = stage_key

static func snapshot() -> Dictionary:
	var paths: Array = _resources.keys()
	paths.sort()
	return {"stage":_stage_key,"count":paths.size(),"loads":_loads,"releases":_releases,"paths":paths}

static func clear() -> void:
	_releases += _resources.size()
	_resources.clear()
	_stage_key = ""

static func release(paths: Array) -> void:
	for path: String in paths:
		if _resources.erase(path): _releases += 1
