extends SceneTree
## Actual reward presenter at phone widths, including async/stale input contracts.
const Fixture = preload("res://verify_battle_hud.gd")
class App extends Fixture.App:
	signal response_ready
	var reroll_view := {"status":"available","remaining":3,"free":true,"available":true,"locked":false,"note":"젬 다시 뽑기 · 무료"}
	var requests := 0
	func gem_reroll_state() -> Dictionary: return reroll_view.duplicate()
	func reroll_reward_gems() -> Dictionary:
		requests += 1
		reroll_view.merge({"status":"processing","available":false,"locked":true,"note":"리롤 처리 중…"},true)
		hud.refresh()
		await response_ready
		return {"ok":true}
var failures: Array[String] = []
var checks := 0
var capture_dir := ""
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
func reward_bounds(hud) -> Dictionary:
	var result := {"modal":hud.overlay.get_global_rect()}
	for name in ["GemRewardTitle","GemRewardReroll","GemRewardCards","GemRewardDetails","GemRewardShards"]:
		result[name] = hud.overlay_body.find_child(name,true,false).get_global_rect()
	return result

func same_bounds(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size(): return false
	for key in expected:
		if not actual.has(key) or not (actual[key] as Rect2).is_equal_approx(expected[key]): return false
	return true

func verify_stable_reward_layout(app, hud) -> void:
	var state: Dictionary = app.run_domain.state
	var original: Array = state.rewardOptions.duplicate()
	var view: Dictionary = app.reroll_view.duplicate(true)
	var groups := [["attackSpeed","range","physicalDamage"],["elementalDamage","lightWeapon","heavyWeapon"],["damageOverTime","explosion","chain"],["criticalChance","aimSpeed","damageAmplifier"],["armorPiercing","multipleProjectiles","range"]]
	for width in [440,320]:
		root.size = Vector2i(width,900 if width == 440 else 736); root.content_scale_size = root.size
		state.rewardOptions = original.duplicate(); hud.refresh(); await frames()
		var expected := reward_bounds(hud)
		for options in groups:
			state.rewardOptions = options.duplicate(); hud.refresh(); await frames()
			check(reward_bounds(hud) == expected,"candidate-independent row/modal bounds "+str(width)+str(options))
			var row: HBoxContainer = hud.overlay_body.find_child("GemRewardCards",true,false)
			for card in row.get_children():
				check(card.size.y == 220,"fixed220 card height "+str(width)+str(card.get_meta("gem_type")))
				var content: VBoxContainer = card.get_child(0)
				check(content.get_combined_minimum_size().y <= content.size.y+0.5,"card copy fits fixed height "+str(width)+str(card.get_meta("gem_type")))
			var detail: Label = hud.overlay_body.find_child("GemRewardRules",true,false)
			check(detail.get_minimum_size().y <= detail.get_parent().size.y,"all rule lines fit reserved height "+str(width)+str(options))
		for note in ["리롤 처리 중…","처리 결과를 확인해야 합니다. 다시 눌러 확인하세요.","저장에 실패했습니다. 다시 눌러 저장을 재시도하세요."]:
			app.reroll_view.merge({"status":"recovering","locked":true,"note":note},true)
			hud.refresh(); await frames()
			check(reward_bounds(hud) == expected,"status-independent row/modal bounds "+str(width)+note)
			var detail: Label = hud.overlay_body.find_child("GemRerollStatus",true,false)
			check(detail.get_minimum_size().y <= detail.get_parent().size.y,"status fits reserved height "+str(width)+note)
		app.reroll_view = view.duplicate(true)
		state.rewardOptions = original.duplicate(); hud.refresh(); await frames()
		check(reward_bounds(hud) == expected,"final original layout restored "+str(width))

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	var app := App.new()
	check(app.catalog.load_catalog() and app.run_domain.initialize(app.catalog,{},0,100),"catalog/domain initialized")
	root.add_child(app)
	var hud = load("res://ui/battle_hud.gd").new()
	hud.app = app; app.hud = hud; root.add_child(hud)
	await frames()
	var state: Dictionary = app.run_domain.state
	state.economyRunId = "reroll-ui"
	state.phase = "reward"; state.completedRounds = 5; state.isPurchasedGemReward = false
	state.rewardOptions = ["attackSpeed","range","heavyWeapon"]
	state.gemInventory = {"attackSpeed":1,"range":1}; state.gemShards = 20
	hud.refresh(); await frames()
	check(hud.rewards.gem_entrance.active,"ordinary wave keeps entrance")
	var early_reroll: Button = hud.overlay_body.find_child("GemRewardReroll",true,false)
	early_reroll.pressed.emit()
	check(app.requests == 0,"entrance prevents reroll")
	hud.rewards.gem_entrance._apply(1.0)
	await verify_stable_reward_layout(app,hud)
	for width in [440,320]:
		root.size = Vector2i(width,900 if width == 440 else 736); root.content_scale_size = root.size
		hud.refresh(); await frames()
		var hit: Button = hud.overlay_body.find_child("GemRewardReroll",true,false)
		var title: Label = hud.overlay_body.find_child("GemRewardTitle",true,false)
		check(hit.size.x >= 44 and hit.size.y >= 44,"minimum touch target at "+str(width))
		check(hit.find_child("RerollSquare",true,false).size == Vector2(32,32),"32px square at "+str(width))
		check(hit.get_node("RerollRemaining").get_global_rect().position.y >= hud.overlay_body.get_global_rect().position.y,"badge clears scroll clipping at "+str(width))
		check(title.get_global_rect().end.x <= hit.get_global_rect().position.x,"title does not overlap action at "+str(width))
		check(title.get_theme_font("font").get_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,title.get_theme_font_size("font_size")).x <= title.size.x,"title fits at "+str(width))
		check(hud.overlay.get_global_rect().position.x >= 0 and hud.overlay.get_global_rect().end.x <= width,"modal fits at "+str(width))
		check(hit.get_node("RerollRemaining/Count").text == "3" and hit.get_node("RerollCost").text == "무료","free count/cost at "+str(width))
		await capture("reward-free-"+str(width))
	var hit: Button = hud.overlay_body.find_child("GemRewardReroll",true,false)
	var cards: HBoxContainer = hud.overlay_body.find_child("GemRewardCards",true,false)
	var stale_card: Callable = cards.get_child(0).pressed.get_connections()[0].callable
	var stale_reroll: Callable = hit.pressed.get_connections()[0].callable
	hit.pressed.emit()
	stale_reroll.call(); stale_card.call()
	check(app.requests == 1 and hud.rewards.pending_gem.is_empty(),"duplicate and stale card callbacks rejected")
	check(hud.rewards.close_back(),"in-flight back consumed")
	cards = hud.overlay_body.find_child("GemRewardCards",true,false)
	var shard: Button = hud.overlay_body.find_child("GemRewardShards",true,false)
	check(cards.get_child(0).disabled and shard.disabled,"in-flight cards and shards disabled")
	cards.get_child(0).pressed.emit(); shard.pressed.emit()
	var before: Dictionary = state.duplicate(true)
	hud.rewards._settle({"kind":"chooseRewardShards"})
	check(state == before and not hud.rewards.shard_selected and hud.rewards.pending_gem.is_empty(),"locked inputs cannot settle")
	state.rewardOptions = ["criticalChance","elementalDamage","chain"]
	state.gemRerollsUsed = 1
	app.reroll_view = {"status":"available","remaining":2,"free":false,"available":true,"locked":false,"note":"젬 다시 뽑기 · 젬 리셋권 1장"}
	app.response_ready.emit(); await frames()
	check(hud.rewards.gem_flip.active,"successful reroll starts flip")
	hud.rewards.gem_flip._apply(1.0); await frames()
	check(not hud.rewards.gem_entrance.active,"reroll does not replay wave entrance")
	stale_card.call(); stale_reroll.call()
	check(app.requests == 1 and hud.rewards.pending_gem.is_empty(),"old rendered callbacks stay stale after success")
	for width in [440,320]:
		root.size = Vector2i(width,900 if width == 440 else 736); root.content_scale_size = root.size
		hud.refresh(); await frames()
		hit = hud.overlay_body.find_child("GemRewardReroll",true,false)
		check(hit.get_node("RerollRemaining/Count").text == "2" and not hit.disabled,"ticket count at "+str(width))
		var ticket: TextureRect = hit.find_child("GemResetTicket",true,false)
		check(ticket != null and ticket.texture != null and ticket.texture.get_size() == Vector2(256,256),"approved runtime ticket at "+str(width))
		await capture("reward-ticket-"+str(width))
	for status in ["recovering","save_failed"]:
		app.reroll_view.merge({"status":status,"available":true,"locked":true,"note":"처리 결과를 확인해야 합니다. 다시 눌러 확인하세요."},true)
		hud.refresh(); await frames()
		hit = hud.overlay_body.find_child("GemRewardReroll",true,false)
		check(not hit.disabled and hit.get_node("RerollCost").text == "재시도","recovery remains retryable: "+status)
		check(hud.rewards.close_back() and hud.overlay_body.find_child("GemRewardCards",true,false).get_child(0).disabled,"recovery still blocks settlement: "+status)
		if status == "recovering": await capture("reward-recovering-320")
		var prior_requests := app.requests
		hit.pressed.emit()
		check(app.requests == prior_requests+1,"locked recovery action really retries: "+status)
		app.reroll_view.merge({"status":status,"available":true,"locked":true},true)
		app.response_ready.emit(); await frames()
		check(not hud.overlay_body.find_child("GemRewardReroll",true,false).disabled,"unresolved retry can retry again: "+status)
	app.reroll_view.merge({"status":"empty","available":false,"locked":false,"note":"젬 리셋권이 없습니다."},true)
	hud.refresh(); await frames()
	hit = hud.overlay_body.find_child("GemRewardReroll",true,false)
	check(hit.disabled and not hud.overlay_body.find_child("GemRewardCards",true,false).get_child(0).disabled,"empty tickets disable only reroll")
	app.reroll_view.merge({"status":"exhausted","remaining":0,"available":false,"note":"이번 도전의 리롤을 모두 사용했습니다."},true)
	hud.refresh(); await frames()
	hit = hud.overlay_body.find_child("GemRewardReroll",true,false)
	check(hit.disabled and hit.get_node("RerollRemaining/Count").text == "0" and hit.get_node("RerollCost").text == "소진","exhausted total and cost")
	await capture("reward-exhausted-320")
	state.isPurchasedGemReward = true; hud.refresh(); await frames()
	check(hud.overlay_body.find_child("GemRewardReroll",true,false) == null,"purchased gem choices excluded")
	state.isPurchasedGemReward = false
	app.reroll_view.merge({"status":"available","remaining":1,"available":true,"locked":false},true)
	hud.refresh(); await frames()
	hit = hud.overlay_body.find_child("GemRewardReroll",true,false); hit.pressed.emit()
	state.economyRunId = "new-run"
	app.reroll_view.merge({"status":"available","remaining":3,"free":true,"available":true,"locked":false},true)
	hud.refresh(); await frames()
	var generation: int = hud.rewards._layout_revision
	app.response_ready.emit(); await frames()
	check(hud.rewards._layout_revision == generation and not hud.rewards._reroll_pending,"late response leaves new reward untouched")
	# Initial receipt, including migrated budget, must not manufacture a reroll
	# flip from zero cards or resize the approved reward frame.
	state.economyRunId = "initial-empty"
	state.rewardOptions = []
	state.gemRerollsUsed = 0
	app.reroll_view.merge({"status":"awaiting_offer","available":true,"locked":true,"note":"서버 젬 후보를 확인하고 있습니다."},true)
	hud.refresh(); await frames()
	hud.rewards.gem_entrance._apply(1.0); await frames()
	var waiting_bounds := reward_bounds(hud)
	check(hud.overlay_body.find_child("GemRewardCards",true,false).get_child_count() == 0 and hud.overlay_body.find_child("GemRewardShards",true,false).disabled, "initial wait has no candidates and disables alternate")
	check(hud.overlay_body.find_child("GemRerollStatus",true,false).text == "서버 젬 후보를 확인하고 있습니다.", "initial pending status is visible")
	state.rewardOptions = ["attackSpeed","range","heavyWeapon"]
	state.gemRerollsUsed = 1
	app.reroll_view.merge({"status":"available","available":true,"locked":false,"free":false,"remaining":2,"note":""},true)
	hud.refresh(); await frames()
	check(not hud.rewards.gem_flip.active and not hud.rewards._hold_reroll_offer and hud.overlay_body.find_child("GemRewardCards",true,false).get_child_count() == 3, "initial server receipt appears without a flip even with migrated budget")
	if not same_bounds(reward_bounds(hud), waiting_bounds): print("INITIAL_BOUNDS before=", waiting_bounds, " after=", reward_bounds(hud))
	check(same_bounds(reward_bounds(hud), waiting_bounds), "initial arrival preserves existing row and modal layout")
	print("GEM_REROLL_UI checks=",checks," failures=",failures)
	hud.queue_free(); app.queue_free(); await frames(2)
	quit(0 if failures.is_empty() else 1)
