extends SceneTree
const Runtime = preload("res://combat/native_combat_runtime.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		push_error(label)
func row(id: int, shot: int, cooldown: float, duration: float = 2.0, radius: float = 1.58) -> Array:
	return [id, 3.5 + id, 4.5, 2.1, shot, 1.0, "frost", 1, {"cooldown":cooldown,"duration":duration,"radius":radius}]
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.last_frame.time = 10.0
	scene._sync_turrets([row(1,0,0),row(2,0,1)])
	var a = scene.turrets[1].frost_effect
	var b = scene.turrets[2].frost_effect
	check(a.charge == 1.0 and b.charge == .5, "independent ready / partial charge")
	check(a.mist.multimesh == b.mist.multimesh and a.mist.multimesh.instance_count == 32, "shared static 32-instance geometry")
	check(a.mist_material != b.mist_material, "independent effect clocks")
	check(a._fins.size() > 0, "approved fin materials selected")
	check(scene.turrets[1].head.rotation.y == 0 and scene.turrets[1].flashes.is_empty() and scene.turrets[1].smokes.is_empty(), "no tracking or generic muzzle effects")
	var rest: float = scene.turrets[1].barrel_rest_z
	scene.last_frame.time = 20.0
	scene._sync_turrets([row(1,0,0),row(2,0,0)])
	check(a.charge == 1 and not a.mist.visible, "idle holds ready indefinitely")
	scene._sync_turrets([row(1,1,2,2,2.25),row(2,0,0)])
	check(a.charge == 0 and a.mist.visible and not b.mist.visible, "shot releases and resets only firing tower")
	check(scene.turrets[1].barrel.position.z == rest, "no recoil")
	check(a.mist_material.get_shader_parameter("effect_radius") == 2.25, "actual upgraded tile radius")
	scene.last_frame.time = 20.4
	scene._sync_turrets([row(1,1,1.6),row(2,0,0)])
	var age: float = a.mist_material.get_shader_parameter("age")
	for i in 5: scene._sync_turrets([row(1,1,1.6),row(2,0,0)])
	check(a.mist_material.get_shader_parameter("age") == age and is_equal_approx(a.charge,.2), "paused combat clock freezes mist and charge")
	scene.last_frame.time = 21.2
	scene._sync_turrets([row(1,1,.8),row(2,0,0)])
	check(not a.mist.visible and is_equal_approx(a.charge,.6), "absolute combat time ends mist")
	scene.last_frame.time = 19.0
	scene._sync_turrets([row(1,0,0),row(2,0,0)])
	check(not a.mist.visible and a.charge == 1, "rewind clears old release without replay")
	scene._sync_build_preview(row(99,0,0))
	check(scene._build_preview.head.rotation.y == 0, "build preview fixed heading")
	scene._sync_turrets([[1,3.5,4.5,1.2,0,0,"frost",1]])
	check(a.charge == 1, "eight-field legacy row remains safe")
	var restored := row(3,40,.9,2.0)
	restored[5] = 0.0
	scene._sync_turrets([[1,3.5,4.5,1.2,0,0,"frost",1],restored,row(4,40,.9,2.0)])
	check(not scene.turrets[3].frost_effect.mist.visible and scene.turrets[3].frost_effect.charge < 1, "restored shot history with zero feedback never replays as a new release")
	check(not scene.turrets[4].frost_effect.mist.visible, "initial snapshot with residual feedback also never replays")
	var weak = weakref(a)
	scene._sync_turrets([])
	check(weak.get_ref() == null, "sale removes effect")
	scene._sync_turrets([row(1,0,0)])
	check(scene.turrets[1].frost_effect.charge == 1 and not scene.turrets[1].frost_effect.mist.visible, "reused ID starts ready without old mist")
	var units: Array = []
	for i in 8: units.append(row(i,0,0))
	scene._sync_turrets(units)
	var lights := 0
	for entry in scene.turrets.values():
		if entry.frost_effect.lamp.light_energy > 0: lights += 1
	check(lights == 4, "frost lighting capped at four shadowless lights")
	var first = weakref(scene.turrets[0].frost_effect)
	scene._clear_scene()
	check(first.get_ref() == null, "epoch/reset teardown removes charge and mist")
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	var input: Dictionary = {}
	for fixture in fixtures:
		var c: Dictionary = fixture.config
		if c.type == "frost" and c.level == 1 and c.gems.is_empty() and c.primary == null and c.secondary == null and c.boost == 0 and c.scale == 1:
			input = fixture.input
			break
	var runtime = Runtime.new()
	runtime.process_command({"epoch":1,"sequence":0,"dt":0,"bootstrap":{"tileSize":48.0,"turrets":[{"id":1,"position":[0,0],"statInput":input,"state":{"x":0,"y":0},"cooldown":.9}],"enemies":[]}})
	var t: Dictionary = runtime.turrets["1"]
	t.cooldown = .9
	t.lastBaseCooldown = 0.0
	var frame: Dictionary = runtime.decorate_frame({})
	var state: Dictionary = frame.turrets[0][8]
	check(state.cooldown == .9 and state.duration >= .9 and state.radius == t.stats.centeredAreaRadius/48.0, "restored cooldown denominator and logical radius")
	check(t.lastBaseCooldown == 0, "presentation never mutates combat state")
	scene.free()
	print("FROST_CHARGE_CHECK failures=", failures)
	quit(0 if failures.is_empty() else 1)
