shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// 색상 텍스처가 아닌 RGBA8 물리량. 공간 선형 보간, 시간 블록 경계 반복 금지.
uniform sampler3D u_field : filter_linear, repeat_disable;
uniform sampler2D u_scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform mat4 u_view_to_local;
uniform vec3 u_field_frame_0;
uniform vec3 u_field_frame_1;
uniform vec3 u_field_uv_scale;
uniform vec3 u_field_min = vec3(-2.35, 0.0, -2.35);
uniform vec3 u_field_extent = vec3(4.7, 2.9, 4.7);
uniform float u_field_mix = 0.0;
uniform float u_density_scale = 64.0;
uniform float u_emission_scale = 32.0;
uniform float u_age = 0.0;
uniform float u_progress = 1.0;
uniform float u_angle = 0.0;
uniform bool u_orthographic = true;
uniform bool u_camera_inside = false;
uniform vec3 u_camera_local;
uniform vec3 u_ray_direction = vec3(0.0, -1.0, 0.0);
uniform vec3 u_light_direction = vec3(-0.70, 0.45, 0.55);

varying vec3 volume_position;
const vec3 HALF_EXTENT = vec3(2.35, 1.45, 2.35);


void vertex() {
	volume_position = VERTEX;
}


float hash_3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}


vec3 sample_field(vec3 p) {
	float c = cos(u_angle);
	float s = sin(u_angle);
	// 원본 GLSL mat2의 열 우선 회전 순서.
	vec3 q = vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
	vec3 uvw = (q - u_field_min) / u_field_extent;
	if (any(lessThan(uvw, vec3(0.0))) || any(greaterThan(uvw, vec3(1.0)))) {
		return vec3(0.0);
	}
	vec4 cached = mix(
		texture(u_field, u_field_frame_0 + uvw * u_field_uv_scale),
		texture(u_field, u_field_frame_1 + uvw * u_field_uv_scale), u_field_mix
	);
	float density = dot(cached.rg, vec2(256.0 / 257.0, 1.0 / 257.0)) * u_density_scale;
	float emission = cached.b * u_emission_scale;
	if (u_age < 0.055) {
		float flash = max(0.0, 1.0 - length(p - vec3(0.0, 0.07, 0.0)) / 0.085)
			* (1.0 - smoothstep(0.008, 0.055, u_age));
		density += flash * 5.0;
		emission += flash * 35.0;
	}
	return vec3(density, emission, cached.a);
}


void fragment() {
	if (u_progress >= 1.0) {
		discard;
	}
	// 외부는 입구면, 내부는 출구면만 적분. 양면을 두 번 적분하지 않음.
	if ((!u_camera_inside && !FRONT_FACING) || (u_camera_inside && FRONT_FACING)) {
		discard;
	}
	// CPU에서 박스의 역전역변환 적용. Godot의 view-space VERTEX와 혼용하지 않음.
	vec3 direction = u_orthographic ? normalize(u_ray_direction)
		: normalize(volume_position - u_camera_local);
	vec3 origin = u_orthographic ? volume_position - direction * 4.0 : u_camera_local;
	vec3 safe_direction = sign(direction) * max(abs(direction), vec3(0.00001));
	if (safe_direction.x == 0.0) { safe_direction.x = 0.00001; }
	if (safe_direction.y == 0.0) { safe_direction.y = 0.00001; }
	if (safe_direction.z == 0.0) { safe_direction.z = 0.00001; }
	vec3 a = (-vec3(1.0) - origin) / safe_direction;
	vec3 b = (vec3(1.0) - origin) / safe_direction;
	vec3 near_plane = min(a, b);
	vec3 far_plane = max(a, b);
	float begin = max(0.0, max(near_plane.x, max(near_plane.y, near_plane.z)));
	float end = min(far_plane.x, min(far_plane.y, far_plane.z));
	// 박스 입구의 깊이 검사만으로는 안쪽 지형·적 뒤의 연기까지 합성된다.
	// 한 번 읽은 불투명 장면 깊이에서 적분을 끝내 착탄이 돌 표면에 맞물리게 한다.
	float scene_depth = texture(u_scene_depth, SCREEN_UV).r;
	vec3 scene_ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	scene_ndc.z = scene_depth * 2.0 - 1.0;
#endif
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(scene_ndc, 1.0);
	vec3 scene_local = (u_view_to_local * vec4(scene_view.xyz / scene_view.w, 1.0)).xyz;
	end = min(end, dot(scene_local - origin, direction));
	if (end <= begin) {
		discard;
	}
	float step_size = (end - begin) / 32.0;
	float metric_step = length(direction * HALF_EXTENT) * step_size;
	float jitter = hash_3(vec3(FRAGCOORD.xy, 17.0));
	vec3 radiance = vec3(0.0);
	float transmission = 1.0;
	vec3 light_direction = normalize(u_light_direction);
	float illumination = 0.5;
	int shadow_step = -4;
	for (int i = 0; i < 32; i++) {
		vec3 local = origin + direction * (begin + (float(i) + jitter) * step_size);
		vec3 p = local * HALF_EXTENT + vec3(0.0, HALF_EXTENT.y, 0.0);
		if (p.y < 0.012) {
			continue;
		}
		vec3 sample_value = sample_field(p);
		float density = sample_value.x;
		if (density < 0.005) {
			continue;
		}
		if (i - shadow_step >= 4) {
			shadow_step = i;
			float shadow_density = sample_field(p + light_direction * 0.24).x;
			illumination = 0.10 + 1.15 * exp(-shadow_density * 0.63);
		}
		vec3 ash = mix(vec3(0.068, 0.048, 0.030), vec3(0.053, 0.050, 0.044),
			smoothstep(0.25, 0.9, p.y));
		ash *= mix(0.60, 1.35, sample_value.z);
		vec3 flame = mix(vec3(1.0, 0.018, 0.0003), vec3(1.0, 0.15, 0.006), sample_value.z);
		vec3 source = ash * illumination + flame * sample_value.y / max(density, 0.001);
		float opacity = 1.0 - exp(-density * metric_step);
		radiance += transmission * opacity * source;
		transmission *= 1.0 - opacity;
		if (transmission < 0.015) {
			break;
		}
	}
	float alpha = 1.0 - transmission;
	if (alpha < 0.003) {
		discard;
	}
	// HDR 선형값을 Godot 환경의 톤 매핑으로 전달. 색 공간 변환의 중복 적용 방지.
	ALBEDO = radiance / max(alpha, 0.001);
	ALPHA = alpha;
}
