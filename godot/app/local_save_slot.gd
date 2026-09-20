class_name LocalSaveSlot
extends RefCounted
## Exact Dart LocalSaveSlot namespace; account IDs must be UUIDs before path use.
var account_id: String = ""

static func guest() -> LocalSaveSlot:
	return LocalSaveSlot.new()

static func account(value: String) -> LocalSaveSlot:
	var normalized := value.to_lower()
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
	if pattern.search(normalized) == null:
		return null
	var slot := LocalSaveSlot.new()
	slot.account_id = normalized
	return slot

func is_guest() -> bool:
	return account_id.is_empty()

func get_namespace() -> String:
	return "guest" if is_guest() else "account:" + account_id

func is_valid() -> bool:
	return is_guest() or account(account_id) != null
