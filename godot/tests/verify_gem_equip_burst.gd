extends SceneTree
## Actual app/session/checkpoint/account command paths with an inert renderer.
const Fixture = preload("res://tests/verify_result_settlement.gd")
const GemFixture = preload("res://tests/verify_gem_reroll.gd")
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
const Settlement = preload("res://app/reward_settlement.gd")
class Host extends "res://tests/verify_support_fake_battlefield.gd":
	var receipts: Array = []
	func play_gem_equip_burst(id: int, gem: String) -> void:
		receipts.append([id, gem])
class FailingStore extends Store:
	var reject_revision := -1
	func save_save(value: Dictionary) -> Error:
		if reject_revision >= 0 and int(value.get("activeRun", {}).get("gemOfferRevision", 0)) >= reject_revision:
			return ERR_FILE_CANT_WRITE
		return super.save_save(value)
var checks := 0
var failures: Array[String] = []
var fixture
var gems
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func offer(app, wave: int, revision: int) -> void:
	gems.wave(app, wave)
	var http = app.services.account.transport
	var value: Dictionary = gems.snapshot(http, app, revision)
	gems.response(http, app, value)
	var result: Dictionary = await app.reroll_reward_gems()
	check(result.ok and GemFixture.Offer.current_offer(app.run_domain.state), "server offer durable wave%d" % wave)
	http.snapshot = value
func choice(app, kind: String, gem: String, revision: int, id := -1) -> Dictionary:
	var http = app.services.account.transport
	var value: Dictionary = gems.snapshot(http, app, revision, 0, GemFixture.OLD, gem)
	gems.response(http, app, value)
	var command := {"kind":kind,"type":gem}
	if kind == "chooseRewardGemEquip": command.merge({"id":id,"slot":0})
	return await app.choose_reward(command)
func run() -> void:
	fixture = Fixture.new()
	fixture.directory = OS.get_cache_dir().path_join("gem-equip-burst-" + Settlement.uuid())
	gems = GemFixture.new()
	var app = fixture.make_app("cue")
	app.scene.free()
	var host := Host.new()
	app.scene = host
	check(await app.start_stage(0), "domain starts")
	app.run_domain.state.gold = 10000
	var map: Dictionary = app.stage_map(0)
	var tile: int = map.tiles.find("build")
	check(app.apply_run_command({"kind":"build", "type":"arrow", "x":tile % int(map.columns), "y":tile / int(map.columns)}), "build")
	var id: int = app.run_domain.state.turrets[0].id
	app.run_domain.state.gemInventory = {"attackSpeed":1, "range":1}
	check(app.apply_run_command({"kind":"equipGem", "id":id, "type":"attackSpeed", "slot":0}), "inventory equip")
	check(host.receipts == [[id, "attackSpeed"]], "accepted equip emits once")
	check(not app.apply_run_command({"kind":"equipGem", "id":id, "type":"attackSpeed", "slot":0}), "duplicate equip rejected")
	check(not app.apply_run_command({"kind":"equipGem", "id":-1, "type":"range", "slot":0}), "missing turret rejected")
	for frame in 3: app.refresh_selection()
	check(host.receipts.size() == 1, "failed command and repeated frames do not replay")
	check(app.apply_run_command({"kind":"equipGem", "id":id, "type":"range", "slot":0}), "inventory replacement")
	check(host.receipts.size() == 2 and host.receipts[-1] == [id, "range"], "replacement emits once")
	check(app.apply_run_command({"kind":"removeGem", "id":id, "slot":0}), "remove")
	check(host.receipts.size() == 2, "remove has no burst")
	check(not app.apply_run_command({"kind":"equipGem", "id":id, "type":"explosion", "slot":0}), "missing inventory rejected")
	var service = fixture.attach(app)
	var http = service.account.transport
	http.snapshot.gemOfferVersion = 1
	http.snapshot.wallet.gemResetTickets = 2
	check((await service.economy.refresh()).ok, "authenticated economy ready")
	await offer(app, 5, 1)
	check(not app.apply_run_command({"kind":"chooseRewardGemEquip", "id":id, "type":"physicalDamage", "slot":0}), "local reward bypass rejected")
	var invalid: Dictionary = await app.choose_reward({"kind":"chooseRewardGemEquip", "id":-1, "type":"physicalDamage", "slot":0})
	check(not invalid.ok and host.receipts.size() == 2, "invalid server reward target has no cue")
	var result: Dictionary = await choice(app, "chooseRewardGemEquip", "physicalDamage", 2, id)
	check(result.ok, "direct server reward equip")
	check(host.receipts.size() == 3 and host.receipts[-1] == [id, "physicalDamage"], "direct reward emits once")
	var saved: Dictionary = app.checkpoint.store.load_save()
	check(app.run_domain.state.turrets[0].equippedGemSlots[0] == "physicalDamage" and app.run_domain.state.gemInventory.get("physicalDamage", 0) == 0 and saved.activeRun.turrets[0].equippedGemSlots[0] == "physicalDamage", "direct reward uses persisted canonical grant")
	result = await app.choose_reward({"kind":"chooseRewardGemEquip", "id":id, "type":"physicalDamage", "slot":0})
	check(not result.ok and host.receipts.size() == 3, "chosen reward cannot replay cue")
	await offer(app, 10, 3)
	result = await choice(app, "chooseRewardGemEquip", "range", 4, id)
	check(result.ok, "server reward replacement")
	check(host.receipts.size() == 4 and host.receipts[-1] == [id, "range"], "reward replacement emits once")
	check(app.run_domain.state.gemInventory.get("physicalDamage", 0) == 1, "replacement returns previous gem")
	await offer(app, 15, 5)
	result = await choice(app, "chooseRewardGem", "attackSpeed", 6)
	check(result.ok, "server reward to inventory")
	var restored: Dictionary = app.run_domain.state.duplicate(true)
	app.run_domain.restore(restored)
	app.refresh_selection()
	check(host.receipts.size() == 4, "inventory reward and restored equipment do not emit")
	app.checkpoint.store._valid_slot = false
	check(not app.apply_run_command({"kind":"equipGem", "id":id, "type":"attackSpeed", "slot":0}), "failed persistence rejected")
	check(host.receipts.size() == 4, "failed inventory persistence does not emit success cue")
	app.checkpoint.store._valid_slot = true
	app.run_domain.restore(restored)
	check(app.persist_progression(), "persistence retry ready")
	await offer(app, 20, 7)
	var failing := FailingStore.new(app.checkpoint.base_directory, Slot.account(Fixture.ACCOUNT))
	app.checkpoint.store = failing
	failing.reject_revision = 8
	result = await choice(app, "chooseRewardGemEquip", "attackSpeed", 8, id)
	check(not result.ok and app._pending_gem_reroll(), "failed canonical choice save stays pending")
	check(host.receipts.size() == 4 and app.run_domain.state.turrets[0].equippedGemSlots[0] == "range", "failed reward persistence does not equip or emit cue")
	var posts: Array = http.sent.filter(func(item): return item.url.ends_with("/gems/choose"))
	check(posts.size() == 4 and posts.all(func(item): return JSON.parse_string(item.body).clientCompatibilityVersion == 14 and item.headers.Authorization == "Bearer fixture-access"), "all reward choices use authenticated generation14 server transport")
	# Effect rendering, fade and lifetime are covered by the actual-renderer visual check.
	check(host.combat_runtime.clock == 0.0, "feedback does not advance combat")
	check(fixture.failures.is_empty() and gems.failures.is_empty(), "shared account/offer fixture setup")
	service.free()
	app.free()
	host.free()
	gems.free()
	fixture._remove(fixture.directory)
	fixture.free()
	print("GEM_EQUIP_BURST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
