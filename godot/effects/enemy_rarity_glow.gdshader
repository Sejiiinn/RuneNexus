shader_type spatial;
// Magic/rare tier rim drawn as a material overlay over the authored body.
// Additive and view-dependent only: the body colour, runes and core stay readable.
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 rim_color : source_color = vec4(0.42, 0.58, 1.0, 1.0);
uniform float rim_power = 2.4;
uniform float strength = 1.25;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = rim_color.rgb * pow(1.0 - facing, rim_power) * strength;
}
