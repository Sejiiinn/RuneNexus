extends Node
func _ready() -> void:
	var native := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			native = true
	get_tree().change_scene_to_file.call_deferred("res://validation/benchmark.tscn" if native else "res://main.tscn")
