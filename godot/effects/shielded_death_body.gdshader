shader_type spatial;
render_mode cull_disabled;
// Accepted shielded PBR (albedo/normal/baked rune emission) with the dying rune
// power and an opaque dither fade that keeps the stone depth.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform vec4 emission_tint : source_color = vec4(1.0);
uniform float roughness_factor = 0.8;
uniform float metallic_factor = 0.0;
uniform float normal_strength = 1.0;
uniform bool use_normal = false;
uniform bool use_emission = false;
instance uniform float death_light = 1.0;
instance uniform float death_opacity = 1.0;

void fragment() {
	float coverage = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	if (coverage > death_opacity) discard;
	// The pale rune crystal reads as lit even without emission; dull it as power dies.
	vec3 rune = use_emission ? texture(emission_map, UV).rgb : vec3(0.0);
	float rune_mask = clamp(max(rune.r, max(rune.g, rune.b)) * 1.5, 0.0, 1.0);
	ALBEDO = texture(albedo_map, UV).rgb * albedo_tint.rgb * (1.0 - 0.65 * rune_mask * clamp(1.0 - death_light, 0.0, 1.0));
	ROUGHNESS = roughness_factor;
	METALLIC = metallic_factor;
	NORMAL_MAP = use_normal ? texture(normal_map, UV).rgb : vec3(0.5, 0.5, 1.0);
	NORMAL_MAP_DEPTH = normal_strength;
	EMISSION = rune * emission_tint.rgb * death_light;
}
