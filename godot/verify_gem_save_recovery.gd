extends SceneTree
## Independent crash-boundary coverage for server-mutated saves and gem receipts.
const Online = preload("res://services/online_save.gd")
const Outbox = preload("res://app/reward_outbox.gd")
const Codec = preload("res://app/save_codec.gd")
const Json = preload("res://app/save_json.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const ACCOUNT := "12345678-1234-4234-8234-123456789abc"
const RUN := "22345678-1234-4234-8234-123456789abc"
const OFFER := "32345678-1234-4234-8234-123456789abc"
const STAMP := "2026-10-12T00:00:00Z"
var failures: Array[String] = []
var checks := 0
var sandbox: String

class Server extends RefCounted:
	var credentials := {"accountId": ACCOUNT}
	var api_base_url := "http://127.0.0.1:19767"
	var tree: SceneTree
	var save: Dictionary
	var revision := 4
	var generation := 0
	var offline := false
	var calls: Array = []
	func request(method, path, raw := "", headers := {}) -> Dictionary:
		calls.append({"method":method, "path":path, "raw":raw, "headers":headers.duplicate(true)})
		await tree.process_frame
		if offline: return {"ok":false,"status":0,"code":"NETWORK_UNAVAILABLE","body":{},"retryable":true}
		if path == "/v1/save/writer":
			generation += 1
			return {"ok":true,"status":200,"body":{"writerGeneration":generation,"claimedAt":STAMP}}
		if path == "/v1/save" and method == "GET":
			if headers.get("If-None-Match") == '"rn-save-%d"' % revision:
				return {"ok":false,"status":304,"body":{}}
			return {"ok":true,"status":200,"body":{"revision":revision,"serverSavedAt":STAMP,"data":save.duplicate(true)}}
		if path == "/v1/save" and method == "PUT":
			var body: Dictionary = Json.parse(raw)
			if body.expectedRevision != revision: return {"ok":false,"status":409,"code":"SAVE_REVISION_CONFLICT","body":{}}
			revision += 1
			save = body.data.duplicate(true)
			return {"ok":true,"status":200,"body":{"revision":revision,"serverSavedAt":STAMP}}
		return {"ok":false,"status":500,"code":"UNEXPECTED_FIXTURE_ENDPOINT","body":{}}

func _initialize() -> void:
	# The native runner assigns a separate HOME to every script.
	sandbox = OS.get_user_data_dir().path_join("gem-save-recovery")
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func offer() -> Dictionary:
	return {"runId":RUN,"rewardWave":5,"offerId":OFFER,"revision":2,"totalUsed":0,"gemOptions":["attackSpeed","range","chain"],"status":"chosen","choice":"shards","grantedGem":"","grantedShards":10,"gemInventory":{},"gemShards":17}

func payload(chosen := false, active := true) -> Dictionary:
	var run: Variant = null
	if active:
		run = {"economyRunId":RUN,"phase":"preparation" if chosen else "reward","completedRounds":5,"roundIndex":5,"stageNumber":1,"gemOfferId":OFFER,"gemOfferRevision":2 if chosen else 1,"gemOfferStatus":"chosen" if chosen else "pending","gemRerollsUsed":0,"rewardOptions":[] if chosen else ["attackSpeed","range","chain"],"gemInventory":{},"gemShards":17 if chosen else 7}
	return Codec.decode({"version":2,"savedAtMillis":100,"preferences":{},"progression":{},"turretModules":{},"activeRun":run})

func economy_snapshot() -> Dictionary:
	return {"authorityState":"server_authoritative","authorityEpoch":"fixture-epoch","authorityVersion":1,"catalogVersion":1,"economyRevision":2,"serverTime":STAMP,"wallet":{"freeDiamonds":0,"paidDiamonds":0,"moduleTickets":0,"gemResetTickets":0},"turretModules":{"drawCount":0,"ticketPurchaseCount":0,"items":[]},"entitlements":{"researchSlotTwoUnlocked":false},"pendingProgressionEffects":[],"claimedRewardKeys":[],"gemOfferVersion":1,"gemOffer":offer()}

func command() -> Dictionary:
	return {"kind":"choose_gem","path":"v1/economy/gems/choose","idempotencyKey":"42345678-1234-4234-8234-123456789abc","createdAtMillis":1,"encodedBody":JSON.stringify({"runId":RUN,"completedRounds":5,"offerId":OFFER,"expectedOfferRevision":1,"choice":"shards","clientCompatibilityVersion":9})}

func make_online(label: String, remote: Server):
	var online = Online.new()
	root.add_child(online)
	online.configure(remote, sandbox.path_join(label), "independent-gem-recovery")
	online.set_process(false)
	return online

func prepare(label: String) -> Dictionary:
	var remote := Server.new()
	remote.tree = self
	remote.save = payload()
	var online = make_online(label, remote)
	var boot: Dictionary = await online.bootstrap({}, false)
	check(boot.get("ok",false) and online.state.baseRevision == 4, label + ": initial authenticated save ready")
	remote.save = payload(true)
	remote.revision = 5
	# The valid local fallback intentionally predates the run entirely.
	check(online.store.save_save(payload(false, false)) == OK, label + ": write pre-run checkpoint")
	check(online.store.save_save(payload(true)) == OK, label + ": write granted checkpoint with pre-run backup")
	var box = Outbox.new(online.root_path, ACCOUNT)
	check(box.load_state() == OK, label + ": load economy outbox")
	var queued: Dictionary = box.state.duplicate(true)
	queued.inFlight = command()
	queued.lastServerSnapshot = economy_snapshot()
	check(box.save_state(queued) == OK, label + ": retain exact choose command and authority cache")
	var receipt := {"gemReceipt":{"version":1,"economyRevision":2,"authorityEpoch":"fixture-epoch","gemResetTickets":0},"saveRevision":5,"serverSavedAt":STAMP,"gemOffer":offer(),"command":command()}
	check(await online.accept_gem_save(receipt), label + ": acknowledge server save after local grant")
	check(online.state.get("gemAckPending",false) and online.state.baseRevision == 5, label + ": durable ack journal survives until save upload")
	return {"online":online,"remote":remote,"box":box,"receipt":receipt}

func corrupt_primary(online, label: String) -> void:
	var file := FileAccess.open(online.store.primary_path, FileAccess.WRITE)
	check(file != null, label + ": open isolated primary for crash fixture")
	if file == null: return
	file.store_string("{broken-primary")
	file.close()
	var recovered: Variant = online.store.load_save()
	check(recovered is Dictionary and recovered.activeRun == null, label + ": actual corrupt-primary fallback restores pre-run backup")

func dispose_online(online) -> void:
	online.dispose()
	online.queue_free()
	await process_frame

func puts(calls: Array) -> int:
	return calls.filter(func(call): return call.method == "PUT").size()

func _run() -> void:
	await _restart_case("ack-before-retire", false, false)
	await _restart_case("retired-before-upload", true, false)
	await _restart_case("cached-offer-backup", true, true)
	await _missing_projection_case()
	await _failed_recovery_case()
	await _ordinary_ack_case()
	await _healthy_unsynced_progress_case()
	await _old_receipt_current_checkpoint_case()
	await _equipment_backup_case()
	await _synced_source_case()
	await _same_marker_backup_case()
	await _ack_before_projection_restart_case()
	await _legacy_usage_bootstrap_case()
	print("GEM_SAVE_RECOVERY checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _restart_case(label: String, retire: bool, uploaded: bool) -> void:
	var fixture := await prepare(label)
	var online = fixture.online
	var remote: Server = fixture.remote
	if retire:
		var retired: Dictionary = fixture.box.state.duplicate(true)
		retired.inFlight = null
		check(fixture.box.save_state(retired) == OK, label + ": durable command retirement")
	if uploaded:
		check((await online.sync_checkpoint()).get("ok",false), label + ": projected save upload completes")
		check(not online.state.get("gemAckPending",false), label + ": ordinary save ack clears gem journal")
		# Model a historical, still valid backup after later primary corruption.
		check(online.store._write_atomic(online.store.backup_path, JSON.stringify(payload(false,false),"",false,true)) == OK, label + ": retain historical pre-run backup")
	corrupt_primary(online, label)
	var expected_revision := remote.revision
	await dispose_online(online)
	var offset := remote.calls.size()
	var resumed = make_online(label, remote)
	var boot: Dictionary = await resumed.bootstrap({}, false)
	check(boot.get("ok",false) and resumed.requires_reload, label + ": restart requires canonical run reload")
	check(resumed.store.load_save() == remote.save and remote.save.activeRun.gemShards == 17, label + ": immutable grant restored exactly once")
	check(remote.revision == expected_revision and puts(remote.calls.slice(offset)) == 0, label + ": stale backup never uploads over canonical run")
	var backup: Variant = Json.parse(FileAccess.get_file_as_string(resumed.store.conflict_path))
	check(backup is Dictionary and backup.data.activeRun == null, label + ": pre-run fallback retained in conflict backup")
	var restored = Outbox.new(resumed.root_path, ACCOUNT)
	check(restored.load_state() == OK and restored.state.inFlight == (null if retire else command()), label + ": exact command state preserved for economy recovery")
	await dispose_online(resumed)

func _missing_projection_case() -> void:
	var fixture := await prepare("missing-live-projection")
	var online = fixture.online
	# Rewind only the online ACK to model receipt persistence before ACK.
	online.state.baseRevision = 4
	online.state.gemAckPending = false
	online.state.basePayloadHash = Hash.hash_payload(payload())
	check(online._commit(), "missing projection: pre-ACK journal prepared")
	corrupt_primary(online, "missing projection")
	var offset: int = fixture.remote.calls.size()
	check(await online.accept_gem_save(fixture.receipt), "missing projection: receipt recovers full canonical save")
	check(online.requires_reload and online.store.load_save().activeRun.gemShards == 17 and puts(fixture.remote.calls.slice(offset)) == 0, "missing projection: full recovery occurs before ACK without stale upload")
	await dispose_online(online)

func _failed_recovery_case() -> void:
	var fixture := await prepare("offline-crash-recovery")
	corrupt_primary(fixture.online, "offline recovery")
	await dispose_online(fixture.online)
	fixture.remote.offline = true
	var resumed = make_online("offline-crash-recovery", fixture.remote)
	var offset: int = fixture.remote.calls.size()
	var boot: Dictionary = await resumed.bootstrap({}, false)
	check(not boot.get("ok",false) and resumed.state.get("gemAckPending",false), "offline recovery: failed network retains gem ACK journal")
	check(puts(fixture.remote.calls.slice(offset)) == 0 and fixture.remote.save.activeRun.gemShards == 17, "offline recovery: failure never uploads restored null run")
	var retained = Outbox.new(resumed.root_path, ACCOUNT)
	check(retained.load_state() == OK and retained.state.inFlight == command(), "offline recovery: immutable choose request remains pending")
	await dispose_online(resumed)

func _ordinary_ack_case() -> void:
	var fixture := await prepare("ordinary-ack")
	var online = fixture.online
	var retired: Dictionary = fixture.box.state.duplicate(true)
	retired.inFlight = null
	check(fixture.box.save_state(retired) == OK,"ordinary ACK: exact successful command retired before later run")
	check((await online.sync_checkpoint()).get("ok",false) and not online.state.get("gemAckPending",false), "ordinary ACK: durable projected upload clears recovery marker")
	var newer := payload(true)
	newer.activeRun.economyRunId = "52345678-1234-4234-8234-123456789abc"
	newer.activeRun.completedRounds = 0
	newer.activeRun.roundIndex = 0
	newer.activeRun.gemOfferId = ""
	newer.activeRun.gemOfferRevision = 0
	newer.activeRun.gemOfferStatus = ""
	check((await online.sync(newer)).get("ok",false), "older receipt: newer run is durably saved")
	var revision: int = online.state.baseRevision
	var offset: int = fixture.remote.calls.size()
	check(await online.accept_gem_save(fixture.receipt), "older receipt: successful old outcome may retire")
	check(online.state.baseRevision == revision and online.store.load_save() == newer and fixture.remote.calls.size() == offset + 1 and fixture.remote.calls.back().method == "GET", "older receipt: current read without revision rollback or old-run resurrection")
	await dispose_online(online)

func _healthy_unsynced_progress_case() -> void:
	var fixture := await prepare("healthy-unsynced-progress")
	var online = fixture.online
	var retired: Dictionary = fixture.box.state.duplicate(true)
	retired.inFlight = null
	check(fixture.box.save_state(retired) == OK, "healthy progress: successful choice command retired")
	var later := payload(true)
	later.savedAtMillis = 200
	later.activeRun.completedRounds = 7
	later.activeRun.roundIndex = 7
	later.activeRun.gold = 123
	check(online.store.save_save(later) == OK, "healthy progress: later wave checkpoint survives before periodic upload")
	await dispose_online(online)
	var resumed = make_online("healthy-unsynced-progress", fixture.remote)
	var boot: Dictionary = await resumed.bootstrap({}, false)
	check(boot.get("ok",false), "healthy progress: account can restart")
	check(resumed.store.load_save() == later and fixture.remote.save == later, "healthy progress: gem ACK guard must not roll later local waves back to chosen wave")
	check(not resumed.state.get("gemAckPending",false), "healthy progress: confirmed upload finishes gem ACK journal")
	await dispose_online(resumed)

func _old_receipt_current_checkpoint_case() -> void:
	var fixture := await prepare("historical-full-receipt")
	var online = fixture.online
	var latest := payload(true)
	latest.savedAtMillis = 300
	latest.activeRun.completedRounds = 9
	latest.activeRun.roundIndex = 9
	latest.activeRun.gold = 777
	fixture.remote.save = latest
	fixture.remote.revision = 12
	var old: Dictionary = fixture.receipt.duplicate(true)
	old.activeRun = payload().activeRun # Legacy frozen payload is deliberately old.
	old.erase("gemReceipt")
	check(await online.accept_gem_save(old), "legacy historical receipt reads current canonical save")
	check(online.requires_reload and online.store.load_save() == latest and online.state.baseRevision == 12,"receipt recovery never installs old wave5 over current wave9")
	await dispose_online(online)

func _equipment_backup_case() -> void:
	var remote := Server.new()
	remote.tree = self
	var source := payload()
	source.activeRun.turrets = [{"x":1,"y":1,"type":"arrow","level":1,"slotLimit":1,"equippedGemSlots":["range"],"equippedGems":["range"]}]
	source = Codec.decode(source)
	remote.save = source
	var online = make_online("equipment-backup", remote)
	check((await online.bootstrap({}, false)).get("ok",false), "equipment backup: canonical equipped source bootstraps")
	var old := source.duplicate(true)
	old.activeRun.turrets[0].equippedGemSlots = [null]
	old.activeRun.turrets[0].equippedGems = []
	old.activeRun.gemInventory = {"range":1}
	check(online.store._write_atomic(online.store.backup_path, JSON.stringify(old,"",false,true)) == OK, "equipment backup: old loose allocation retained")
	var file := FileAccess.open(online.store.primary_path, FileAccess.WRITE)
	file.store_string("{broken-primary"); file.close()
	var canonical := source.duplicate(true)
	canonical.activeRun.phase = "preparation"
	canonical.activeRun.rewardOptions = []
	canonical.activeRun.gemOfferRevision = 2
	canonical.activeRun.gemOfferStatus = "chosen"
	canonical.activeRun.gemInventory = {"attackSpeed":1}
	remote.save = canonical
	remote.revision = 5
	var pending := command()
	var request: Dictionary = Json.parse(pending.encodedBody)
	request.sourceSaveRevision = 4
	pending.encodedBody = JSON.stringify(request)
	pending.sourcePayloadHash = Hash.hash_payload(source)
	var receipt := {"saveRevision":5,"serverSavedAt":STAMP,"command":pending}
	check(await online.accept_gem_save(receipt), "equipment backup: current save resolves before projection")
	check(online.requires_reload and online.store.load_save() == canonical,"equipment backup: canonical equipped range is not erased by old loose-inventory backup")
	check(online._owned_gems(online.store.load_save().activeRun) == {"attackSpeed":1,"range":1},"equipment backup: complete owned allocation conserved")
	# Even matching current markers cannot certify a checkpoint missing a gem.
	var forged := canonical.duplicate(true)
	forged.activeRun.turrets[0].equippedGemSlots = [null]
	forged.activeRun.turrets[0].equippedGems = []
	check(not online._represents_current_run(forged, canonical),"current marker alone cannot certify missing ownership")
	await dispose_online(online)

func _synced_source_case() -> void:
	var remote := Server.new()
	remote.tree = self
	remote.save = payload()
	var online = make_online("synced-live-source", remote)
	check((await online.bootstrap({}, false)).get("ok",false),"synced source: bootstrap")
	var source: Dictionary = online.store.load_save()
	var pending := command()
	var body: Dictionary = Json.parse(pending.encodedBody)
	body.sourceSaveRevision = remote.revision
	pending.encodedBody = JSON.stringify(body)
	pending.sourcePayloadHash = online.context().sourcePayloadHash
	var box = Outbox.new(online.root_path, ACCOUNT)
	check(box.load_state() == OK,"synced source: durable authority outbox")
	var queued: Dictionary = box.state.duplicate(true)
	queued.inFlight = pending
	check(box.save_state(queued) == OK,"synced source: exact command survives before projection")
	remote.save = payload(true)
	remote.revision += 1
	var receipt := {"saveRevision":remote.revision,"serverSavedAt":STAMP,"command":pending}
	check(await online.accept_gem_save(receipt) and not online.requires_reload,"synced source: full acknowledged source hash allows narrow live projection")
	check(online.store.load_save() == source and online.state.gemAckPending,"synced source: preprojection proof does not synthesize current offer markers")
	var offset := remote.calls.size()
	var waiting: Dictionary = await online.sync_checkpoint()
	check(waiting.get("waitingForEconomy", false) and puts(remote.calls.slice(offset)) == 0,"synced source: periodic upload cannot precede unresolved exact outcome")
	var projected := source.duplicate(true)
	projected.activeRun = preload("res://app/gem_reroll.gd").project(source.activeRun, offer())
	queued.inFlight = null
	check(box.save_state(queued) == OK,"synced source: confirmed outcome retired")
	check(online.store.save_save(projected) == OK and (await online.sync_checkpoint()).get("ok",false),"synced source: confirmed patch persists and syncs")
	check(remote.save.activeRun.gemShards == 17,"synced source: exactly one confirmed grant")
	await dispose_online(online)

func _same_marker_backup_case() -> void:
	var remote := Server.new()
	remote.tree = self
	var current := payload(true)
	current.activeRun.gold = 777
	current.activeRun.turrets = [{"x":1,"y":1,"type":"arrow","level":1,"slotLimit":1,"equippedGemSlots":["range"],"equippedGems":["range"]}]
	current = Codec.decode(current)
	remote.save = current
	var online = make_online("same-marker-backup", remote)
	check((await online.bootstrap({}, false)).get("ok",false),"same marker backup: current equipped layout bootstraps")
	var old := current.duplicate(true)
	old.activeRun.gold = 100
	old.activeRun.turrets[0].equippedGemSlots = [null]
	old.activeRun.turrets[0].equippedGems = []
	old.activeRun.gemInventory = {"range":1}
	check(online._owned_gems(old.activeRun) == online._owned_gems(current.activeRun),"same marker backup: totals alone do not prove freshness")
	check(online.store._write_atomic(online.store.backup_path, JSON.stringify(old,"",false,true)) == OK,"same marker backup: historical checkpoint retained")
	var file := FileAccess.open(online.store.primary_path, FileAccess.WRITE)
	file.store_string("{broken-primary"); file.close()
	check(online.store.load_save() == old and online.store.has_recovery_marker(),"same marker backup: fallback provenance persisted before primary repair")
	await dispose_online(online)
	var resumed = make_online("same-marker-backup", remote)
	var result: Dictionary = await resumed.bootstrap({}, false)
	check(result.get("ok",false) and resumed.requires_reload and resumed.store.load_save() == current,"same marker backup: next process restores canonical layout and gold")
	check(not resumed.store.has_recovery_marker(),"same marker backup: successful durable rebase clears provenance")
	var backup: Variant = Json.parse(FileAccess.get_file_as_string(resumed.store.conflict_path))
	check(backup is Dictionary and backup.data == old,"same marker backup: uncertain local progress retained as conflict backup")
	await dispose_online(resumed)

func _ack_before_projection_restart_case() -> void:
	var remote := Server.new()
	remote.tree = self
	remote.save = payload()
	var online = make_online("ack-before-projection-restart", remote)
	check((await online.bootstrap({}, false)).get("ok",false),"preprojection restart: source ready")
	var pending := command()
	var request: Dictionary = Json.parse(pending.encodedBody)
	request.sourceSaveRevision = remote.revision
	pending.encodedBody = JSON.stringify(request)
	pending.sourcePayloadHash = online.context().sourcePayloadHash
	remote.save = payload(true)
	remote.revision += 1
	check(await online.accept_gem_save({"saveRevision":remote.revision,"serverSavedAt":STAMP,"command":pending}),"preprojection restart: ACK durable before local grant")
	# Simulate crash before projection/cache update; the economy fallback has no
	# usable in-flight command. The online ACK journal must still force GET data.
	await dispose_online(online)
	var offset := remote.calls.size()
	var resumed = make_online("ack-before-projection-restart", remote)
	check((await resumed.bootstrap({}, false)).get("ok",false) and resumed.requires_reload,"preprojection restart: current canonical grant recovered from ACK journal")
	check(resumed.store.load_save() == remote.save and resumed.store.load_save().activeRun.gemShards == 17 and puts(remote.calls.slice(offset)) == 0,"preprojection restart: unapplied checkpoint never uploads over confirmed grant")
	await dispose_online(resumed)

func _legacy_usage_bootstrap_case() -> void:
	var remote := Server.new()
	remote.tree = self
	var legacy := payload()
	legacy.activeRun.gemOfferId = ""
	legacy.activeRun.gemOfferRevision = 0
	legacy.activeRun.gemOfferStatus = ""
	legacy.activeRun.gemRerollsUsed = 2
	legacy.activeRun.rewardOptions = []
	remote.save = legacy
	var online = make_online("legacy-usage-cold-bootstrap", remote)
	check((await online.bootstrap({}, false)).get("ok",false),"legacy cold bootstrap: pre-upgrade account ready at used2")
	var dirty := legacy.duplicate(true)
	dirty.activeRun.gold = 123
	dirty.activeRun.rewardOptions = ["attackSpeed","range","chain"]
	check(online.store._write_atomic(online.store.backup_path, JSON.stringify(dirty,"",false,true)) == OK,"legacy cold bootstrap: unsynced legacy checkpoint retained")
	var broken := FileAccess.open(online.store.primary_path,FileAccess.WRITE)
	broken.store_string("{broken-primary"); broken.close()
	# Migration 016 normalizes canonical usage from the durable generation-7
	# budget and advances its revision before a generation-9 writer can claim.
	remote.save.activeRun.gemRerollsUsed = 3
	remote.revision += 1
	await dispose_online(online)
	var offset := remote.calls.size()
	var resumed = make_online("legacy-usage-cold-bootstrap", remote)
	var result: Dictionary = await resumed.bootstrap({}, false)
	check(result.get("ok",false) and resumed.requires_reload,"legacy cold bootstrap: newer migration header forces canonical rebase before economy configuration")
	check(puts(remote.calls.slice(offset)) == 0 and resumed.store.load_save().activeRun.gemRerollsUsed == 3,"legacy cold bootstrap: stale used2 cannot PUT before current usage3 is read")
	var backup: Variant = Json.parse(FileAccess.get_file_as_string(resumed.store.conflict_path))
	check(backup is Dictionary and backup.data.activeRun.gold == 123 and backup.data.activeRun.gemRerollsUsed == 2 and backup.data.activeRun.rewardOptions == dirty.activeRun.rewardOptions,"legacy cold bootstrap: unnormalized fallback and unsynced progress remain in conflict backup")
	var restored: Dictionary = resumed.store.load_save().activeRun
	check(restored.rewardOptions.is_empty() and not preload("res://app/gem_reroll.gd").current_offer(restored),"legacy cold bootstrap: historical candidates never become selectable")
	await dispose_online(resumed)
