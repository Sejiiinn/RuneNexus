extends "res://app/app_save_state.gd"
## Reward gem offers, rerolls, purchases and choices, through the run deck or
## immutable server commands.

# Every offer/purchase/choice/reroll is an immutable account command. In-flight state
# is read from the checkpoint even before the economy service has been configured.
func _pending_gem_reroll() -> bool:
	var box = checkpoint.rewards()
	if box == null or not box.loaded: return true
	var pending: Variant = box.state.get("inFlight")
	return pending is Dictionary and pending.get("kind") in ["offer_gems", "purchase_gems", "reroll_gems", "choose_gem"]

func gem_reroll_state() -> Dictionary:
	var state: Dictionary = run_domain.state
	var used := clampi(int(state.get("gemRerollsUsed", 0)), 0, GemReroll.MAX_USES)
	var view := {"status":"available", "remaining":GemReroll.MAX_USES-used, "free":used == 0, "available":false, "locked":false, "note":_gem_reroll_note}
	var purchased := bool(state.get("isPurchasedGemReward", false))
	if state.get("phase") != "reward" or (not purchased and not GemReroll.eligible(state)): return view
	if _gem_deck_missing():
		view.merge({"status":"processing", "locked":true, "note":"젬 후보를 불러오는 중…"}, true)
		return view
	if not _gem_deck().is_empty():
		# Deck runs never wait for the network; only local save health matters.
		if save_failed:
			view.merge({"status":"save_failed", "available":true, "locked":true, "note":"저장에 실패했습니다. 다시 눌러 저장을 재시도하세요."}, true)
			return view
		return _gem_reroll_budget(view, state, purchased)
	if _gem_reroll_requesting or (services != null and services.economy != null and services.economy.busy):
		view.merge({"status":"processing", "locked":true, "note":"서버 보상 확인 중…"}, true)
		return view
	if checkpoint.owner == "guest" or services == null or not services.connected() or not services.online_ready or services.blocks_play():
		view.merge({"status":"offline", "locked":true, "note":"인증과 서버 연결을 완료해 주세요."}, true)
		return view
	if _pending_gem_reroll():
		view.merge({"status":"recovering", "available":true, "locked":true, "note":"처리 결과를 확인해야 합니다. 다시 눌러 확인하세요."}, true)
		return view
	if save_failed:
		view.merge({"status":"save_failed", "available":true, "locked":true, "note":"저장에 실패했습니다. 다시 눌러 저장을 재시도하세요."}, true)
		return view
	if services.economy == null or int(services.economy.snapshot.get("gemOfferVersion", 0)) != 1:
		view.merge({"status":"unsupported", "locked":true, "note":"서버 젬 보상을 사용할 수 없습니다."}, true)
		return view
	if not GemReroll.current_offer(state):
		view.merge({"status":"awaiting_offer", "available":true, "locked":true, "note":"서버 젬 후보를 확인하고 있습니다. 다시 눌러 재시도하세요."}, true)
		return view
	return _gem_reroll_budget(view, state, purchased)

func _gem_reroll_budget(view: Dictionary, state: Dictionary, purchased: bool) -> Dictionary:
	var used := clampi(int(state.get("gemRerollsUsed", 0)), 0, GemReroll.MAX_USES)
	if not GemReroll.current_offer(state):
		view.merge({"status":"awaiting_offer", "locked":true}, true)
		return view
	if purchased:
		view.status = "purchased"
		return view
	if used >= GemReroll.MAX_USES:
		view.merge({"status":"exhausted", "note":"이번 도전의 리롤을 모두 사용했습니다."}, true)
		return view
	if used > 0 and int(state.get("progression", {}).get("gemResetTickets", 0)) <= 0:
		view.merge({"status":"empty", "note":"젬 리셋권이 없습니다."}, true)
		return view
	view.available = true
	return view

func _gem_values() -> Dictionary:
	var state: Dictionary = run_domain.state
	return {"runId":state.get("economyRunId", ""), "completedRounds":state.get("completedRounds", 0),
		"offerId":state.get("gemOfferId", ""), "expectedOfferRevision":int(state.get("gemOfferRevision", 0)),
		"expectedRerollCount":int(state.get("gemRerollsUsed", 0))}

func _maybe_request_gem_offer() -> void:
	if in_lobby: return
	if run_domain.state.get("isPurchasedGemReward", false) or not GemReroll.eligible(run_domain.state) or GemReroll.current_offer(run_domain.state): return
	if _gem_reroll_requesting or Time.get_ticks_msec() < _gem_offer_retry_at: return
	var deck := _gem_deck()
	if not deck.is_empty():
		if not _apply_gem_step(func(state: Dictionary) -> Dictionary: return GemDeck.offer(state, deck)).get("ok", false):
			_gem_offer_retry_at = Time.get_ticks_msec() + 5000
		return
	if _gem_deck_missing():
		_gem_offer_retry_at = Time.get_ticks_msec() + 5000
		if services != null and not services.blocks_play() and not services.economy.busy: _reload_gem_deck.call_deferred()
		return
	if services == null or services.blocks_play() or services.economy == null or services.economy.busy: return
	_gem_offer_retry_at = Time.get_ticks_msec() + 5000
	reroll_reward_gems.call_deferred()

func reroll_reward_gems() -> Dictionary:
	if run_domain.state.get("isPurchasedGemReward", false): return {"ok":false,"code":"REROLL_UNAVAILABLE"}
	var deck := _gem_deck()
	if not deck.is_empty():
		if save_failed and not persist_progression(): return {"ok":false, "code":"LOCAL_SAVE_FAILED", "initialOffer":false}
		var available := gem_reroll_state()
		if not available.available or available.locked: return {"ok":false, "code":"REROLL_UNAVAILABLE", "initialOffer":false}
		var rerolled := _apply_gem_step(func(state: Dictionary) -> Dictionary: return GemDeck.reroll(state, deck))
		rerolled.initialOffer = false
		return rerolled
	var view := gem_reroll_state()
	if not view.available or _gem_reroll_requesting or startup_blocked or in_lobby or _gem_deck_missing(): return {"ok":false, "code":"REROLL_UNAVAILABLE"}
	if save_failed and not persist_progression(): return {"ok":false, "code":"LOCAL_SAVE_FAILED"}
	if not GemReroll.eligible(run_domain.state): return {"ok":false, "code":"STALE_REWARD"}
	var initial := not GemReroll.current_offer(run_domain.state)
	var action := "refresh" if _pending_gem_reroll() else ("offer_gems" if initial else "reroll_gems")
	var result: Dictionary = await _perform_gem_command(action, _gem_values())
	result.initialOffer = initial
	return result

func purchase_reward_gems() -> Dictionary:
	if _gem_reroll_requesting or startup_blocked or in_lobby or _battle_preparation_pending() or _gem_deck_missing(): return {"ok":false,"code":"GEM_PURCHASE_UNAVAILABLE"}
	if _pending_gem_reroll(): return await recover_reward_command()
	if services == null or services.blocks_play() or not _server_run_matches(): return {"ok":false,"code":"ACCOUNT_REQUIRED"}
	if save_failed and not persist_progression(): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	if not command() or run_domain.state.get("phase") not in ["preparation", "wave"]: return {"ok":false,"code":"STALE_REWARD"}
	var cost := int(run_domain.growth.data.constants.gemChoicePurchaseCost)
	if int(run_domain.state.get("gemShards", 0)) < cost: return {"ok":false,"code":"INSUFFICIENT_GEM_SHARDS"}
	var deck := _gem_deck()
	if not deck.is_empty():
		var resume := {"runId":run_domain.state.get("economyRunId", ""), "running":not bool(scene.combat_runtime.session.get("paused", false)), "pauseGeneration":_pause_generation}
		if not command([], {"paused":true}): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
		var purchased := _apply_gem_step(func(state: Dictionary) -> Dictionary: return GemDeck.purchase(state, deck, cost))
		if purchased.get("ok", false): _gem_purchase_resume = resume
		elif resume.running and int(resume.pauseGeneration) == _pause_generation: command([], {"paused":false})
		return purchased
	return await _perform_gem_command("purchase_gems", _gem_values())

func recover_reward_command() -> Dictionary:
	if startup_blocked or in_lobby: return {"ok":false,"code":"GEM_OFFER_PENDING"}
	if save_failed and not persist_progression(): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	return await _perform_gem_command("refresh", {})

func choose_reward(command: Dictionary) -> Dictionary:
	if startup_blocked or in_lobby: return {"ok":false,"code":"GEM_OFFER_PENDING"}
	if gem_reroll_state().locked or not GemReroll.current_offer(run_domain.state): return {"ok":false,"code":"GEM_OFFER_PENDING"}
	if command.get("kind") not in RunKinds.REWARD_CHOICES: return {"ok":false,"code":"INVALID_CHOICE"}
	if command.kind == RunKinds.CHOOSE_REWARD_SHARDS and run_domain.state.get("isPurchasedGemReward", false): return {"ok":false,"code":"INVALID_CHOICE"}
	var values := _gem_values()
	values.choice = "shards" if command.kind == RunKinds.CHOOSE_REWARD_SHARDS else str(command.get("type", ""))
	if values.choice != "shards" and values.choice not in run_domain.state.rewardOptions: return {"ok":false,"code":"INVALID_CHOICE"}
	if command.kind == RunKinds.CHOOSE_REWARD_GEM_EQUIP:
		if not run_domain.service.validate_reward_equip(run_domain.state, command): return {"ok":false,"code":"INVALID_EQUIP"}
		var target: Dictionary = run_domain.service.turret(run_domain.state, int(command.get("id", -1)))
		values.equipIntent = {"x":target.x,"y":target.y,"turretType":target.type,"slot":command.get("slot", -1),"buySlot":command.get("buySlot", false)}
	if not _gem_deck().is_empty():
		var chosen := _apply_gem_step(func(state: Dictionary) -> Dictionary: return _deck_choice(state, str(values.choice), command))
		if chosen.get("ok", false) and command.kind == RunKinds.CHOOSE_REWARD_GEM_EQUIP: scene.play_gem_equip_burst(int(command.id), str(values.choice))
		_resume_after_gem_purchase()
		refresh_ui()
		return chosen
	return await _perform_gem_command("choose_gem", values)

## Server runs reconcile owned gems through the deck log, so a support core can
## spend a gem only in deck runs; a run without a deck validates every upload
## against server ownership instead. Guest runs keep their gems locally.
func support_core_blocked() -> bool:
	return checkpoint.owner != "guest" and _gem_deck().is_empty()

## The active run's gem deck, or {} when rewards use server commands.
func _gem_deck() -> Dictionary:
	if services == null or services.economy == null or checkpoint.owner == "guest" or run_domain.state.is_empty() or not services.economy.has_method("gem_deck"): return {}
	return services.economy.gem_deck(str(run_domain.state.get("economyRunId", "")))

func _gem_deck_missing() -> bool:
	if services == null or services.economy == null or run_domain.state.is_empty() or not services.economy.has_method("gem_deck_missing"): return false
	return services.economy.gem_deck_missing(str(run_domain.state.get("economyRunId", "")))

# A restarted process reads the deck again; deck runs never use server offers.
func _reload_gem_deck() -> void:
	_gem_reroll_requesting = true
	refresh_ui()
	await services.perform("refresh")
	_gem_reroll_requesting = false
	refresh_ui()

## Applies one deck reward step to the live run and its durable checkpoint.
func _apply_gem_step(step: Callable) -> Dictionary:
	if startup_blocked or in_lobby or _battle_preparation_pending(): return {"ok":false,"code":"GEM_OFFER_PENDING"}
	if (step.call(run_domain.state) as Dictionary).is_empty(): return {"ok":false,"code":"REROLL_UNAVAILABLE"}
	# Settle combat events first so the step builds on the live run.
	if not command(): return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	var next: Dictionary = step.call(run_domain.state)
	if next.is_empty(): return {"ok":false,"code":"REROLL_UNAVAILABLE"}
	if not commit_run_state(next):
		_record_save_failure()
		return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	_gem_reroll_note = ""
	refresh_selection()
	refresh_ui()
	return {"ok":true}

func _deck_choice(state: Dictionary, choice: String, request: Dictionary) -> Dictionary:
	var next := GemDeck.choose(state, choice)
	if next.is_empty() or request.get("kind") != RunKinds.CHOOSE_REWARD_GEM_EQUIP: return next
	var service = run_domain.service
	var id := int(request.get("id", -1))
	if request.get("buySlot", false):
		var linked: Dictionary = service.apply(next, {"kind":RunKinds.LINK, "id":id})
		if not linked.get("ok", false): return {}
		next = linked.state
	var equipped: Dictionary = service.apply(next, {"kind":RunKinds.EQUIP_GEM, "id":id, "slot":int(request.get("slot", -1)), "type":choice})
	if not equipped.get("ok", false): return {}
	next = equipped.state
	next.gemOfferEquipRevision = next.gemOfferRevision
	return next

func _perform_gem_command(action: String, values: Dictionary) -> Dictionary:
	if _gem_reroll_requesting or _battle_preparation_pending(): return {"ok":false,"code":"BUSY"}
	if services == null or services.blocks_play() or checkpoint.owner == "guest": return {"ok":false,"code":"ACCOUNT_REQUIRED"}
	_gem_reroll_requesting = true
	_gem_reroll_note = ""
	if action == "purchase_gems":
		_gem_purchase_resume = {"runId":run_domain.state.get("economyRunId", ""), "running":not bool(scene.combat_runtime.session.get("paused", false)), "pauseGeneration":_pause_generation}
		if not command([], {"paused":true}):
			_gem_reroll_requesting = false
			return {"ok":false,"code":"LOCAL_SAVE_FAILED"}
	refresh_ui()
	var result: Dictionary = await services.perform(action, values)
	_gem_reroll_requesting = false
	_gem_offer_retry_at = Time.get_ticks_msec() + 5000
	if not result.get("ok", false):
		var code := str(result.get("code", "REQUEST_FAILED"))
		if code in ["INSUFFICIENT_GEM_RESET_TICKETS", "INSUFFICIENT_GEM_TICKETS"]: _gem_reroll_note = "젬 리셋권이 없습니다."
		elif code == "INSUFFICIENT_GEM_SHARDS": _gem_reroll_note = "젬 파편이 부족합니다."
		elif code == "GEM_REROLL_LIMIT_REACHED": _gem_reroll_note = "이번 도전의 리롤을 모두 사용했습니다."
		else: _gem_reroll_note = "서버 보상을 확인하지 못했습니다. 다시 시도해 주세요."
	if result.get("ok", false) and action == "choose_gem" and values.has("equipIntent") and run_domain.state.get("economyRunId") == values.get("runId"):
		var intent: Dictionary = values.equipIntent
		for target in run_domain.state.get("turrets", []):
			var slot := int(intent.get("slot", -1))
			var slots: Array = target.get("equippedGemSlots", [])
			if target.x == intent.x and target.y == intent.y and target.type == intent.turretType and slot >= 0 and slot < slots.size() and slots[slot] == values.choice:
				scene.play_gem_equip_burst(int(target.id), str(values.choice))
				break
	_resume_after_gem_purchase()
	if action == "purchase_gems" and not result.get("ok", false): checkpoint.message = _gem_reroll_note
	refresh_selection()
	refresh_ui()
	return result

# A purchased choice paused combat; resume it once that reward is finished.
func _resume_after_gem_purchase() -> void:
	if _gem_purchase_resume.is_empty(): return
	var same_run: bool = run_domain.state.get("economyRunId") == _gem_purchase_resume.get("runId")
	var reward_finished: bool = run_domain.state.get("phase") in ["preparation", "wave"]
	if not same_run or (reward_finished and not _pending_gem_reroll()):
		if same_run and _gem_purchase_resume.get("running", false) and int(_gem_purchase_resume.pauseGeneration) == _pause_generation:
			command([], {"paused":false})
		_gem_purchase_resume.clear()
