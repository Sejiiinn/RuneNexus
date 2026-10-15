shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, shadows_disabled;
// Actual Blender-authored branched tubes: UV2.x is longitudinal center station,
// UV.y distinguishes the hairline hot core from its wider, dim plasma sheath.
// Both layers stay in one surface. INSTANCE_CUSTOM.r selects one of three links
// or two contact coronas; .g is a fixed roll. No wall clock or particle state.
uniform bool contact_forks = false;
instance uniform float death_age = 0.0;
instance uniform int burst_index = 0;
instance uniform vec3 anchor_0 = vec3(0.0);
instance uniform vec3 anchor_1 = vec3(0.0);
instance uniform vec3 anchor_2 = vec3(0.0);
instance uniform vec3 anchor_3 = vec3(0.0);
instance uniform vec3 anchor_4 = vec3(0.0);
instance uniform vec3 anchor_5 = vec3(0.0);
instance uniform vec3 anchor_6 = vec3(0.0);
const float BURST_TIME[5] = float[](0.083, 0.292, 0.5, 0.667, 1.458);
varying float v_energy;
varying float v_tail;

vec3 anchor(int index) {
	if (index == 0) return anchor_0;
	if (index == 1) return anchor_1;
	if (index == 2) return anchor_2;
	if (index == 3) return anchor_3;
	if (index == 4) return anchor_4;
	if (index == 5) return anchor_5;
	return anchor_6;
}

int source_index(int burst, int link) {
	if (burst == 4) return link == 0 ? 0 : (link == 1 ? 1 : 2);
	if (burst == 1) return link == 0 ? 0 : (link == 1 ? 5 : 1);
	if (burst == 3) return link == 0 ? 0 : (link == 1 ? 1 : 0);
	return link == 1 ? 1 : 0;
}

int target_index(int burst, int link) {
	if (burst == 4) return 6;
	if (burst == 0) return link == 0 ? 1 : (link == 1 ? 3 : 2);
	if (burst == 1) return link == 0 ? 5 : (link == 1 ? 1 : 4);
	if (burst == 2) return link == 0 ? 1 : (link == 1 ? 3 : 4);
	return link == 0 ? 2 : (link == 1 ? 5 : 1);
}

float pulse(float t, float start, float end) {
	return smoothstep(start, start + 0.002, t) * (1.0 - smoothstep(start + 0.008, end, t));
}

void vertex() {
	int link = int(INSTANCE_CUSTOM.r + 0.5);
	float t = death_age - BURST_TIME[burst_index] - float(link) * 0.003;
	// A short breakdown, a visible dark gap, then two weaker re-ignitions.
	float strike = pulse(t, 0.0, 0.031) + 0.72 * pulse(t, 0.044, 0.082) + 0.32 * pulse(t, 0.106, 0.132);
	float residual = contact_forks ? 0.16 * smoothstep(0.075, 0.095, t) * (1.0 - smoothstep(0.11, 0.18, t)) : 0.0;
	v_energy = (strike + residual) * (link == 2 ? 0.58 : 1.0);
	v_tail = smoothstep(0.075, 0.14, t);
	if (t < 0.0 || t > 0.18 || v_energy < 0.001) {
		VERTEX = vec3(0.0);
		v_energy = 0.0;
	} else {
		vec3 start = anchor(source_index(burst_index, link));
		vec3 end = anchor(target_index(burst_index, link));
		vec3 delta = end - start;
		float distance = max(length(delta), 0.001);
		vec3 forward = delta / distance;
		vec3 right = normalize(cross(abs(forward.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0), forward));
		vec3 up = cross(forward, right);
		// Re-strikes select a different spatial branch orientation in discrete
		// steps, with anchored endpoints. It never looks like rotating debris.
		float roll = INSTANCE_CUSTOM.g + floor(t * 41.0) * 2.04;
		mat2 turn = mat2(vec2(cos(roll), sin(roll)), vec2(-sin(roll), cos(roll)));
		vec3 local = VERTEX;
		if (contact_forks) {
			local *= 0.34;
			local.xy = turn * local.xy;
			VERTEX = end + right * local.x + up * local.y + forward * local.z;
			if (burst_index == 4) VERTEX.y = max(VERTEX.y, anchor_6.y + 0.002);
		} else {
			// Stretch only the authored centerline station. Tube cross sections
			// keep the fine core / sheath width at every attachment distance.
			float width = link == 2 ? 0.25 : 0.34;
			local.xy = turn * local.xy * width;
			local.z = (local.z - UV2.x) * width + UV2.x * distance;
			VERTEX = start + right * local.x + up * local.y + forward * local.z;
		}
	}
}

void fragment() {
	float hot = UV.y;
	vec3 cyan_sheath = vec3(0.06, 0.57, 0.84);
	vec3 white_core = vec3(0.74, 0.96, 1.0) * 1.9;
	float current = 0.90 + 0.10 * sin(UV.x * 93.0 - death_age * 117.0);
	float fragments = mix(1.0, smoothstep(0.38, 0.72, 0.5 + 0.5 * sin(UV.x * 67.0 + floor(death_age * 83.0))), v_tail);
	ALBEDO = mix(cyan_sheath, white_core, hot) * current;
	ALPHA = COLOR.a * mix(0.24, 0.98, hot) * v_energy * fragments;
}
