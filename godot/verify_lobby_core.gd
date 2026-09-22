extends SceneTree
const Core = preload("res://ui/lobby_core.gd")
const Growth = preload("res://app/growth_rules.gd")
class Host extends Control:
	var app: Dictionary
	var state: Dictionary
	var body := VBoxContainer.new()
	var core_draft := {}
	var modal: VBoxContainer
	var fail_save := false
	func _p() -> Dictionary: return state
	func _title(id: String) -> String: return id
	func _core_effect_text(_d: Dictionary,rank: int) -> String: return "다음 등급 효과 %d" % rank
	func close_modal() -> bool:
		if is_instance_valid(modal):
			remove_child(modal)
			modal.queue_free()
			modal = null
		return true
	func open_modal(_title_text: String) -> VBoxContainer:
		close_modal()
		modal = VBoxContainer.new()
		add_child(modal)
		return modal
	func _change(command: Dictionary) -> void:
		if fail_save: return
		var result: Dictionary = app.run_domain.growth.execute(state,command)
		if result.ok: state = result.state
var failures: Array[String] = []
func check(value: bool,message: String) -> void:
	if not value: failures.append(message)
func _init() -> void: run.call_deferred()
func run() -> void:
	var growth := Growth.new()
	check(growth.load_catalog(),"growth catalog")
	var host := Host.new()
	host.app = {"run_domain":{"growth":growth}}
	host.state = growth.data.defaultProgression.duplicate(true)
	host.state.totalCorePoints = 30
	host.state.corePassiveNodeRanks = {}
	host.add_child(host.body)
	root.add_child(host)
	var core := Core.new()
	core.setup(host)
	core.render()
	core.view.size = Vector2(400,640)
	core._resize()
	check(core.POLAR.size()==21,"all 21 nodes")
	check(core.GLYPHS.size()==19,"19 material glyphs plus 2 asset icons")
	check(is_equal_approx(core.zoom,400.0/720*0.92),"Flutter fit scale")
	check(core.point("attackOutput")==Vector2(470,360),"unscaled original coordinates")
	core.select_at(core.offset+Vector2(455.242207,236.478848)*core.zoom)
	check(core.selected=="attackPrecompute","visible medium node edge selects correct node")
	check(is_instance_valid(core.inline_panel) and not is_instance_valid(host.modal),"node details are inline without modal barrier")
	core.select_at(core.offset+core.point("attackOutput")*core.zoom)
	check(core.selected=="attackOutput","switch nodes without closing panel")
	var preview_count := 0
	for child in core.inline_body.get_children():
		if child is Label and child.text.begins_with("효과"):
			preview_count += 1
			check(child.text=="효과 1","zero-rank detail previews first effect")
	check(preview_count==1,"detail presents a single effect preview")
	core.change_rank("attackOverclock",1)
	check(host.core_draft.is_empty(),"unreachable allocation rejected")
	core.change_rank("attackHaste",1)
	check(host.core_draft.get("attackHaste")==1 and core.changed(),"draft staged without save")
	check(host.state.corePassiveNodeRanks.is_empty(),"draft does not mutate progression")
	core.scale_at(1.5,Vector2(200,300))
	var zoom_before: float = core.zoom
	var offset_before: Vector2 = core.offset
	var draft_before: Dictionary = host.core_draft.duplicate()
	core.skills()
	var locked := false
	for child in core.inline_body.get_children():
		if child is Button and child.text.begins_with("잠김"): locked = child.disabled
	check(locked,"rift skill locked before chapter two")
	host.close_modal()
	check(core.zoom==zoom_before and core.offset==offset_before and host.core_draft==draft_before,"skills preserve zoom pan and draft")
	core.cancel()
	check(host.core_draft.is_empty() and not core.changed(),"cancel restores persisted ranks")
	for i in range(3): core.change_rank("attackHaste",1)
	check(core.valid(core.candidate("attackPrecompute",1)),"third rank enables neighbor")
	core.change_rank("attackPrecompute",1)
	check(not core.valid(core.candidate("attackHaste",-1)),"cannot disconnect invested neighbor")
	host.fail_save = true
	core.apply()
	check(host.state.corePassiveNodeRanks.is_empty() and core.changed(),"failed save preserves draft")
	host.fail_save = false
	core.apply()
	check(host.state.corePassiveNodeRanks==host.core_draft and not core.changed(),"apply saves complete allocation")
	check(core.allocating,"allocation feedback begins after persisted apply")
	var saved_draft: Dictionary = host.core_draft.duplicate()
	core.change_rank("attackOutput",1)
	check(host.core_draft==saved_draft,"allocation locks rank input")
	check(core.rendered_rank("attackPrecompute")==0,"future wave remains unlit")
	core._advance_allocation(480)
	check(core.rendered_rank("attackPrecompute")==1,"neighbor wave lights after 200+280ms")
	core.allocation_tween.kill()
	core._finish_allocation()
	core.confirm_reset()
	check(not host.state.corePassiveNodeRanks.is_empty(),"reset requires confirmation")
	host.close_modal()
	check(not host.state.corePassiveNodeRanks.is_empty(),"reset cancellation preserves ranks")
	for dimensions in [Vector2(320,480),Vector2(800,360),Vector2(400,640)]:
		core.view.size = dimensions
		core._resize()
		check(core.zoom>0 and core.offset.is_finite(),"viewport %s" % dimensions)
	host.state.unlockedStageCount = 6
	core.skills()
	var equip: Button
	for child in core.inline_body.get_children():
		if child is Button and child.text == "장착": equip = child
	check(is_instance_valid(equip) and not equip.disabled,"rift skill unlocked at stage six")
	equip.pressed.emit()
	check(host.state.coreCombatSkill=="riftMark","rift equip command")
	for child in core.inline_body.get_children():
		if child is Button and child.text=="해제": child.pressed.emit(); break
	check(host.state.get("coreCombatSkill")==null,"skill unequip command")
	check(not core.valid({"attackHaste":6}),"rank cap rejected")
	host.state.totalCorePoints = 0
	check(not core.valid({"attackHaste":1}),"insufficient points rejected")
	await process_frame
	if failures.is_empty(): print("PASS lobby core: topology, draft, skills, reset, viewport and constraints")
	else: push_error(str(failures))
	host.queue_free()
	quit(0 if failures.is_empty() else 1)
