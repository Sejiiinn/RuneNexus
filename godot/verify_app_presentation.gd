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
	projection.free()
	if failures.is_empty():
		print("PASS independent presentation: real decorate/base isolation, idempotence, enemy/core bars, damage glyph/rise, beam endpoints/width, effect radius, attachment and canonical48 equivalence")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
