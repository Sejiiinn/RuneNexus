extends RefCounted
## Device-only graphics settings, deliberately outside account save snapshots.
const PATH := "user://standalone-session/device.cfg"
const FPS_LIMITS := [30, 60]
const RENDER_SCALES := [50, 75, 100]
static func read() -> Dictionary:
	var c := ConfigFile.new()
	var loaded := c.load(PATH)
	if loaded == ERR_FILE_NOT_FOUND and Engine.has_singleton("RuneNexusPlatform"):
		var platform = Engine.get_singleton("RuneNexusPlatform")
		var result: Variant = JSON.parse_string(platform.device_preferences())
		if result is Dictionary and result.get("ok",false) and result.get("value") is String:
			var original: Variant = JSON.parse_string(result.value)
			if original is Dictionary:
				var migrated := {"msaa":original.get("msaaSamples",2),"shadow":original.get("shadowMapSize",2048),"fps":60,"render_scale":100}
				if write(migrated): return migrated
	var msaa := int(c.get_value("graphics", "msaa", 2))
	var shadow := int(c.get_value("graphics", "shadow", 2048))
	var fps := int(c.get_value("graphics", "fps", 60))
	var render_scale := int(c.get_value("graphics", "render_scale", 100))
	return {"msaa": msaa if msaa in [0, 2] else 2, "shadow": shadow if shadow in [0, 512, 1024, 2048] else 2048,
		"fps": fps if fps in FPS_LIMITS else 60, "render_scale": render_scale if render_scale in RENDER_SCALES else 100}

static func write(settings: Dictionary) -> bool:
	if not settings.get("msaa") in [0, 2] or not settings.get("shadow") in [0, 512, 1024, 2048]: return false
	# Files written before these settings existed keep the defaults.
	if not settings.get("fps", 60) in FPS_LIMITS or not settings.get("render_scale", 100) in RENDER_SCALES: return false
	var dir := ProjectSettings.globalize_path("user://standalone-session")
	if DirAccess.make_dir_recursive_absolute(dir) != OK: return false
	var c := ConfigFile.new()
	c.set_value("graphics", "msaa", settings.msaa)
	c.set_value("graphics", "shadow", settings.shadow)
	c.set_value("graphics", "fps", settings.get("fps", 60))
	c.set_value("graphics", "render_scale", settings.get("render_scale", 100))
	if c.save(PATH + ".tmp") != OK: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH)) == OK

static func apply(options: Dictionary) -> void:
	var settings := read()
	options.msaa_samples = settings.msaa
	options.shadows = settings.shadow > 0
	options.shadow_map_size = maxi(512, settings.shadow)
	options.max_fps = settings.fps
	options.render_scale = settings.render_scale / 100.0
