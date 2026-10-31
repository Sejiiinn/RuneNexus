shader_type spatial;
// Dark earth chunks thrown out by the blast: one arc, one small bounce, then they rest. Motion is rebuilt from the
// absolute age only, so pause, game speed and pool reuse give the same frame (the GodotImpact contract).
// 투명 단계에서 플립북 카드 위에 겹쳐 그리되, 화구 안(0.3초 전, 중심 가까이)에서는 투명하게 두었다가 밖으로 나오며 드러낸다.
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// Row per chunk. Column 0: angle, horizontal speed, vertical speed, size. Column 1: delay, spin, flatness, heat.
uniform sampler2D data : filter_nearest, repeat_disable;
uniform float age = 0.0;
uniform float duration = 1.1;

const float GRAVITY = 13.0;
const float START_HEIGHT = 0.35;
const float DRAG = 1.1;

varying float v_heat;
varying float v_tint;
varying float v_glow;
varying float v_reveal;
varying float v_inside;

mat3 spin_matrix(vec3 a) {
	vec3 c = cos(a);
	vec3 s = sin(a);
	mat3 x = mat3(vec3(1, 0, 0), vec3(0, c.x, s.x), vec3(0, -s.x, c.x));
	mat3 y = mat3(vec3(c.y, 0, -s.y), vec3(0, 1, 0), vec3(s.y, 0, c.y));
	mat3 z = mat3(vec3(c.z, s.z, 0), vec3(-s.z, c.z, 0), vec3(0, 0, 1));
	return x * y * z;
}

void vertex() {
	vec4 launch = texelFetch(data, ivec2(0, INSTANCE_ID), 0);
	vec4 look = texelFetch(data, ivec2(1, INSTANCE_ID), 0);
	float t = age - look.x;
	if (t < 0.0) {
		VERTEX = vec3(0.0);
	} else {
		float vz = launch.z;
		float hit = (vz + sqrt(vz * vz + 2.0 * GRAVITY * START_HEIGHT)) / GRAVITY;
		float height;
		float bounce_time = max(t - hit, 0.0);
		if (t < hit) {
			height = START_HEIGHT + vz * t - 0.5 * GRAVITY * t * t;
		} else {
			float up = 0.28 * (GRAVITY * hit - vz);
			height = max(up * bounce_time - 0.5 * GRAVITY * bounce_time * bounce_time, 0.0);
		}
		// Air drag until the first landing, then a short skid.
		float air = (1.0 - exp(-DRAG * min(t, hit))) / DRAG;
		float skid = exp(-DRAG * hit) * 0.35 * (1.0 - exp(-6.0 * bounce_time)) / 6.0;
		float distance = launch.y * (air + skid);
		vec3 origin = vec3(cos(launch.x) * distance, height, sin(launch.x) * distance);
		float turn = look.y * min(t, hit + 0.12);
		mat3 rotation = spin_matrix(vec3(turn + float(INSTANCE_ID), turn * 0.71, turn * 1.27));
		// Sink away over the last 0.15 s so nothing is left when the effect ends.
		float fade = clamp((duration - age) / 0.15, 0.0, 1.0);
		vec3 size = vec3(1.0, look.z, 1.0) * launch.w * fade;
		VERTEX = rotation * (VERTEX * size) + origin;
		NORMAL = rotation * NORMAL;
		// Only some chunks are torn from the hot core, and they cool within about 0.2 s.
		v_heat = max(look.w - 0.55, 0.0) * 2.2 * exp(-t * 11.0);
		v_tint = fract(float(INSTANCE_ID) * 0.618);
		v_glow = exp(-age * 7.0);
		v_reveal = max(smoothstep(0.45, 0.85, distance), smoothstep(0.36, 0.44, age));
		// 화구와 겹치는 동안(0.45초 전, 중심 가까이)은 불 앞의 어두운 실루엣으로 둔다.
		v_inside = 1.0 - max(smoothstep(0.55, 0.95, distance), smoothstep(0.38, 0.46, age));
	}
}

void fragment() {
	// 그늘진 면도 구멍처럼 보이지 않도록 순흑보다 밝은 흙색.
	ALBEDO = mix(vec3(0.06, 0.05, 0.043), vec3(0.12, 0.105, 0.09), v_tint) * mix(1.0, 0.25, v_inside);
	ROUGHNESS = 0.92;
	SPECULAR = 0.3;
	// 막 뜯겨 나온 조각은 잠깐 달아올랐다 흙색으로 식고, 화구 곁에서는 가장자리에 주황 역광을 받는다.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	// 그늘면도 최소 밝기를 남겨 순흑 구멍처럼 보이지 않게 한다.
	EMISSION = vec3(3.0, 0.75, 0.08) * v_heat + vec3(1.6, 0.45, 0.06) * rim * max(v_glow, v_inside * 0.6)
		+ ALBEDO * 0.5 * (1.0 - v_inside);
	ALPHA = v_reveal;
}
