shader_type spatial;
// 저격 에너지 폭발의 임팩트 갈래. 끝이 0.05초 안에 뻗고 밑동이 끝 쪽으로 빠지며 사라진다.
// 인스턴스 변환의 y축이 방향·길이, x·z축이 굵기다. INSTANCE_CUSTOM.x는 지연이다.
// 폭발 중심이 맞은 적 몸체 안이므로 깊이 가림 없이 몸체 위로 비쳐 보인다.
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled;

uniform float u_age = 0.0;

varying float v_along;
varying float v_fade;

void vertex() {
	float t = u_age - INSTANCE_CUSTOM.x;
	float tip = 1.0 - pow(1.0 - clamp(t / 0.05, 0.0, 1.0), 3.0);
	float base = smoothstep(0.04, 0.2, t);
	v_along = VERTEX.y;
	v_fade = (1.0 - smoothstep(0.12, 0.22, t)) * step(0.0, t);
	VERTEX.y = mix(base * 0.95, tip, VERTEX.y);
	VERTEX.xz *= 1.0 - base * 0.6;
	if (v_fade <= 0.0) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec3 color = mix(vec3(1.0), vec3(0.3, 0.95, 1.0), smoothstep(0.0, 0.35, v_along));
	color = mix(color, vec3(0.05, 0.63, 0.9), smoothstep(0.35, 1.0, v_along));
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = color * (0.75 + 0.25 * facing) * v_fade * 1.8;
	ALPHA = 1.0;
}
