extends RefCounted
## Opt-in inspection timings. Disabled in normal launches.
static var enabled := false
static var samples: Dictionary = {}
static var options: Dictionary = {}

static func configure() -> void:
	enabled = "--profile-app" in OS.get_cmdline_user_args()
	options = {}
	if enabled and FileAccess.file_exists("user://profile_options.json"):
		var value = JSON.parse_string(FileAccess.get_file_as_string("user://profile_options.json"))
		if value is Dictionary: options = value
		enabled = bool(options.get("timings", true))

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func finish(label: String, start: int) -> void:
	if not enabled: return
	var elapsed := Time.get_ticks_usec() - start
	var sample: Array = samples.get(label, [0, 0, 0])
	sample[0] += 1
	sample[1] += elapsed
	sample[2] = maxi(sample[2], elapsed)
	samples[label] = sample

static func drain() -> Dictionary:
	var result := {}
	for label in samples:
		var v: Array = samples[label]
		result[label] = {"count":v[0], "total_ms":v[1]/1000.0, "mean_ms":v[1]/float(v[0])/1000.0, "max_ms":v[2]/1000.0}
	samples.clear()
	return result

const CANVAS_BITS := {"hud":2, "labels":4, "effects":8, "selection":16, "feedback":32, "badges":64}
const CANVAS_PARTITIONS := {"hud_only":3, "battle_only":125, "labels_badges":69, "effects_selection":57, "badges_only":65, "labels_only":5, "effects_only":9, "selection_only":17, "feedback_only":33}

static func tag_canvas(item: CanvasItem, group: String) -> void:
	if options.has("render_partition"): item.visibility_layer = CANVAS_BITS[group]

static var _render_key := ""
static var _canvas_mask := 0xffffffff

static func apply_render_partition(viewport: Viewport, wave: bool) -> void:
	if not options.has("render_partition"): return
	var partition := str(options.render_partition) if wave else "full"
	if partition == _render_key: return
	if _render_key.is_empty(): _canvas_mask = viewport.canvas_cull_mask
	_render_key = partition
	viewport.disable_3d = partition in ["2d", "none"]
	viewport.canvas_cull_mask = 0 if partition in ["3d", "none"] else int(CANVAS_PARTITIONS.get(partition, _canvas_mask))
	print("RENDER_PARTITION ", partition, " disable_3d=", viewport.disable_3d, " canvas_mask=", viewport.canvas_cull_mask)
