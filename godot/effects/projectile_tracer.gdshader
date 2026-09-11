shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform vec3 u_color : source_color = vec3(1.0, 0.76, 0.32);
uniform float u_opacity = 1.0;

void fragment() {
	// 원통 UV의 위쪽이 탄두 방향. 꼬리는 가늘고 어둡게 소멸.
	float head = 1.0 - UV.y;
	vec3 hot = mix(u_color, vec3(1.0, 0.98, 0.85), head * 0.75);
	ALBEDO = hot;
	EMISSION = hot * 1.2;
	ALPHA = u_opacity * mix(0.12, 0.92, head);
}
