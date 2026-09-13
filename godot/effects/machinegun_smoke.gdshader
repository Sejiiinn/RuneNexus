shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler3D u_noise : filter_linear, repeat_disable;
uniform sampler2D u_scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform mat4 u_view_to_local;
uniform float u_progress = 1.0;
uniform float u_seed = 0.0;
uniform vec3 u_ray_direction = vec3(0.0, -1.0, 0.0);
uniform vec3 u_camera_local;
uniform bool u_orthographic = true;
uniform bool u_camera_inside = false;
varying vec3 volume_position;

void vertex() {
	volume_position = VERTEX;
}

void fragment() {
	if (u_progress >= 1.0 || (!u_camera_inside && !FRONT_FACING) || (u_camera_inside && FRONT_FACING)) {
		discard;
	}
	vec3 direction = normalize(u_orthographic ? u_ray_direction : volume_position - u_camera_local);
	vec3 origin = u_camera_inside ? u_camera_local : volume_position;
	vec3 inverse_direction = 1.0 / (sign(direction + vec3(0.00001)) * max(abs(direction), vec3(0.00001)));
	vec3 a = (-vec3(0.5) - origin) * inverse_direction;
	vec3 b = (vec3(0.5) - origin) * inverse_direction;
	vec3 exits = max(a, b);
	float ray_length = max(0.0, min(exits.x, min(exits.y, exits.z)));
	// 포신·적·돌 뒤쪽의 체적을 적분하지 않는다. 추가 표본은 픽셀당 깊이 한 번.
	float scene_depth = texture(u_scene_depth, SCREEN_UV).r;
	vec3 scene_ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	scene_ndc.z = scene_depth * 2.0 - 1.0;
#endif
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(scene_ndc, 1.0);
	vec3 scene_local = (u_view_to_local * vec4(scene_view.xyz / scene_view.w, 1.0)).xyz;
	ray_length = min(ray_length, dot(scene_local - origin, direction));
	if (ray_length <= 0.0) {
		discard;
	}
	float step_size = ray_length / 16.0;
	float opacity = 0.0;
	vec3 color = vec3(0.0);
	for (int index = 0; index < 16; index++) {
		vec3 p = origin + direction * (float(index) + 0.5) * step_size;
		vec3 uvw = p + vec3(0.5);
		// 비대칭으로 풀리는 가는 제트. 베이크 잡음은 시간에 따라 조금씩 이동.
		vec3 warp = vec3(sin(u_seed), cos(u_seed * 1.7), sin(u_seed * 0.6)) * 0.06;
		vec3 noise_uv = clamp(uvw * 0.77 + vec3(0.11, -u_progress * 0.10, u_progress * 0.08) + warp, vec3(0.01), vec3(0.99));
		float turbulence = texture(u_noise, noise_uv).r;
		float shape = 1.0 - smoothstep(0.20, 0.50, length(p.xy * vec2(1.0, 1.08)));
		shape *= smoothstep(0.0, 0.16, uvw.z) * (1.0 - smoothstep(0.42, 1.0, uvw.z));
		float density = shape * smoothstep(0.31, 0.67, turbulence) * (1.0 - u_progress) * 9.0;
		float alpha = 1.0 - exp(-density * step_size);
		vec3 lit_smoke = mix(vec3(0.18, 0.22, 0.27), vec3(0.61, 0.66, 0.70), uvw.y * 0.65 + turbulence * 0.35);
		lit_smoke += vec3(0.30, 0.12, 0.018) * max(0.0, 1.0 - u_progress * 7.0) * (1.0 - uvw.z);
		color += (1.0 - opacity) * alpha * lit_smoke;
		opacity += (1.0 - opacity) * alpha;
	}
	ALBEDO = color / max(opacity, 0.0001);
	ALPHA = opacity;
}
