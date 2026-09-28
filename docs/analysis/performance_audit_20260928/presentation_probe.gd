extends SceneTree
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Normalize = preload("res://ui/app_presentation.gd")
class Probe extends Node:
 var writes := 0
 var value: float = 0.0:
  set(next): value = next; writes += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var probe := Probe.new(); root.add_child(probe)
 var player := AnimationPlayer.new(); probe.add_child(player)
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var animation := Animation.new(); animation.length = 1.0
 var track := animation.add_track(Animation.TYPE_VALUE)
 animation.track_set_path(track,NodePath(".:value"))
 animation.track_insert_key(track,0.0,0.0); animation.track_insert_key(track,1.0,1.0)
 var library := AnimationLibrary.new(); library.add_animation("test",animation); player.add_animation_library("",library)
 player.play("test"); player.advance(0.0); probe.writes = 0
 player.seek(0.4,true); var seek_writes := probe.writes
 player.advance(0.0); var both_writes := probe.writes
 print("ANIMATION_WRITES seek_true=",seek_writes," seek_true_plus_advance_zero=",both_writes," value=",probe.value)
 probe.writes = 0; player.seek(0.4,true); player.advance(0.0)
 print("ANIMATION_UNCHANGED_PHASE_WRITES=",probe.writes)
 probe.free()
 var runtime := Runtime.new(); runtime.active = true; runtime.session = {"clock":"godot","phase":"wave"}
 var base := {"presentation":{"effects":{"items":[],"events":[]},"labels":{},"selection":{}},"enemies":[],"turrets":[]}
 for count in [0,64,256,1024]:
  runtime.visual_effects.clear()
  for i in count:
   runtime.visual_effects.append({"id":i,"kind":"damage","born":0.0,"duration":0.75,"x":1.0,"y":1.0,"tileSize":1.0,"scale":1.0/48,"color":0xffff6666,"text":"100","feedback":"neutral","motion":"rise","arcDirection":1,"points":[],"screenOffset":[0,0]})
  for i in 20: Normalize.normalize(runtime.decorate_frame(base,true))
  var times := []
  for trial in 5:
   var started := Time.get_ticks_usec()
   for i in 150: Normalize.normalize(runtime.decorate_frame(base,true))
   times.append(float(Time.get_ticks_usec()-started)/150.0)
  times.sort()
  print("DECORATE_NORMALIZE synthetic_damage=",count," median_us=",times[2]," trials_us=",times)
 quit()
