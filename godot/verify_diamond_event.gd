extends SceneTree
const Effects = preload("res://ui/battlefield_effects.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Session = preload("res://session/run_session.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var effects := Effects.new()
	root.add_child(effects)
	var event := {"id":1,"kind":"diamond","born":0.0,"bornSquared":0.0,"duration":1.05,"x":2.0,"y":3.0,"tileSize":48.0,"scale":1.5,"text":"+3","hasImage":true}
	for speed in [1.0, 4.0]:
		effects.clear()
		effects.apply_frame({"clock":0.0,"playbackSpeed":speed,"events":[event]})
		assert(effects.items.size()==1 and effects._diamond!=null)
		assert(effects.items[0].text=="+3" and effects.items[0].hasImage)
		var surface = effects._effect_nodes[1]
		effects.apply_frame({"clock":0.4*speed,"playbackSpeed":speed,"events":[event]})
		assert(effects.items.size()==1 and effects._effect_nodes[1]==surface)
		assert(is_equal_approx(effects.items[0].age,0.4),"receipt motion is readable at both speeds")
		assert(is_equal_approx(effects.items[0].screenOffset[1],-9.6))
		assert(not event.has("age") and not event.has("screenOffset") and event.duration==1.05,"input DTO is immutable")
		effects.apply_frame({"clock":0.4*speed,"playbackSpeed":speed,"events":[event]})
		assert(effects.items.size()==1 and is_equal_approx(effects.items[0].age,0.4),"paused/retry frame cannot advance age")
		await process_frame
		assert(is_equal_approx(effects.items[0].age,0.4),"wall time cannot age receipt")
		effects.apply_frame({"clock":1.449*speed,"playbackSpeed":speed})
		assert(effects.items.size()==1,"source journal expiry must not cut off receipt")
		effects.apply_frame({"clock":1.451*speed,"playbackSpeed":speed})
		assert(effects.items.is_empty() and not effects._effect_nodes.has(1))
		effects.apply_frame({"clock":1.5*speed,"playbackSpeed":speed,"events":[event]})
		assert(effects.items.is_empty(),"expired retries cannot resurrect rewards")
	# Speed changes preserve already elapsed display time.
	effects.clear()
	effects.apply_frame({"clock":0.0,"events":[event]})
	effects.apply_frame({"clock":0.4})
	effects.apply_frame({"clock":2.0,"playbackSpeed":4.0})
	assert(is_equal_approx(effects.items[0].age,0.8))
	var late := event.duplicate(true)
	late.id=2
	late.retainedAge=0.4
	effects.apply_frame({"clock":2.0,"playbackSpeed":4.0,"events":[late]})
	assert(effects.items.size()==2 and is_equal_approx(effects.items[1].age,0.1),"coalesced receipt keeps retained source sample")
	effects.apply_frame({"generation":1,"clock":2.0})
	effects.apply_frame({"generation":0,"clock":2.0,"events":[late]})
	assert(effects.items.is_empty(),"old scene cannot restore reward")
	effects.clear()
	_verify_native_kill(effects)
	print("PASS diamond event: real turret kill + actual economy amount, non-carrier/debug exclusions, pause/retry/generation, immutable DTO, 1.45-second receipt at 1x/4x and speed changes")
	quit(0)

func _verify_native_kill(effects) -> void:
	var catalog := Catalog.new()
	assert(catalog.load_catalog())
	var session := Session.new()
	assert(session.initialize(catalog,{},0,7))
	var enemy: Dictionary = catalog.enemy(0,0,"normal",1,{"enemyValues":{"diamondReward":3}})
	enemy.maxHp=1.0; enemy.hp=1.0; enemy.speed=0.0
	var setup: Dictionary = catalog.bootstrap(0)
	setup.enemies=[enemy]
	setup.turrets=[{"id":10,"position":[enemy.x+1.0,enemy.y],"statInput":catalog.turret("arrow"),"state":{"x":0,"y":0}}]
	var runtime := Runtime.new()
	runtime.process_command({"epoch":7,"sequence":0,"bootstrap":setup,"session":{"clock":"godot","phase":"wave","paused":false,"speed":4.0}})
	for i in range(120):
		runtime.advance_session(1.0/60.0)
		if runtime.enemies["1"].killReported: break
	assert(runtime.enemies["1"].killReported,"real turret must kill carrier")
	assert(session.collect(runtime).ok and session.state.pendingEconomyDiamonds==3,"receipt amount equals awarded economy amount")
	var base := {"presentation":{"effects":{"events":[],"items":[]},"labels":{}}}
	var frame: Dictionary = runtime.decorate_frame(base)
	assert(frame.presentation.effects.events.size()==1 and frame.presentation.effects.events[0].text=="+3")
	var receipt: Dictionary = frame.presentation.effects.events[0]
	effects.apply_frame({"clock":runtime.clock,"playbackSpeed":4.0,"events":[receipt]})
	assert(effects.items.size()==1 and effects.items[0].text=="+3")
	runtime.process_command({"epoch":7,"sequence":1,"ackEvent":session.event_ack})
	assert(not runtime.enemies.has("1"),"economy ACK removes carrier")
	frame=runtime.decorate_frame(base)
	effects.apply_frame({"clock":runtime.clock,"playbackSpeed":4.0,"events":frame.presentation.effects.events})
	assert(effects.items.size()==1 and session.state.pendingEconomyDiamonds==3,"source retry does not duplicate receipt or economy")
	for id in [2,3]:
		var other: Dictionary = catalog.enemy(0,0,"normal",id)
		if id==3: other.diamondReward=3; other.isDebug=true
		runtime.process_command({"epoch":7,"sequence":id,"commands":[{"kind":"spawn","enemy":other},{"kind":"coreDamage","enemyId":id,"damage":100000}]})
	assert(runtime.visual_effects.filter(func(e): return e.kind=="diamond").size()==1,"ordinary and debug kills cannot show false rewards")
	assert(session.collect(runtime).ok and session.state.pendingEconomyDiamonds==3)
	effects.clear()
