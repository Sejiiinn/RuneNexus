extends SceneTree
const Guardian = preload("res://presentation/guardian_preview.gd")
var failed: Array[String] = []
var count := 0
func check(ok: bool, label: String) -> void:
 count += 1
 print("PASS " if ok else "FAIL ", label)
 if not ok: failed.append(label)
func near(a: float,b: float) -> bool: return absf(a-b)<0.00001
func _initialize() -> void:
 var world := Node3D.new()
 root.add_child(world)
 var helper = Guardian.new(world)
 var body := Node3D.new()
 world.add_child(body)
 var e := {"root":body}
 helper.update_facing(e,-1.2,0.0)
 check(near(body.rotation.y,-1.2),"initial nonzero facing appears immediately")
 helper.update_facing(e,0.0,0.01)
 helper.update_facing(e,0.0,1.0)
 helper.update_facing(e,PI/2.0,1.0)
 check(near(body.rotation.y,0.0),"turn starts from visible heading without a snap")
 var samples: Array[float] = [body.rotation.y]
 for t in [1.03,1.06,1.09,1.12]:
  helper.update_facing(e,PI/2.0,t)
  samples.append(body.rotation.y)
 check(near(samples[2],3.0*PI/8.0),"90 degree turn reaches 75 percent at 0.06 combat seconds")
 check(near(samples[4],PI/2.0),"90 degree turn finishes at 0.12 combat seconds")
 var shrinking := true
 for i in range(1,4): shrinking = shrinking and samples[i]-samples[i-1]>samples[i+1]-samples[i]
 check(shrinking,"quarter-step angular increments decrease toward target")
 helper.update_facing(e,-PI/2.0,2.0)
 helper.update_facing(e,-PI/2.0,2.04)
 var frozen: float = body.rotation.y
 for i in range(20): helper.update_facing(e,-PI/2.0,2.04)
 check(near(body.rotation.y,frozen),"same combat time cannot advance turning")
 helper.update_facing(e,0.4,2.04)
 check(near(body.rotation.y,frozen),"mid-turn retarget preserves current visible angle")
 helper.update_facing(e,0.4,3.0)
 check(near(body.rotation.y,0.4),"retarget settles without overshoot")
 helper.update_facing(e,deg_to_rad(179.0),0.0)
 helper.update_facing(e,deg_to_rad(-179.0),0.01)
 check(near(float(e.turn_duration),0.12*2.0/90.0),"179 to -179 takes shortest two degree turn")
 helper.update_facing(e,deg_to_rad(-179.0),0.01+0.12/90.0)
 check(near(rad_to_deg(body.rotation.y),180.5),"wrap crossing samples shortest arc with ease-out")
 helper.update_facing(e,deg_to_rad(-179.0),0.02)
 check(near(wrapf(body.rotation.y-deg_to_rad(-179.0),-PI,PI),0.0),"wrapped target settles exactly")
 helper.update_facing(e,-0.7,-1.0)
 check(near(body.rotation.y,-0.7),"combat clock rewind resets facing immediately")
 print("INDEPENDENT_TURN ",JSON.stringify({"checks":count,"failures":failed,"samples":samples}))
 helper.clear()
 world.free()
 quit(0 if failed.is_empty() else 1)
