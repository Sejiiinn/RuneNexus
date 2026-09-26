extends SceneTree
const OUT = "/Users/sejin/Documents/Codex/RuneNexus/design/fire_tower_concepts/runic_3d/optimized-game-distance/review/"
func _initialize() -> void:
	for mode in ["angled","drone"]:
		var original := Image.load_from_file(OUT+"original-"+mode+"-crop-native.png")
		var optimized := Image.load_from_file(OUT+"optimized-"+mode+"-crop-native.png")
		var sheet := Image.create(original.get_width()+optimized.get_width()+12,maxi(original.get_height(),optimized.get_height()),false,Image.FORMAT_RGBA8)
		sheet.fill(Color("142326"))
		original.convert(Image.FORMAT_RGBA8)
		optimized.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(original,Rect2i(Vector2i.ZERO,original.get_size()),Vector2i.ZERO)
		sheet.blit_rect(optimized,Rect2i(Vector2i.ZERO,optimized.get_size()),Vector2i(original.get_width()+12,0))
		sheet.save_png(OUT+mode+"-native-pair-left-original-right-optimized.png")
		print("NATIVE PACK ",mode," ",sheet.get_size()," (no resampling)")
	quit()
