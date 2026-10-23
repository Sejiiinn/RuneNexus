shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

// Enemy burn anchors and particle timing, drawn as slow toxic-green bubbles instead of
// flame frames. Same combat clock (no engine TIME) and same skinned inputs.
uniform sampler2D particle_data : filter_nearest, repeat_disable;
uniform float burn_time = 0.0;
uniform bool skinned_status = false;
uniform float coordinate_scale = 1.0;
uniform vec3 bubble_color : source_color = vec3(0.22, 0.78, 0.32);
instance uniform float phase_offset = 0.0;
instance uniform bool world_up_motion = false;
varying float life;

void vertex() {
	int row = int(skinned_status ? CUSTOM0.x : INSTANCE_CUSTOM.x);
	vec4 motion = texelFetch(particle_data, ivec2(0, row), 0);
	vec4 shape = texelFetch(particle_data, ivec2(1, row), 0);
	float clock = (burn_time + phase_offset) * 0.55;
	float age = fract((clock + motion.y) / motion.x);
	life = pow(max(0.0, sin(3.14159265359 * age)), 0.8);
	float seed = shape.y;
	vec3 offset = vec3(0.6 * motion.w * age + 0.02 * sin(age * 6.0 + seed),
		0.55 * shape.x * age, -0.015 * sin(age * 4.0 + seed));
	vec3 center = (MODELVIEW_MATRIX * vec4(skinned_status ? VERTEX + offset / coordinate_scale : offset, 1.0)).xyz;
	if (world_up_motion) {
		center = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz
			+ (VIEW_MATRIX * vec4(offset * length(MODEL_MATRIX[0].xyz), 0.0)).xyz;
	}
	float body_scale = length(MODEL_MATRIX[0].xyz) / (skinned_status ? coordinate_scale : 1.0);
	// Bubbles swell slightly as they rise, then pop at the end of life.
	vec2 quad = (skinned_status ? UV2 : VERTEX.xy) * motion.z * (0.42 + 0.25 * age) * body_scale;
	VERTEX = center + vec3(quad, 0.0);
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float disc = 1.0 - smoothstep(0.82, 1.0, d);
	float rim = smoothstep(0.5, 0.92, d);
	float glint = 1.0 - smoothstep(0.0, 0.22, length(UV - vec2(0.36, 0.32)));
	ALBEDO = mix(bubble_color, vec3(0.75, 1.0, 0.8), glint * 0.8);
	ALPHA = disc * (0.28 + 0.62 * rim + 0.6 * glint) * life;
}
