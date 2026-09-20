extends SceneTree
const Calculation = preload("res://combat/attack_calculation.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected fixture and output JSON paths")
		quit(1)
		return
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not fixtures is Array:
		push_error("Invalid fixture JSON")
		quit(1)
		return
	var results: Array = []
	for fixture in fixtures:
		results.append({"name": fixture["name"], "result": Calculation.resolve(fixture["input"])})
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(JSON.stringify(results, "\t", false, true))
	output.close()
	quit(0)
