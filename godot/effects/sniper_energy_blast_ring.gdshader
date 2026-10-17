shader_type spatial;
// 저격 에너지 폭발의 지면 충격파. 0.18초에 실제 스플래시 반경(1)에 닿고 곧 사라진다.
// 64개 호마다 굵기·밝기가 다르고 일부 호는 끊겨 매끈한 원으로 보이지 않는다.
// 터질 때만 반경 안 바닥이 짧게 밝아진다.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float u_age = 0.0;
uniform float u_seed = 0.0;
// 평면 반경. sniper_energy_blast.gd RING_EXTENT와 같다.
const float EXTENT = 1.05;
const float SEGMENTS = 64.0;

float noise(float segment) {
	return fract(sin(mod(segment, SEGMENTS) * 12.9898 + u_seed * 78.233) * 43758.5453);
}

void fragment() {
	vec2 at = (UV * 2.0 - 1.0) * EXTENT;
	float d = length(at);
	float p = clamp(u_age / 0.18, 0.0, 1.0);
	float r = 1.0 - pow(1.0 - p, 3.0);
	float fade = 1.0 - smoothstep(0.08, 0.24, u_age);
	float turn = (atan(at.y, at.x) / TAU + 0.5) * SEGMENTS;
	float segment = floor(turn);
	float n = noise(segment);
	float n2 = noise(segment + 1.0);
	float thickness = mix(0.025, 0.09, n) * (1.0 - 0.5 * p) * mix(1.0, mix(0.7, 1.0, n2), fract(turn));
	float s = (r - d) / thickness;
	vec3 color = vec3(0.0);
	if (n >= 0.28 && s >= 0.0 && s <= 1.0) {
		color = mix(vec3(0.75, 1.0, 1.0), vec3(0.15, 0.55, 1.0), s) * fade * mix(0.35, 1.0, n) * (1.0 - s);
	}
	color += vec3(0.1, 0.6, 0.85) * 0.5 * (1.0 - smoothstep(0.0, 0.12, u_age)) * max(0.0, 1.0 - d / max(r, 0.001));
	color *= 1.6;
	if (max(color.r, max(color.g, color.b)) < 0.002) {
		discard;
	}
	ALBEDO = color;
	ALPHA = 1.0;
}
