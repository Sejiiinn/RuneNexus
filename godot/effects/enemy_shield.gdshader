shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

instance uniform float shield_ratio : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.6);
	ALBEDO = vec3(0.18, 0.66, 0.91) * (0.10 + rim * 0.44);
	ALPHA = shield_ratio * (0.045 + rim * 0.54);
}
