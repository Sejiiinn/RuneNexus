extends SceneTree
# Deterministic runtime export. ImageGen masters remain unchanged; no crop/repaint.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1, "Pass the checkout root after --")
	var directory: String = args[0].trim_suffix("/")+"/"
	var source := directory+"design/gem_simplification/2026-10-09/source/"
	var runtime := directory+"assets/images/gems/simplified/"
	var comparison := directory+"build/gem-qa/godot/comparison/256/"
	DirAccess.make_dir_recursive_absolute(comparison)
	for file in DirAccess.get_files_at(source):
		if not file.ends_with(".png"): continue
		var image := Image.load_from_file(source+file)
		assert(image != null and not image.is_empty())
		for extent in [128,256]:
			var output := image.duplicate() as Image
			output.resize(extent,extent,Image.INTERPOLATE_LANCZOS)
			var path: String = (runtime if extent == 128 else comparison)+file
			if extent == 128 and file in ["attackSpeed.png","damageAmplifier.png"]: continue
			assert(output.save_png(path) == OK)
	print("PASS runtime export")
	quit()
