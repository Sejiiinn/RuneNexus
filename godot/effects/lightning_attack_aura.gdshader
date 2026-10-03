shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

// A real spherical hull bounds a short world-space volume integral. Nothing
// faces the camera; the current's rear half is clipped by real opaque geometry.
// Ten samples only, no texture noise, lights, volume fog or compute dependency.
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float energy : hint_range(0.0, 2.0) = 1.0;
uniform float radius_world = 0.275;
uniform float event_age = 0.0;
uniform float seed_phase = 0.0;
uniform bool impact = false;
varying vec3 hull_world;
varying vec3 center_world;

void vertex() {
	hull_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	center_world = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	vec3 ray = normalize(hull_world - camera);
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		ray = -normalize(INV_VIEW_MATRIX[2].xyz);
		camera = hull_world - ray * dot(hull_world - camera, ray);
	}
	vec3 offset = camera - center_world;
	float b = dot(offset, ray);
	float c = dot(offset, offset) - radius_world * radius_world;
	float disc = max(0.0, b * b - c);
	float half_chord = sqrt(disc);
	float near_t = max(0.0, -b - half_chord);
	float far_t = -b + half_chord;
	float depth = texture(scene_depth, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ndc.z = depth * 2.0 - 1.0;
#endif
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	scene_view.xyz /= scene_view.w;
	vec3 opaque_world = (INV_VIEW_MATRIX * vec4(scene_view.xyz, 1.0)).xyz;
	far_t = min(far_t, dot(opaque_world - camera, ray));
	float step_length = max(0.0, far_t - near_t) / 10.0;
	float shell_sum = 0.0;
	float heart_sum = 0.0;
	for (int i = 0; i < 10; i++) {
		vec3 p = (camera + ray * (near_t + (float(i) + 0.5) * step_length) - center_world) / radius_world;
		// Low-amplitude 3D density variation preserves the approved soft round
		// boundary, without a hard sphere surface or latitude/longitude lines.
		float noise = sin(p.x * 8.2 + seed_phase) * sin(p.y * 7.1 + event_age * 2.0) * sin(p.z * 6.8 - seed_phase);
		float radial = length(p) + noise * 0.021;
		float shell = smoothstep(0.60, 0.85, radial) * (1.0 - smoothstep(0.85, 1.0, radial));
		shell_sum += shell * (0.82 + noise * 0.18);
		heart_sum += exp(-radial * radial * (impact ? 18.0 : 8.0));
	}
	float integral_scale = step_length / max(0.001, radius_world);
	float halo = shell_sum * integral_scale;
	float heart = heart_sum * integral_scale;
	vec3 violet = impact ? vec3(0.44, 0.35, 1.0) : vec3(0.38, 0.16, 0.95);
	ALBEDO = violet + vec3(0.65, 0.65, 0.85) * heart * (impact ? 1.4 : 0.08);
	ALPHA = energy * (halo * (impact ? 0.12 : 0.37) + heart * (impact ? 0.8 : 0.075));
}
