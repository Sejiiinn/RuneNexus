shader_type spatial;
// 독액 착탄 웅덩이(독 장판). 착탄 범위만큼 순식간에 번지고, 가장자리에 튄 자국과 터지는 기포를
// 남긴 채 장판 유지 시간 동안 머문 뒤 가장자리부터 말라 들어가며 사라진다. 전장 조명을 받는 젖은 독액 재질로,
// 깊은 곳은 짙은 독초록, 얕은 가장자리는 흙에 스민 젖은 얼룩이 된다.
// 평면 크기 2, 노드 배율이 착탄 반경이다.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float u_age = 0.0;
uniform float u_duration = 1.1;
uniform float u_seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return 0.55 * noise(p) + 0.3 * noise(p * 2.1 + 3.7) + 0.15 * noise(p * 4.3 - 1.9);
}

// 웅덩이 경계까지의 부호 거리(안쪽 음수). 불규칙한 본체와 가장자리에 튄 자국.
float puddle_distance(vec2 p, float grow, float dry) {
	float a = atan(p.y, p.x);
	float edge = (0.64 + 0.07 * sin(a * 5.0 + u_seed) + 0.05 * sin(a * 9.0 - u_seed * 1.7)
		+ 0.03 * sin(a * 14.0 + u_seed * 0.6)) * grow * dry;
	float d = length(p) - edge + (fbm(p * 5.0 + u_seed) - 0.5) * 0.06;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float angle = u_seed * 0.37 + fi * 1.047 + 0.4 * sin(u_seed + fi * 2.3);
		vec2 center = vec2(cos(angle), sin(angle)) * (0.84 + 0.12 * sin(u_seed * 1.3 + fi * 4.1)) * grow;
		d = min(d, length(p - center) - (0.07 + 0.035 * sin(fi * 5.7 + u_seed)) * grow * dry);
	}
	return d;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float grow = 1.0 - pow(1.0 - clamp(u_age / 0.13, 0.0, 1.0), 3.0);
	// 장판 판정이 끝나는 마지막 0.6초(짧은 장판은 후반 55%) 동안 말라 사라진다.
	float fading = smoothstep(max(u_duration * 0.45, u_duration - 0.6), u_duration, u_age);
	float dry = 1.0 - 0.18 * fading;
	float d = puddle_distance(p, grow, dry);
	float liquid = 1.0 - smoothstep(-0.012, 0.012, d);
	// 경계 바깥으로 흙에 스민 젖은 얼룩.
	float stain = (1.0 - smoothstep(0.0, 0.09, d)) * (1.0 - liquid);
	float depth = smoothstep(0.0, -0.22, d);
	float murk = fbm(p * 3.2 + vec2(u_seed, u_age * 0.4));
	vec3 deep = mix(vec3(0.008, 0.07, 0.016), vec3(0.02, 0.12, 0.03), murk);
	vec3 shallow = vec3(0.04, 0.22, 0.05);
	vec3 color = mix(shallow, deep, depth);
	// 잔물결 노멀: 착탄 직후 퍼지는 고리와 느린 표면 흔들림.
	float ripple = sin(length(p) * 18.0 - u_age * 12.0) * exp(-u_age * 5.0) * 0.5;
	vec2 slope = vec2(fbm(p * 2.6 + u_age * 0.3) - fbm(p * 2.6 + vec2(0.25, 0.0) + u_age * 0.3),
		fbm(p * 2.6 + u_age * 0.3) - fbm(p * 2.6 + vec2(0.0, 0.25) + u_age * 0.3)) * 0.8 + normalize(p + 0.0001) * ripple * depth * 0.5;
	// 터지는 기포: 은은한 독기만 낸다.
	float bubbles = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		vec2 center = vec2(sin(u_seed * 2.1 + fi * 3.7), cos(u_seed * 1.3 + fi * 2.9)) * 0.4 * grow;
		float phase = fract(u_age * 1.7 + fi * 0.27);
		float ring = 1.0 - smoothstep(0.0, 0.016, abs(length(p - center) - (0.02 + 0.06 * phase)));
		bubbles = max(bubbles, ring * (1.0 - phase) * depth);
	}
	ALBEDO = mix(vec3(0.03, 0.06, 0.025), color, liquid);
	ROUGHNESS = mix(0.5, 0.2, liquid);
	SPECULAR = 0.35;
	METALLIC = 0.0;
	NORMAL_MAP = vec3(slope * liquid * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	// 넓은 발광은 전장 조명에서 형광색으로 날려 기포에만 약하게 둔다.
	EMISSION = (vec3(0.0, 0.035, 0.01) * depth + vec3(0.08, 0.4, 0.12) * bubbles * 0.35) * liquid;
	ALPHA = (liquid * 0.92 + stain * 0.4) * (1.0 - fading);
}
