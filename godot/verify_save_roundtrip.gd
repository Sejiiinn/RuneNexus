extends SceneTree
const Codec = preload("res://app/save_codec.gd")
const SaveJson = preload("res://app/save_json.gd")
const Store = preload("res://app/local_save_store.gd")
func _initialize() -> void:
	var inputs = SaveJson.parse(FileAccess.get_file_as_string("res://fixtures/godot_save_codec_inputs.json"))
	if not inputs is Array:
		quit(1)
		return
	var store = Store.new("res://roundtrip")
	var results: Array = []
	for index in range(inputs.size()):
		var decoded = Codec.decode(inputs[index])
		if decoded == null:
			results.append(null)
			continue
		if store.clear() != OK or store.save_save(decoded) != OK:
			push_error("Roundtrip write failed at fixture %d: %s" % [index,store.last_error_message])
			quit(1)
			return
		var loaded = Store.new("res://roundtrip").load_save()
		if loaded == null:
			push_error("Roundtrip reload failed at fixture %d" % index)
			quit(1)
			return
		results.append(loaded)
	var output := FileAccess.open("res://roundtrip-results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "", false, true))
	output.close()
	print("SAVE_FILE_ROUNDTRIP count=", inputs.size())
	quit(0)
