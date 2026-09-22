extends RefCounted
## Device-only graphics settings, deliberately outside account save snapshots.
const PATH := "user://standalone-session/device.cfg"
static func read() -> Dictionary:
	var c := ConfigFile.new()
	c.load(PATH)
	var msaa := int(c.get_value("graphics", "msaa", 2))
	var shadow := int(c.get_value("graphics", "shadow", 2048))
	return {"msaa": msaa if msaa in [0, 2] else 2, "shadow": shadow if shadow in [0, 512, 1024, 2048] else 2048}

static func write(settings: Dictionary) -> bool:
	if not settings.get("msaa") in [0, 2] or not settings.get("shadow") in [0, 512, 1024, 2048]: return false
	var dir := ProjectSettings.globalize_path("user://standalone-session")
	if DirAccess.make_dir_recursive_absolute(dir) != OK: return false
	var c := ConfigFile.new()
	c.set_value("graphics", "msaa", settings.msaa)
	c.set_value("graphics", "shadow", settings.shadow)
	if c.save(PATH + ".tmp") != OK: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH)) == OK

static func apply(options: Dictionary) -> void:
	var settings := read()
	options.msaa_samples = settings.msaa
	options.shadows = settings.shadow > 0
	options.shadow_map_size = maxi(512, settings.shadow)
