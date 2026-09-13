shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler3D u_noise : filter_linear, repeat_disable;
uniform sampler2D u_scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform mat4 u_view_to_local;
uniform float u_opacity = 0.0;
uniform float u_time = 0.0;
uniform vec3 u_ray_direction = vec3(0.0, -1.0, 0.0);
uniform vec3 u_camera_local;
uniform bool u_orthographic = true;
uniform bool u_camera_inside = false;
varying vec3 volume_position;

void vertex() {
	volume_position = VERTEX;
}

void fragment() {
	if (u_opacity <= 0.0 || (!u_camera_inside && !FRONT_FACING) || (u_camera_inside && FRONT_FACING)) {
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
		// +Z는 철구 뒤 표면. 화염은 앞 절반, 연기는 뒤쪽에서 짧게 풀린다.
		vec3 noise_uv = clamp(uvw * 0.76 + vec3(0.11 + sin(u_time * 9.0) * 0.025, 0.12, 0.12 + sin(u_time * 7.0) * 0.035), vec3(0.01), vec3(0.99));
		float turbulence = texture(u_noise, noise_uv).r;
		float radial = length(p.xy + vec2(sin(uvw.z * 10.0 + u_time * 13.0), cos(uvw.z * 8.0 - u_time * 9.0)) * 0.035);
		float envelope = (1.0 - smoothstep(0.24, 0.49, radial)) * smoothstep(0.0, 0.20, uvw.z);
		float flame = smoothstep(0.34, 0.90, uvw.z) * (1.0 - smoothstep(0.06, 0.25, radial)) * smoothstep(0.34, 0.70, turbulence);
		float smoke = envelope * smoothstep(0.27, 0.66, turbulence) * (1.0 - smoothstep(0.60, 1.0, uvw.z));
		float density = (smoke * 6.0 + flame * 10.0) * u_opacity;
		float alpha = 1.0 - exp(-density * step_size);
		vec3 grey = mix(vec3(0.13, 0.15, 0.17), vec3(0.43, 0.45, 0.47), uvw.y * 0.70 + turbulence * 0.30);
		vec3 fire = mix(vec3(1.0, 0.16, 0.008), vec3(1.0, 0.62, 0.05), turbulence);
		vec3 lit_smoke = mix(grey, fire, clamp(flame * 4.0, 0.0, 1.0));
		color += (1.0 - opacity) * alpha * lit_smoke;
		opacity += (1.0 - opacity) * alpha;
	}
	ALBEDO = color / max(opacity, 0.0001);
	ALPHA = opacity;
}
