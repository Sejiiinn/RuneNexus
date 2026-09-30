extends SceneTree
## Exercises real modal lifetimes with fixture state and isolated device settings.
const LobbyFixture = preload("res://verify_lobby.gd")
const BattleFixture = preload("res://verify_battle_hud.gd")
const Lobby = preload("res://ui/lobby.gd")
const HUD = preload("res://ui/battle_hud.gd")
const Device = preload("res://app/device_preferences.gd")
class GraphicsScene extends RefCounted:
	var options := {}
	var applications := 0
	func _apply_options() -> void: applications += 1
class App extends LobbyFixture.FakeApp:
	var scene := GraphicsScene.new()
var failures: Array[String] = []
var checks := 0
var captures := OS.get_environment("MODAL_REFRESH_CAPTURE_DIR")
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func settle() -> void:
	for i in range(8): await process_frame
func dimensions(width: int, height: int) -> void:
	root.size = Vector2i(width,height)
	root.content_scale_size = root.size
	await settle()
func capture(label: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(label+".png"))
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		root.push_input(event,true)
	await settle()
func home_ids(home: Control) -> Array:
	return [home.modal.get_instance_id(),home.modal_frame.get_instance_id(),home.modal_scroll.get_instance_id(),home.modal_content.get_instance_id()]
func lobby_ids(lobby: Control) -> Array:
	return [lobby.modal.get_instance_id(),lobby.modal_frame.get_instance_id(),lobby.modal_scroll.get_instance_id(),lobby.modal_body.get_instance_id()]
func battle_ids(hud: Control) -> Array:
	return [hud.modal.get_instance_id(),hud.modal_panel.get_instance_id(),hud.modal_scroll.get_instance_id(),hud.modal_body.get_instance_id()]
func texts(node: Node) -> String:
	var value: String = node.text if node is Label or node is Button else ""
	for child in node.get_children(): value += "\n" + texts(child)
	return value
func run() -> void:
	# The regression runner's named project differs from the user's RuneNexus app.
	check(ProjectSettings.get_setting("application/config/name","") in ["Native regression tests","Modal refresh implementation 20261001"],"Device settings use an isolated regression project")
	if not failures.is_empty(): quit(1); return
	ProjectSettings.set_setting("accessibility/disable_animations",false)
	check(Device.write({"msaa":2,"shadow":2048}),"Fixture graphics settings initialize")
	await dimensions(320,220)
	var app := App.new()
	app.catalog.load_catalog(); app.run_domain.growth.load_catalog()
	app.progression_inputs = {"runes":10000,"clearedStageNumbers":[1,2,3,4,5,6],"unlockedStageCount":7,"researchLevels":{},"activeResearches":[],"turretModules":{"items":[],"tickets":0}}
	var lobby := Lobby.new(); lobby.app=app; root.add_child(lobby)
	await settle()
	lobby.home.open_settings()
	check(is_zero_approx(lobby.home.modal_frame.modulate.a),"Initial settings open has an entrance")
	await create_timer(0.35).timeout
	var ids := home_ids(lobby.home)
	lobby.home.modal_scroll.scroll_vertical = 40; await settle()
	var scroll_y: int = lobby.home.modal_scroll.scroll_vertical
	var choice := lobby.home.modal.find_child("msaa_0",true,false) as Button
	choice.button_pressed=true; choice.pressed.emit()
	await settle()
	check(home_ids(lobby.home)==ids and is_equal_approx(lobby.home.modal_frame.modulate.a,1),"Graphics change preserves shell and entrance state")
	check(lobby.home.modal_scroll.scroll_vertical==scroll_y,"Graphics change preserves settings scroll")
	check(Device.read().msaa==0 and app.scene.options.msaa_samples==0 and app.scene.applications==1,"Graphics choice persists and applies once")
	var prefs_path := ProjectSettings.globalize_path(Device.PATH)
	var saved_at := FileAccess.get_modified_time(prefs_path)
	await create_timer(1.1).timeout
	(lobby.home.modal.find_child("msaa_0",true,false) as Button).pressed.emit()
	check(FileAccess.get_modified_time(prefs_path)==saved_at and app.scene.applications==1,"Already selected graphics value does not write or apply again")
	var shadow := lobby.home.modal.find_child("shadow_512",true,false) as Button
	shadow.button_pressed=true; shadow.pressed.emit(); await settle()
	check(home_ids(lobby.home)==ids and Device.read().shadow==512 and app.scene.options.shadow_map_size==512,"Shadow choice updates within the same settings shell")
	lobby.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN); await settle()
	check(home_ids(lobby.home)==ids and lobby.home.modal_scroll.scroll_vertical==scroll_y,"Focus refresh preserves settings shell and scroll")
	check(is_equal_approx(lobby.home.modal_frame.modulate.a,1),"Focus refresh does not restart the entrance")
	lobby.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	lobby.home.close_modal(); await settle()
	check(not is_instance_valid(lobby.home.modal),"Delayed focus cannot reopen closed settings")
	lobby.home.open_settings(); await create_timer(0.3).timeout
	lobby.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	lobby.home.open_events()
	var events_ids := home_ids(lobby.home)
	await create_timer(0.3).timeout
	check(home_ids(lobby.home)==events_ids and not texts(lobby.home.modal).contains("MSAA"),"Delayed focus cannot replace an intentional dialog transition")
	await dimensions(320,100)
	lobby.home.modal_scroll.scroll_vertical=30; await settle()
	var events_scroll: int=lobby.home.modal_scroll.scroll_vertical
	lobby.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN); await settle()
	check(home_ids(lobby.home)==events_ids and lobby.home.modal_scroll.scroll_vertical==events_scroll,"Event focus preserves shell and scroll")
	await dimensions(440,900)
	lobby.home.open_settings(); await create_timer(0.3).timeout
	lobby.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN); await settle()
	await capture("settings-refreshed-440")
	lobby.home.close_modal()
	lobby.open_page("연구"); await settle()
	lobby.growth._details("researchEfficiency")
	check(is_zero_approx(lobby.modal_visual.modulate.a),"Initial research detail has an entrance")
	await create_timer(0.3).timeout
	var research_ids := lobby_ids(lobby)
	await dimensions(320,220)
	lobby.modal_scroll.scroll_vertical=30; await settle()
	var research_scroll: int=lobby.modal_scroll.scroll_vertical
	app.progression_inputs.runes=0
	lobby.refresh_economy(); await settle()
	check(lobby_ids(lobby)==research_ids and is_equal_approx(lobby.modal_visual.modulate.a,1),"Research economy refresh preserves shell without an entrance")
	check(lobby.modal_scroll.scroll_vertical==research_scroll,"Research refresh preserves scroll")
	check(texts(lobby.modal).contains("보유 0") and texts(lobby.modal).contains("룬 부족"),"Research refresh updates current wallet and start conditions")
	app.progression_inputs.runes=10000
	var result: Dictionary=app.run_domain.growth.execute(app.progression_inputs,{"kind":"startResearch","id":"researchEfficiency","nowMillis":int(Time.get_unix_time_from_system()*1000)})
	check(result.ok,"Fixture research starts")
	app.progression_inputs=result.state
	lobby.refresh(); await settle()
	check(lobby_ids(lobby)==research_ids and texts(lobby.modal).contains("즉시 완료") and texts(lobby.modal).contains("연구 중단"),"Research detail updates active research and its actions in place")
	lobby.refresh()
	lobby.close_modal(); await settle()
	check(not is_instance_valid(lobby.modal),"Deferred research refresh cannot reopen a closed modal")
	lobby.growth._details("researchEfficiency"); await settle()
	lobby.refresh()
	lobby.open_modal("다른 대화상자")
	var other_id: int=lobby.modal.get_instance_id()
	await settle()
	check(lobby.modal.get_instance_id()==other_id and not texts(lobby.modal).contains("즉시 완료"),"Deferred research refresh cannot overwrite another modal")
	lobby.close_modal(); await dimensions(440,900)
	lobby.growth._details("researchEfficiency"); await create_timer(0.3).timeout
	lobby.refresh_economy(); await settle()
	await capture("research-refreshed-440")
	lobby.free(); await settle()
	var battle := BattleFixture.App.new(); root.add_child(battle)
	battle.catalog.load_catalog(); battle.run_domain.initialize(battle.catalog,{},0,100)
	battle.run_domain.state.gold=10000; battle.run_domain.state.gemShards=1000
	var map: Dictionary=battle.catalog.stage(0).map
	var index: int=map.tiles.find("build")
	battle.selected=Vector2i(index % int(map.columns),index / int(map.columns))
	battle.apply_run_command({"kind":"build","x":battle.selected.x,"y":battle.selected.y,"type":"arrow"})
	battle.run_domain.state.turrets[0].level=7
	var hud := HUD.new(); hud.app=battle; battle.hud=hud; root.add_child(hud)
	await settle()
	hud.turret_panel._open_current_traits()
	check(is_zero_approx(hud.modal_panel.modulate.a),"Initial traits modal has an entrance")
	await create_timer(0.3).timeout
	var trait_ids := battle_ids(hud)
	var quote: Dictionary=battle.run_domain.service.quotes(battle.run_domain.state,int(battle.run_domain.state.turrets[0].id))
	var first: String=quote.primaryTraits[0]
	(hud.modal_body.find_child("TraitChoice_"+first,true,false) as Button).pressed.emit()
	await click(hud.modal_body.find_child("TraitTier1",true,false) as Button)
	check(battle_ids(hud)==trait_ids and hud.trait_preview==first and (hud.modal_body.find_child("TraitTier1",true,false) as Button).button_pressed,"Native click on the selected trait tier preserves its preview, panel and selection")
	await dimensions(320,300)
	hud.modal_scroll.scroll_vertical=40; await settle()
	var trait_scroll: int=hud.modal_scroll.scroll_vertical
	(hud.modal_body.find_child("TraitTier2",true,false) as Button).pressed.emit()
	await settle()
	check(battle_ids(hud)==trait_ids and is_equal_approx(hud.modal_panel.modulate.a,1),"Trait tier transition reuses the panel without a fade")
	check(hud.modal_scroll.scroll_vertical==trait_scroll and battle.scene._native_combat.session.paused,"Trait tier transition preserves scroll and combat pause")
	check(hud.trait_preview.is_empty() and (hud.modal_body.find_child("TraitConfirm",true,false) as Button).disabled,"Tier transition resets preview and enforces prerequisite")
	(hud.modal_body.find_child("TraitTier1",true,false) as Button).pressed.emit(); await settle()
	(hud.modal_body.find_child("TraitChoice_"+first,true,false) as Button).pressed.emit()
	var shards: int=battle.run_domain.state.gemShards
	(hud.modal_body.find_child("TraitConfirm",true,false) as Button).pressed.emit(); await settle()
	check(battle.run_domain.state.turrets[0].primaryTrait==first and battle.run_domain.state.gemShards==shards-int(quote.primaryTrait),"Trait confirmation charges actual quote once")
	check(not hud.modal_active() and not battle.scene._native_combat.session.paused,"Trait confirmation closes and resumes combat")
	await dimensions(440,900)
	hud.turret_panel._open_current_traits(); await create_timer(0.3).timeout
	var stale_tab := (hud.modal_body.find_child("TraitTier1",true,false) as Button).pressed.get_connections()[0].callable as Callable
	(hud.modal_body.find_child("TraitTier1",true,false) as Button).pressed.emit(); await settle()
	check((hud.modal_body.find_child("TraitConfirm",true,false) as Button).disabled,"Chosen primary trait remains immutable")
	(hud.modal_body.find_child("TraitTier2",true,false) as Button).pressed.emit(); await settle()
	await capture("trait-tier-refreshed-440")
	hud.close_modal(); stale_tab.call(); await settle()
	check(not hud.modal_active() and not battle.scene._native_combat.session.paused,"A closed traits tab callback cannot reopen the modal or pause combat")
	hud.free(); battle.free(); await settle()
	print("MODAL_REFRESH checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
