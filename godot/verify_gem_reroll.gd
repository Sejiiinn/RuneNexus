extends SceneTree
## Durable server offer integration against real app/checkpoint/outbox code.
const Offer = preload("res://app/gem_reroll.gd")
const Commands = preload("res://app/run_commands.gd")
const Codec = preload("res://app/save_codec.gd")
const Fixture = preload("res://verify_result_settlement.gd")
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
const Settlement = preload("res://app/reward_settlement.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const OLD := ["attackSpeed", "range", "physicalDamage"]
const NEW := ["elementalDamage", "lightWeapon", "heavyWeapon"]
class FailingStore extends Store:
	var reject_revision := -1
	func save_save(value: Dictionary) -> Error:
		if reject_revision >= 0 and int(value.get("activeRun", {}).get("gemOfferRevision", 0)) >= reject_revision: return ERR_FILE_CANT_WRITE
		return super.save_save(value)
class RecoveryTransport extends Fixture.Transport:
	var canonical: Dictionary = {}
	var save_revision := 8
	var save_reads := 0
	var writer := 0
	var lose_choice := true
	var exact_choice: Dictionary = {}
	func request(method: int, url: String, body := "", headers := {}) -> Dictionary:
		if url.ends_with("/v1/save/writer"):
			writer += 1
			return {"ok":true,"status":200,"body":{"writerGeneration":writer,"claimedAt":"2026-10-12T00:00:00Z"}}
		if url.ends_with("/v1/save"):
			if method == HTTPClient.METHOD_GET:
				save_reads += 1
				return {"ok":true,"status":200,"body":{"revision":save_revision,"serverSavedAt":"2026-10-12T00:00:00Z","data":canonical.duplicate(true)}}
			var payload: Dictionary = preload("res://app/save_json.gd").parse(body)
			if int(payload.expectedRevision) != save_revision: return {"ok":false,"status":409,"code":"SAVE_REVISION_CONFLICT","body":{}}
			canonical = payload.data.duplicate(true)
			save_revision += 1
			return {"ok":true,"status":200,"body":{"revision":save_revision,"serverSavedAt":"2026-10-12T00:00:00Z"}}
		if url.ends_with("/gems/choose"):
			sent.append({"method":method,"url":url,"body":body,"headers":headers.duplicate(true)})
			if exact_choice.is_empty():
				canonical.activeRun = Offer.project(canonical.activeRun, next_snapshot.gemOffer)
				save_revision += 1
				exact_choice = response.duplicate(true)
				exact_choice.body.saveRevision = save_revision
				snapshot = next_snapshot.duplicate(true)
				next_snapshot = {}
			if lose_choice:
				lose_choice = false
				return {"ok":false,"status":0,"code":"NETWORK_UNAVAILABLE","body":{}}
			return exact_choice.duplicate(true)
		return await super.request(method, url, body, headers)

var failures: Array = []
var checks := 0
var fixture
var delayed_frames := 0
var delayed_max_frame_usec := 0
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label)
func dispose(app):
	if app.services != null: app.services.free()
	app.scene.free()
	app.free()
func wave(app, number := 5):
	var state: Dictionary = app.run_domain.state
	state.phase = "reward"
	state.roundIndex = number
	state.completedRounds = number
	state.isPurchasedGemReward = false
	state.rewardOptions = []
	app.command([], {"phase":"reward", "paused":true})
	check(app.persist_progression(), "waiting offer durable")
func auth(service):
	service.account._authenticated = true
	service.play_ready = true
	service.online_ready = true
func snapshot(http, app, revision: int, count := 0, options := OLD, choice := "") -> Dictionary:
	var result: Dictionary = http.snapshot.duplicate(true)
	result.economyRevision = 10 + revision
	result.gemOfferVersion = 1
	result.wallet.gemResetTickets = 2-maxi(0,count-1)
	result.erase("gemReroll")
	result.erase("gemRerollVersion")
	var offer := {"offerId":"00000000-0000-4000-8000-000000000099","runId":app.run_domain.state.economyRunId,
		"rewardWave":int(app.run_domain.state.completedRounds),"revision":revision,"totalUsed":count,
		"gemOptions":options.duplicate(),"status":"pending" if choice.is_empty() else "chosen","choice":choice,
		"grantedGem":"" if choice in ["","shards"] else choice,"grantedShards":10 if choice == "shards" else 0,
		"gemInventory":app.run_domain.state.gemInventory.duplicate(true),"gemShards":int(app.run_domain.state.gemShards)}
	if choice == "shards": offer.gemShards += 10
	elif not choice.is_empty(): offer.gemInventory[choice] = int(offer.gemInventory.get(choice,0))+1
	result.gemOffer = offer
	return result
func response(http, _app, value: Dictionary):
	http.next_snapshot = value.duplicate(true)
	http.response = {"ok":true,"status":200,"body":{"gemReceipt":{"version":1,"authorityEpoch":value.authorityEpoch,"economyRevision":value.economyRevision,"gemResetTickets":value.wallet.gemResetTickets},"gemOffer":value.gemOffer,
		"saveRevision":20+int(value.gemOffer.revision),"serverSavedAt":"2026-10-12T00:00:00Z"}}
func prepare(name: String):
	var app = fixture.make_app(name)
	check(await app.start_stage(0), name+" starts")
	wave(app)
	var service = fixture.attach(app)
	service.account.transport.snapshot.gemOfferVersion = 1
	service.account.transport.snapshot.wallet.gemResetTickets = 2
	check((await service.economy.refresh()).ok, name+" initial economy")
	return app
func posts(http) -> Array:
	return http.sent.filter(func(item): return "/gems/" in item.url)
func acquire(app):
	var http = app.services.account.transport
	var value := snapshot(http,app,1)
	response(http,app,value)
	var result: Dictionary = await app.reroll_reward_gems()
	check(result.ok and result.initialOffer and Offer.current_offer(app.run_domain.state), "initial server offer durable")
	http.snapshot = value
	return result
func run():
	fixture = Fixture.new()
	fixture.directory = OS.get_cache_dir().path_join("server-gem-" + Settlement.uuid())
	check(Settlement.COMPATIBILITY_VERSION == 11 and preload("res://services/economy_service.gd").COMPATIBILITY == 11 and preload("res://services/online_save.gd").COMPATIBILITY == 11,"all compatibility11")
	var app = await prepare("pending")
	var service = app.services
	var http = service.account.transport
	check(app.gem_reroll_state().locked and app.run_domain.state.rewardOptions.is_empty(),"initial has no client candidates and all selection locked")
	check(not app.apply_run_command({"kind":"chooseRewardShards"}),"no local shard alternate bypass")
	http.response = {"ok":false,"status":0,"code":"NETWORK_UNAVAILABLE","body":{}}
	var result: Dictionary = await app.reroll_reward_gems()
	check(not result.ok and app._pending_gem_reroll() and posts(http).size() == 1,"lost initial response retains immutable outbox")
	var sent: Dictionary = posts(http)[0].duplicate(true)
	# Pending is owned by checkpoint, even when account restore never configures economy.
	service.economy.outbox = null
	check(app._pending_gem_reroll() and app.gem_reroll_state().locked,"auth failure/unconfigured economy still sees durable pending")
	service.economy.outbox = app.checkpoint.rewards()
	auth(service)
	var initial := snapshot(http,app,1)
	response(http,app,initial)
	result = await app.reroll_reward_gems()
	check(result.ok and posts(http).size()==2 and posts(http)[1].body==sent.body and posts(http)[1].headers==sent.headers,"initial recovery exact bytes and key")
	check(not app._pending_gem_reroll() and app.run_domain.state.rewardOptions==OLD,"initial appears only after durable recovery")
	http.snapshot = initial
	# Initial read does not consume the free use. A failed paid projection cannot publish.
	var free := snapshot(http,app,2,1,NEW)
	response(http,app,free)
	result = await app.reroll_reward_gems()
	check(result.ok and app.run_domain.state.gemRerollsUsed==1 and app.run_domain.state.progression.gemResetTickets==2,"first reroll free")
	http.snapshot = free
	var failing := FailingStore.new(app.checkpoint.base_directory,Slot.account(Fixture.ACCOUNT))
	app.checkpoint.store = failing
	failing.reject_revision = 3
	var paid := snapshot(http,app,3,2,OLD)
	response(http,app,paid)
	result = await app.reroll_reward_gems()
	check(not result.ok and app._pending_gem_reroll() and app.run_domain.state.rewardOptions==NEW and app.run_domain.state.progression.gemResetTickets==2,"write failure keeps old wallet/offer and locks")
	failing.reject_revision = -1
	result = await app.reroll_reward_gems()
	check(result.ok and app.run_domain.state.gemRerollsUsed==2 and app.run_domain.state.progression.gemResetTickets==1,"same paid receipt safely recovers")
	http.snapshot = paid
	var last := snapshot(http,app,4,3,NEW)
	response(http,app,last)
	result = await app.reroll_reward_gems()
	check(result.ok and not app.gem_reroll_state().available and not app.gem_reroll_state().locked,"third reroll exhausts but choice stays available")
	http.snapshot = last
	var count := posts(http).size()
	await app.reroll_reward_gems()
	check(posts(http).size()==count,"no fourth reroll request")
	# Current-save recovery precedes projection; failures retain the exact outcome.
	var shards_before := int(app.run_domain.state.gemShards)
	var chosen := snapshot(http,app,5,3,NEW,"shards")
	response(http,app,chosen)
	service.online.ack_fail = true
	result = await app.choose_reward({"kind":"chooseRewardShards"})
	check(not result.ok and app._pending_gem_reroll() and app.run_domain.state.gemShards==shards_before,"failed current save recovery does not project historical choice")
	check(not app.apply_run_command({"kind":"purchaseGemChoice"}),"pending choice locks other run mutation")
	service.online.ack_fail = false
	http.snapshot = chosen
	check((await service.perform("refresh")).ok,"choice ACK retry")
	check(not app._pending_gem_reroll() and app.run_domain.state.gemShards==shards_before+10,"choice exact replay no double shards")
	check(service.online.acknowledged_revision==25,"server save revision adopted")
	# Cached receipt repairs rollback to pre-choice checkpoint before live restore.
	var before_choice: Dictionary = app.checkpoint.store.load_save()
	before_choice.activeRun.phase="reward"; before_choice.activeRun.rewardOptions=NEW.duplicate()
	before_choice.activeRun.gemOfferRevision=4; before_choice.activeRun.gemOfferStatus="pending"
	before_choice.activeRun.gemShards=shards_before
	check(app.checkpoint.store.save_save(before_choice)==OK,"simulate old primary")
	dispose(app)
	app=fixture.make_app("pending")
	check(app.run_domain.state.phase=="preparation" and app.run_domain.state.gemShards==shards_before+10 and app.run_domain.state.gemOfferRevision==5,"cached receipt restores activeRun as well as wallet")
	dispose(app)
	await delayed_checks()
	await stale_checkpoint_checks()
	await equip_checks()
	await obsolete_equip_checks()
	await legacy_checks()
	await legacy_purchase_checks()
	await legacy_usage_checks()
	await corrupted_checks()
	await uncertain_terminal_checks()
	check(fixture.failures.is_empty(),"fixture setup")
	fixture.free()
	print("GEM_REROLL checks=%d failures=%s"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
func delayed_checks():
	var app = fixture.make_app("delayed")
	check(await app.start_stage(0), "delayed starts")
	var service = fixture.attach(app)
	var http = service.account.transport
	http.snapshot.gemOfferVersion = 1
	http.snapshot.wallet.gemResetTickets = 2
	await service.economy.refresh()
	var state: Dictionary = app.run_domain.state.duplicate(true)
	state.roundIndex = 4
	state.completedRounds = 4
	var tick := Time.get_ticks_usec()
	var completed: Dictionary = app.run_domain.service.complete_wave(state, 5)
	var calculation_usec := Time.get_ticks_usec()-tick
	check(completed.ok and completed.state.phase == "reward" and completed.state.rewardOptions.is_empty(), "actual wave5 boundary emits no local cards")
	app.run_domain.state = completed.state
	app.command([], {"phase":"reward", "paused":true})
	tick = Time.get_ticks_usec()
	check(app.persist_progression(), "wave5 boundary persisted")
	var checkpoint_usec := Time.get_ticks_usec()-tick
	response(http, app, snapshot(http, app, 1))
	http.hold = true
	_delayed_release(app, http)
	tick = Time.get_ticks_usec()
	var result: Dictionary = await app.reroll_reward_gems()
	var elapsed_usec := Time.get_ticks_usec()-tick
	check(result.ok and result.initialOffer and delayed_frames >= 15 and elapsed_usec >= 550000, "600ms network wait keeps processing frames; initial response has no reroll flip")
	check(delayed_max_frame_usec < 200000, "delayed request does not stall a frame for the network wait")
	print("GEM_OFFER_TIMING wave_cpu_usec=%d checkpoint_usec=%d injected_network_usec=600000 total_usec=%d continued_frames=%d max_frame_usec=%d" % [calculation_usec, checkpoint_usec, elapsed_usec, delayed_frames, delayed_max_frame_usec])
	await process_frame # Let the transport signal finish before another request.
	http.snapshot = snapshot(http, app, 1)
	response(http, app, snapshot(http, app, 2, 1, NEW))
	_delayed_release(app, http, OLD)
	tick = Time.get_ticks_usec()
	result = await app.reroll_reward_gems()
	elapsed_usec = Time.get_ticks_usec()-tick
	check(result.ok and not result.initialOffer and delayed_frames >= 15 and app.run_domain.state.rewardOptions == NEW, "delayed reroll keeps rendering and replaces only confirmed candidates")
	check(delayed_max_frame_usec < 200000, "reroll response delay never blocks a frame")
	print("GEM_REROLL_TIMING injected_network_usec=600000 total_usec=%d continued_frames=%d max_frame_usec=%d" % [elapsed_usec, delayed_frames, delayed_max_frame_usec])
	await process_frame
	dispose(app)
func _delayed_release(app, http, expected_options: Array = []):
	var finish := Time.get_ticks_usec()+600000
	var previous := Time.get_ticks_usec()
	delayed_frames = 0
	delayed_max_frame_usec = 0
	while Time.get_ticks_usec() < finish:
		await process_frame
		var now := Time.get_ticks_usec()
		delayed_max_frame_usec = maxi(delayed_max_frame_usec, now-previous)
		previous = now
		delayed_frames += 1
		check(app.run_domain.state.rewardOptions == expected_options and app.gem_reroll_state().locked, "waiting network keeps cards and alternate locked")
	http.release.emit()
func stale_checkpoint_checks():
	var app = await prepare("stale-checkpoint")
	var service = app.services
	var http = service.account.transport
	var offered := snapshot(http,app,1)
	response(http,app,offered)
	http.hold = true
	_swap_during_offer(app, service, http)
	var result: Dictionary = await app.reroll_reward_gems()
	check(not result.ok and app.run_domain.state.is_empty() and service.economy.outbox.state.inFlight != null, "late receipt cannot mutate replacement checkpoint or retire old owner command")
	await process_frame
	dispose(app)
func _swap_during_offer(app, service, http):
	await process_frame
	check(service._load_slot("00000000-0000-4000-8000-000000000002"), "replacement account checkpoint loads")
	http.release.emit()
func equip_checks():
	var app = fixture.make_app("equip")
	check(await app.start_stage(0),"equip starts")
	var build: Dictionary = app.run_domain.service.apply(app.run_domain.state,{"kind":"build","type":"arrow","x":2,"y":2})
	# Pick the first legal tile instead of depending on a particular stage layout.
	if not build.ok:
		var map: Dictionary = app.catalog.stage_map(0)
		for cell in range(map.tiles.size()):
			if map.tiles[cell] != "build": continue
			build = app.run_domain.service.apply(app.run_domain.state,{"kind":"build","type":"arrow","x":cell%int(map.columns),"y":cell/int(map.columns)})
			if build.ok: break
	check(build.ok,"valid equip target")
	app.run_domain.state=build.state
	app.command(build.commands)
	wave(app)
	var service=fixture.attach(app)
	var http=service.account.transport
	http.snapshot.gemOfferVersion=1; http.snapshot.wallet.gemResetTickets=2
	await service.economy.refresh()
	await acquire(app)
	var choice:=snapshot(http,app,2,0,OLD,"attackSpeed")
	response(http,app,choice)
	service.online.ack_fail=true
	var target: Dictionary=app.run_domain.state.turrets[0]
	var result: Dictionary=await app.choose_reward({"kind":"chooseRewardGemEquip","type":"attackSpeed","id":target.id,"slot":0})
	check(not result.ok and app.run_domain.state.turrets[0].equippedGemSlots[0]==null and int(app.run_domain.state.gemInventory.get("attackSpeed",0))==0,"failed recovery leaves local equipment unchanged")
	var saved: Dictionary=app.checkpoint.store.load_save()
	dispose(app)
	app=fixture.make_app("equip")
	service=fixture.attach(app); http=service.account.transport
	http.snapshot=choice
	response(http,app,choice)
	check((await service.perform("refresh")).ok,"restart replays chosen equip")
	check(app.run_domain.state.turrets[0].equippedGemSlots[0]=="attackSpeed" and int(app.run_domain.state.gemInventory.get("attackSpeed",0))==0,"replay never restores extra inventory")
	check(await app.resume_run(), "restored equip resumes")
	check(app.apply_run_command({"kind":"removeGem","id":app.run_domain.state.turrets[0].id,"slot":0}),"remove approved gem locally")
	check((await service.economy.refresh()).ok and app.run_domain.state.turrets[0].equippedGemSlots[0]==null and app.run_domain.state.gemInventory.attackSpeed==1,"refresh cannot undo later equipment")
	var other: Dictionary=app.run_domain.state.duplicate(true)
	other.economyRunId="other-run"
	check(Offer.project(other,choice.gemOffer)==other,"receipt never crosses run")
	var later: Dictionary=app.run_domain.state.duplicate(true)
	later.completedRounds=10; later.phase="reward"; later.rewardOptions=[]
	check(Offer.project(later,choice.gemOffer).rewardOptions.is_empty(),"receipt never reopens prior wave")
	saved=app.checkpoint.store.load_save()
	var changed:=saved.duplicate(true); changed.activeRun.gemOfferEquipRevision=0
	check(Hash.hash_payload(changed)!=Hash.hash_payload(saved),"equip recovery marker participates in save hash")
	dispose(app)
func legacy_checks():
	var app=await prepare("legacy")
	var service=app.services
	var http=service.account.transport
	var body={"runId":app.run_domain.state.economyRunId,"completedRounds":5,"expectedRerollCount":0,"clientCompatibilityVersion":7}
	var box=app.checkpoint.rewards()
	var pending: Dictionary=box.state.duplicate(true)
	pending.inFlight={"kind":"reroll_gems","path":"v1/economy/gems/reroll","idempotencyKey":Settlement.uuid(),"encodedBody":JSON.stringify(body),"createdAtMillis":1}
	check(box.save_state(pending)==OK,"old exact command saved")
	var old: Dictionary=http.snapshot.duplicate(true)
	old.erase("gemOfferVersion"); old.gemRerollVersion=1
	old.gemReroll={"runId":body.runId,"rewardWave":5,"totalUsed":1,"gemOptions":NEW.duplicate()}
	http.response={"ok":true,"status":200,"body":{"economy":old,"gemReroll":old.gemReroll}}
	check((await service.economy.refresh()).ok and not app._pending_gem_reroll(),"generation7 successful receipt can retire")
	check(app.run_domain.state.rewardOptions.is_empty() and app.gem_reroll_state().locked,"legacy candidates never become selectable")
	dispose(app)
func corrupted_checks():
	var app=await prepare("corrupt")
	await acquire(app)
	var store=app.checkpoint.store
	# Two writes establish a valid offer backup; corrupt only the primary.
	check(app.persist_progression(),"offer backup checkpoint")
	var fallback: Dictionary = Codec.decode(preload("res://app/save_json.gd").parse(FileAccess.get_file_as_string(store.backup_path)))
	var file=FileAccess.open(store.primary_path,FileAccess.WRITE)
	file.store_string("{broken"); file.close()
	dispose(app)
	app=fixture.make_app("corrupt")
	check(app.checkpoint.store.has_recovery_marker(),"backup provenance waits for current server recovery before cached offer projection")
	check(app.checkpoint.store.load_save() == fallback,"cached economy and migration cannot mutate original uncertain fallback before reconciliation")
	dispose(app)

func legacy_purchase_checks():
	var app = fixture.make_app("legacy-purchase")
	check(await app.start_stage(0),"legacy purchased run starts fixture")
	var alias: Dictionary = app.checkpoint.store.load_save()
	alias.activeRun.phase = "reward"
	alias.activeRun.erase("isPurchasedGemReward")
	alias.activeRun.paidGemRoll = true
	alias.activeRun.rewardReturnPhase = "wave"
	alias.activeRun.rewardOptions = OLD.duplicate()
	check(Codec.decode(alias).activeRun.isPurchasedGemReward,"paidGemRoll alias-only checkpoint remains purchased")
	app.run_domain.state.phase = "reward"
	app.run_domain.state.isPurchasedGemReward = true
	app.run_domain.state.rewardReturnPhase = "wave"
	app.run_domain.state.rewardOptions = OLD.duplicate()
	app.run_domain.state.gemShards = 80
	app.command([], {"phase":"reward","paused":true})
	check(app.persist_progression(),"legacy purchased checkpoint persists without offer markers")
	var service = fixture.attach(app)
	var http = service.account.transport
	http.snapshot.gemOfferVersion = 1
	http.snapshot.wallet.gemResetTickets = 2
	var imported := snapshot(http, app, 1)
	imported.gemOffer.merge({"kind":"purchase","returnPhase":"wave","purchaseSequence":1,"economyRevision":11})
	http.snapshot = imported
	check((await service.economy.refresh()).ok and Offer.current_offer(app.run_domain.state) and app.run_domain.state.gemShards == 80,"current imported offer bridges markerless paid choice without charging again")
	var chosen := snapshot(http, app, 2, 0, OLD, "attackSpeed")
	chosen.gemOffer.merge({"kind":"purchase","returnPhase":"wave","purchaseSequence":1,"economyRevision":12})
	response(http, app, chosen)
	var syncs: int = service.online.sync_calls
	check((await app.choose_reward({"kind":"chooseRewardGem","type":"attackSpeed"})).ok,"imported purchase selects through server")
	check(service.online.sync_calls > syncs and posts(http).size() == 1 and posts(http)[0].url.ends_with("/gems/choose"),"marker bridge synchronizes before choose with no second purchase")
	check(app.run_domain.state.phase == "wave" and app.run_domain.state.gemShards == 80 and app.run_domain.state.gemInventory.attackSpeed == 1,"legacy purchase preserves original debit and return phase")
	dispose(app)

func legacy_usage_checks():
	var app = await prepare("legacy-usage")
	var service = app.services
	var http = service.account.transport
	app.run_domain.state.gemRerollsUsed = 2
	check(app.persist_progression(),"legacy usage: older canonical used2 persists")
	http.snapshot.economyRevision = 15
	http.snapshot.gemRerollVersion = 1
	http.snapshot.gemReroll = {"runId":app.run_domain.state.economyRunId,"rewardWave":5,"totalUsed":3,"gemOptions":NEW.duplicate()}
	check((await service.economy.refresh()).ok and app.run_domain.state.gemRerollsUsed == 3,"legacy usage: current durable used3 repairs canonical counter before sync")
	check(app.run_domain.state.rewardOptions.is_empty() and not Offer.current_offer(app.run_domain.state),"legacy usage: historical candidates remain unusable")
	var offered := snapshot(http, app, 6, 3, OLD)
	response(http, app, offered)
	check((await app.reroll_reward_gems()).ok and service.online.synced_gem_uses.back() == 3,"legacy usage: first new offer synchronizes durable budget3")
	check(app.run_domain.state.rewardOptions == OLD and not app.gem_reroll_state().available,"legacy usage: current offer shown without resetting exhausted budget")
	var protected: Dictionary = app.run_domain.state.duplicate(true)
	protected.gemEconomyRevision = 20
	protected.gemRerollsUsed = 2
	check(Offer.project_snapshot(protected, http.snapshot).gemRerollsUsed == 2,"legacy usage: stale snapshot revision cannot increase protected current budget")
	dispose(app)

func uncertain_terminal_checks():
	var app = await prepare("uncertain-terminal")
	var fallback: Dictionary = app.checkpoint.store.load_save().duplicate(true)
	fallback.activeRun.phase = "failure"
	fallback.activeRun.pendingEconomyDiamonds = 3
	fallback.activeRun.rewardOptions = OLD.duplicate()
	check(app.checkpoint.store._write_atomic(app.checkpoint.store.backup_path, JSON.stringify(fallback,"",false,true)) == OK,"uncertain terminal: historical terminal fallback retained")
	var broken := FileAccess.open(app.checkpoint.store.primary_path,FileAccess.WRITE)
	broken.store_string("{broken-primary"); broken.close()
	app.startup_blocked = true
	check(app.retry_load() and app.checkpoint.store.has_recovery_marker(),"uncertain terminal: actual load restores fallback with durable provenance")
	check(app.checkpoint.rewards().state.pendingRewards.is_empty(),"uncertain terminal: loader never queues a reward from untrusted backup")
	check(app.checkpoint.enqueue_saved(fallback) == ERR_BUSY and app.checkpoint.rewards().state.pendingRewards.is_empty(),"uncertain terminal: direct enqueue also waits for canonical recovery")
	check(not app.persist_progression() and app.checkpoint.store.load_save() == fallback,"uncertain terminal: lifecycle save cannot replace original fallback")
	dispose(app)

func obsolete_equip_checks():
	await _equip_recovery_case(true)
	await _equip_recovery_case(false)

func _equip_recovery_case(target_sold: bool):
	var app = fixture.make_app("obsolete-equip" if target_sold else "retired-equip")
	check(await app.start_stage(0),"obsolete equip: start")
	var map: Dictionary = app.catalog.stage_map(0)
	var tile: int = map.tiles.find("build")
	var built: Dictionary = app.run_domain.service.apply(app.run_domain.state,{"kind":"build","type":"arrow","x":tile%int(map.columns),"y":tile/int(map.columns)})
	check(built.ok,"obsolete equip: approved target exists")
	app.run_domain.state = built.state
	app.command(built.commands)
	wave(app)
	var service = fixture.attach(app)
	service.account.transport.snapshot.gemOfferVersion = 1
	service.account.transport.snapshot.wallet.gemResetTickets = 2
	await service.economy.refresh()
	await acquire(app)
	var old_http = service.account.transport
	var http := RecoveryTransport.new()
	http.app = app
	http.canonical = app.checkpoint.store.load_save().duplicate(true)
	http.snapshot = old_http.snapshot.duplicate(true)
	service.account.add_child(http)
	service.account.transport = http
	old_http.free()
	service.online.free()
	var online = preload("res://services/online_save.gd").new()
	service.add_child(online)
	service.online = online
	service.root_path = app.checkpoint.base_directory
	online.configure(service.account,app.checkpoint.base_directory,"obsolete-equip-fixture",{"quiesce":service._quiesce,"resume":service._resume})
	online.set_process(false)
	check((await online.bootstrap({},false)).ok,"obsolete equip: real canonical save coordinator bootstrapped")
	var chosen := snapshot(http,app,2,0,OLD,"attackSpeed")
	response(http,app,chosen)
	var target: Dictionary = app.run_domain.state.turrets[0].duplicate(true)
	var request := {"kind":"chooseRewardGemEquip","type":"attackSpeed","id":target.id,"slot":0}
	check(not (await app.choose_reward(request)).ok and app.checkpoint.rewards().state.inFlight != null,"obsolete equip: committed server choice loses ACK and retains exact intent")
	var exact: Dictionary = app.checkpoint.rewards().state.inFlight.duplicate(true)
	if not target_sold:
		auth(service)
		check((await service.perform("refresh")).ok and app.checkpoint.rewards().state.inFlight == null and app.run_domain.state.turrets[0].equippedGemSlots[0] == "attackSpeed","retired equip: successful fresh replay equips and retires before equipment upload")
		var writes_before: int = posts(http).size()
		var fallback: Dictionary = http.canonical.duplicate(true)
		check(app.checkpoint.store._write_atomic(app.checkpoint.store.backup_path,JSON.stringify(fallback,"",false,true)) == OK,"retired equip: preserve pre-equipment canonical fallback")
		var broken := FileAccess.open(app.checkpoint.store.primary_path,FileAccess.WRITE)
		broken.store_string("{broken-primary"); broken.close()
		check(app.checkpoint.store.load_save() == fallback and app.checkpoint.store.has_recovery_marker(),"retired equip: actual corrupt primary activates fallback provenance")
		check((await service.sync()).ok and app.run_domain.state.turrets[0].equippedGemSlots[0] == null and int(app.run_domain.state.get("gemOfferEquipRevision",0)) == 0,"retired equip: canonical reload does not trust cached positive revision to equip")
		var reads_before: int = http.save_reads
		check((await service.economy.refresh()).ok and http.save_reads > reads_before,"retired equip: live refresh obtains fresh canonical proof")
		check(posts(http).size() == writes_before and app.run_domain.state.turrets[0].equippedGemSlots[0] == "attackSpeed" and app.run_domain.state.gemInventory.get("attackSpeed",0) == 0,"retired equip: durable intent restores allocation without POST replay or another grant")
		reads_before = http.save_reads
		check((await service.economy.refresh()).ok and http.save_reads == reads_before and posts(http).size() == writes_before,"retired equip: handled allocation does not repeat canonical read or equipment")
		dispose(app)
		return
	# Device B loads the confirmed grant, sells the old target at the same wave,
	# and uploads a newer full canonical checkpoint before device A reconnects.
	var device_b: Dictionary = app.run_domain.state.duplicate(true)
	device_b = Offer.project(device_b,chosen.gemOffer)
	var sold: Dictionary = app.run_domain.service.apply(device_b,{"kind":"sell","id":target.id})
	check(sold.ok,"obsolete equip: device B sells target after committed choice")
	http.canonical.activeRun.turrets = []
	http.canonical.activeRun.gold = sold.state.gold
	http.canonical.activeRun.gemInventory = sold.state.gemInventory.duplicate(true)
	http.save_revision += 1
	var current_gold: int = http.canonical.activeRun.gold
	# Network loss revokes play authorization; a successful reconnect is required
	# before the exact command can retry (real authentication has separate tests).
	auth(service)
	var recovered: Dictionary = await service.perform("refresh")
	check(recovered.ok,"obsolete equip: exact replay plus real current canonical rebase completes: "+JSON.stringify(recovered))
	check(posts(http).size() == 2 and posts(http)[0].body == posts(http)[1].body,"obsolete equip: replay keeps exact original choice request")
	check(app.checkpoint.rewards().state.inFlight == null and app.run_domain.state.turrets.is_empty(),"obsolete equip: successful choice retires without restoring sold layout")
	check(app.run_domain.state.gemInventory.get("attackSpeed",0) == 1 and app.run_domain.state.gold == current_gold and app.run_domain.state.gemOfferEquipRevision == chosen.gemOffer.revision,"obsolete equip: confirmed loose grant and newer gold retained, old equip intent handled")
	var later: Dictionary = app.run_domain.state.duplicate(true)
	later.turrets = [target.duplicate(true)]
	var replay: Dictionary = app.checkpoint._project_gem_offer(app,later,chosen,exact)
	check(not replay.is_empty() and replay.turrets[0].equippedGemSlots[0] == null and replay.gemInventory.get("attackSpeed",0) == 1,"obsolete equip: handled intent cannot attach to a later replacement target")
	# A newer canonical revision cancels even if the spatial address is reused.
	later.gemOfferEquipRevision = 0
	replay = app.checkpoint._project_gem_offer(app,later,chosen,exact)
	check(not replay.is_empty() and replay.turrets[0].equippedGemSlots[0] == null and replay.gemInventory == later.gemInventory,"obsolete equip: same-tile same-type replacement is not redirected")
	later.turrets[0].equippedGemSlots[0] = "range"
	later.turrets[0].equippedGems = ["range"]
	replay = app.checkpoint._project_gem_offer(app,later,chosen,exact)
	check(not replay.is_empty() and replay.turrets == later.turrets and replay.gemInventory == later.gemInventory,"obsolete equip: newer occupied target slot is untouched")
	later.gemInventory = {}
	later.gold = 10000
	var buy_slot: Dictionary = exact.duplicate(true)
	buy_slot.equipIntent.buySlot = true
	buy_slot.equipIntent.slot = later.turrets[0].slotLimit
	# Exercise pre-link cancellation independently of the newer-revision guard:
	# the promised gem is already allocated, so a failed equip cannot buy a slot.
	var parsed: Dictionary = preload("res://app/save_json.gd").parse(exact.encodedBody)
	online.state.baseRevision = int(parsed.sourceSaveRevision) + 1
	# An old persisted positive revision is not fresh proof for cache reloads.
	# lastGemChoice still contains the original intent, but no explicit recovered
	# command means no equip and no consumed/cancelled marker may be synthesized.
	var cached: Dictionary = later.duplicate(true)
	cached.gemInventory = {"attackSpeed":1}
	replay = app.checkpoint._project_gem_offer(app,cached,chosen)
	check(replay.turrets == cached.turrets and replay.gemInventory == cached.gemInventory and replay.gemOfferEquipRevision == 0,"cached equip: positive stale journal revision neither applies nor consumes intent")
	replay = app.checkpoint._project_gem_offer(app,later,chosen,buy_slot)
	check(not replay.is_empty() and replay.turrets == later.turrets and replay.gold == later.gold and replay.gemInventory.is_empty(),"obsolete equip: missing loose gem cannot charge or retain an extra slot")
	later.gemInventory = {"attackSpeed":1}
	replay = app.checkpoint._project_gem_offer(app,later,chosen,exact)
	check(not replay.is_empty() and replay.turrets[0].equippedGemSlots[0] == "attackSpeed" and replay.gemInventory.get("range",0) == 1,"current source: originally approved occupied-slot replacement still executes")
	replay = app.checkpoint._project_gem_offer(app,later,chosen,buy_slot)
	check(not replay.is_empty() and replay.turrets[0].slotLimit == int(later.turrets[0].slotLimit)+1 and replay.turrets[0].equippedGemSlots[int(buy_slot.equipIntent.slot)] == "attackSpeed" and replay.gold < later.gold,"current source: originally approved buy-slot equipment still executes")
	# Cancellation is still a durable save, never permission to swallow disk
	# errors. The successful server grant stays pending until that save succeeds.
	online.state.baseRevision = http.save_revision
	app.run_domain.state.gemOfferEquipRevision = 0
	var box = app.checkpoint.rewards()
	var queued: Dictionary = box.state.duplicate(true)
	queued.inFlight = exact
	check(box.save_state(queued) == OK,"obsolete equip: exact intent retained for write-failure boundary")
	var failing := FailingStore.new(app.checkpoint.base_directory,Slot.account(Fixture.ACCOUNT))
	app.checkpoint.store = failing
	failing.reject_revision = chosen.gemOffer.revision
	var refused: Dictionary = await service.perform("refresh")
	check(not refused.ok and box.state.inFlight != null and app.run_domain.state.gemOfferEquipRevision == 0,"obsolete equip: disk failure cannot retire unresolved local cancellation")
	failing.reject_revision = -1
	check((await service.perform("refresh")).ok and box.state.inFlight == null and app.run_domain.state.gemInventory.get("attackSpeed",0) == 1,"obsolete equip: retry persists cancellation without another grant")
	dispose(app)
