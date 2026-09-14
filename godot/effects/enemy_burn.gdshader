shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

// All enemies share one clock and one baked Blender texture. No engine TIME:
// combat pause, speed and seek are authoritative, exactly as impact GPU motion.
uniform sampler2D flame_atlas : source_color, filter_linear, repeat_disable;
uniform sampler2D particle_data : filter_nearest, repeat_disable;
uniform float burn_time = 0.0;
uniform float intensity = 1.0;
instance uniform float phase_offset = 0.0;
varying float atlas_frame;

void vertex() {
	int row = int(INSTANCE_CUSTOM.x);
	vec4 motion = texelFetch(particle_data, ivec2(0, row), 0);
	vec4 shape = texelFetch(particle_data, ivec2(1, row), 0);
	float clock = burn_time + phase_offset;
	float age = fract((clock + motion.y) / motion.x);
	float life = pow(max(0.0, sin(3.14159265359 * age)), 0.65);
	float seed = shape.y;
	// Original Blender V3 coordinates converted from Z-up to Godot Y-up.
	vec3 offset = vec3(motion.w * age + 0.024 * sin(age * 7.0 + seed),
		shape.x * age, -0.018 * sin(age * 5.0 + seed));
	vec3 center = (MODELVIEW_MATRIX * vec4(offset, 1.0)).xyz;
	float body_scale = length(MODEL_MATRIX[0].xyz);
	vec2 scale = vec2(1.0 - 0.35 * age, 1.0 + 0.55 * age);
	// 1.25 includes the atlas padding around the source volume carrier.
	vec2 quad = VERTEX.xy * motion.z * life * scale * 1.25 * body_scale;
	float angle = 0.20 * sin(seed + age * 5.0);
	quad = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * quad;
	VERTEX = center + vec3(quad, 0.0);
	atlas_frame = mod(clock * 8.0 + seed * 0.731, 16.0);
}

vec3 flame_sample(float frame, vec2 base_uv) {
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0));
	// Half-pixel inset avoids sampling the adjacent tile at the boundary.
	vec2 uv = (cell * 128.0 + vec2(0.5) + base_uv * 127.0) / 512.0;
	return texture(flame_atlas, uv).rgb;
}

void fragment() {
	vec3 fire = mix(flame_sample(floor(atlas_frame), UV),
		flame_sample(mod(floor(atlas_frame) + 1.0, 16.0), UV), fract(atlas_frame));
	ALBEDO = fire * intensity;
	ALPHA = 1.0;
}
