extends SceneTree
const Frame = preload("res://ui/lobby_frame.gd")
const Art = preload("res://ui/app_theme.gd")
func _initialize() -> void:
	for name in Frame.CENTERS:
		var path: String = "ui/components/%s.png" % name
		var master := Art.texture(path)
		var original_size := master.get_size()
		var frame := Frame.new(path,7)
		assert(frame is StyleBoxTexture)
		assert(frame.texture.get_size() == original_size/4)
		assert(master.get_size() == original_size, "Shared source remains unchanged")
		assert(frame.texture.get_image().get_data() == master.get_image().get_data(), "No image resampling")
		assert(frame.get_minimum_size() == Vector2(14,14), "Content margins remain independent of frame margins")
		var another := Frame.new(path,0)
		assert(another.texture == frame.texture, "One logical texture per source and scale")
	var flat := Frame.new("quests/ui/dialog_frame.png",9)
	assert(flat.texture == Art.texture("quests/ui/dialog_frame.png"))
	assert(flat.get_texture_margin(SIDE_LEFT) == 0)
	var primary := Frame.new("lobby_primary_button.png",0)
	primary.source_scale = 3
	primary.source_center = Rect2(12,14,276,28)
	assert(primary.texture.get_size() == Art.texture("lobby_primary_button.png").get_size()/3)
	assert(primary.get_texture_margin(SIDE_LEFT)==12)
	assert(Frame.new().texture != null, "Missing-asset color fallback remains native")
	print("PASS lobby_frame: native StyleBoxTexture, unresampled source, cached logical size, independent margins, stretch fallback, primary scale3")
	quit()
