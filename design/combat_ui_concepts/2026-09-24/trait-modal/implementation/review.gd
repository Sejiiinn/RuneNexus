extends SceneTree
var app
var hud
var failures=[]
var checks=0
var observations=[]
var out="/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-24/trait-modal/implementation/"
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)
func state(): return app.run_domain.state
func turret(): return state().turrets[0]
func node(name): return hud.modal_body.find_child(name,true,false)
func settle(): await create_timer(0.2).timeout
func click(b):
	check(b!=null,"button exists")
	if b==null:return
	var p=b.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(p),"click visible "+str(b.name))
	var m=InputEventMouseMotion.new();m.position=p;root.push_input(m,true)
	for down in [true,false]:
		var e=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true)
		await process_frame
	await settle()
func open(tier=1):
	var t=turret()
	hud.turret_panel._traits(t,app.run_domain.service.quotes(state(),int(t.id)),tier)
	await settle()
func close():
	hud.close_modal();await settle()
func reset(level=7,shards=1000,kind="arrow"):
	if hud.modal_active():await close()
	var t=turret();t.type=kind;t.level=level;t.primaryTrait=null;t.secondaryTrait=null
	state().gemShards=shards;hud.trait_preview="";hud.refresh();await settle()
func layout(label):
	var rows=[]
	for c in hud.modal_body.get_children():
		if str(c.name).begins_with("TraitChoice_"):rows.append(c)
	check(rows.size()==2,label+" two rows")
	check(hud.modal_panel.get_global_rect().size.x<=root.size.x,label+" modal width")
	for row in rows:
		var icon=row.find_child("TraitIcon",true,false)
		check(icon!=null and icon.texture!=null,label+" trait icon loaded")
		if icon!=null and icon.texture!=null:check(icon.texture.resource_path.contains("ui/traits/"),label+" independent trait icon path")
		var title=row.find_child("TraitName",true,false);var detail=row.find_child("TraitDescription",true,false);var radio=row.find_child("TraitRadio",true,false)
		# Uniform rows intentionally reserve breathing room even for short text.
		# Oversized-row regression is bounded below; exact whitespace is visual QA.
		check(row.size.y<=240,label+" row not inflated "+str(row.name)+" height="+str(row.size.y))
		observations.append({"state":label,"row":str(row.name),"row_height":row.size.y,"title_height":title.size.y,"detail_height":detail.size.y,"detail_lines":detail.get_line_count(),"detail_width":detail.size.x})
		check(row.get_global_rect().encloses(detail.get_global_rect()),label+" description stays in row "+str(row.name))
		check(icon.get_global_rect().end.x<=title.global_position.x,label+" icon before title")
		check(detail.get_global_rect().end.x<=radio.global_position.x,label+" text before radio")
		check(row.get_global_rect().end.x<=hud.modal_panel.get_global_rect().end.x,label+" row right bound")
	observations.append({"state":label,"modal_size":str(hud.modal_panel.size),"body_height":hud.modal_body.size.y,"scroll_height":hud.modal_scroll.size.y})
func run():
	assert(OS.get_user_data_dir().contains("RuneNexus-TurretStats-Review"))
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await create_timer(2).timeout
	app=scene._standalone_session;hud=app.hud
	root.content_scale_size=Vector2i(440,900);root.size=root.content_scale_size
	app.start_stage(0);state().progression=app.run_domain.growth.data.defaultProgression.duplicate(true)
	var map=app.catalog.stage(0).map;var index=map.tiles.find("build")
	app.board_tap(Vector2i(index % int(map.columns),index / int(map.columns)));app.build_selected()
	await reset();await open()
	check(node("TraitWalletAmount").text=="1000","live wallet")
	check(node("TraitConfirm").disabled,"confirm disabled until selected")
	await click(node("TraitChoice_overheatMagazine"));await click(node("TraitChoice_overheatMagazine"))
	check(turret().primaryTrait==null and state().gemShards==1000,"repeat row click never commits")
	check(not node("TraitConfirm").disabled,"selected enables confirm")
	await close();check(turret().primaryTrait==null and state().gemShards==1000,"close cancels")
	await open();check(node("TraitConfirm").disabled,"reopen clears pending selection")
	await click(node("TraitChoice_overheatMagazine"))
	var price=int(app.run_domain.service.quotes(state(),int(turret().id)).primaryTrait)
	var original=turret().duplicate(true)
	await click(node("TraitConfirm"))
	check(turret().primaryTrait=="overheatMagazine" and state().gemShards==1000-price,"explicit confirm charges exact quote once")
	hud.turret_panel._confirm_trait(original,"primaryTrait")
	check(state().gemShards==1000-price,"repeat confirm cannot charge again")
	await open(1);check(node("TraitConfirm").disabled and node("TraitChoice_lightweightBarrel").disabled,"chosen primary immutable");await close()
	await open(2);await click(node("TraitChoice_suppressiveFire"))
	price=int(app.run_domain.service.quotes(state(),int(turret().id)).secondaryTrait);var balance=int(state().gemShards)
	await click(node("TraitConfirm"));check(turret().secondaryTrait=="suppressiveFire" and state().gemShards==balance-price,"secondary quote single charge")
	await reset(7,1000);await open(2)
	check(node("TraitConfirm").disabled and node("TraitBlockedReason").text.contains("먼저"),"secondary prerequisite")
	await reset(2,1000);await open(1)
	check(node("TraitConfirm").disabled and node("TraitChoice_overheatMagazine").disabled and node("TraitBlockedReason").text.contains("Lv.3"),"primary level condition")
	await reset(6,1000);turret().primaryTrait="overheatMagazine";await open(2)
	check(node("TraitConfirm").disabled and node("TraitBlockedReason").text.contains("Lv.7"),"secondary level condition")
	await reset(7,0);await open(1)
	check(node("TraitConfirm").disabled and node("TraitChoice_overheatMagazine").disabled and node("TraitBlockedReason").text.contains("부족"),"insufficient currency")
	await reset();app.command([],{"paused":false});await open()
	check(app.scene._native_combat.session.paused,"open pauses running session")
	await click(node("TraitChoice_overheatMagazine"));check(app.scene._native_combat.session.paused,"row rebuild preserves pause")
	await close();check(not app.scene._native_combat.session.paused,"close restores running session")
	app.command([],{"paused":true});await open();await close();check(app.scene._native_combat.session.paused,"already paused stays paused")
	for size in [Vector2i(440,900),Vector2i(320,760),Vector2i(320,480)]:
		root.content_scale_size=size;root.size=size
		for kind in ["arrow","cannon","magic","frost","sniper","lightning"]:
			await reset(7,1000,kind);await open(1);layout(str(size)+kind+"-primary")
			var q=app.run_domain.service.quotes(state(),int(turret().id));turret().primaryTrait=q.primaryTraits[0]
			await open(2);layout(str(size)+kind+"-secondary")
			if size.y==480:
				hud.modal_scroll.scroll_vertical=100000;await settle()
				var viewport_rect=hud.modal_scroll.get_global_rect()
				var notice_rect=node("TraitPermanentNotice").get_global_rect()
				observations.append({"state":kind+"-short-bottom","viewport":str(viewport_rect),"notice":str(notice_rect),"scroll":hud.modal_scroll.scroll_vertical})
				check(viewport_rect.grow(1).encloses(notice_rect),kind+" short screen bottom reachable "+str(viewport_rect)+" notice="+str(notice_rect))
	var report={"checks":checks,"failures":failures,"observations":observations,"user_dir":OS.get_user_data_dir()}
	var f=FileAccess.open(out+"review-result.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("REVIEW ",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
