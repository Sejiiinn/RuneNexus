extends RefCounted
const Current = preload("res://app/content_run_save.gd")
const OriginalCatalog = preload("res://independent-oracle-catalog.gd")
const Original = preload("res://independent-oracle-content-save.gd")
var catalog
var growth
var current
var original
var error := ""
var failures: Array = []
var rng_reject_differences := 0
var captures := 0
var prepares := 0
func _init(c,g) -> void:
 catalog = c; growth = g; current = Current.new(c,g); original = Original.new(OriginalCatalog.new(),g)
func fail(message: String) -> void:
 failures.append(message); print("PARITY_FAIL ",message)
func capture(state: Dictionary,snapshot: Dictionary,saved_at: int,preferences: Dictionary = {}) -> Dictionary:
 original.catalog.data = catalog.data.duplicate(true); original.catalog.error = catalog.error
 var before: Array = [state.duplicate(true),snapshot.duplicate(true),preferences.duplicate(true)]
 catalog.counts = {"bootstrap":0,"enemy":0,"random_spawn_values":0,"turret":0}
 var result: Dictionary = current.capture(state,snapshot,saved_at,preferences)
 var counts: Dictionary = catalog.counts.duplicate()
 error = current.error
 var expected: Dictionary = original.capture(before[0].duplicate(true),before[1].duplicate(true),saved_at,before[2].duplicate(true))
 captures += 1
 if result != expected or error != original.error: fail("capture #"+str(captures)+" result/error parity current="+error+" old="+original.error)
 if var_to_bytes(before) != var_to_bytes([state,snapshot,preferences]): fail("capture input mutation #"+str(captures))
 for key in counts:
  if counts[key] != 0: fail("capture materialized "+key+"="+str(counts[key])+" #"+str(captures))
 return result
func prepare(envelope: Dictionary,battle_inputs: Dictionary = {},spawn_rng: RandomNumberGenerator = null) -> Dictionary:
 original.catalog.data = catalog.data.duplicate(true); original.catalog.error = catalog.error
 var before := [envelope.duplicate(true),battle_inputs.duplicate(true)]
 var rng := spawn_rng if spawn_rng != null else RandomNumberGenerator.new()
 if spawn_rng == null: rng.seed = 889
 var expected_rng := RandomNumberGenerator.new(); expected_rng.state = rng.state
 var result: Dictionary = current.prepare(envelope,battle_inputs,rng)
 error = current.error
 var expected: Dictionary = original.prepare(before[0].duplicate(true),before[1].duplicate(true),expected_rng)
 prepares += 1
 if result != expected or error != original.error: fail("prepare #"+str(prepares)+" result/error parity current="+error+" old="+original.error)
 if var_to_bytes(before) != var_to_bytes([envelope,battle_inputs]): fail("prepare input mutation #"+str(prepares))
 if rng.state != expected_rng.state:
  if not result.is_empty(): fail("successful prepare RNG state mismatch #"+str(prepares))
  else: rng_reject_differences += 1; print("REJECT_RNG_DIFFERENCE #",prepares," error=",error)
 return result
