shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, fog_disabled;
instance uniform float death_age = 0.0;
varying float opacity;

void vertex() {
	float t = max(death_age - 0.07, 0.0);
	VERTEX += vec3(INSTANCE_CUSTOM.x * t * 0.12, INSTANCE_CUSTOM.y * t, INSTANCE_CUSTOM.z * t * 0.12);
	opacity = smoothstep(0.07, 0.18, death_age) * (1.0 - smoothstep(0.32, 0.55, death_age));
}

void fragment() {
	ALBEDO = vec3(0.15, 0.75, 0.85);
	EMISSION = vec3(0.1, 0.65, 0.8);
	ALPHA = opacity * 0.6;
}
