extends PanelContainer
## One icon path for draw results. Until final art is supplied, use the existing
## collection glyph, with the same part and grade tint as the inventory.
const T = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const CollectionUI = preload("res://ui/lobby_collection.gd")
const FrameShader = preload("res://ui/module_icon_frame.gdshader")
const ASSET_PATHS := {
	"core": "res://assets/app/turret_modules/icons/core.png",
	"barrel": "res://assets/app/turret_modules/icons/barrel.png",
	"frame": "res://assets/app/turret_modules/icons/frame.png",
}
var part := ""
var turret_type := ""
var grade := ""
var icon_path := ""
var tint := Color.WHITE

func set_extent(extent: int) -> void:
	custom_minimum_size = Vector2(extent, extent)
	var center := get_child(0)
	var art: Control = center.get_child(0)
	art.custom_minimum_size = Vector2.ONE * maxf(20, extent - (12 if art is TextureRect else 16))

static func create(item: Dictionary, extent: int) -> PanelContainer:
	var icon := new()
	icon.name = "ModuleIcon"
	icon.part = str(item.get("part", ""))
	icon.turret_type = str(item.get("turretType", ""))
	icon.grade = str(item.get("grade", ""))
	icon.icon_path = str(ASSET_PATHS.get(icon.part, ""))
	icon.tint = CollectionUI.COLORS.get(icon.grade, Color("b9d6e4"))
	icon.custom_minimum_size = Vector2(extent, extent)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Frame.new("ui/components/card_frame.png", 5)
	frame.modulate_color = icon.tint
	icon.add_theme_stylebox_override("panel", frame)
	var frame_material := ShaderMaterial.new()
	frame_material.shader = FrameShader
	if frame.texture and frame.texture.get_size().x > 1:
		frame_material.set_shader_parameter("source_size", frame.texture.get_size() * frame.source_scale)
		icon.material = frame_material
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(center)
	var texture := T.texture(icon.icon_path) if not icon.icon_path.is_empty() else null
	if texture != null:
		var art := TextureRect.new()
		art.name = "ModuleIconTexture"
		art.texture = texture
		art.modulate = icon.tint
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2.ONE * maxf(20, extent - 12)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(art)
	else:
		var glyph := CollectionUI.PartGlyph.new()
		glyph.name = "ModulePartGlyph"
		glyph.part = icon.part
		glyph.tint = icon.tint
		glyph.custom_minimum_size = Vector2.ONE * maxf(20, extent - 16)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(glyph)
	icon.set_extent(extent)
	return icon
