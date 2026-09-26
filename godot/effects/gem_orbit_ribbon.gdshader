shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 ribbon_color : source_color = vec4(0.1, 0.8, 1.0, 1.0);

void fragment() {
	float lateral = abs(UV.y * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(0.64, 1.0, lateral);
	float fade = pow(1.0 - UV.x, 0.72);
	float spine = pow(1.0 - lateral, 5.0);
	ALBEDO = mix(ribbon_color.rgb, vec3(1.0), spine * 0.55);
	// Visible without bloom; normal depth testing keeps the rear arc occluded.
	ALPHA = ribbon_color.a * edge * fade * 0.94;
}
