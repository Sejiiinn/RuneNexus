shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 glass_emission : source_color = vec4(0.0);
uniform float emission_energy = 1.0;
uniform float surface_roughness = 0.055;
uniform float surface_metallic = 0.0;
uniform float transmission_factor = 0.8;
uniform float index_of_refraction = 1.46;

varying float crystal_height;

void vertex() {
	crystal_height = VERTEX.y;
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	float facing = clamp(dot(normal, view), 0.0, 1.0);
	float reflectance = pow((index_of_refraction - 1.0) / (index_of_refraction + 1.0), 2.0);
	float fresnel = reflectance + (1.0 - reflectance) * pow(1.0 - facing, 5.0);
	// 뾰족한 끝은 얇고 몸통은 두꺼운 결정의 광학 경로 근사.
	float cross_section = clamp(1.0 - pow(crystal_height / 0.42, 2.0), 0.0, 1.0);
	float thickness = clamp(0.24 * cross_section / max(facing, 0.35), 0.025, 0.38);
	vec3 ray = refract(-view, normal, 1.0 / index_of_refraction);
	vec4 projected = PROJECTION_MATRIX * vec4(VERTEX + ray * thickness, 1.0);
	vec2 refraction_uv = clamp(projected.xy / projected.w * 0.5 + 0.5, vec2(0.001), vec2(0.999));
	float depth = texture(scene_depth, refraction_uv).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(refraction_uv * 2.0 - 1.0, depth, 1.0);
	// 앞쪽 물체를 결정 안으로 끌어들이지 않는 깊이 검증.
	if (behind.z / behind.w > VERTEX.z - 0.002) {
		refraction_uv = SCREEN_UV;
	}
	vec3 transmission = texture(scene_color, refraction_uv).rgb;
	vec3 tint = COLOR.rgb * base_color.rgb;
	// 원본 면색에 따른 두께별 흡수. 임의의 청록 보정·모서리 발광 없음.
	vec3 absorption = pow(max(tint, vec3(0.001)), vec3(thickness / 0.24));
	ALBEDO = tint * (1.0 - transmission_factor);
	METALLIC = surface_metallic;
	ROUGHNESS = surface_roughness;
	SPECULAR = reflectance / 0.08;
	EMISSION = transmission * absorption * transmission_factor * (1.0 - fresnel)
		+ glass_emission.rgb * emission_energy;
	ALPHA = 1.0;
}
