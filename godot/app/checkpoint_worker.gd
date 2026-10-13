extends RefCounted
## Dedicated FIFO conversion/validation/IO worker. No Node, live simulation or
## caller-owned content tree is touched. Every accepted request completes once.
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Capture = preload("res://app/checkpoint_capture.gd")
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
const Order = preload("res://app/local_save_order.gd")
var _thread := Thread.new()
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _progress := Semaphore.new()
var _requests: Array = []
var _completions: Array = []
var _submitted := 0
var _finished := 0
var _closing := false
var _start_error: Error = OK
var _capture
var _store
var _order
var _owner: String
var _slot: String
# Optional owned callable for deterministic staging (e.g. an isolated regression
# semaphore). Install at construction; never change hooks on a running worker.
var _before_commit: Callable

func _init(content_data: Dictionary, growth_data: Dictionary, directory: String, owner: String, before_commit: Callable = Callable()) -> void:
	var catalog = Catalog.new()
	catalog._data = content_data
	var growth = Growth.new()
	growth.data = growth_data
	_capture = Capture.new(catalog, growth)
	_owner = owner
	_slot = Order.slot_key(directory, owner)
	_store = Store.new(directory, Slot.guest() if owner == "guest" else Slot.account(owner))
	if owner != "guest" and Slot.account(owner) == null: _store._valid_slot = false
	_order = _store.slot_order()
	_before_commit = before_commit
	_start_error = _thread.start(_run, Thread.PRIORITY_LOW)

func submit(owned_request: Dictionary) -> Dictionary:
	_mutex.lock()
	if _closing or _start_error != OK:
		var error: Error = ERR_UNAVAILABLE if _closing else _start_error
		_mutex.unlock()
		return {"error":error, "sequence":0}
	_submitted += 1
	var sequence := _submitted
	# Reserve before returning acceptance. Later direct store readers/writers
	# wait for this exact request, even while its conversion has not yet started.
	_requests.append({"request":owned_request, "sequence":sequence, "ticket":_order.reserve()})
	_mutex.unlock()
	_wake.post()
	return {"error":OK, "sequence":sequence}

func _run() -> void:
	while true:
		_wake.wait()
		_mutex.lock()
		if _requests.is_empty():
			var closing := _closing
			_mutex.unlock()
			if closing: return
			continue
		var jobs: Array = [_requests.pop_front()]
		# The newest queued snapshot supersedes older unstarted ones. Only adjacent
		# tickets coalesce, so no other slot user can observe a skipped state.
		while not _requests.is_empty() and int(_requests[0].ticket) == int(jobs[-1].ticket) + 1:
			jobs.append(_requests.pop_front())
		_mutex.unlock()
		var completed: Array = _commit(jobs)
		_mutex.lock()
		_completions.append_array(completed)
		_finished = int(jobs[-1].sequence)
		var done: bool = _closing and _requests.is_empty()
		_mutex.unlock()
		_progress.post()
		if done: return

# Converts and writes only the last job; every job completes with that result.
func _commit(jobs: Array) -> Array:
	var job: Dictionary = jobs[-1]
	var request: Dictionary = job.request
	var result: Error = OK
	var message := "Saved v2 checkpoint"
	var prepared: Dictionary = _capture.prepare(request)
	if _before_commit.is_valid(): _before_commit.call()
	# Superseded tickets are passed in order before the final write claims its own.
	for skipped in jobs.slice(0, jobs.size() - 1):
		_order.leave(_order.enter(int(skipped.ticket)))
	# Scope is claimed even on validation failure, releasing the reserved ticket
	# exactly once and allowing later requests/barriers to make progress.
	var _transaction_scope = Order.scope(_order, int(job.ticket))
	if prepared.is_empty():
		result = ERR_INVALID_DATA
		message = _capture.error
	elif not prepared.before.is_empty() or prepared.saved.activeRun.phase in ["success", "failure", "coreDestruction"]:
		result = ERR_INVALID_DATA
		message = "Terminal/transition checkpoints require the durable outbox boundary"
	elif _owner != "guest" and _store.has_recovery_marker():
		result = ERR_BUSY
		message = "서버 저장 복구를 먼저 완료해 주세요"
	else:
		result = _store.save_save(prepared.saved)
		if result != OK: message = _store.last_error_message
	var durable_progression := {}
	if result == OK:
		durable_progression = prepared.saved.progression.duplicate()
		durable_progression.turretModules = prepared.saved.turretModules
	var completed: Array = []
	for each: Dictionary in jobs:
		completed.append({"sequence":int(each.sequence), "generation":int(each.request.generation),
			"slot":_slot, "error":result, "message":message, "durable":result == OK,
			"saved_at":int(request.saved_at), "progression":durable_progression})
	return completed

func take_completions() -> Array:
	_mutex.lock()
	var completed := _completions
	_completions = []
	_mutex.unlock()
	return completed

func pending_count() -> int:
	_mutex.lock()
	var pending := _submitted - _finished
	_mutex.unlock()
	return pending

func flush() -> Array:
	_mutex.lock()
	var target := _submitted
	_mutex.unlock()
	while true:
		_mutex.lock()
		var finished := _finished
		_mutex.unlock()
		if finished >= target: break
		_progress.wait()
	return take_completions()

func shutdown() -> Array:
	_mutex.lock()
	_closing = true
	_mutex.unlock()
	_wake.post()
	if _thread.is_started(): _thread.wait_to_finish()
	return take_completions()
