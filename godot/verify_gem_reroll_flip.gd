extends SceneTree
## Actual presenter regression: commit ordering, center pivots, controls and lifecycle.
const Fixture = preload("res://verify_gem_reroll_ui.gd")
class App extends Fixture.App:
	var response := {"ok":true}
	func reroll_reward_gems() -> Dictionary:
		requests += 1
		reroll_view.merge({"status":"processing","available":false,"locked":true,"note":"리롤 처리 중…"},true)
		hud.refresh()
		await response_ready
		return response
var failures: Array[String] = []
var checks := 0
var capture_dir := ""
var app
var hud
const OLD := ["attackSpeed","range","heavyWeapon"]
const NEW := ["criticalChance","elementalDamage","chain"]
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func frames(count := 4) -> void:
	for index in count: await process_frame
func capture(label: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir+"/"+label+".png") == OK,"capture "+label)
func cards() -> HBoxContainer: return hud.overlay_body.find_child("GemRewardCards",true,false)
func hit() -> Button: return hud.overlay_body.find_child("GemRewardReroll",true,false)
func faces() -> Array:
	var result := []
	for card in cards().get_children(): result.append(str(card.get_meta("gem_type")))
	return result
func available() -> void:
	app.reroll_view.merge({"status":"available","remaining":3-int(app.run_domain.state.gemRerollsUsed),"free":false,"available":true,"locked":false,"note":""},true)
func commit(options: Array) -> void:
	app.run_domain.state.rewardOptions = options.duplicate()
	app.run_domain.state.gemRerollsUsed += 1
	hud.refresh()
func complete(ok := true) -> void:
	app.response = {"ok":ok}
	app.response_ready.emit()
func reset(width: int) -> void:
	root.size = Vector2i(width,900 if width == 440 else 736); root.content_scale_size = root.size
	app = App.new()
	check(app.catalog.load_catalog() and app.run_domain.initialize(app.catalog,{},0,100),"fixture initialized")
	root.add_child(app)
	hud = load("res://ui/battle_hud.gd").new(); hud.app = app; app.hud = hud; root.add_child(hud)
	await frames()
	var state: Dictionary = app.run_domain.state
	state.merge({"economyRunId":"flip-test","phase":"reward","completedRounds":5,"isPurchasedGemReward":false,"rewardOptions":OLD.duplicate(),"gemRerollsUsed":0,"gemInventory":{"attackSpeed":1},"gemShards":20},true)
	app.scene._native_combat.session.paused = true
	hud.refresh(); await frames(); hud.rewards.gem_entrance._apply(1.0); await frames()
func destroy() -> void:
	hud.queue_free(); app.queue_free(); await frames(2)
func steady() -> Dictionary:
	var result := {}
	for name in ["GemRewardTitle","GemRewardReroll","GemRewardShards"]:
		var node: Control = hud.overlay_body.find_child(name,true,false)
		result[name] = {"node":node,"rect":node.get_global_rect()}
	return result
func check_steady(expected: Dictionary, label: String) -> void:
	for name in expected:
		var node: Control = hud.overlay_body.find_child(name,true,false)
		check(node == expected[name].node and node.get_global_rect().is_equal_approx(expected[name].rect),label+" steady "+name)
func short_clip() -> void:
	await reset(320)
	root.size = Vector2i(320,400); root.content_scale_size = root.size
	for gem in hud.rewards.GEM_COLORS: app.run_domain.state.gemInventory[gem] = 4
	hud.refresh(); await frames()
	hit().pressed.emit(); await frames(); commit(NEW); available(); complete()
	var flip = hud.rewards.gem_flip
	flip.set_process(false); await frames()
	var scroll: ScrollContainer = hud.overlay_body.get_parent()
	scroll.scroll_vertical = 120; await frames()
	flip._apply(0.09); await frames()
	var expected := scroll.get_global_rect().intersection(Rect2(Vector2.ZERO,Vector2(root.size)))
	check(cards().get_child(0).get_global_rect().position.y < expected.position.y,"short viewport actually clips the cards")
	for track in flip._cards:
		var value: Vector4 = track.material.get_shader_parameter("clip_rect")
		var applied := Rect2(Vector2(value.x,value.y)*Vector2(root.size),Vector2(value.z,value.w)*Vector2(root.size))
		check(applied.is_equal_approx(expected),"composite inherits original scroll clipping")
	if not capture_dir.is_empty():
		for track in flip._cards: track.group.hide()
		await RenderingServer.frame_post_draw
		var baseline := root.get_texture().get_image()
		for track in flip._cards: track.group.show()
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		var leaked := 0
		for y in rendered.get_height():
			for x in rendered.get_width():
				if not expected.has_point(Vector2(x+0.5,y+0.5)) and rendered.get_pixel(x,y) != baseline.get_pixel(x,y): leaked += 1
		check(leaked == 0,"actual GL composite has zero pixels outside scroll clip")
	await capture("flip-scroll-320x400-front")
	flip._apply(0.18); await frames(); await capture("flip-scroll-320x400-edge")
	flip._apply(0.27); await frames(); await capture("flip-scroll-320x400-new")
	flip._apply(0.6); await frames()
	check(flip.get_child_count() == 0,"short scrolled composite cleans up")
	await destroy()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	for width in [440,320]:
		await reset(width)
		var old_callback: Callable = cards().get_child(0).pressed.get_connections()[0].callable
		await capture("flip-before-"+str(width))
		hit().pressed.emit(); await frames()
		await capture("flip-pending-"+str(width))
		commit(NEW); await frames()
		check(faces() == OLD and not hud.rewards.gem_flip.active,"persisted-before-await stays old "+str(width))
		available(); hud.refresh(); await frames()
		check(faces() == OLD and not hud.rewards.gem_flip.active,"early unlocked service signal stays old "+str(width))
		complete()
		var flip = hud.rewards.gem_flip
		flip.set_process(false)
		await frames()
		check(flip.active and not hud.rewards.gem_entrance.active,"success uses only flip "+str(width))
		flip.set_process(false)
		flip._apply(0.0); await frames()
		var surroundings := steady()
		var revision: int = hud.rewards._layout_revision
		var old_cards: HBoxContainer = cards()
		var centers := []
		for card in cards().get_children(): centers.append(card.position+card.size*0.5)
		var before: Dictionary = app.run_domain.state.duplicate(true)
		old_callback.call(); hit().pressed.emit(); cards().get_child(0).pressed.emit()
		hud.overlay_body.find_child("GemRewardShards",true,false).pressed.emit()
		hud.rewards._settle({"kind":"chooseRewardShards"})
		check(hud.rewards.close_back() and app.requests == 1 and app.run_domain.state == before and hud.rewards.pending_gem.is_empty() and not hud.rewards.shard_selected,"all inputs locked "+str(width))
		for sample in [[0.0,"old"],[0.09,"closing"],[0.179,"before-edge"],[0.18,"edge"],[0.181,"after-edge"],[0.27,"opening"],[0.359,"open"]]:
			flip._apply(sample[0]); hud.refresh(); await frames()
			check(cards() == old_cards and hud.rewards._layout_revision == revision,"refresh retains nodes "+sample[1]+str(width))
			check_steady(surroundings,sample[1]+str(width))
			check(faces() == (OLD if sample[0] < 0.18 else NEW),"face boundary "+sample[1]+str(width))
			for index in 3:
				var card: Control = cards().get_child(index)
				check(card.scale == Vector2.ONE and card.rotation == 0 and card.modulate.a == 0.0,"original bounds stay untransformed "+sample[1]+str(width))
				check(card.pivot_offset == Vector2.ZERO and (card.get_transform()*(card.size*0.5)).is_equal_approx(centers[index]),"exact fixed center "+sample[1]+str(width))
				var track: Dictionary = flip._cards[index]
				check(track.copy.size == card.size and track.group.global_position.is_equal_approx(card.get_global_rect().position),"composite follows fixed slot "+sample[1]+str(width))
				if sample[1] == "edge": check(absf(cos(flip.angle)) < 0.001,"edge-on Y rotation "+str(width))
				check(is_equal_approx(flip.angle,PI*float(sample[0])/0.36) and flip.angle < PI,"single half-turn without a second edge crossing "+sample[1]+str(width))
			await capture("flip-"+str(width)+"-"+sample[1])
		flip._apply(0.6); await frames()
		check(not flip.active and faces() == NEW and not cards().get_child(0).disabled and not hit().disabled,"final cleanup and unlock "+str(width))
		check(flip.get_child_count() == 0,"temporary face groups freed after completion "+str(width))
		check(hud.overlay_body.find_children("*","Label",true,false).any(func(label): return label.text == hud.rewards.RULES.chain),"updated rule after flip "+str(width))
		check(app.scene._native_combat.session.paused,"battle pause preserved "+str(width))
		for card in cards().get_children(): check(card.scale == Vector2.ONE and card.pivot_offset == Vector2.ZERO and card.modulate.a == 1.0,"transforms restored "+str(width))
		hud.refresh(); await frames(); check(not flip.active and not hud.rewards.gem_entrance.active,"no duplicate replay "+str(width))
		await capture("flip-"+str(width)+"-final")
		await destroy()
	await short_clip()
	# An already-open shard confirmation keeps its geometry and cannot settle.
	await reset(320)
	hud.overlay_body.find_child("GemRewardShards",true,false).pressed.emit(); await frames()
	var confirm: Button
	for button in hud.overlay_body.find_children("*","Button",true,false):
		if button.text == "파편 받기": confirm = button
	var confirm_rect := confirm.get_global_rect()
	var frame_rect: Rect2 = hud.overlay.get_global_rect()
	hit().pressed.emit(); await frames(); commit(NEW); available(); complete()
	hud.rewards.gem_flip.set_process(false); await frames()
	for button in hud.overlay_body.find_children("*","Button",true,false):
		if button.text == "파편 받기": confirm = button
	confirm.pressed.emit()
	check(hud.rewards.shard_selected and app.run_domain.state.phase == "reward" and confirm.disabled,"open shard confirmation is preserved but locked")
	check(confirm.get_global_rect().is_equal_approx(confirm_rect) and hud.overlay.get_global_rect().is_equal_approx(frame_rect),"open shard confirmation geometry stays fixed")
	hud.rewards.gem_flip._apply(0.6); await frames()
	for button in hud.overlay_body.find_children("*","Button",true,false):
		if button.text == "파편 받기": confirm = button
	check(hud.rewards.shard_selected and not confirm.disabled and confirm.get_global_rect().is_equal_approx(confirm_rect),"completed flip preserves open shard confirmation")
	await destroy()
	# Recovery completing during the initial entrance must wait, not compete.
	await reset(320)
	app.run_domain.state.economyRunId = "entrance-recovery"
	hud.refresh(); await frames()
	hud.rewards.gem_entrance.set_process(false)
	check(hud.rewards.gem_entrance.active,"new reward entrance active")
	app.reroll_view.merge({"status":"recovering","available":true,"locked":true},true); hud.refresh()
	commit(NEW); available(); hud.refresh(); await frames()
	check(hud.rewards.gem_entrance.active and not hud.rewards.gem_flip.active and faces() == OLD,"recovery holds old face until entrance completes")
	hud.rewards.gem_entrance._apply(1.0)
	hit().pressed.emit()
	check(app.requests == 0,"confirmed waiting flip blocks reroll before next refresh")
	hud.refresh()
	hud.rewards.gem_flip.set_process(false); await frames()
	check(not hud.rewards.gem_entrance.active and hud.rewards.gem_flip.active,"confirmed recovery flips after entrance")
	hud.rewards.gem_flip._apply(1.0); await frames()
	check(faces() == NEW and not cards().get_child(0).disabled,"serialized recovery finishes and unlocks")
	await destroy()
	# Confirmed failure without a candidate commit restores ordinary selection.
	await reset(320)
	hit().pressed.emit(); await frames(); available(); complete(false); await frames()
	check(not hud.rewards.gem_flip.active and faces() == OLD and not cards().get_child(0).disabled,"definite failure retains face and unlocks")
	# A delayed rejection/ordinary save retry can unlock without changing offers.
	hit().pressed.emit(); await frames()
	app.reroll_view.merge({"status":"save_failed","available":true,"locked":true},true)
	complete(false); await frames()
	check(cards().get_child(0).disabled and faces() == OLD,"same-offer failed save initially remains locked")
	available(); hud.refresh(); await frames()
	check(not cards().get_child(0).disabled and not hud.rewards._hold_reroll_offer and not hud.rewards.gem_flip.active,"delayed unchanged-offer unlock clears presentation hold")
	# A durable candidate followed by failed outbox retirement is not success.
	hit().pressed.emit(); await frames(); commit(NEW)
	app.reroll_view.merge({"status":"recovering","available":true,"locked":true},true)
	complete(false); await frames()
	check(faces() == OLD and not hud.rewards.gem_flip.active and cards().get_child(0).disabled and not hit().disabled,"failed post-save/outbox holds old face and permits retry")
	hud.refresh(); await frames(); check(faces() == OLD,"duplicate failed refresh cannot flash new face")
	hit().pressed.emit(); await frames(); available(); complete(); await frames()
	check(hud.rewards.gem_flip.active,"retry confirmed prior commit flips once")
	hud.rewards.gem_flip.set_process(false)
	# Resize before midpoint, then drop directly past the end.
	root.size = Vector2i(440,900); root.content_scale_size = root.size; hud.refresh(); await frames()
	hud.rewards.gem_flip._apply(0.09); await frames()
	for card in cards().get_children(): check(card.pivot_offset == Vector2.ZERO and card.scale == Vector2.ONE,"resize retains native card geometry")
	var swaps := [0]
	var original_swap: Callable = hud.rewards.gem_flip._swap
	hud.rewards.gem_flip._swap = func():
		swaps[0] += 1
		original_swap.call()
	hud.rewards.gem_flip._apply(4.0); await frames()
	var completed_revision: int = hud.rewards._layout_revision
	hud.rewards.gem_flip._apply(5.0)
	check(swaps[0] == 1 and is_equal_approx(hud.rewards.gem_flip.angle,PI) and hud.rewards._layout_revision == completed_revision,"dropped frames swap once and finish exactly at PI")
	check(faces() == NEW and not hud.rewards.gem_flip.active and cards().get_child(0).scale == Vector2.ONE,"dropped frame swaps and restores")
	await destroy()
	# Background recovery requires its lock to be released after the commit.
	await reset(320)
	app.reroll_view.merge({"status":"recovering","available":true,"locked":true},true); hud.refresh()
	commit(NEW); await frames(); check(faces() == OLD and not hud.rewards.gem_flip.active,"background unconfirmed commit stays old")
	available(); hud.refresh(); await frames(); check(hud.rewards.gem_flip.active,"background confirmed recovery flips")
	hud.hide(); hud.rewards.gem_flip._process(0.0); await frames(); hud.show(); hud.refresh(); await frames()
	check(not hud.rewards.gem_flip.active and faces() == NEW and not cards().get_child(0).disabled,"hide/reopen consumes flip and unlocks")
	check(hud.rewards.gem_flip.get_child_count() == 0,"hidden/reopened flip leaves no temporary faces")
	# Old request cannot affect a new reward identity.
	hit().pressed.emit(); await frames()
	app.run_domain.state.economyRunId = "new-run"; app.run_domain.state.rewardOptions = OLD.duplicate(); app.run_domain.state.gemRerollsUsed = 0
	available(); hud.refresh(); await frames()
	var revision: int = hud.rewards._layout_revision
	complete(); await frames(); check(hud.rewards._layout_revision == revision and faces() == OLD and not hud.rewards.gem_flip.active,"stale completion ignores new reward")
	# Scene exit while awaiting and while flipping never touches freed controls.
	hit().pressed.emit(); await frames(); hud.queue_free(); await frames(2); complete(); await frames(2)
	app.queue_free(); await frames(2)
	await reset(440)
	hit().pressed.emit(); await frames(); commit(NEW); available(); complete(); await frames()
	check(hud.rewards.gem_flip.active,"exit fixture begins flip")
	await destroy()
	# Reusing a detached HUD must not retain locks or replay a consumed flip.
	await reset(440)
	hit().pressed.emit(); await frames(); commit(NEW); available()
	root.remove_child(hud); complete(); await frames(2); root.add_child(hud); hud.refresh(); await frames()
	check(not hud.rewards._reroll_pending and not hud.rewards.gem_flip.active and faces() == NEW and not cards().get_child(0).disabled,"detach/readd after awaited success clears lock without replay")
	hit().pressed.emit(); await frames(); commit(OLD); available(); complete(); await frames()
	check(hud.rewards.gem_flip.active,"detach flip fixture starts")
	root.remove_child(hud); root.add_child(hud); hud.refresh(); await frames()
	check(not hud.rewards.gem_flip.active and faces() == OLD and not cards().get_child(0).disabled,"detach/readd consumes active flip")
	check(hud.rewards.gem_flip.get_child_count() == 0,"scene exit leaves no temporary faces")
	await destroy()
	# Real wall-clock playback, including a paused SceneTree, finishes unaided.
	await reset(440)
	hit().pressed.emit(); await frames(); commit(NEW); available(); complete(); await frames()
	var began := Time.get_ticks_usec()
	paused = true
	while hud.rewards.gem_flip.active and Time.get_ticks_usec()-began < 900000: await process_frame
	paused = false
	check(not hud.rewards.gem_flip.active and faces() == NEW and Time.get_ticks_usec()-began < 550000,"real-time 0.36s flip completes while paused")
	await destroy()
	if not capture_dir.is_empty():
		# Deterministic 60fps samples from the actual GL viewport, for GIF evidence.
		for width in [440,320]:
			await reset(width)
			hit().pressed.emit(); await frames(); commit(NEW); available(); complete()
			var flip = hud.rewards.gem_flip
			flip.set_process(false)
			await frames()
			check(not flip.swapped and faces() == OLD,"capture begins on old face "+str(width))
			for index in 23:
				flip._apply(minf(index/60.0,0.36)); await frames(2)
				await capture("sequence-"+str(width)+"-%02d" % index)
			await destroy()
	print("GEM_REROLL_FLIP checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
