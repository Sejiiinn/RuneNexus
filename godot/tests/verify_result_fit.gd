extends SceneTree
## Stage result fits one screen: at the minimum 440x760 the longest real
## results (first clear with a challenge, hard loot with a challenge, a failed
## hard settlement, a failed local save on the first clear with the most
## unlocks) need no scrolling, and roomy screens keep the full crystal and
## breathing space. Server settlement is never shown.
const Fixture = preload("res://tests/verify_battle_hud.gd")
const Presenter = preload("res://ui/battle_result_presenter.gd")
const Progression = preload("res://content/stage_progression.gd")
class Services extends Fixture.FixtureServices:
	var loot := {}
	var status := "completed"
	func run_settlement_state(_id: String) -> Dictionary:
		return {"status":status,"code":"","hardRewards":loot}
var checks := 0
var failures: Array[String] = []
# Parsing and validating the content takes most of this script's run time, and
# every measured layout reads the same immutable catalog.
var catalog := Fixture.QueryCatalog.new()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void: call_deferred("run")

## Returns [content height, visible height, crystal height, spacer height, shows settlement text].
func measure(size: Vector2i, extra: Dictionary, loot: Dictionary, stage := 0, status := "completed") -> Array:
	root.size = size
	root.content_scale_size = size
	var app := Fixture.App.new()
	app.stage = stage
	var services := Services.new()
	services.loot = loot
	services.status = status
	app.services = services
	app.catalog = catalog
	app.run_domain.initialize(app.catalog,{},stage,100)
	root.add_child(app)
	var hud = load("res://ui/battle_hud.gd").new()
	hud.app = app
	app.hud = hud
	root.add_child(hud)
	for i in 3: await process_frame
	var state: Dictionary = app.run_domain.state
	state.economyRunId = "fit"
	state.phase = "success"
	state.completedRounds = 40
	state.progression.lastRunRuneReward = 11949
	for key in extra:
		if key.begins_with("p."): state.progression[key.substr(2)] = extra[key]
		else: state[key] = extra[key]
	hud.refresh()
	for i in 10: await process_frame
	var scroll: ScrollContainer = hud.overlay_body.get_parent()
	var body: Control = hud.overlay_body.get_node("ResultBody")
	var result := [hud.overlay_body.get_combined_minimum_size().y, scroll.size.y, body.find_child("ResultCrystal",true,false).custom_minimum_size.y, body.get_node("ResultBreathingSpace").custom_minimum_size.y, body.find_children("*", "Label", true, false).any(func(label): return "정산" in label.text)]
	hud.queue_free()
	app.queue_free()
	for i in 2: await process_frame
	return result

func run() -> void:
	check(catalog.load_catalog(),"content catalog")
	var module := {"turretType":"machinegun","grade":"rare","id":"fit","effects":[]}
	var cases := {
		"plain": [{}, {}, 0],
		"failure": [{"phase":"failure"}, {}, 0],
		"first clear with challenge": [{"lastRunChallengeAchieved":true,"lastRunFirstClear":true,"p.lastRunCorePointReward":2,"p.lastRunTurretModuleTicketReward":3}, {}, 4],
		"hard loot with challenge": [{"difficulty":"hard","lastRunChallengeAchieved":true,"p.lastRunCorePointReward":2,"p.lastRunTurretModuleTicketReward":3}, {"modules":[module,module],"moduleTickets":2}, 4],
		"hard retry with challenge": [{"difficulty":"hard","lastRunChallengeAchieved":true,"p.lastRunCorePointReward":2,"p.lastRunTurretModuleTicketReward":3}, {}, 4, "retry"],
	}
	for name in cases:
		var spec: Array = cases[name]
		var short: Array = await measure(Vector2i(440,760), spec[0], spec[1], spec[2], spec[3] if spec.size() > 3 else "completed")
		check(short[0] <= short[1] + 0.5, "%s fits 440x760 without scrolling (%d > %d)" % [name, short[0], short[1]])
		check(short[2] >= Presenter.CRYSTAL_MIN_HEIGHT, "%s keeps a visible crystal" % name)
		check(not short[4], "%s shows no server settlement text" % name)
	# The first clear's unlock list differs per stage; a failed save adds its row.
	var longest := 0
	for stage in 30:
		if Progression.unlock_items(stage + 1).size() > Progression.unlock_items(longest + 1).size(): longest = stage
	var combo: Array = await measure(Vector2i(440,760), {"lastRunChallengeAchieved":true,"lastRunFirstClear":true,"p.lastRunCorePointReward":2,"p.lastRunTurretModuleTicketReward":3}, {}, longest, "save_failed")
	check(combo[0] <= combo[1] + 0.5, "first clear with the most unlocks, a challenge and a failed save fits (%d > %d)" % [combo[0], combo[1]])
	var roomy: Array = await measure(Vector2i(440,900), {}, {})
	check(roomy[2] == Presenter.CRYSTAL_HEIGHT and roomy[3] == 64, "roomy screens keep the full crystal and breathing space")
	print("RESULT_FIT checks=%d failures=%s" % [checks, failures])
	quit(0 if failures.is_empty() else 1)
