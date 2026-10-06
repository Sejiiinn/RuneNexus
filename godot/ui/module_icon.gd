extends PanelContainer
## Shared part/grade artwork, with an optional grade-tinted equipment/draw frame.
const T = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const PartGlyph = preload("res://ui/module_part_glyph.gd")
const FrameShader = preload("res://ui/module_icon_frame.gdshader")
const PARTS := ["core", "barrel", "frame"]
const GRADES := ["normal", "magic", "rare", "unique"]
const ASSET_ROOT := "res://assets/app/turret_modules/icons/"
const BACKGLOW_PATH := ASSET_ROOT + "unique_backglow.png"
var part := ""
var turret_type := ""
var grade := ""
var icon_path := ""
var tint := Color.WHITE

func set_extent(extent: int) -> void:
	custom_minimum_size = Vector2(extent, extent)
	var center := get_child(0)
	var art: Control = center.get_child(0)
	art.custom_minimum_size = Vector2.ONE * maxf(20, extent - 12)

static func asset_path(item: Dictionary) -> String:
	var component := str(item.get("part", ""))
	var rarity := str(item.get("grade", ""))
	if component not in PARTS or rarity not in GRADES: return ""
	return ASSET_ROOT + "%s_%s.png" % [component, rarity]

static func create_art(item: Dictionary, extent: int) -> Control:
	var path := asset_path(item)
	var texture := T.texture(path) if not path.is_empty() else null
	var art: Control
	if texture != null:
		var image := TextureRect.new()
		image.name = "ModuleIconTexture"
		image.texture = texture
		# Each PNG already contains its grade materials, light and color.
		image.modulate = Color.WHITE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if str(item.get("grade", "")) == "unique":
			var glow := TextureRect.new()
			glow.name = "ModuleUniqueBackglow"
			glow.texture = T.texture(BACKGLOW_PATH)
			glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glow.show_behind_parent = true
			glow.modulate.a = 0.55
			image.add_child(glow)
			# Relative anchors follow inventory and equipment size changes without
			# changing layout minima; the diffuse light extends behind the silhouette.
			glow.anchor_left = -0.18
			glow.anchor_top = -0.18
			glow.anchor_right = 1.18
			glow.anchor_bottom = 1.18
		art = image
	else:
		var glyph := PartGlyph.new()
		glyph.name = "ModulePartGlyph"
		glyph.part = str(item.get("part", ""))
		glyph.tint = PartGlyph.COLORS.get(str(item.get("grade", "")), Color("b9d6e4"))
		art = glyph
	art.set_meta("icon_path", path)
	art.custom_minimum_size = Vector2.ONE * extent
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art

static func create(item: Dictionary, extent: int) -> PanelContainer:
	var icon := new()
	icon.name = "ModuleIcon"
	icon.part = str(item.get("part", ""))
	icon.turret_type = str(item.get("turretType", ""))
	icon.grade = str(item.get("grade", ""))
	icon.icon_path = asset_path(item)
	icon.tint = PartGlyph.COLORS.get(icon.grade, Color("b9d6e4"))
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
	center.add_child(create_art(item, maxi(20, extent - 12)))
	icon.set_extent(extent)
	return icon
