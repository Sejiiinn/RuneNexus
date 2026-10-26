extends SceneTree
const Lobby = preload("res://ui/lobby.gd")
const TestLobby = preload("res://tests/verify_lobby.gd")
class RefreshingApp extends TestLobby.FakeApp:
	var lobby_view
	var reject_next := false
	func apply_growth_command(command: Dictionary) -> bool:
		if reject_next:
			reject_next = false
			return false
		var applied := super.apply_growth_command(command)
		# The real lifecycle refreshes the lobby from inside the command too.
		if applied and is_instance_valid(lobby_view): lobby_view.refresh()
		return applied
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
	var app := RefreshingApp.new()
	check(app.catalog.load_catalog(),"catalog loads")
	check(app.run_domain.growth.load_catalog(),"growth loads")
	app.progression_inputs = app.run_domain.growth.data.defaultProgression.duplicate(true)
	app.progression_inputs.totalCorePoints = 60
	app.progression_inputs.corePassiveTreeRevision = 5
	app.progression_inputs.corePassiveNodeRanks = {}
	var lobby := Lobby.new()
	lobby.app = app
	app.lobby_view = lobby
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
	check(not core.expanded_tree.camera.is_empty() and core.zoom<0.39,"overview tap eases the camera instead of jumping")
	await create_timer(0.7).timeout
	check(core.expanded_tree.camera.is_empty() and not core.view.is_processing(),"camera ease finishes on the frame loop and stops ticking")
	check(core.zoom>=0.39 and core.selected.is_empty(),"overview tap zooms without investing")
	core.select_at(core.offset+core.point("S1")*core.zoom)
	core.settle_camera()
	check(core.selected=="S1","detailed touch selects node")
	var s1: Vector2 = core.offset+core.point("S1")*core.zoom
	check(s1.y<core.inline_panel.position.y,"selected node eases above its sheet")
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
	# Background always covers the view: extreme drags stop at the art edge.
	for z in [core.minimum_zoom(),0.3,0.6,0.9]:
		for corner in [Vector2(9000,9000),Vector2(-9000,-9000),Vector2(9000,-9000),Vector2(-9000,9000)]:
			core.zoom = z
			core.offset = corner
			core._clamp()
			var bz: float = maxf(core.zoom,core.expanded_tree.cover_zoom(core))
			var art := Rect2(core.offset+core.center()*core.zoom-Vector2.ONE*1400*bz,Vector2.ONE*2800*bz)
			check(art.position.x<=0.01 and art.position.y<=0.01 and art.end.x>=core.view.size.x-0.01 and art.end.y>=core.expanded_tree.visible_height(core)-0.01,"background covers view at zoom %.2f" % z)
	core.zoom = 0.5
	core._clamp()
	core.change_rank("K1",1)
	check(lobby.core_draft.is_empty(),"unreachable key rejected")
	core.node_details("S1")
	core.change_rank("S1",1)
	check(core.expanded_tree.tick(core,0.05) and core.expanded_tree.grow["S1"]>0 and core.expanded_tree.grow["S1"]<1.0/3,"links grow toward neighbours instead of appearing")
	for i in 2: core.change_rank("S1",1)
	for i in 30: core.expanded_tree.tick(core,0.1)
	check(is_equal_approx(core.expanded_tree.grow["S1"],1.0),"rank three link reaches its neighbours")
	check(core.expanded_tree.remaining_label.text=="60" and core.expanded_tree.draft_chip.visible and core.expanded_tree.draft_chip.text=="−4P 예정","point bar shows remaining points and the draft delta")
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
	core.settle_camera()
	await settle()
	var label: Label = core.inline_body.find_child("CoreCurrentEffect",true,false)
	check(label.text.contains("2회") and label.text.contains("50%"),"stockpile detail uses latest key")
	check(not label.text.contains("감폭"),"removed penalty absent")
	await capture("expanded-tree-stockpile-detail-440")
	var k2_path: Dictionary = lobby.core_draft.duplicate()
	lobby.core_draft = {"S6":3,"A01":3,"B01":3,"C02":2,"B02":1}
	core.update_state()
	core.node_details("C02")
	for i in 20: core.expanded_tree.tick(core,0.1)
	var c02: Node = core.inline_body.find_child("CoreRankBar",true,false)
	check(c02.rank==2 and c02.maximum==3 and c02.applied==0,"C02 rank bar preserves its three segments and planned ranks")
	await settle()
	await capture("expanded-tree-node-detail-440")
	lobby.core_draft = k2_path
	core.update_state()
	core.node_details("C12")
	await settle()
	core.settle_camera()
	# Lower-edge selections are valid above the sheet, but outside the full-view
	# clamp. Rebuilding the sheet must not clamp its briefly absent state.
	core.offset = Vector2(core.view.size.x/2-core.point("C12").x*core.zoom,core.expanded_tree.visible_height(core)-2800.0*core.zoom)
	var apply_zoom: float = core.zoom
	var apply_offset: Vector2 = core.offset
	var apply_view: Control = core.view
	await capture("expanded-tree-before-apply-440")
	core.apply_button.pressed.emit()
	check(core.view==apply_view,"apply updates the existing viewport even when the app refreshes inside the command")
	check(core.actual()==lobby.core_draft,"draft apply persists through real lobby command")
	check(core.zoom==apply_zoom and core.offset==apply_offset,"apply keeps the current viewport immediately")
	# Light leaves the core and reaches each allocated node in path order.
	var wave: Dictionary = core.expanded_tree.wave
	check(not wave.is_empty() and core.allocating,"apply starts the core light wave")
	var path_order := ["S6","A01","B01","C02","K2"]
	for i in path_order.size()-1:
		check(float(wave.distance[path_order[i]])<float(wave.distance[path_order[i+1]]),"wave reaches %s before %s" % [path_order[i],path_order[i+1]])
	check(core.rendered_rank("K2")==0,"keystone stays unlit before the wave arrives")
	core.allocation_elapsed = (float(wave.distance.C02)+1)/float(wave.speed)*1000.0
	check(core.rendered_rank("C02")==3 and core.rendered_rank("K2")==0,"ranks light exactly as the front passes")
	core.allocation_elapsed = 0
	# Extending a kept allocation starts from those nodes, not from the core.
	var kept := {"S6":3,"A01":3,"B01":3}
	var extended := {"S6":3,"A01":3,"B01":3,"B02":1}
	var saved_wave: Dictionary = core.expanded_tree.wave
	core.expanded_tree.begin_wave(core,kept,extended)
	var branch: Dictionary = core.expanded_tree.wave
	check(branch.origins==["B01"] and float(branch.distance.B01)==0.0,"extension light leaves the kept node")
	check(is_equal_approx(float(branch.distance.B02),core.point("B01").distance_to(core.point("B02"))),"extension travels only the new link")
	check(branch.links.size()==1,"kept links do not replay")
	check(core.expanded_tree.begin_wave(core,kept,{"S6":5,"A01":3,"B01":3})==core.expanded_tree.WAVE_BURST_MS,"raising a kept node flashes in place")
	core.expanded_tree.wave = saved_wave
	for i in 120:
		await process_frame
		if not is_equal_approx(core.zoom,apply_zoom) or not core.offset.is_equal_approx(apply_offset):
			check(false,"apply keeps the current viewport through refresh and allocation")
			break
	await create_timer(core.allocation_duration/1000.0+0.1).timeout
	check(not core.allocating and core.selected=="C12","apply finishes allocation and preserves selection")
	check(is_equal_approx(core.zoom,apply_zoom) and core.offset.is_equal_approx(apply_offset),"allocation completion keeps the current viewport")
	await capture("expanded-tree-after-apply-440")
	core.change_rank("S1",1)
	await settle()
	core.settle_camera()
	core.expanded_tree.animate_to(core,[core.zoom*1.1,core.offset+Vector2(40,30)])
	check(not core.expanded_tree.camera.is_empty(),"selection can still be easing before apply")
	apply_zoom = core.zoom
	apply_offset = core.offset
	core.apply_button.pressed.emit()
	check(core.expanded_tree.camera.is_empty(),"apply stops the in-flight camera at its current position")
	await create_timer(core.allocation_duration/1000.0+0.2).timeout
	check(core.actual()==lobby.core_draft and not core.allocating,"apply during easing persists and completes")
	check(is_equal_approx(core.zoom,apply_zoom) and core.offset.is_equal_approx(apply_offset),"apply during easing preserves position and zoom through completion")
	core.change_rank("S1",1)
	app.reject_next = true
	core.apply_button.pressed.emit()
	await settle()
	check(not lobby.message.is_empty() and core.changed() and not core.allocating,"failed apply keeps its draft and displays the existing error")
	core.zoom = 0.6
	core.expanded_tree.interrupt()
	core._clamp()
	core.settle_camera()
	var error_label: Label = lobby._message_label
	apply_view = core.view
	apply_zoom = core.zoom
	apply_offset = core.offset
	core.apply_button.pressed.emit()
	await create_timer(core.allocation_duration/1000.0+0.2).timeout
	check(lobby.message.is_empty() and error_label.text.is_empty(),"successful retry clears the previous failure text")
	check(core.view==apply_view and is_equal_approx(core.zoom,apply_zoom) and core.offset.is_equal_approx(apply_offset),"successful retry preserves the viewport while clearing its error")
	var zoom_before: float = core.zoom
	var offset_before: Vector2 = core.offset
	core.skills()
	check(core.zoom==zoom_before and core.offset==offset_before,"central skill selection preserves viewport")
	core.node_details("C12")
	await settle()
	check(core.inline_body.find_child("CoreCurrentEffect",true,false).text.contains("회복 불가"),"C12 latest nonrecoverable HP detail")
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
	check(not core.zoom_controls.visible,"camera controls hide while a sheet is open")
	core._close_inline()
	var controls: Rect2 = core.zoom_controls.get_rect()
	check(core.zoom_controls.visible and is_equal_approx(controls.end.x,core.view.size.x-8) and is_equal_approx(controls.end.y,core.view.size.y-8),"closing details returns camera controls to the bottom right")
	core.settle_camera()
	core.skills()
	await settle()
	check(core.inline_body.find_child("CoreSkill_guardianBeam",true,false)!=null,"central rune opens the skill sheet")
	await capture("expanded-tree-skill-440")
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
