shader_type spatial;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
instance uniform float death_opacity = 1.0;
instance uniform float death_light = 1.0;
void fragment() {
    // Keep the original opaque surface depth within the joined rigid mesh.
    // Alpha blending sorts the eye spheres in front of their stone sockets.
    float coverage = fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453);
    if (coverage > death_opacity) discard;
    vec4 color = texture(albedo_map, UV);
    ALBEDO = color.rgb;
    ROUGHNESS = texture(roughness_map, UV).g;
    NORMAL_MAP = texture(normal_map, UV).rgb;
    EMISSION = texture(emission_map, UV).rgb * death_light;
}
