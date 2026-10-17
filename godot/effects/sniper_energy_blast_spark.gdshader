shader_type spatial;
// 저격 에너지 폭발의 불티. 위로 튀었다 떨어지며 흰빛에서 진한 청록으로 식는다.
// INSTANCE_CUSTOM: xyz 초속(반경 기준), w 수명. 지연은 순번으로 정한다.
// 폭발 중심이 맞은 적 몸체 안이므로 깊이 가림 없이 몸체 위로 비쳐 보인다.
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform float u_age = 0.0;
// 노드 배율(타일). 중력과 지면 높이를 반경 기준 좌표로 바꾼다.
uniform float u_radius = 1.0;
// sniper_energy_blast.gd HIT_HEIGHT와 같다.
const float HIT_HEIGHT = 0.42;

varying float v_along;
varying float v_heat;
varying float v_fade;

void vertex() {
	vec3 v0 = INSTANCE_CUSTOM.xyz;
	float life = INSTANCE_CUSTOM.w;
	float t = u_age - fract(sin(float(INSTANCE_ID) * 91.7) * 43758.5453) * 0.04;
	float p = clamp(t / life, 0.0, 1.0);
	vec3 g = vec3(0.0, -4.2 / u_radius, 0.0);
	vec3 head = v0 * t * (1.0 - 0.3 * p) + 0.5 * g * t * t;
	vec3 forward = normalize(v0 * (1.0 - 0.55 * p) + g * t);
	vec3 tail = head - forward * (0.16 * (1.0 - p) + 0.03);
	vec3 right = normalize(cross(abs(forward.y) > 0.98 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0), forward));
	vec3 up = cross(forward, right);
	float width = mix(0.012, 0.02, VERTEX.y);
	v_along = VERTEX.y;
	v_heat = p;
	v_fade = 1.0 - p;
	// 지면(맞은 높이에서 0.02타일 위까지) 아래로 내려간 불티는 그리지 않는다.
	bool alive = t >= 0.0 && t <= life && head.y * u_radius > 0.02 - HIT_HEIGHT;
	VERTEX = alive ? mix(tail, head, VERTEX.y) + (right * VERTEX.x + up * VERTEX.z) * width : vec3(0.0);
}

void fragment() {
	vec3 cool = mix(vec3(1.0), vec3(0.2, 0.85, 1.0), smoothstep(0.0, 0.5, v_heat));
	cool = mix(cool, vec3(0.05, 0.5, 0.75), smoothstep(0.5, 1.0, v_heat));
	ALBEDO = cool * v_fade * v_along * 1.8;
	ALPHA = 1.0;
}
