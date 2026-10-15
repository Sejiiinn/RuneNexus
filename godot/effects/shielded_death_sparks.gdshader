shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// Deterministic spark streaks for the shielded death. INSTANCE_CUSTOM:
// r=burst index, g=azimuth, b=elevation, a=speed. Coordinates are model-local.
instance uniform float death_age = 0.0;
// Hover jolts (authored frames 3/8/13/17) and the body's ground impact (frame 36).
const float BURST_TIME[5] = float[](0.083, 0.292, 0.5, 0.667, 1.458);
const vec3 BURST_ORIGIN[5] = vec3[](vec3(0.02, 0.06, 0.28), vec3(-0.12, 0.18, 0.16),
	vec3(0.10, -0.08, 0.22), vec3(0.0, 0.10, -0.20), vec3(0.18, -0.56, 0.36));
const float LIFE = 0.34;
varying float v_alpha;

void vertex() {
	int burst = int(INSTANCE_CUSTOM.r + 0.5);
	float t = death_age - BURST_TIME[burst];
	if (t < 0.0 || t > LIFE) {
		VERTEX = vec3(0.0);
		v_alpha = 0.0;
	} else {
		float azimuth = INSTANCE_CUSTOM.g;
		float elevation = INSTANCE_CUSTOM.b;
		vec3 direction = vec3(cos(azimuth) * cos(elevation), sin(elevation), sin(azimuth) * cos(elevation));
		vec3 launch = direction * INSTANCE_CUSTOM.a;
		vec3 gravity = vec3(0.0, -7.0, 0.0);
		vec3 point = BURST_ORIGIN[burst] + launch * t + 0.5 * gravity * t * t;
		vec3 velocity = launch + gravity * t;
		vec3 forward = normalize(velocity);
		vec3 side = normalize(cross(forward, abs(forward.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)));
		vec3 up = cross(side, forward);
		// Unit box: a thin streak trailing behind its head along the velocity.
		float streak = 0.03 + 0.05 * length(velocity);
		VERTEX = point + side * VERTEX.x * 0.026 + up * VERTEX.y * 0.026 - forward * (VERTEX.z + 0.5) * streak;
		v_alpha = 1.0 - smoothstep(0.35 * LIFE, LIFE, t);
	}
}

void fragment() {
	ALBEDO = vec3(0.55, 1.35, 2.1);
	ALPHA = v_alpha;
}
