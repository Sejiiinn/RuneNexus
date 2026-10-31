shader_type spatial;
// 착탄 지점의 그을음 자국. 0.1초에 노이즈 경계로 깔리고 0.8~1.1초에 사라진다.
// 곱하기 혼합은 모바일 렌더러에서 자국 밖 사각 경계가 비쳐, 어두운 색과 투명도로 덮는다.
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;

uniform float age = 0.0;
uniform float duration = 1.1;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	return 0.55 * value_noise(p) + 0.3 * value_noise(p * 2.1) + 0.15 * value_noise(p * 4.3);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float grow = smoothstep(0.03, 0.12, age);
	float edge = grow * (0.72 + 0.4 * fbm(p * 3.0 + 7.0));
	float mask = 1.0 - smoothstep(edge * 0.5, edge, r);
	mask *= 0.75 + 0.25 * fbm(p * 7.5 + 2.0);
	float fade = 1.0 - smoothstep(0.8, duration, age);
	ALBEDO = vec3(0.02, 0.016, 0.014);
	ALPHA = clamp(mask * fade * 0.9, 0.0, 1.0);
}
