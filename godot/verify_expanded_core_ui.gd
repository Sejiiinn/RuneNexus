extends SceneTree
const Lobby = preload("res://ui/lobby.gd")
const TestLobby = preload("res://verify_lobby.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value: failures.append(message)
func settle() -> void:
	for i in 4: await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("RUNE_TREE_CAPTURE_DIR")
	if path.is_empty(): return
	DirAccess.make_dir_recursive_absolute(path)
	root.get_texture().get_image().save_png(path.path_join(name+".png"))
func run() -> void:
	root.content_scale_size = Vector2i(440,760)
	root.size = Vector2i(440,900)
	var app := TestLobby.FakeApp.new()
	check(app.catalog.load_catalog(),"catalog loads")
	check(app.run_domain.growth.load_catalog(),"growth loads")
	app.progression_inputs = app.run_domain.growth.data.defaultProgression.duplicate(true)
	app.progression_inputs.totalCorePoints = 60
	app.progression_inputs.corePassiveTreeRevision = 5
	app.progression_inputs.corePassiveNodeRanks = {}
	var lobby := Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	await settle()
	lobby.open_page("코어")
	await settle()
	var core = lobby.core
	var health = preload("res://ui/core_health_text.gd")
	check(health.combined_numbers({"hp":100.0,"max_hp":100.0,"additional_hp":15.0})=="115/115","integrated additional HP compact total")
	check(health.has_additional_hp({"additional_hp":0.0,"config":{"nexusAdditionalHpRate":0.15}}),"spent additional HP remains visibly zero")
	check(not health.has_additional_hp({"hp":100.0}),"legacy HUD fixtures have no additional grant")
	check(core.expanded(),"v5 selects expanded renderer")
	check(core.node_ids().size()==60,"all sixty purchased nodes present")
	check(core.data().edges.size()==89,"all eighty-nine exact straight edges present")
	check(core.point("S1")==Vector2(1287.5,1205.144),"source graph coordinates preserved")
	check(core.point("CORE")==Vector2(1400,1400),"core coordinate preserved")
	check(core.spent({"S1":3})==4,"incremental rank costs not raw ranks")
	check(core.accessible_nodes().size()==6,"six immediate starts")
	await capture("expanded-tree-overview-440")
	var origin: Vector2 = core.offset+core.point("S1")*core.zoom
	core.select_at(origin)
	check(core.zoom>=0.39 and core.selected.is_empty(),"overview tap zooms without investing")
	core.select_at(core.offset+core.point("S1")*core.zoom)
	check(core.selected=="S1","detailed touch selects node")
	check(core.expanded_tree.hit_rect(core,"S1").size.x>=44,"minimum detailed touch width")
	check(lobby.core_draft.is_empty(),"selection never purchases")
	var touch := InputEventScreenTouch.new()
	touch.index = 0; touch.position = Vector2(200,220); touch.pressed = true
	core.input_tree(touch)
	var second := InputEventScreenTouch.new()
	second.index = 1; second.position = Vector2(240,220); second.pressed = true
	core.input_tree(second)
	var before_pinch: float = core.zoom
	var drag := InputEventScreenDrag.new()
	drag.index = 1; drag.position = Vector2(270,220); drag.relative = Vector2(30,0)
	core.input_tree(drag)
	check(core.zoom>before_pinch,"two-finger pinch zoom")
	second.pressed = false; core.input_tree(second)
	touch.pressed = false; core.input_tree(touch)
	check(lobby.core_draft.is_empty(),"pinch never purchases or changes selection")
	core.change_rank("K1",1)
	check(lobby.core_draft.is_empty(),"unreachable key rejected")
	for i in 3: core.change_rank("S1",1)
	check(core.spent(lobby.core_draft)==4,"three ranks spend four points")
	check(core.accessible_nodes().has("A03"),"three-rank start opens neighbor")
	core.change_rank("A03",1)
	check(not core.valid(core.candidate("S1",-1)),"disconnecting refund rejected")
	core.cancel()
	check(lobby.core_draft.is_empty(),"cancel refreshes detail and draft")
	# Approved 27P K2 path, with no penalty text and terminal semantics.
	lobby.core_draft = {"S6":3,"A01":3,"B01":3,"C02":3,"K2":1}
	core.update_state()
	check(core.valid(lobby.core_draft),"approved K2 path valid")
	check(core.spent(lobby.core_draft)==27,"approved K2 route costs 27P")
	core.zoom = 0.6
	core.expanded_tree.select_at(core,core.offset+core.point("K2")*core.zoom)
	await settle()
	var label: Label = core.inline_body.get_node("CoreCurrentEffect")
	check(label.text.contains("2회") and label.text.contains("50%"),"stockpile detail uses latest key")
	check(not label.text.contains("감폭"),"removed penalty absent")
	await capture("expanded-tree-stockpile-detail-440")
	core.apply()
	check(core.actual()==lobby.core_draft,"draft apply persists through real lobby command")
	if core.allocation_tween: core.allocation_tween.kill()
	core._finish_allocation()
	var zoom_before: float = core.zoom
	var offset_before: Vector2 = core.offset
	core.skills()
	check(core.zoom==zoom_before and core.offset==offset_before,"central skill selection preserves viewport")
	core.node_details("C12")
	await settle()
	check(core.inline_body.get_node("CoreCurrentEffect").text.contains("회복 불가"),"C12 latest nonrecoverable HP detail")
	for size in [Vector2i(320,480),Vector2i(800,360),Vector2i(440,900)]:
		root.size = size
		await settle()
		core.node_details("K2")
		await settle()
		check(core.inline_panel.position.y>=0 and core.inline_panel.get_rect().end.y<=core.view.size.y+1,"bounded detail at %s" % size)
		check(core.inline_scroll.size.x<=core.view.size.x,"no horizontal sheet overflow at %s" % size)
		var purchase: Button = core.inline_body.find_child("CorePurchaseRank",true,false)
		check(purchase.size.y>=44,"44px actions at %s" % size)
		if size==Vector2i(320,480): await capture("expanded-tree-detail-320")
	root.size = Vector2i(440,900)
	await settle()
	core._close_inline()
	core.fit_tree()
	await settle()
	await capture("expanded-tree-invested-overview-440")
	app.progression_inputs.corePassiveTreeRevision = 4
	app.progression_inputs.corePassiveNodeRanks = {"attackHaste":1}
	lobby.open_page("코어")
	await settle()
	core.node_details("attackHaste")
	core.scale_at(1.5,Vector2(200,200))
	check(core.selected=="attackHaste" and not core.expanded(),"legacy selected node before migration")
	app.progression_inputs.corePassiveTreeRevision = 5
	app.progression_inputs.corePassiveNodeRanks = {}
	lobby.open_page("코어")
	await settle()
	check(core.expanded() and core.selected.is_empty() and lobby.core_draft.is_empty(),"migration clears stale legacy selection and draft")
	check(is_equal_approx(core.zoom,core.minimum_zoom()),"migration resets legacy720-unit zoom for2800-unit graph")
	print("EXPANDED_CORE_UI failures=",failures)
	lobby.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
