extends SceneTree
const Reroll = preload("res://app/gem_reroll.gd")
const Commands = preload("res://app/run_commands.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Codec = preload("res://app/save_codec.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const Fixture = preload("res://verify_result_settlement.gd")
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
const Settlement = preload("res://app/reward_settlement.gd")
class FailingStore extends Store:
	var reject := false
	var reject_at_count := 0
	func save_save(value: Dictionary) -> Error:
		if reject and int(value.get("activeRun", {}).get("gemRerollsUsed", 0)) >= reject_at_count: return ERR_FILE_CANT_WRITE
		return super.save_save(value)
var failures: Array = []
var checks := 0
var fixture
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label)
func offer(app):
	var state: Dictionary = app.run_domain.state
	state.phase = "reward"
	state.roundIndex = 5
	state.completedRounds = 5
	state.isPurchasedGemReward = false
	state.rewardOptions = ["attackSpeed", "range", "physicalDamage"]
	app.command([], {"phase":"reward", "paused":true})
	check(app.persist_progression(), "offer durable")
func posts(http) -> Array:
	return http.sent.filter(func(item): return item.url.ends_with("/gems/reroll"))
func server_snapshot(http, app, count: int, tickets: int, revision: int) -> Dictionary:
	var result: Dictionary = http.snapshot.duplicate(true)
	result.economyRevision = revision
	result.gemRerollVersion = 1
	result.wallet.gemResetTickets = tickets
	result.gemReroll = null if count == 0 else {"runId":app.run_domain.state.economyRunId, "rewardWave":5, "totalUsed":count, "gemOptions":["elementalDamage", "lightWeapon", "heavyWeapon"]}
	return result
func dispose(app):
	if app.services != null: app.services.free()
	app.scene.free()
	app.free()
func run():
	pure_checks()
	fixture = Fixture.new()
	fixture.directory = OS.get_cache_dir().path_join("reroll-" + Settlement.uuid())
	var guest = fixture.make_app("guest", "guest")
	check(await guest.start_stage(0), "guest starts")
	offer(guest)
	var before: Dictionary = guest.run_domain.state.duplicate(true)
	var saved = guest.checkpoint.store
	var failing := FailingStore.new(guest.checkpoint.base_directory, Slot.guest())
	guest.checkpoint.store = failing
	failing.reject = true
	var result: Dictionary = await guest.reroll_reward_gems()
	check(not result.ok and guest.run_domain.state.rewardOptions == before.rewardOptions and guest.run_domain.state.gemRerollsUsed == 0, "guest failed save preserves free use and candidates")
	failing.reject = false
	result = await guest.reroll_reward_gems()
	check(result.ok and guest.run_domain.state.gemRerollsUsed == 1, "guest durable free")
	check(guest.checkpoint.store.load_save().activeRun.rewardOptions == guest.run_domain.state.rewardOptions, "guest offer persisted")
	check(not guest.gem_reroll_state().available and guest.gem_reroll_state().remaining == 2, "guest cannot spend account ticket")
	var guest_options: Array = guest.run_domain.state.rewardOptions.duplicate()
	dispose(guest)
	guest = fixture.make_app("guest", "guest")
	check(guest.run_domain.state.gemRerollsUsed == 1 and guest.run_domain.state.rewardOptions == guest_options, "guest restart preserves free usage and offer")
	dispose(guest)
	var app = fixture.make_app("account")
	check(await app.start_stage(0), "account starts")
	offer(app)
	var service = fixture.attach(app)
	var http = service.account.transport
	http.snapshot = server_snapshot(http, app, 0, 2, 3)
	check((await service.economy.refresh()).ok, "initial account snapshot")
	check(app.gem_reroll_state().available and app.gem_reroll_state().free, "account free available")
	var original: Array = app.run_domain.state.rewardOptions.duplicate()
	http.response = {"ok":false, "status":0, "code":"NETWORK_UNAVAILABLE", "body":{}}
	result = await app.reroll_reward_gems()
	check(not result.ok and posts(http).size() == 1 and app._pending_gem_reroll(), "lost response durable outbox")
	check(app.gem_reroll_state().locked and not app.apply_run_command({"kind":"chooseRewardShards"}), "unknown result locks candidate settlement")
	check(app.run_domain.state.rewardOptions == original, "timeout keeps old display candidates")
	var first: Dictionary = posts(http)[0].duplicate(true)
	# A nominal 200 without the exact offer receipt must not unlock the old cards.
	http.response = {"ok":true, "status":200, "body":{"economy":http.snapshot}}
	result = await app.reroll_reward_gems()
	check(not result.ok and app._pending_gem_reroll() and app.run_domain.state.rewardOptions == original, "malformed success retains exact pending intent")
	for invalid_economy in [null, []]:
		http.response = {"ok":true, "status":200, "body":{"economy":invalid_economy}}
		result = await app.reroll_reward_gems()
		check(not result.ok and not service.economy.busy and app._pending_gem_reroll(), "malformed nested snapshot returns retryable failure")
	var old_run: String = app.run_domain.state.economyRunId
	dispose(app)
	app = fixture.make_app("account")
	check(await app.resume_run(), "pending account reward resumes paused")
	service = fixture.attach(app)
	http = service.account.transport
	check(app.run_domain.state.economyRunId == old_run and app._pending_gem_reroll(), "account restart restores pending intent and identity")
	http.snapshot = server_snapshot(http, app, 1, 2, 4)
	http.response = {"ok":true, "status":200, "body":{"economy":http.snapshot, "gemReroll":http.snapshot.gemReroll}}
	result = await app.reroll_reward_gems()
	check(result.ok and posts(http).size() == 1 and posts(http)[0].body == first.body and posts(http)[0].headers == first.headers, "recovery replays exact body and key")
	check(not app._pending_gem_reroll() and app.run_domain.state.gemRerollsUsed == 1 and app.run_domain.state.progression.gemResetTickets == 2, "recovery publishes free offer without second consume")
	check(not app.gem_reroll_state().free and app.gem_reroll_state().remaining == 2, "free becomes ticket")
	app.run_domain.state.progression.gemResetTickets = 0
	var empty_posts := posts(http).size()
	check(app.gem_reroll_state().status == "empty" and not app.gem_reroll_state().locked, "no tickets leaves old candidates selectable")
	await app.reroll_reward_gems()
	check(posts(http).size() == empty_posts, "no tickets never submits a consume")
	app.run_domain.state.progression.gemResetTickets = 2
	# Saving server-success state fails after the request: wallet and offer stay atomic.
	failing = FailingStore.new(app.checkpoint.base_directory, Slot.account(Fixture.ACCOUNT))
	app.checkpoint.store = failing
	http.snapshot = server_snapshot(http, app, 1, 2, 4)
	var second_snapshot := server_snapshot(http, app, 2, 1, 5)
	http.response = {"ok":true, "status":200, "body":{"economy":second_snapshot, "gemReroll":second_snapshot.gemReroll}}
	# Earlier sync writes remain valid; fail only the confirmed paid outcome.
	failing.reject_at_count = 2
	failing.reject = true
	result = await app.reroll_reward_gems()
	check(not result.ok and app._pending_gem_reroll() and app.run_domain.state.gemRerollsUsed == 1 and app.run_domain.state.progression.gemResetTickets == 2, "server success local write failure preserves live pair and pending receipt")
	failing.reject = false
	http.snapshot = server_snapshot(http, app, 2, 1, 5)
	result = await app.reroll_reward_gems()
	check(result.ok and app.run_domain.state.gemRerollsUsed == 2 and app.run_domain.state.progression.gemResetTickets == 1, "retry commits paid wallet and offer together")
	var durable: Dictionary = app.checkpoint.store.load_save()
	check(durable.activeRun.gemRerollsUsed == 2 and durable.progression.gemResetTickets == 1, "paid pair durable")
	var third_snapshot := server_snapshot(http, app, 3, 0, 6)
	http.response = {"ok":true, "status":200, "body":{"economy":third_snapshot, "gemReroll":third_snapshot.gemReroll}}
	result = await app.reroll_reward_gems()
	check(result.ok and app.gem_reroll_state().remaining == 0 and not app.gem_reroll_state().available, "maximum two tickets exhausted")
	var post_count := posts(http).size()
	await app.reroll_reward_gems()
	check(posts(http).size() == post_count, "exhausted no extra request")
	dispose(app)
	# Undeployed API never leaves a permanent lock or performs local account reroll.
	app = fixture.make_app("unsupported")
	check(await app.start_stage(0), "unsupported starts")
	offer(app)
	service = fixture.attach(app)
	check((await service.economy.refresh()).ok and app.gem_reroll_state().status == "unsupported", "old server capability is safely unavailable")
	await app.reroll_reward_gems()
	check(posts(service.account.transport).is_empty(), "old server no consume")
	dispose(app)
	check(fixture.failures.is_empty(), "fixture setup checks")
	fixture.free()
	print("GEM_REROLL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
func pure_checks():
	check(Settlement.COMPATIBILITY_VERSION == 7 and preload("res://services/economy_service.gd").COMPATIBILITY == 7 and preload("res://services/online_save.gd").COMPATIBILITY == 7, "all client save and settlement paths use compatibility 7")
	var catalog := Catalog.new()
	var growth := Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(), "catalogs")
	var command := Commands.new(catalog, growth)
	var state: Dictionary = command.initial_state()
	state.economyRunId = "00000000-0000-4000-8000-000000000007"
	state.phase = "reward"
	state.completedRounds = 5
	state.rewardOptions = ["attackSpeed", "range", "physicalDamage"]
	var request := {"kind":"rerollRewardFree", "runId":state.economyRunId, "completedRounds":5, "expectedRerollCount":0}
	var original: Dictionary = state.duplicate(true)
	check(Reroll.options("0198b955-3656-7c40-b3cb-87f427b90be6", 5, 1, Codec.ENUMS.GemType, ["attackSpeed", "range", "physicalDamage"]) == ["damageAmplifier", "elementalDamage", "criticalChance"], "Go/Godot fixed SHA256 candidate vector")
	seed(100)
	var expected_rng := randi()
	seed(100)
	var first: Dictionary = command.apply(state, request)
	check(randi() == expected_rng, "reroll does not consume global combat RNG")
	check(first.ok and state == original and first.state.rewardOptions.size() == 3, "pure free transaction")
	check(first.state.rewardOptions.all(func(gem):return gem not in original.rewardOptions), "exclude immediate previous three")
	check(command.apply(state, request).state.rewardOptions == first.state.rewardOptions, "same identity deterministic")
	check(not command.apply(first.state, request).ok, "guest free cannot repeat")
	state.isPurchasedGemReward = true
	check(not command.apply(state, request).ok, "purchased 20 shard choice excluded")
	state.isPurchasedGemReward = false
	request.completedRounds = 10
	check(not command.apply(state, request).ok, "stale callback reward identity rejected")
	var available: Array = command.derived(state).availableGemTypes
	var second := Reroll.options(state.economyRunId, 5, 2, available, first.state.rewardOptions)
	check(second.all(func(gem): return gem not in first.state.rewardOptions), "second excludes only latest offer")
	var can_repeat := false
	for seq in range(2, 40):
		var rolled := Reroll.options(state.economyRunId, 5, seq, available, first.state.rewardOptions)
		if rolled.any(func(gem):return gem in original.rewardOptions): can_repeat = true
	check(can_repeat, "earlier candidates may return")
	var receipt := {"runId":state.economyRunId, "rewardWave":5, "totalUsed":2, "gemOptions":second}
	var later := state.duplicate(true)
	later.completedRounds = 10
	later.rewardOptions = original.rewardOptions.duplicate()
	var projected := Reroll.project(later, receipt)
	check(projected.gemRerollsUsed == 2 and projected.rewardOptions == later.rewardOptions, "count persists across waves without reopening old offer")
	later.economyRunId = "new-run"
	check(Reroll.project(later, receipt) == later, "receipt cannot cross run identity")
	var envelope: Dictionary = Codec.decode({"version":2,"progression":{"gemResetTickets":2},"preferences":{},"turretModules":{},"activeRun":first.state})
	check(envelope.activeRun.gemRerollsUsed == 1 and envelope.progression.gemResetTickets == 2, "codec preserves count and wallet")
	var changed := envelope.duplicate(true)
	changed.activeRun.gemRerollsUsed = 2
	check(Hash.hash_payload(changed) != Hash.hash_payload(envelope), "run count included in sync hash")
	changed = envelope.duplicate(true)
	changed.progression.gemResetTickets = 3
	check(Hash.hash_payload(changed) != Hash.hash_payload(envelope), "ticket cache included in sync hash")
