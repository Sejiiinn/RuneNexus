shader_type spatial;
// 저격 에너지 폭발의 중심 섬광과 후광. 같은 셰이더를 크기·색·시간만 달리해 쓴다.
// 폭발 중심이 맞은 적 몸체 안이므로 깊이 가림 없이 몸체 위로 비쳐 보인다.
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled;

uniform float u_age = 0.0;
uniform vec3 tint = vec3(1.0);
uniform float softness = 1.6;
// 반경 1 기준 구 반경의 시작·끝.
uniform vec2 scale_range = vec2(0.1, 0.2);
uniform float grow_time = 0.05;
uniform float grow_power = 2.0;
uniform vec2 fade_range = vec2(0.03, 0.12);
uniform float peak = 1.0;

void vertex() {
	float grow = 1.0 - pow(1.0 - clamp(u_age / grow_time, 0.0, 1.0), grow_power);
	VERTEX *= mix(scale_range.x, scale_range.y, grow);
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float fade = 1.0 - smoothstep(fade_range.x, fade_range.y, u_age);
	ALBEDO = tint * pow(facing, softness) * peak * fade;
	ALPHA = 1.0;
}
