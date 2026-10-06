shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded, cull_disabled;
instance uniform float dust_alpha = 1.0;

void fragment() {
	// Small 3D puffs retain the accepted silhouette at every camera angle.
	float softness = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.4);
	ALBEDO = vec3(0.48, 0.44, 0.36);
	ALPHA = softness * 0.20 * dust_alpha;
}
