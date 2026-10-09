extends SceneTree
## Native reward presentation lifetime, input and domain-isolation regression.
const Fixture = preload("res://verify_battle_hud.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func frames(count := 4) -> void:
	for index in count: await process_frame
func real_delay(seconds: float) -> void:
	await create_timer(seconds,true,false,true).timeout
func run() -> void:
	root.size = Vector2i(440,900)
	root.content_scale_size = root.size
	var app := Fixture.App.new()
	check(app.catalog.load_catalog() and app.run_domain.initialize(app.catalog,{},0,100),"fixture initialized")
	root.add_child(app)
	var hud = load("res://ui/battle_hud.gd").new()
	hud.app = app
	app.hud = hud
	root.add_child(hud)
	await frames()
	var state: Dictionary = app.run_domain.state
	state.economyRunId = "gem-entrance"
	state.phase = "reward"
	state.completedRounds = 15
	state.isPurchasedGemReward = false
	state.rewardOptions = ["lightWeapon","criticalChance","damageOverTime"]
	state.gemInventory = {"attackSpeed":2,"chain":1}
	hud.refresh()
	var entrance = hud.rewards.gem_entrance
	var cards: HBoxContainer = hud.overlay_body.find_child("GemRewardCards",true,false)
	var shard: Button = hud.overlay_body.find_child("GemRewardShards",true,false)
	check(entrance.active and cards.get_child_count() == 3,"ordinary fifth-wave reward starts with three existing cards")
	check(cards.get_child(0).disabled and shard.disabled,"input is blocked before layout")
	var before: Dictionary = state.duplicate(true)
	cards.get_child(0).pressed.emit()
	shard.pressed.emit()
	check(hud.rewards.pending_gem.is_empty() and not hud.rewards.shard_selected and state == before,"early selection cannot mutate presentation or domain")
	await frames()
	var start: int = entrance.started_usec
	check(start > 0 and entrance._ring != null,"timeline begins with native layout and auxiliary rune")
	var frame_position: Vector2 = entrance._frame_track.position
	var frame_pivot: Vector2 = entrance._frame_track.pivot
	var frame_size: Vector2 = hud.overlay.size
	# Sample approved start pose without changing the real-time timeline.
	entrance._apply(0)
	check(hud.overlay.scale.is_equal_approx(Vector2(0.9,0.9)) and hud.overlay.position.is_equal_approx(frame_position+Vector2(0,14)),"frame starts smaller and fourteen pixels below native placement")
	check(hud.overlay.pivot_offset.is_equal_approx(frame_size*0.5) and hud.overlay.size.is_equal_approx(frame_size),"frame scales around center without changing native size")
	check((entrance._ring.position+entrance._ring.size*0.5).is_equal_approx(hud.overlay.get_transform()*(hud.overlay.size*0.5)),"sibling rune stays centered on moving frame")
	var left: Control = cards.get_child(0)
	var middle: Control = cards.get_child(1)
	var right: Control = cards.get_child(2)
	check(is_equal_approx(left.position.x,middle.position.x) and is_equal_approx(right.position.x,middle.position.x),"cards start gathered at the central card")
	check(left.scale.is_equal_approx(Vector2(0.7,0.7)) and is_equal_approx(rad_to_deg(left.rotation),8) and is_equal_approx(rad_to_deg(right.rotation),-8),"approved start scale and opposite eight-degree rotations")
	check(is_zero_approx(shard.modulate.a),"shards remain concealed before their delay")
	entrance._apply(0.20)
	check(hud.overlay.scale.x > 0.9 and hud.overlay.scale.x < 1 and hud.overlay.position.y > frame_position.y and hud.overlay.position.y < frame_position.y+14,"frame eases toward native scale and position")
	entrance._apply(0.38)
	check(left.position.x < middle.position.x and right.position.x > middle.position.x,"middle pose spreads cards toward native positions")
	check(is_zero_approx(shard.modulate.a) and is_zero_approx(hud.overlay_body.find_child("GemRewardInventory",true,false).modulate.a),"later content stays concealed during spread")
	entrance._apply(0.40)
	check(hud.overlay.scale == Vector2.ONE and hud.overlay.position == frame_position and entrance.active and left.disabled,"frame settles at forty hundredths while card timeline and lock continue")
	entrance._apply(entrance.elapsed())
	await real_delay(0.18)
	state.gold += 1
	hud.refresh()
	cards = hud.overlay_body.find_child("GemRewardCards",true,false)
	check(cards.get_child(0).disabled,"rebuild immediately locks replacement controls")
	await frames()
	check(entrance.started_usec == start and entrance.elapsed() > 0.18,"body rebuild retains elapsed real time")
	entrance._apply(0.20)
	var rebuilt_position: Vector2 = entrance._frame_track.position
	entrance._apply(0.20)
	check(entrance._frame_track.position == rebuilt_position,"repeated frame sampling does not accumulate animated displacement after rebuild")
	root.size = Vector2i(320,736)
	root.content_scale_size = root.size
	hud.refresh()
	await frames()
	check(entrance.started_usec == start,"resize retains the original timeline")
	var resized_position: Vector2 = (hud.get_viewport_rect().size-hud.overlay.size)*0.5
	entrance._apply(0.20)
	# Animated offsets can round native Control size; compare centers as above.
	check(entrance._frame_track.position.is_equal_approx(resized_position) and hud.overlay.pivot_offset.is_equal_approx(hud.overlay.size*0.5),"resize adopts current native placement and current frame center")
	entrance._apply(entrance.elapsed())
	Engine.time_scale = 0.05
	paused = true
	await real_delay(0.9)
	check(not entrance.active,"real-time entrance completes under pause and altered speed")
	paused = false
	Engine.time_scale = 1
	cards = hud.overlay_body.find_child("GemRewardCards",true,false)
	shard = hud.overlay_body.find_child("GemRewardShards",true,false)
	for card in cards.get_children():
		check(card.scale == Vector2.ONE and is_zero_approx(card.rotation) and card.modulate.a == 1 and not card.disabled,"finished card transform and input restored")
	check(shard.modulate.a == 1 and not shard.disabled and hud.overlay.modulate.a == 1 and hud.rewards.shade.modulate.a == 1,"finished fades and shard input restored")
	check(hud.overlay.position.is_equal_approx(resized_position) and hud.overlay.scale == Vector2.ONE and is_zero_approx(hud.overlay.rotation) and hud.overlay.pivot_offset == frame_pivot,"finished frame restores resized native placement and original transform")
	check(entrance._ring == null and entrance._tracks.is_empty() and entrance._frame_track.is_empty(),"temporary rune and transform tracks removed")
	check(state == before.merged({"gold":state.gold},true),"animation only changes presentation")
	hud.refresh()
	check(not entrance.active and entrance.started_usec == start,"same reward refresh does not replay")
	hud.rewards.pending_gem = "lightWeapon"
	hud.refresh()
	check(hud.rewards.targeting() and not entrance.active,"target selection stays settled")
	hud.rewards.replacement_id = 100
	hud.refresh()
	check(not entrance.active,"replacement screen does not animate reward cards")
	hud.rewards.close_back()
	hud.rewards.close_back()
	check(not entrance.active and hud.overlay.visible,"return from target and replacement stays settled")
	state.phase = "preparation"
	hud.refresh()
	state.phase = "reward"
	hud.refresh()
	check(not entrance.active,"same reward after phase interruption is seen")
	# Preserve caller-owned transforms even when cancellation follows a native fit.
	var custom_scale := Vector2(1.04,0.96)
	var custom_rotation := 0.07
	var custom_pivot := Vector2(11,9)
	hud.overlay.scale = custom_scale
	hud.overlay.rotation = custom_rotation
	custom_rotation = hud.overlay.rotation
	hud.overlay.pivot_offset = custom_pivot
	state.completedRounds = 20
	hud.refresh()
	await frames()
	check(entrance.active,"next fifth-wave reward starts its own entrance")
	await real_delay(0.1)
	hud.rewards._fit_key.clear()
	hud.rewards._fit_modal()
	var cancelled_position: Vector2 = hud.overlay.position
	var cancelled_size: Vector2 = hud.overlay.size
	hud.hide()
	await real_delay(0.04)
	check(not entrance.active and hud.overlay.modulate.a == 1 and entrance._ring == null,"hidden HUD cancels and restores presentation")
	check(hud.overlay.position == cancelled_position and hud.overlay.size == cancelled_size and hud.overlay.scale == custom_scale and hud.overlay.rotation == custom_rotation and hud.overlay.pivot_offset == custom_pivot,"cancel adopts last native fit and exactly restores caller-owned frame transform")
	hud.overlay.scale = Vector2.ONE
	hud.overlay.rotation = 0
	hud.overlay.pivot_offset = frame_pivot
	hud.show()
	hud.refresh()
	check(not entrance.active,"cancelled reward is not replayed on show")
	state.economyRunId = "purchased"
	state.isPurchasedGemReward = true
	hud.refresh()
	check(not entrance.active,"purchased gem choices do not animate")
	state.economyRunId = "non-fifth"
	state.isPurchasedGemReward = false
	state.completedRounds = 16
	hud.refresh()
	check(not entrance.active,"ordinary non-fifth fixture is excluded")
	state.economyRunId = "gem-entrance-stage"
	state.completedRounds = 5
	hud.refresh()
	await frames()
	check(entrance.active,"new run identity starts same numbered reward")
	app.stage = 1
	hud.refresh()
	await frames()
	check(entrance.active and entrance.identity.contains(",1,5"),"stage participates in presentation identity")
	state.phase = "success"
	hud.refresh()
	await frames()
	check(not entrance.active and hud.rewards.result_entrance.active,"terminal entrance retains its separate lifetime")
	check(hud.overlay.modulate.a == 1,"gem fade does not leak into result panel")
	check(hud.overlay.scale == Vector2.ONE and is_zero_approx(hud.overlay.rotation) and hud.overlay.pivot_offset == frame_pivot,"gem frame transform does not leak into result panel")
	state.phase = "preparation"
	hud.refresh()
	state.phase = "reward"
	state.economyRunId = "free-active"
	hud.refresh()
	await frames()
	hud.free()
	check(not is_instance_valid(entrance),"helper lifetime follows HUD free")
	app.free()
	await frames(2)
	print("GEM_REWARD_ENTRANCE checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
