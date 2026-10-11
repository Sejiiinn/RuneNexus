shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

// 명중 접점의 백열 핵과 십자 섬광. 카메라를 향하는 판이 아닌 입체 메시다.
// COLOR.r=1은 핵, 0은 표면 접선·수직 방향의 가는 섬광 갈래.
uniform float u_time = 0.0;
const float LIFE = 0.06;

varying float v_strength;
varying float v_core;

void vertex() {
	float age = u_time - INSTANCE_CUSTOM.x;
	v_strength = 0.0;
	v_core = COLOR.r;
	if (age < 0.0 || age > LIFE) {
		VERTEX = vec3(0.0);
	} else {
		float k = pow(1.0 - age / LIFE, 1.5);
		v_strength = k;
		VERTEX *= 0.35 + 0.65 * k;
	}
}

void fragment() {
	vec3 white = vec3(1.0, 0.97, 0.88);
	vec3 amber = vec3(1.0, 0.70, 0.32);
	// 핵 가장자리는 시선과의 각도로 부드럽게 줄어 둥근 열점으로 보인다.
	float rim = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	vec3 core = mix(amber, white, rim) * rim * 3.0;
	ALBEDO = mix(white * 2.4, core, v_core) * v_strength;
}
