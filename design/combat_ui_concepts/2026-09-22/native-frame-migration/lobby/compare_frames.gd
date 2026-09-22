extends SceneTree
func _initialize():
	var dir = OS.get_environment("FRAME_OUT")
	for w in [320,440]:
		for page in ["강화","연구","포탑","퀘스트"]:
			var a = Image.load_from_file(dir+"/before-%d-%s.png"%[w,page])
			var b = Image.load_from_file(dir+"/after-%d-%s.png"%[w,page])
			var count = 0
			var total = 0.0
			var max_diff = 0.0
			for y in range(a.get_height()):
				for x in range(a.get_width()):
					var ca = a.get_pixel(x,y)
					var cb = b.get_pixel(x,y)
					var diff = maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)))
					if diff>0: count += 1
					max_diff = maxf(max_diff,diff)
					total += diff
			print("%d %s different=%d max=%f mean=%f"%[w,page,count,max_diff*255,total*255/a.get_width()/a.get_height()])
	quit()
