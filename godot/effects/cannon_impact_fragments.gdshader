shader_type spatial;
// The original StandardMaterial3D's default lighting, depth and cull modes.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#include "cannon_impact_motion.gdshaderinc"

void fragment() {
	// Original StandardMaterial3D used linear_to_srgb() on this color. Shader
	// ALBEDO is already linear, so do not apply a second color conversion.
	ALBEDO = vec3(0.019, 0.020, 0.021);
	METALLIC = 0.48;
	ROUGHNESS = 0.72;
	SPECULAR = 0.5;
}
