shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform float u_progress = 1.0;
uniform float u_seed = 0.0;

void vertex() {
	// 중심축을 유지하고 압력 화염의 폭·길이만 짧게 수축.
	VERTEX.xy *= 0.8 + sin(u_progress * 3.141593) * 0.25;
	VERTEX.z *= 1.0 - u_progress * 0.28;
}

void fragment() {
	float distance_from_muzzle = 1.0 - UV.y;
	float core = clamp(UV.x + (1.0 - distance_from_muzzle) * 0.7, 0.0, 1.0);
	vec3 hot = mix(vec3(1.0, 0.16, 0.012), vec3(1.0, 0.9, 0.55), core);
	float fade = 1.0 - smoothstep(0.12, 1.0, u_progress);
	float edge = 1.0 - smoothstep(0.65, 1.0, distance_from_muzzle);
	ALBEDO = hot;
	EMISSION = hot * (2.0 + UV.x * 2.0);
	ALPHA = fade * edge * (0.8 + 0.2 * sin(u_seed + distance_from_muzzle * 16.0));
}
