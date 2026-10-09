shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_map : filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform vec4 emission_tint : source_color = vec4(1.0);
uniform float roughness_factor = 1.0;
uniform float metallic_factor = 1.0;
uniform float normal_strength = 1.0;
uniform bool use_ao = false;
uniform bool use_albedo = false;
uniform bool use_normal = false;
uniform bool use_roughness = false;
uniform bool use_metallic = false;
uniform bool use_emission = false;
instance uniform float death_opacity = 1.0;
void fragment() {
    // Opaque coverage retains the approved stone depth throughout the fade.
    float coverage = fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453);
    if (coverage > death_opacity) discard;
    ALBEDO = (use_albedo ? texture(albedo_map, UV).rgb : vec3(1.0)) * albedo_tint.rgb;
    ROUGHNESS = (use_roughness ? texture(roughness_map, UV).g : 1.0) * roughness_factor;
    METALLIC = (use_metallic ? texture(metallic_map, UV).b : 1.0) * metallic_factor;
    NORMAL_MAP = use_normal ? texture(normal_map, UV).rgb : vec3(0.5, 0.5, 1.0);
    NORMAL_MAP_DEPTH = normal_strength;
    EMISSION = (use_emission ? texture(emission_map, UV).rgb : vec3(1.0)) * emission_tint.rgb;
    AO = use_ao ? texture(ao_map, UV).r : 1.0;
}
