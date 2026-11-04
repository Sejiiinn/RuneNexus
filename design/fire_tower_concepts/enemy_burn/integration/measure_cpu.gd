extends SceneTree

const Burn = preload("res://effects/enemy_burn.gd")
const COUNT := 300
const WARMUP := 120
const SAMPLES := 1000


func _initialize() -> void:
	call_deferred("_measure")


func _measure() -> void:
	var entries: Array[Dictionary] = []
	var kinds := ["normal", "armored", "shielded", "fast", "tank", "boss"]
	for i in range(COUNT):
		var body := Node3D.new()
		root.add_child(body)
		var entry := {"root": body, "type": kinds[i % kinds.size()]}
		Burn.apply(entry, true, 0.0)
		entries.append(entry)
	var samples: Array[float] = []
	for frame in range(WARMUP + SAMPLES):
		var time := float(frame) / 60.0
		var start := Time.get_ticks_usec()
		Burn.set_time(time)
		for entry: Dictionary in entries:
			Burn.apply(entry, true, time)
		var elapsed := float(Time.get_ticks_usec() - start) / 1000.0
		if frame >= WARMUP:
			samples.append(elapsed)
	var average := 0.0
	for value in samples:
		average += value
	average /= float(samples.size())
	samples.sort()
	var result := {
		"scope": "CPU-only stable EnemyBurn.apply x300 plus one shared set_time per sample; initialization excluded",
		"environment": "macOS arm64 Godot 4.7.2 headless dummy renderer",
		"enemy_count": COUNT,
		"warmup_samples": WARMUP,
		"measured_samples": SAMPLES,
		"average_ms": average,
		"p50_ms": samples[int(SAMPLES * 0.50)],
		"p95_ms": samples[int(SAMPLES * 0.95)],
		"max_ms": samples[-1],
		"gpu_time": "not measured",
		"physical_android_device": "not measured",
		"limitations": "Excludes rendering submissions, transparent fragment shading, Flutter bridge, whole-frame pacing and model transforms. No speedup ratio claimed."
	}
	var args := OS.get_cmdline_user_args()
	if args.size() == 1:
		var output := FileAccess.open(args[0], FileAccess.WRITE)
		output.store_string(JSON.stringify(result, "\t") + "\n")
		output.close()
	print(JSON.stringify(result))
	for entry: Dictionary in entries:
		entry["root"].free()
	quit()
