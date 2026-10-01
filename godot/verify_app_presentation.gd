extends SceneTree
const Adapter = preload("res://ui/app_presentation.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Catalog = preload("res://content/content_catalog.gd")
class TestProjection extends "res://ui/battlefield_effects.gd":
	func _project(tile: Vector2, _height := 0.0) -> Vector2:
		return Vector2(100+tile.x*60+tile.y*8,50+tile.y*36)
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func _initialize() -> void:
	var catalog := Catalog.new()
	check(catalog.load_catalog(),"catalog")
	var runtime := Runtime.new()
	var setup: Dictionary = catalog.bootstrap(0)
	setup.enemies = [catalog.enemy(0,0,"normal",1)]
	runtime.process_command({"epoch":1,"sequence":0,"bootstrap":setup,"session":{"clock":"godot","phase":"wave","paused":false,"speed":1.0}})
	var native_effects: Array = [
		{"kind":"damage","tileSize":1.0,"scale":1.0/48,"x":2.0,"y":3.0,"screenOffset":[0,-17.0],"text":"25","age":0.5,"duration":0.75},
		{"kind":"coreBeam","tileSize":1.0,"scale":1.0/48,"x":2.0,"y":3.0,"points":[[2.0,3.0],[6.0,4.0]],"screenOffset":[0,0]},
		{"kind":"impact","tileSize":1.0,"scale":1.0/48,"radius":0.75,"x":2.0,"y":3.0,"points":[],"screenOffset":[0,0]},
		{"kind":"charge","tileSize":1.0,"scale":1.0/48,"attachmentRadius":0.25,"x":2.0,"y":3.0,"points":[],"screenOffset":[0,0]}
	]
	var base := {"presentation":{"labels":{},"effects":{"items":native_effects,"events":[],"shake":[0.0,0.0]},"selection":{"logicalTileSize":48.0}},"projectiles":[[3,2.0,3.0]],"impacts":[]}
	var original := JSON.stringify(base)
	var decorated: Dictionary = runtime.decorate_frame(base)
	var size_before: Array = decorated.presentation.labels.enemies[0].size.duplicate()
	Adapter.normalize(decorated)
	check(JSON.stringify(base)==original,"base frame remains unscaled")
	var normalized_once := JSON.stringify(decorated)
	Adapter.normalize(decorated)
	check(JSON.stringify(decorated)==normalized_once,"normalization is idempotent")
	var labels: Dictionary = decorated.presentation.labels
	check(labels.logicalTileSize==48.0,"canonical label unit")
	check(is_equal_approx(labels.enemies[0].size[0],size_before[0]*48),"enemy width conversion")
	check(is_equal_approx(float(labels.enemies[0].size[0])/48,float(size_before[0])),"enemy width tile invariance")
	check(is_equal_approx(3.0/float(labels.logicalTileSize),3.0/48),"health bar height uses canonical 3px")
	check(is_equal_approx(maxf(4,labels.logicalTileSize*0.11)/labels.logicalTileSize,0.11),"core cooldown height no 4-tile floor")
	var projection := TestProjection.new()
	var items: Array = decorated.presentation.effects.items
	var canonical_damage: Dictionary = native_effects[0].duplicate(true)
	canonical_damage.tileSize = 48.0
	canonical_damage.scale = 1.0
	var damage_basis: Transform2D = projection.effect_transform(items[0])
	var reference: Transform2D = projection.effect_transform(canonical_damage)
	check(damage_basis.is_equal_approx(reference),"damage glyph basis and rise match canonical48")
	check(is_equal_approx(damage_basis.x.length()*15,60.0/48*15),"15px damage text does not become 15 tiles")
	var beam: Dictionary = items[1]
	projection._basis = projection.effect_transform(beam)
	var points: PackedVector2Array = projection._local_points(beam)
	check((projection._basis*points[0]).is_equal_approx(projection._project(Vector2(2,3))),"beam source anchor unchanged")
	check((projection._basis*points[1]).is_equal_approx(projection._project(Vector2(6,4))),"beam target and length unchanged")
	check(is_equal_approx(10.0*float(beam.scale)/float(beam.tileSize),10.0/48),"beam width canonical48")
	check(is_equal_approx(float(items[2].radius)/float(items[2].tileSize),0.75),"impact radius remains 0.75 tiles")
	check(is_equal_approx(float(items[3].attachmentRadius),0.25),"charge attachment stays tile units")
	var repeated: Dictionary = Adapter.normalize(runtime.decorate_frame(base))
	check(repeated.presentation.labels.enemies[0].size == labels.enemies[0].size,"fresh decorate does not accumulate label scale")
	check(repeated.presentation.effects.items[0].scale == items[0].scale,"fresh decorate does not accumulate effect scale")
	var canonical := {"presentation":{"labels":{"logicalTileSize":48.0,"enemies":[{"size":[24.0,30.0],"position":[2,3]}]},"effects":{"items":[canonical_damage]}}}
	var canonical_before := JSON.stringify(canonical)
	Adapter.normalize(canonical)
	check(JSON.stringify(canonical)==canonical_before,"existing canonical48 input preserved")
	var event_frame := {"presentation":{"labels":{"logicalTileSize":1.0,"enemies":[]},"effects":{"events":[{"id":1,"kind":"blast","tileSize":1.0,"radius":0.8,"scale":1.0/48}],"shake":[0.05,-0.02]}}}
	Adapter.normalize(event_frame)
	check(is_equal_approx(event_frame.presentation.effects.events[0].radius/48,0.8),"event blast radius tile invariant")
	check(is_equal_approx(event_frame.presentation.effects.shake[0],2.4),"shake returns to canonical screen pixels")
	var event_before := JSON.stringify(event_frame)
	Adapter.normalize(event_frame)
	check(JSON.stringify(event_frame)==event_before,"event and shake normalization idempotent")
	_prepared_effect_checks(catalog)
	projection.free()
	if failures.is_empty():
		print("PASS independent presentation: real decorate/base isolation, idempotence, enemy/core bars, damage glyph/rise, beam endpoints/width, effect radius, attachment and canonical48 equivalence")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _prepared_effect_checks(catalog) -> void:
	var runtime := Runtime.new()
	var setup: Dictionary = catalog.bootstrap(0)
	setup.enemies = [catalog.enemy(0,0,"normal",1),catalog.enemy(0,0,"normal",2)]
	runtime.process_command({"epoch":20,"sequence":0,"bootstrap":setup,"session":{"clock":"godot","phase":"wave"}})
	var target: Dictionary = runtime.enemies["1"]
	target.diamondReward = 3
	var turret := {"statInput":{"definition":{"type":"cannon"}}}
	runtime._visual("blast",Vector2(2,3),turret,{"radius":0.8,"screenOffset":[0.05,-0.02]})
	runtime._visual("damage",Vector2(2,3),turret,{"text":"12","duration":0.65})
	runtime._visual("chain",Vector2(2,3),turret,{"points":[[2,3],[target.x,target.y]],"targetIds":[-1,1]})
	runtime._core_visual("coreBeam",[target],0xff8ee6ff)
	runtime._core_visual("rift",runtime.enemies.values(),0xffcfa7ff)
	runtime._diamond_reward_visual(target)
	var base := {"presentation":{"labels":{},"effects":{"items":[{"kind":"damage","tileSize":1.0,"scale":1.0/48,"screenOffset":[0,-17]}],"events":[{"kind":"blast","tileSize":2.0,"scale":0.5,"radius":2.0,"screenOffset":[1,2]}]}}}
	var original := base.duplicate(true)
	var raw: Dictionary = runtime.decorate_frame(base)
	check(raw.presentation.effects.items[1].tileSize == 1.0,"public frame retains authored raw units")
	var expected: Dictionary = Adapter.normalize(raw)
	var actual: Dictionary = Adapter.normalize(runtime.decorate_frame(base,true,true))
	check(actual.presentation.effects.get("_canonicalNativeEffects",false),"internal canonical effects bypass repeated conversion")
	actual.presentation.effects.erase("_canonicalNativeEffects")
	check(actual == expected,"prepared internal effects equal public normalize for mixed legacy entries and every dynamic kind")
	check(base == original,"prepared mixed frame preserves original base entries")
	var marked_legacy := {"presentation":{"labels":{"logicalTileSize":48.0},"effects":{"_canonicalNativeEffects":true,"items":[{"kind":"blast","tileSize":2.0,"radius":2.0,"scale":0.5}]}}}
	var public_mixed: Dictionary = Adapter.normalize(runtime.decorate_frame(marked_legacy))
	check(public_mixed.presentation.effects.items[0].radius == 48.0 and public_mixed.presentation.effects.items[1].tileSize == 48.0,"public raw frame clears inherited fast-path marker before mixed conversion")
	var prior := actual.duplicate(true)
	var beam_index := -1
	var chain_index := -1
	var rift_index := -1
	for i in actual.presentation.effects.items.size():
		var item: Dictionary = actual.presentation.effects.items[i]
		if item.get("kind") == "coreBeam": beam_index = i
		if item.get("kind") == "chain": chain_index = i
		if item.get("kind") == "rift": rift_index = i
	# Public nested DTOs remain writable and detached from journal/prepared payloads.
	var public: Dictionary = runtime.decorate_frame(base)
	public.presentation.effects.items[chain_index].points[0][0] = 999
	public.presentation.effects.items[chain_index].targetIds[1] = 999
	public.presentation.effects.events[-1].screenOffset[0] = 999
	var unchanged: Dictionary = Adapter.normalize(runtime.decorate_frame(base,true,true))
	unchanged.presentation.effects.erase("_canonicalNativeEffects")
	check(unchanged == prior,"public nested mutations cannot modify prepared payload or later frame")
	target.x += 0.5
	target.y += 0.25
	var moved: Dictionary = Adapter.normalize(runtime.decorate_frame(base,true,true))
	check(moved.presentation.effects.items[beam_index].points[1] == [target.x,target.y] and moved.presentation.effects.items[chain_index].points[-1] == [target.x,target.y],"prepared beam and chain follow moving logical target")
	check(actual == prior,"later linked frame cannot mutate earlier dynamic endpoints")
	var last_point: Array = moved.presentation.effects.items[beam_index].points[1].duplicate()
	target.hp = 0
	var dead: Dictionary = Adapter.normalize(runtime.decorate_frame(base,true,true))
	check(dead.presentation.effects.items[beam_index].points[1] == last_point and dead.presentation.effects.items[chain_index].points[-1] == last_point,"missing linked target retains last displayed endpoint")
	check(dead.presentation.effects.items[rift_index].points.size() == 1,"rift excludes dead target without reusing prior points")
	var receipt: Dictionary = dead.presentation.effects.events[-1]
	check(receipt.kind == "diamond" and receipt.born == 0.0 and not receipt.has("age") and receipt.text == "+3","prepared diamond preserves receiver-owned receipt time")
	runtime.enemies.clear()
	runtime.running = false
	runtime._step(10)
	check(runtime.visual_effects.is_empty() and runtime._prepared_effects.is_empty(),"expired effects release static payloads with journal")
	runtime._visual("damage",Vector2.ZERO,turret)
	runtime.process_command({"epoch":21,"sequence":0,"bootstrap":{},"session":{"clock":"godot","phase":"preparation"}})
	check(runtime._prepared_effects.is_empty(),"epoch reset discards prepared presentation")
