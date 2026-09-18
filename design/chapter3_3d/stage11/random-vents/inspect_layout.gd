extends SceneTree
func _initialize() -> void:
	var layout = load("res://environment/chapter_three_tiles.gd")
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("../chapter_three_frames.json"))[0]["map"]
	var variants: Dictionary = layout.variants(map)
	for entry: Dictionary in layout.panel_layout(map):
		if entry["kind"] == "panel_vent":
			print(JSON.stringify({"index": entry["index"], "side": entry["side"], "tile": variants.get(entry["index"], "path_tile")}))
	quit()
