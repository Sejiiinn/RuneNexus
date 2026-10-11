shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// 명중면에서 반사되는 불티. 인스턴스 변환은 명중 시 한 번만 기록한다.
// INSTANCE_CUSTOM: x=시작 시각, y=명중 seed, z=명중 안의 불티 순번.
// 로컬 +Z는 탄이 들어온 반대 방향(사수 쪽), +Y는 월드 위쪽이다.
uniform float u_time = 0.0;

varying float v_fade;
varying float v_heat;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void vertex() {
	float start = INSTANCE_CUSTOM.x;
	float s = INSTANCE_CUSTOM.y * 13.17 + INSTANCE_CUSTOM.z * 7.31;
	float age = u_time - start;
	float life = mix(0.09, 0.17, hash(s + 1.0));
	v_fade = 0.0;
	v_heat = 0.0;
	if (age < 0.0 || age > life) {
		VERTEX = vec3(0.0);
	} else {
		// 표면을 따라 퍼지는 갈래와 위로 튀는 갈래를 함께 만든다.
		float yaw = (hash(s + 2.0) - 0.5) * 2.0 * mix(0.75, 1.35, hash(s + 6.0));
		float pitch = mix(-0.15, 0.95, hash(s + 3.0));
		float speed = mix(2.2, 4.4, hash(s + 4.0));
		vec3 v0 = vec3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * speed;
		vec3 g = vec3(0.0, -4.5, 0.0);
		vec3 position = v0 * age + 0.5 * g * age * age;
		vec3 velocity = v0 + g * age;
		vec3 forward = normalize(velocity);
		vec3 right = normalize(cross(abs(forward.y) > 0.98 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0), forward));
		vec3 up = cross(forward, right);
		float k = age / life;
		// 기본 전장 거리에서 한 줄기씩 읽히는 최소 굵기·길이.
		float len = clamp(length(velocity) * 0.045, 0.05, 0.2) * (1.0 - 0.45 * k);
		float width = mix(0.018, 0.008, k);
		// 메시 z -0.5..0.5에서 머리를 현재 위치에 두고 꼬리를 뒤로 끈다.
		VERTEX = position + right * VERTEX.x * width + up * VERTEX.y * width + forward * (VERTEX.z - 0.5) * len;
		v_fade = pow(1.0 - k, 1.2);
		v_heat = k;
	}
}

void fragment() {
	vec3 white = vec3(1.0, 0.96, 0.84) * 3.2;
	vec3 amber = vec3(1.0, 0.62, 0.20) * 2.4;
	vec3 ember = vec3(1.0, 0.30, 0.06) * 1.6;
	vec3 color = v_heat < 0.4 ? mix(white, amber, v_heat / 0.4) : mix(amber, ember, (v_heat - 0.4) / 0.6);
	ALBEDO = color * v_fade;
}
