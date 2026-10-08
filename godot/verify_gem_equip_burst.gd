extends SceneTree
## Actual app/session command path with a lightweight renderer host and no save I/O.
class App extends "res://app/app_lifecycle.gd":
	var save_ok := true
	func _ready() -> void: pass
	func persist_progression() -> bool: return save_ok
class Host extends Node3D:
	var _native_combat = preload("res://combat/native_combat_runtime.gd").new()
	var _native_combat_base_frame := {"presentation":{}}
	var receipts: Array = []
	func _apply_frame(_frame: Dictionary) -> void: pass
	func play_gem_equip_burst(id: int, gem: String) -> void:
		receipts.append([id, gem])
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	var host := Host.new()
	root.add_child(host)
	var app := App.new()
	app.scene = host
	app.startup_blocked = false
	app.in_lobby = false
	check(app.catalog.load_catalog(), "catalog")
	check(app.run_domain.initialize(app.catalog, {}, 0, app.epoch), "domain")
	host._native_combat.process_command({"epoch":app.epoch, "sequence":0, "session":{"clock":"godot", "phase":"preparation", "paused":true}, "bootstrap":app.catalog.bootstrap(0)})
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
	app.run_domain.state.phase = "reward"
	app.run_domain.state.rewardOptions = ["physicalDamage"]
	check(app.apply_run_command({"kind":"chooseRewardGemEquip", "id":id, "type":"physicalDamage", "slot":0}), "direct reward equip")
	check(host.receipts.size() == 3 and host.receipts[-1] == [id, "physicalDamage"], "direct reward emits once")
	app.run_domain.state.phase = "reward"
	app.run_domain.state.rewardOptions = ["range"]
	check(app.apply_run_command({"kind":"chooseRewardGemEquip", "id":id, "type":"range", "slot":0}), "reward replacement")
	check(host.receipts.size() == 4 and host.receipts[-1] == [id, "range"], "reward replacement emits once")
	app.run_domain.state.phase = "reward"
	app.run_domain.state.rewardOptions = ["attackSpeed"]
	check(app.apply_run_command({"kind":"chooseRewardGem", "type":"attackSpeed"}), "reward to inventory")
	var restored: Dictionary = app.run_domain.state.duplicate(true)
	app.run_domain.restore(restored)
	app.refresh_selection()
	check(host.receipts.size() == 4, "inventory reward and restored equipment do not emit")
	app.save_ok = false
	check(not app.apply_run_command({"kind":"equipGem", "id":id, "type":"attackSpeed", "slot":0}), "failed persistence rejected")
	check(host.receipts.size() == 4, "failed persistence does not emit success cue")
	# Effect rendering, fade and lifetime are covered by the actual-renderer visual check.
	check(host._native_combat.clock == 0.0, "feedback does not advance combat")
	app.free()
	host.free()
	print("GEM_EQUIP_BURST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
