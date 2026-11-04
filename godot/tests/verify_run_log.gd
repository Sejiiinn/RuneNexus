extends SceneTree
## Run log builder and isolated send (docs/run_log_design.md).
const CombatKinds = preload("res://combat/combat_kinds.gd")
var failures: Array = []
var checks := 0

class HangingTransport extends Node:
	signal never
	var calls: Array = []
	var timeout_seconds := 0.0
	func request(method: int, url: String, body: String = "", headers: Dictionary = {}) -> Dictionary:
		calls.append({"method": method, "url": url, "body": body, "headers": headers})
		await never
		return {"ok": false, "status": 0}

class AccountStub extends RefCounted:
	var requests := 0
	func context() -> Dictionary:
		return {"accountId": "ACCOUNT-1", "accessToken": "token-1", "apiBaseUrl": "https://api.example.test"}
	func request(_method, _path, _body = "", _headers = {}) -> Dictionary:
		requests += 1
		return {"ok": false, "status": 0}

class Box extends RefCounted:
	var owner := "account-1"
	var state := {"completedRunIds": []}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var app = load("res://session/standalone.gd").new()
	scene.session_controller = app
	scene.add_child(app)
	app.set_process(false)
	app.checkpoint = load("res://session/session_checkpoint.gd").new(OS.get_environment("TMPDIR").path_join("rune-run-log-" + str(OS.get_process_id())))
	var runtime = scene.combat_runtime
	var domain = app.run_domain
	if domain.state.is_empty():
		push_error(domain.error)
		quit(1)
		return
	var source: Dictionary = app.stage_source(0)
	var index: int = source.map.tiles.find("build")
	var tile := Vector2i(index % int(source.map.columns), floori(float(index) / int(source.map.columns)))
	app.board_tap(tile)
	app.build_selected()
	var id: int = domain.selected_id(tile)
	check(id >= 0 and runtime.turrets.has(str(id)), "fixture turret built")

	# Arrivals are tallied from real ARRIVAL events by type and rarity.
	runtime.enemies["9001"] = {"type": "fast", "rarity": "magic"}
	runtime.enemies["9002"] = {"type": "normal"}
	runtime.enemies["9003"] = {"type": "normal", "isDebug": true}
	var first: int = domain.event_ack + 1
	runtime.events.append_array([{"id": first, "kind": CombatKinds.ARRIVAL, "enemyId": 9001},
		{"id": first + 1, "kind": CombatKinds.ARRIVAL, "enemyId": 9002},
		{"id": first + 2, "kind": CombatKinds.ARRIVAL, "enemyId": 9003}])
	domain.collect(runtime)
	check(domain.run_log_arrivals == {"fast:magic": 1, "normal:normal": 1}, "arrivals tallied, debug enemies ignored: %s" % [domain.run_log_arrivals])

	# Damage comes from the runtime, like the result screen; run state is stale.
	runtime.turrets[str(id)].directDamageDealt = 100.0
	runtime.turrets[str(id)].splashDamageDealt = 20.0
	runtime.turrets[str(id)].burnDamageDealt = 3.4
	domain.state.phase = "coreDestruction"
	# A failed abandon save restores the unfinished state; the retry replaces the log.
	var unfinished: Dictionary = domain.state.duplicate(true)
	domain.finish(false, runtime)
	domain.state = unfinished
	domain.finish(false, runtime)
	check(domain.finished_run_logs.size() == 1, "finish queues one log, also after a rolled-back finish")
	var entry: Dictionary = domain.finished_run_logs[0] if domain.finished_run_logs.size() == 1 else {}
	var run_id := str(domain.state.get("economyRunId", ""))
	check(entry.get("schemaVersion") == 1 and entry.get("runId") == run_id and not run_id.is_empty(), "identity fields")
	check(entry.get("stageId") == int(domain.service.catalog.stage_summary(int(domain.state.stage)).id) and entry.get("success") == false and entry.get("difficulty") == "normal", "run result fields")
	check(entry.get("resumed") == false and entry.get("arrivals") == {"fast:magic": 1, "normal:normal": 1}, "session arrivals copied")
	var turrets: Array = entry.get("turrets", [])
	check(turrets.size() == 1 and turrets[0].type == "machinegun" and turrets[0].x == tile.x and turrets[0].y == tile.y and turrets[0].damage == 123, "turret placement and runtime damage: %s" % [turrets])
	check(entry.has_all(["upgradeLevels", "researchLevels", "coreNodeRanks", "totalCorePoints", "moduleCount", "clearedStages", "peakTurrets", "turretTypesUsed", "supportCores", "coreHp", "coreHpMax", "waveCount"]), "summary fields present")
	check(not entry.has("nickname") and not entry.has("accountId"), "no account identity in body")
	domain.finish(false, runtime)
	check(domain.finished_run_logs.size() == 1, "finished run is not logged twice")
	check(domain.take_run_logs(["other-run"]).is_empty() and domain.finished_run_logs.size() == 1, "unsettled run stays")

	# Sending: settled logs only, one POST, not awaited, never through AccountSession.
	var services = load("res://services/app_services.gd").new()
	var account := AccountStub.new()
	var transport := HangingTransport.new()
	services.app = app
	services.account = account
	services.updates = {"installed": {"versionCode": 6062}}
	services._run_log_transport = transport
	root.add_child(transport)
	var box := Box.new()
	box.state.completedRunIds = [run_id]
	var started := Time.get_ticks_usec()
	services._send_settled_run_logs(box)
	var elapsed := Time.get_ticks_usec() - started
	check(elapsed < 50000, "send returns without waiting for a hanging server (%d us)" % elapsed)
	check(transport.calls.size() == 1 and domain.finished_run_logs.is_empty(), "one POST for the settled run")
	var call: Dictionary = transport.calls[0] if transport.calls.size() == 1 else {}
	var body: Variant = JSON.parse_string(str(call.get("body", "")))
	check(call.get("method") == HTTPClient.METHOD_POST and call.get("url") == "https://api.example.test/v1/telemetry/run-logs" and call.get("headers", {}).get("Authorization") == "Bearer token-1", "route and bearer token")
	check(body is Dictionary and body.get("clientBuild") == 6062 and body.get("runId") == run_id, "body carries client build")
	check(account.requests == 0, "AccountSession.request not used")
	services._send_settled_run_logs(box)
	check(transport.calls.size() == 1, "a log is sent once")

	# Another account's outbox never sends this session's logs.
	domain.finished_run_logs = [{"runId": "r2"}]
	box.owner = "someone-else"
	box.state.completedRunIds = ["r2"]
	services._send_settled_run_logs(box)
	check(transport.calls.size() == 1, "account mismatch sends nothing")
	services.free()
	print("RUN_LOG failures=%s checks=%d" % [failures, checks])
	quit(0 if failures.is_empty() else 1)
