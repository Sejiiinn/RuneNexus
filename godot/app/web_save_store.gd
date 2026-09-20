class_name WebSaveStore
extends RefCounted
## Same-origin localStorage contract shared with the Flutter client.
## Acquire the global writer lock before loading (recovery can write) or saving.
const SaveJson = preload("res://app/save_json.gd")
const Codec = preload("res://app/save_codec.gd")
const Slot = preload("res://app/local_save_slot.gd")
const LEGACY_KEY := "rune_nexus_save_v1"
var last_error: Error = OK
var last_error_message: String = ""
var _slot
var _prefix: String
var _owner: String
var _held := false

func _init(slot = null) -> void:
	_slot = Slot.guest() if slot == null else slot
	_prefix = "rune_nexus:save:v2:" + _slot.get_namespace() + ":"
	_owner = str(Time.get_ticks_usec()) + "-" + str(get_instance_id())

func _call(body: String) -> Variant:
	if not OS.has_feature("web"):
		last_error = ERR_UNAVAILABLE
		last_error_message = "Web localStorage requires a browser export"
		return null
	var raw: Variant = JavaScriptBridge.eval("JSON.stringify((()=>{try{return {ok:true,value:(()=>{" + body + "})()}}catch(e){return {ok:false,error:String(e)}}})())", true)
	var result: Variant = JSON.parse_string(str(raw))
	if not result is Dictionary or not result.get("ok", false):
		last_error = ERR_CANT_OPEN
		last_error_message = str(result.get("error", "Browser storage failed")) if result is Dictionary else "Browser storage failed"
		return null
	return result.get("value")

func acquire_writer_lock(tree: SceneTree) -> bool:
	last_error = OK
	last_error_message = ""
	if _held:
		return true
	if not _slot.is_valid():
		last_error = ERR_INVALID_PARAMETER
		return false
	var owner := JSON.stringify(_owner)
	_call("const id=" + owner + "; const locks=globalThis.__runeNexusSaveLocks ||= {}; if(locks[id] && (locks[id].status==='pending' || locks[id].status==='held'))return; const state=locks[id]={status:'pending'}; if(!navigator.locks){state.status='held';return;} navigator.locks.request('rune-nexus-local-save-writer',{mode:'exclusive',ifAvailable:true}, lock=>{if(!lock){state.status='busy';return;}state.status='held';return new Promise(resolve=>state.release=resolve);}).catch(e=>{state.status='error';state.error=String(e);});")
	if last_error != OK:
		return false
	while true:
		var status: Variant = _call("return globalThis.__runeNexusSaveLocks[" + owner + "].status;")
		if last_error != OK:
			return false
		if status == "held":
			_held = true
			return true
		if status != "pending":
			last_error = ERR_BUSY if status == "busy" else ERR_CANT_ACQUIRE_RESOURCE
			last_error_message = "Another tab owns the save writer lock" if status == "busy" else "Unable to acquire the browser save writer lock"
			return false
		await tree.process_frame
	return false

func release_writer_lock() -> void:
	if not OS.has_feature("web"):
		return
	_call("const states=globalThis.__runeNexusSaveLocks;const id=" + JSON.stringify(_owner) + ";const state=states && states[id];if(state && state.release)state.release();if(states)delete states[id];")
	_held = false

func _begin() -> bool:
	last_error = OK
	last_error_message = ""
	if not _held or not _slot.is_valid():
		last_error = ERR_UNAUTHORIZED
		last_error_message = "Save writer lock is not held"
	return last_error == OK

func _read(key: String) -> Variant:
	return _call("return localStorage.getItem(" + JSON.stringify(key) + ");")

func _write(key: String, raw: String) -> Error:
	_call("localStorage.setItem(" + JSON.stringify(key) + "," + JSON.stringify(raw) + ");")
	return last_error

func _decode(raw: Variant, legacy: bool = false) -> Variant:
	if not raw is String:
		return null
	var value: Variant = SaveJson.parse(raw)
	if legacy:
		if not value is Dictionary or value.get("version") != 1:
			return null
	elif not Codec.is_canonical_v2(value):
		return null
	return Codec.decode(value)

func load_save() -> Variant:
	if not _begin():
		return null
	var primary: Variant = _decode(_read(_prefix + "primary"))
	if primary != null or last_error != OK:
		return primary
	var backup: Variant = _decode(_read(_prefix + "backup"))
	if last_error != OK:
		return null
	if backup != null:
		return backup if save_save(backup) == OK else null
	if _slot.is_guest():
		var legacy: Variant = _decode(_read(LEGACY_KEY), true)
		if last_error == OK and legacy != null:
			return legacy if save_save(legacy) == OK else null
	return null

func save_save(data: Dictionary) -> Error:
	if not _begin():
		return last_error
	if not SaveJson.is_json_value(data) or not Codec.is_normalized_v2(data):
		last_error = ERR_INVALID_DATA
		return last_error
	var raw := JSON.stringify(data, "", false, true)
	var old: Variant = _read(_prefix + "primary")
	if last_error != OK:
		return last_error
	if old != raw and _decode(old) != null:
		if _write(_prefix + "backup", old) != OK:
			return last_error
	return _write(_prefix + "primary", raw)

func preserve_current_as_backup() -> Error:
	if not _begin():
		return last_error
	var raw: Variant = _read(_prefix + "primary")
	if last_error == OK and _decode(raw) != null:
		return _write(_prefix + "backup", raw)
	return last_error

func preserve_conflict_backup(envelope: Dictionary) -> Error:
	if not _begin():
		return last_error
	if not SaveJson.is_json_value(envelope) or envelope.get("version") != 1 or not envelope.get("rebaseId") is String or not Codec.is_normalized_v2(envelope.get("data")):
		last_error = ERR_INVALID_DATA
		return last_error
	var raw: Variant = _read(_prefix + "conflict")
	if last_error != OK:
		return last_error
	var existing: Variant = SaveJson.parse(raw) if raw is String else null
	if existing is Dictionary and existing.get("version") == 1 and Codec.is_canonical_v2(existing.get("data")) and existing.get("rebaseId") == envelope.rebaseId:
		return OK
	return _write(_prefix + "conflict", JSON.stringify(envelope, "", false, true))

func clear() -> Error:
	if not _begin():
		return last_error
	var keys: Array = [_prefix + "primary", _prefix + "backup", _prefix + "conflict"]
	if _slot.is_guest():
		keys.append(LEGACY_KEY)
	_call("for(const key of " + JSON.stringify(keys) + ") localStorage.removeItem(key);")
	return last_error
