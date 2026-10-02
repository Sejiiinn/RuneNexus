shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;
uniform bool shell = false;
instance uniform float death_opacity = 1.0;
instance uniform float death_light = 1.0;
vec3 amber_ramp(float facing) {
    vec3 a = vec3(1.8, 1.45, .95);
    vec3 b = vec3(1.0, .760524511, .356400132);
    vec3 c = vec3(1.0, .520995557, .036889449);
    vec3 d = vec3(.564711511, .191201687, .002731743);
    vec3 e = vec3(.132868320, .031896032, .000303527);
    if (facing < .035) return mix(a,b,facing/.035);
    if (facing < .18) return mix(b,c,(facing-.035)/.145);
    if (facing < .48) return mix(c,d,(facing-.18)/.30);
    return mix(d,e,clamp((facing-.48)/.37,0.0,1.0));
}
void fragment() {
    float facing = 1.0 - abs(dot(normalize(NORMAL),normalize(VIEW)));
    vec3 amber = amber_ramp(facing);
    ALBEDO = amber * mix(.075,1.0,clamp(death_light,0.0,1.0));
    EMISSION = amber * 1.05 * death_light;
    ROUGHNESS = .28;
    SPECULAR = .06;
    ALPHA = death_opacity * (shell ? .38 : 1.0);
}
