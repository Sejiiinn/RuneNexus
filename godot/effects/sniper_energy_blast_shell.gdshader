shader_type spatial;
// 저격 에너지 폭발의 에너지 껍질. 지면 중심에서 범위 직전까지 부풀며 옅어진다.
// 지형에 가려지는 반구로 두고 가장자리 밝기를 노이즈로 얼룩지게 해 매끈한 원 윤곽을 피한다.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform float u_age = 0.0;
uniform float u_seed = 0.0;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
	float p = clamp((u_age - 0.01) / 0.2, 0.0, 1.0);
	VERTEX *= mix(0.3, 0.92, 1.0 - pow(1.0 - p, 3.0));
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	vec3 q = normalize(v_local) * 4.0 + u_seed;
	float n = 0.5 + 0.5 * sin(q.x * 2.3 + sin(q.z * 3.1)) * sin(q.y * 2.9 + q.z * 1.7);
	float shape = pow(1.0 - facing, 2.0) * smoothstep(0.05, 0.35, facing) * mix(0.25, 1.4, n);
	float intensity = 1.1 * (1.0 - smoothstep(0.06, 0.24, u_age)) * step(0.01, u_age);
	ALBEDO = vec3(0.25, 1.0, 1.0) * shape * intensity;
	ALPHA = 1.0;
}
