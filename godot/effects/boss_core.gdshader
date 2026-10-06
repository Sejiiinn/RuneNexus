shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D core_mask : filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_factor : source_color = vec4(1.0);
uniform vec3 emission_factor : source_color = vec3(1.0);
uniform float roughness_factor = 1.0;
uniform float metallic_factor = 1.0;
uniform float specular_factor = 0.5;
uniform float authored_emission_scale = 3.0;
// Material textures are shared; one death must never dim another live boss.
instance uniform float death_light = 1.0;
instance uniform float core_strength = 0.30;
instance uniform float death_opacity = 1.0;

void fragment() {
	// Keep the opaque depth/sorting of the authored stone throughout the fade.
	if (death_opacity < 0.9999) {
		float coverage = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
		if (coverage > death_opacity) discard;
	}
	ALBEDO = texture(albedo_map, UV).rgb * albedo_factor.rgb;
	ROUGHNESS = texture(roughness_map, UV).g * roughness_factor;
	METALLIC = texture(metallic_map, UV).b * metallic_factor;
	SPECULAR = specular_factor;
	EMISSION = texture(emission_map, UV).rgb * emission_factor * authored_emission_scale * death_light;
	EMISSION += texture(core_mask, UV).r * vec3(1.0, 0.045, 0.008) * core_strength;
}
