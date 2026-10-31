shader_type spatial;
// 둥근 잉걸불(선 없음). 공중형은 위로 튀었다 공기에 느려지며 떨어지고, 지면형은 곧 땅에 박혀 1.0초 무렵까지 빛난다.
// 불 잔재형은 화구가 꺼지는 0.25~0.47초에 중심 근처에 남아 진한 주홍에서 숯색으로 식는다.
// 절대 나이로만 다시 계산하므로 정지·배속·풀 재사용에 안전하다.
// 더하기 혼합은 밝은 먼지 위에서 분홍으로 뜨므로, 불투명한 점으로 덮어 그린다.
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, skip_vertex_transform;

// 행마다 하나. 열 0: 각도, 수평 속도(잔재형은 중심 거리), 수직 속도(잔재형은 높이), 크기.
// 열 1: 지연, 수명, 깜빡임 위상, 종류(0 공중, 1 지면, 2 불 잔재).
uniform sampler2D data : filter_nearest, repeat_disable;
uniform float age = 0.0;
uniform float duration = 1.1;

const float START_HEIGHT = 0.3;

varying float v_heat;
varying float v_alpha;
varying float v_core;
varying float v_remnant;
varying float v_seed;

void vertex() {
	vec4 launch = texelFetch(data, ivec2(0, INSTANCE_ID), 0);
	vec4 look = texelFetch(data, ivec2(1, INSTANCE_ID), 0);
	float kind = look.w;
	float t = age - look.x;
	float life = look.y;
	v_alpha = 0.0;
	v_heat = 0.0;
	v_core = 0.0;
	v_remnant = step(1.5, kind);
	v_seed = look.z;
	vec3 origin = vec3(0.0);
	float size = 0.0;
	if (kind > 1.5) {
		// 불 잔재: 0.25초에 화구 속에서 드러나 0.47초까지 식으며 줄어든다.
		if (t >= 0.0 && t < life) {
			float k = t / life;
			origin = vec3(cos(launch.x) * launch.y, launch.z, sin(launch.x) * launch.y);
			v_heat = 1.0 - k;
			v_alpha = smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.7, 1.0, k));
			size = launch.w * mix(1.0, 0.6, k);
		}
	} else if (t >= 0.0 && t < life) {
		bool grounded = kind > 0.5;
		float gravity = grounded ? 9.0 : 3.2;
		float drag = grounded ? 4.0 : 3.2;
		float slow = (1.0 - exp(-drag * t)) / drag;
		float height = START_HEIGHT + launch.z * slow - gravity * (t - slow) / drag;
		float distance = launch.y * slow;
		origin = vec3(cos(launch.x) * distance, max(height, 0.02), sin(launch.x) * distance);
		v_heat = exp(-t / 0.09);
		float flicker = 1.0 + 0.3 * sin(t * 63.0 + look.z);
		float fade = grounded ? 1.0 - smoothstep(0.4, 1.05, age) : smoothstep(1.0, 0.7, t / life);
		// 화구 안에 있는 동안은 숨겨 화구 위 반짝이 가루처럼 보이지 않게 한다.
		float hidden = grounded ? smoothstep(0.22, 0.3, age) : smoothstep(0.24, 0.32, age);
		v_alpha = flicker * fade * hidden * clamp((duration - age) / 0.08, 0.0, 1.0);
		v_core = step(0.75, fract(look.z * 0.37));
		size = launch.w * mix(0.6, 1.0, v_heat);
	}
	vec4 view = VIEW_MATRIX * MODEL_MATRIX * vec4(origin, 1.0);
	// 화면을 향한 점 크기에도 폭발 노드의 배율을 적용한다.
	VERTEX = view.xyz + vec3(VERTEX.xy * size * length(MODEL_MATRIX[0].xyz), 0.0);
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
	vec2 p = UV - 0.5;
	float d = length(p) * 2.0;
	vec3 hot = vec3(1.0, 0.43, 0.05) * 3.0;    // #FFB040 부근
	vec3 cool = vec3(0.63, 0.03, 0.003) * 2.2; // #D0300A 부근
	if (v_remnant > 0.5) {
		// 불 잔재: 가장자리를 노이즈로 찢고, 안쪽 틈만 주홍으로 남긴 채 숯색으로 식는다.
		float edge = 0.7 + 0.3 * value_noise(p * 4.0 + v_seed);
		float body = 1.0 - smoothstep(edge * 0.35, edge, d);
		float flicker = 0.8 + 0.4 * value_noise(p * 5.0 + v_seed * 2.0 + vec2(age * 7.0, -age * 5.0));
		float glow = smoothstep(0.2, 0.55, value_noise(p * 4.5 + v_seed * 3.0)) * mix(0.3, 1.0, v_heat) * flicker;
		vec3 ember = mix(vec3(0.75, 0.04, 0.004) * 2.2, mix(cool, hot, 0.3), v_heat);
		ALBEDO = mix(vec3(0.05, 0.035, 0.03), ember, clamp(glow, 0.0, 1.0));
		ALPHA = body * v_alpha * 0.9;
	} else {
		float core = smoothstep(1.0, 0.0, d);
		core *= core;
		// 진홍 바탕에 25%는 밝은 주황 핵이 남아 크기·밝기가 고르지 않다.
		ALBEDO = mix(cool, hot, max(v_heat, v_core * 0.6 * smoothstep(0.45, 0.0, d)));
		ALPHA = clamp(core * 1.6, 0.0, 1.0) * v_alpha;
	}
}
