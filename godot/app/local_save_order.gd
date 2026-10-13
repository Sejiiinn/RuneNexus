extends RefCounted
## One FIFO for every repository using a directory/account slot. A reserved
## background checkpoint cannot be overtaken by an online writer or recovery.
## Recursive scopes keep journal/outbox/save transactions in one decision.
static var _registry_mutex := Mutex.new()
static var _slots: Dictionary = {}

# One immutable validated byte string per live slot, never a parsed save tree.
# Stores own this memo; the permanent FIFO registry only holds a weak reference.
class ValidationMemo extends RefCounted:
	var _mutex := Mutex.new()
	var _raw := ""
	func matches(raw: String) -> bool:
		_mutex.lock()
		var matched := not _raw.is_empty() and raw == _raw
		_mutex.unlock()
		return matched
	func remember(raw: String) -> void:
		_mutex.lock()
		_raw = raw
		_mutex.unlock()
	func clear() -> void:
		remember("")

class SlotOrder extends RefCounted:
	var mutex := Mutex.new()
	var issued := 0
	var completed := 0
	var owner_thread := 0
	var depth := 0
	var active_ticket := 0
	var waiting: Dictionary = {}
	var _validation_memo: WeakRef

	func validation_memo():
		mutex.lock()
		var memo = null if _validation_memo == null else _validation_memo.get_ref()
		if memo == null:
			memo = ValidationMemo.new()
			_validation_memo = weakref(memo)
		mutex.unlock()
		return memo

	func held_by_caller() -> bool:
		mutex.lock()
		var held := owner_thread != 0 and owner_thread == OS.get_thread_caller_id()
		mutex.unlock()
		return held

	func reserve() -> int:
		mutex.lock()
		issued += 1
		var ticket := issued
		var ready := Semaphore.new()
		waiting[ticket] = ready
		if ticket == completed + 1: ready.post()
		mutex.unlock()
		return ticket

	func enter(ticket: int = 0) -> int:
		var caller := OS.get_thread_caller_id()
		mutex.lock()
		if owner_thread == caller:
			depth += 1
			var current := active_ticket
			mutex.unlock()
			return current
		mutex.unlock()
		if ticket == 0: ticket = reserve()
		mutex.lock()
		var ready: Semaphore = waiting[ticket]
		mutex.unlock()
		ready.wait()
		mutex.lock()
		owner_thread = caller
		active_ticket = ticket
		depth = 1
		mutex.unlock()
		return ticket

	func leave(ticket: int) -> void:
		mutex.lock()
		assert(owner_thread == OS.get_thread_caller_id() and active_ticket == ticket)
		depth -= 1
		if depth == 0:
			completed = ticket
			owner_thread = 0
			active_ticket = 0
			waiting.erase(ticket)
			if waiting.has(ticket + 1): waiting[ticket + 1].post()
		mutex.unlock()

class Scope extends RefCounted:
	var order
	var ticket: int
	func _init(slot_order, reserved: int = 0) -> void:
		order = slot_order
		ticket = order.enter(reserved)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE: order.leave(ticket)

static func slot_key(directory: String, owner: String) -> String:
	return ProjectSettings.globalize_path(directory).simplify_path().path_join("saves/" + ("guest" if owner.to_lower() == "guest" else "accounts/" + owner.to_lower()))

static func for_slot(directory: String, owner: String):
	var key := slot_key(directory, owner)
	_registry_mutex.lock()
	if not _slots.has(key): _slots[key] = SlotOrder.new()
	var order = _slots[key]
	_registry_mutex.unlock()
	return order

static func scope(order, reserved: int = 0):
	return Scope.new(order, reserved)
