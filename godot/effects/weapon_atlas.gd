extends MeshInstance3D

## 기존 Blender 포구·연기 아틀라스. 착탄 체적과 독립적인 발사 보조 표현.
const FLASH_TEXTURE: Texture2D = preload("res://assets/effects/muzzle_flash.png")
const SMOKE_TEXTURE: Texture2D = preload("res://assets/effects/gun_smoke.png")
const SHADER_BODY := """
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec2 frame_offset = vec2(0.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float opacity = 1.0;
void fragment() {
	vec4 sampled = texture(atlas, frame_offset + UV * vec2(254.0 / 1024.0, 254.0 / 512.0));
	ALBEDO = sampled.rgb * tint;
	ALPHA = sampled.a * opacity;
}
"""

static var _flash_shader: Shader
static var _smoke_shader: Shader
var display_size := Vector2.ONE
var display_angle := 0.0
var _material: ShaderMaterial


func configure(flash: bool, tint: Color = Color.WHITE) -> void:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = "shader_type spatial; render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;\n" + SHADER_BODY
		_smoke_shader = Shader.new()
		_smoke_shader.code = "shader_type spatial; render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;\n" + SHADER_BODY
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	if flash:
		quad.center_offset.x = 0.22
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = _flash_shader if flash else _smoke_shader
	_material.set_shader_parameter("atlas", FLASH_TEXTURE if flash else SMOKE_TEXTURE)
	_material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func set_frame(frame: int, opacity: float) -> void:
	frame = clampi(frame, 0, 7)
	_material.set_shader_parameter("frame_offset", Vector2(
		float(frame % 4 * 256 + 1) / 1024.0,
		float(floori(float(frame) / 4.0) * 256 + 1) / 512.0
	))
	_material.set_shader_parameter("opacity", opacity)


func update_camera(camera: Camera3D) -> void:
	if not visible:
		return
	# 부모의 조준 회전과 별개로 투영된 포구 방향을 유지하는 전역 기저.
	global_basis = camera.global_basis * Basis(Vector3.BACK, display_angle) \
		* Basis.from_scale(Vector3(display_size.x, display_size.y, 1.0))
