shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

// Authored solid hexagonal cylinder, never a billboard. Local transparent
// radiance only; normal scene depth and the authoritative game clock remain.
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float game_time = 0.0;
uniform float phase_offset = 0.0;
uniform float radius_world = 0.01;
uniform int layer = 0; // 0: thin solid core, 1: soft envelope, 2: compact endpoint.
varying vec3 world_position;
varying vec3 axis_start;
varying vec3 axis_end;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	axis_start = (MODEL_MATRIX * vec4(0.0, -0.5, 0.0, 1.0)).xyz;
	axis_end = (MODEL_MATRIX * vec4(0.0, 0.5, 0.0, 1.0)).xyz;
}

void fragment() {
	// Keep the same endpoints, but reach the brightest stage closer to firing.
	float energy = charge * charge * (3.0 - 2.0 * charge) * charge;
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	vec3 ray = normalize(world_position - camera);
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		// The game uses orthographic cameras: parallel rays, each with its
		// own origin on the camera plane. Perspective keeps the camera origin.
		ray = -normalize(INV_VIEW_MATRIX[2].xyz);
		camera = world_position - ray * dot(world_position - camera, ray);
	}
	vec3 axis = normalize(axis_end - axis_start);
	float length_world = length(axis_end - axis_start);
	vec3 offset = camera - axis_start;
	float coupling = dot(ray, axis);
	float along = (dot(axis, offset) - coupling * dot(ray, offset)) / max(0.00001, 1.0 - coupling * coupling);
	along = clamp(along, 0.0, length_world);
	vec3 on_axis = axis_start + axis * along;
	float ray_distance = max(0.0, dot(on_axis - camera, ray));
	float radial = length(camera + ray * ray_distance - on_axis) / radius_world;
	float envelope = exp(-4.8 * radial * radial);
	float glints = 0.0;
	float separated_glints = 0.0;
	vec3 side = cross(axis, vec3(0.0, 1.0, 0.0));
	if (length(side) < 0.001) { side = cross(axis, vec3(1.0, 0.0, 0.0)); }
	side = normalize(side);
	for (int i = 0; i < 3; i++) {
		float seed = float(i) * 2.17 + phase_offset;
		float station = (0.20 + float(i) * 0.29 + 0.025 * sin(game_time * 1.6 + seed)) * length_world;
		float local_spot = (along - station) / 0.014;
		float pulse = pow(0.5 + 0.5 * sin(game_time * 3.2 + seed), 6.0);
		glints += exp(-local_spot * local_spot) * pulse;
		// Tiny world-space points beside the core, not a brightening of the
		// same center pixels. The fixed authored envelope contains all three.
		float side_offset = i == 1 ? -0.018 : 0.018;
		vec3 glint_center = axis_start + axis * station + side * side_offset;
		float closest_glint = max(0.0, dot(glint_center - camera, ray));
		float glint_distance = length(camera + ray * closest_glint - glint_center) / 0.016;
		separated_glints += exp(-4.0 * glint_distance * glint_distance) * pulse;
	}
	vec3 cyan = vec3(0.045, 0.62, 0.84);
	vec3 white_cyan = vec3(0.72, 0.96, 1.0);
	vec3 color = mix(cyan, white_cyan, energy * energy);
	if (layer == 0) {
		float flow = 0.96 + 0.04 * sin(along * 16.0 - game_time * 4.0 + phase_offset);
		ALBEDO = color * (0.26 + 1.75 * energy + glints * 0.35) * flow;
		ALPHA = 0.22 + 0.78 * energy;
	} else if (layer == 1) {
		float ends = smoothstep(0.0, 0.08, along) * smoothstep(0.0, 0.08, length_world - along);
		ALBEDO = cyan * (0.40 + 0.95 * energy) + white_cyan * separated_glints * 2.2;
		ALPHA = ends * (envelope * (0.022 + 0.20 * energy) + separated_glints * (0.18 + 0.18 * energy));
	} else {
		vec3 center = (axis_start + axis_end) * 0.5;
		float closest = max(0.0, dot(center - camera, ray));
		float distance_center = length(camera + ray * closest - center) / radius_world;
		float halo = exp(-5.0 * distance_center * distance_center);
		float pinpoint = exp(-36.0 * distance_center * distance_center);
		ALBEDO = cyan * 1.2 + white_cyan * pinpoint * (0.7 + 2.6 * energy);
		ALPHA = halo * (0.025 + 0.17 * energy) + pinpoint * (0.04 + 0.43 * energy);
	}
}
