extends SceneTree
func _initialize():
	var font=preload("res://ui/app_theme.gd").font(900)
	for size in [9,13]:
		for text in ["Lv.7 → 8","Lv.7→8","Lv.9→10","7 → 8","9 → 10","강화 확정","19→20","88→89","98→99"]:
			print(size," ",text," ",font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
	quit()
