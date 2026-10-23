shader_type spatial;
// 독 포탑 발사·착탄의 옅은 독 안개. 가장자리로 갈수록 흐려지는 구.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.26, 0.5, 0.3);
instance uniform float u_alpha = 0.0;

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = tint;
	ALPHA = pow(facing, 3.2) * u_alpha;
}
