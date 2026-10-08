shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform vec4 emission_tint : source_color = vec4(1.0);
uniform float roughness_factor = 1.0;
uniform float normal_strength = 1.0;
instance uniform float death_opacity = 1.0;

void fragment() {
	// Match the tank and boss stone exit: fixed screen coverage preserves
	// opaque depth and eye/core occlusion throughout the held-pose fade.
	float coverage = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	if (coverage > death_opacity) discard;
	vec4 color = texture(albedo_map, UV) * albedo_tint;
	ALBEDO = color.rgb;
	ROUGHNESS = texture(roughness_map, UV).g * roughness_factor;
	METALLIC = 0.0;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	EMISSION = texture(emission_map, UV).rgb * emission_tint.rgb;
}
