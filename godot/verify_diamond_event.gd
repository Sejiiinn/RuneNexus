extends SceneTree
const Effects = preload("res://ui/battlefield_effects.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var effects := Effects.new()
	root.add_child(effects)
	var event := {"id":1,"kind":"diamond","born":0.0,"bornSquared":0.0,"duration":1.05,"x":2.0,"y":3.0,"tileSize":48.0,"scale":1.5,"text":"+3","hasImage":true}
	effects.apply_frame({"clock":0.0,"events":[event]})
	assert(effects.items.size()==1 and effects._diamond!=null)
	assert(effects.items[0].text=="+3" and effects.items[0].hasImage)
	var surface = effects._effect_nodes[1]
	effects.apply_frame({"clock":0.4,"events":[event]})
	assert(effects.items.size()==1 and effects._effect_nodes[1]==surface)
	assert(is_equal_approx(effects.items[0].screenOffset[1],-14.4),"original 24 * visualScale pixels per second")
	assert(not event.has("age") and not event.has("screenOffset"),"input DTO is immutable")
	effects.apply_frame({"clock":0.4,"events":[event]})
	assert(effects.items.size()==1 and effects.items[0].age==0.4,"paused/retry frame cannot advance age")
	effects.apply_frame({"clock":1.049})
	assert(effects.items.size()==1)
	effects.apply_frame({"clock":1.05})
	assert(effects.items.is_empty() and not effects._effect_nodes.has(1),"exact original 1.05 second expiry")
	effects.apply_frame({"clock":1.1,"events":[event]})
	assert(effects.items.is_empty(),"expired retries cannot resurrect rewards")
	var late := event.duplicate(true)
	late.id=2
	late.retainedAge=0.4
	effects.apply_frame({"clock":1.1,"events":[late]})
	assert(effects.items.size()==1 and is_equal_approx(effects.items[0].screenOffset[1],-14.4),"coalesced event retains one source sample")
	effects.apply_frame({"clock":1.1})
	assert(effects.items.is_empty())
	effects.apply_frame({"generation":1,"clock":1.1})
	effects.apply_frame({"generation":0,"clock":1.1,"events":[late]})
	assert(effects.items.is_empty(),"old scene cannot restore reward")
	effects.clear()
	print("PASS diamond event: icon/text, original scaled motion, 1.05s expiry, immutable DTO, pause/retry, coalesced delivery and scene cancellation")
	quit(0)
