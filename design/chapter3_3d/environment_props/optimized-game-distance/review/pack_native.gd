extends SceneTree
const OUT="/Users/sejin/Documents/Codex/RuneNexus/design/chapter3_3d/environment_props/optimized-game-distance/review/"
func _initialize():
	for mode in ["angled","drone"]:
		var rows=[]
		var width=0
		var height=0
		for kind in ["elbow_pipe","side_conduit","exhaust_vent"]:
			var a=Image.load_from_file(OUT+"original-"+mode+"-"+kind+"-native.png")
			var b=Image.load_from_file(OUT+"optimized-"+mode+"-"+kind+"-native.png")
			rows.append([a,b])
			width=maxi(width,a.get_width()+12+b.get_width())
			height+=maxi(a.get_height(),b.get_height())+12
		var sheet=Image.create(width,height-12,false,Image.FORMAT_RGBA8)
		sheet.fill(Color("142326"))
		var y=0
		for row in rows:
			for i in range(2):
				row[i].convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(row[i],Rect2i(Vector2i.ZERO,row[i].get_size()),Vector2i(0 if i==0 else row[0].get_width()+12,y))
			y+=maxi(row[0].get_height(),row[1].get_height())+12
		sheet.save_png(OUT+mode+"-native-pairs-left-original-right-optimized.png")
	quit()
