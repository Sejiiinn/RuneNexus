extends CanvasLayer
## 모든 챕터의 공통 정지 배경. 카메라·전투 시계와 독립적이다.
const SPACE_TEXTURE = "res://assets/backgrounds/combat_space_nebula.png"
const NEARBY_TEXTURE = "res://assets/backgrounds/combat_space_nearby.res"
const StageResources = preload("res://presentation/stage_resources.gd")
const STAR_TWINKLE = preload("res://environment/combat_space_twinkle.gdshader")
const CHAPTER_TINTS = {
	"chapterOne": Vector3(0.38, 0.83, 1.0),
	"chapterTwoRift": Vector3(0.76, 0.38, 0.92),
	"chapterThreeForge": Vector3(0.90, 0.42, 0.20),
}
var _star_material := ShaderMaterial.new()
var _theme := "chapterOne"

func _ready() -> void:
	layer = -1
	name = "CombatSpaceBackground"
	var backdrop := TextureRect.new()
	backdrop.name = "Nebula"
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	# Battle texture is attached only on actual stage entry.
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star_material.shader = STAR_TWINKLE
	backdrop.material = _star_material
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply_theme(_theme)

func prepare() -> void:
	assert(not get_viewport().use_hdr_2d, "Space luminance field requires LDR canvas")
	get_node("Nebula").texture = StageResources.load_resource(SPACE_TEXTURE)
	_star_material.set_shader_parameter("nearby_luminance", StageResources.load_resource(NEARBY_TEXTURE))

func apply_theme(theme: String) -> void:
	_theme = theme if CHAPTER_TINTS.has(theme) else "chapterOne"
	_star_material.set_shader_parameter("nebula_tint", CHAPTER_TINTS[_theme])
