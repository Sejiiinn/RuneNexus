extends SceneTree
var app
var hud
var samples=[]
var failures=[]
var out="/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-23/turret-stats-ux/implementation/stable-preview/"
func _initialize(): call_deferred("run")
func rect(n): return [n.global_position.x,n.global_position.y,n.size.x,n.size.y]
func measure():
	var panel=hud.body.find_child("TurretActionPanel",true,false)
	var labels=[]
	for l in panel.find_children("*","Label",true,false): labels.append({"text":l.text,"font":l.get_theme_font_size("font_size")})
	var r={"draw_frame":Engine.get_frames_drawn(),"fonts":labels,"dock":rect(hud.dock),"target":rect(hud.body.find_child("TurretTargetPriority",true,false)),"target_font":hud.body.find_child("TurretTargetPriority",true,false).get_theme_font_size("font_size"),"tags":{},"actions":{}}
	for tag in hud.body.find_child("TurretCategoryAndTarget",true,false).get_children():
		if str(tag.name).begins_with("Category_"): r.tags[str(tag.name)]={"rect":rect(tag),"font":tag.get_child(0).get_theme_font_size("font_size")}
	for name in ["TurretLevelAction","TurretTraitAction","TurretSellAction"]: r.actions[name]=rect(panel.find_child(name,true,false))
	return r
func check(base,now,label):
	for k in ["dock","target","target_font","tags","actions"]:
		if base[k]!=now[k]: failures.append(label+" changed "+k)
	for i in base.fonts.size():
		if base.fonts[i].font!=now.fonts[i].font: failures.append(label+" font "+base.fonts[i].text+" -> "+now.fonts[i].text)
func press():
	var b=hud.body.find_child("TurretLevelAction",true,false)
	var pos=b.get_global_rect().get_center()
	var m=InputEventMouseMotion.new();m.position=pos;root.push_input(m,true)
	for down in [true,false]:
		var e=InputEventMouseButton.new();e.position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true)
func trace(base,label):
	var frames=[]
	for i in 8:
		await RenderingServer.frame_post_draw
		var now=measure();check(base,now,label+"/"+str(i));frames.append(now)
	for i in range(1,frames.size()):
		if frames[i].draw_frame!=frames[i-1].draw_frame+1: failures.append(label+" nonconsecutive frames")
	samples.append({"label":label,"baseline":base,"frames":frames})
func run():
	assert(OS.get_user_data_dir().contains("RuneNexus-TurretStats-Review"))
	var scene=load("res://main.tscn").instantiate();root.add_child(scene)
	await create_timer(2).timeout
	app=scene._standalone_session;hud=app.hud;app.start_stage(0)
	app.run_domain.state.progression=app.run_domain.growth.data.defaultProgression.duplicate(true)
	app.run_domain.state.progression.researchLevels.turretTargetPriority=1
	var map=app.catalog.stage(0).map;var index=map.tiles.find("build");var tile=Vector2i(index % int(map.columns),index / int(map.columns))
	app.board_tap(tile);app.build_selected();hud.tab="stats";hud.main_tab="turrets"
	for width in [440,320]:
		root.content_scale_size=Vector2i(width,900 if width==440 else 760);root.size=root.content_scale_size
		for kind in ["arrow","lightning"]:
			for level in [7,9]:
				var state=app.run_domain.state;state.gold=999999;state.turrets[0].type=kind;state.turrets[0].level=level
				app.selection_view.level_preview=false;hud.body_key="";hud.refresh();await create_timer(0.3).timeout
				var base=measure();var key=str(width)+"-"+kind+"-"+str(level)
				press();await trace(base,key+"-preview")
				assert(app.selection_view.level_preview)
				press();await trace(base,key+"-confirm")
				assert(app.run_domain.state.turrets[0].level==level+1)
				# Re-enter same pre-confirm state to check dismissal and reselection.
				app.run_domain.state.turrets[0].level=level;hud.refresh();await create_timer(0.15).timeout
				press();await trace(base,key+"-preview-again")
				hud.close_back();app.board_tap(tile);await trace(base,key+"-dismiss-reselect")
				assert(not app.selection_view.level_preview and app.run_domain.state.turrets[0].level==level)
	var result={"failures":failures,"transition_count":samples.size(),"samples":samples,"user_dir":OS.get_user_data_dir()}
	var f=FileAccess.open(out+"independent-result.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("INDEPENDENT transitions=",samples.size()," frames=",samples.size()*8," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
