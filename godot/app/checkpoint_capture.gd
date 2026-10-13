extends RefCounted
## Conversion/validation accepts only an owned request tree. This phase may run
## off-thread with an independently owned content/growth context.
const ContentSave = preload("res://app/content_run_save.gd")
var adapter
var error := ""

func _init(content, growth_rules) -> void:
	adapter = ContentSave.new(content, growth_rules)

func prepare(request: Dictionary) -> Dictionary:
	error = ""
	var snapshot: Dictionary = request.snapshot
	var before := {}
	if not request.previous.is_empty():
		before = adapter.capture(request.previous, snapshot, request.saved_at, request.preferences)
		if before.is_empty():
			error = adapter.error
			return {}
	if request.abandoning:
		snapshot.session.phase = "failure"
		snapshot.wave.spawnQueue = []
	var saved: Dictionary = adapter.capture(request.state, snapshot, request.saved_at, request.preferences)
	if saved.is_empty():
		error = adapter.error
		return {}
	return {"saved":saved, "before":before}
