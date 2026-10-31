shader_type spatial;
// Camera-facing explosion card rendered from the game camera angle; two neighbouring cells are blended so the
// 64-frame sheet plays smoothly at any game speed.
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled;

uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform int columns = 8;
uniform int rows = 8;
uniform float frame = 0.0;
uniform float brightness = 1.0;
// 착탄 지점(지면 원점)이 카드에 비치는 UV. 렌더 카메라가 높이 1을 화면 중심에 두므로 1 * cos(63°) / 5.5만큼 아래.
uniform vec2 impact_uv = vec2(0.5, 0.583);

vec4 cell(int index, vec2 uv) {
	int c = index % columns;
	int r = index / columns;
	vec2 size = vec2(1.0 / float(columns), 1.0 / float(rows));
	return texture(sheet, (vec2(float(c), float(r)) + uv) * size);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	int count = columns * rows;
	float f = clamp(frame, 0.0, float(count - 1));
	int a = int(floor(f));
	int b = min(a + 1, count - 1);
	vec4 color = mix(cell(a, UV), cell(b, UV), fract(f));
	float t = frame / 60.0;
	// 지면 위 원은 63° 시점에서 세로로 sin(63°)만큼 눌린다. 반경 1 = 착탄 반경(블래스트 로컬 0.53, 카드 UV 0.097).
	vec2 offset = (UV - impact_uv) / vec2(0.097, 0.097 * 0.89);
	float ragged = 0.8 + 0.4 * value_noise(UV * 14.0);
	float r = length(offset) / ragged;
	// 화구가 꺼진 뒤 먼지는 최대 불투명도를 낮추고, 0.4초부터 착탄 중심을 비워 잉걸불과 그을음 자국을 드러낸다.
	float alpha = min(color.a, mix(1.0, 0.55, smoothstep(0.3, 0.45, t)));
	float hole = (1.0 - smoothstep(0.6, 1.4, r)) * smoothstep(0.35, 0.55, t);
	alpha *= mix(1.0, 0.3, hole);
	// 0.7초부터 바깥부터 흩어져 1.0초에 10% 이하, 1.1초에 0이 된다.
	float spread = smoothstep(0.65, 1.05, t) * (0.75 + 0.12 * r + 0.25 * value_noise(UV * 9.0 + 3.0));
	alpha *= clamp(1.0 - spread, 0.0, 1.0) * (1.0 - smoothstep(1.0, 1.08, t));
	ALBEDO = color.rgb * brightness;
	ALPHA = alpha;
}
