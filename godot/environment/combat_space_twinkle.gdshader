shader_type canvas_item;
render_mode unshaded;
uniform vec3 nebula_tint = vec3(0.38, 0.83, 1.0);

float stable_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 luma_weights = vec3(0.2126, 0.7152, 0.0722);
	float luminance = dot(base.rgb, luma_weights);
	// 중앙 우주는 보호하고 외곽의 낮은 밝기 성운만 색을 바꾼다.
	// 주변보다 밝은 별점/별의 밝은 중심은 원본의 차가운 흰빛을 유지한다.
	vec2 offset = TEXTURE_PIXEL_SIZE * 3.0;
	float nearby = dot((texture(TEXTURE, UV + vec2(offset.x, 0.0)).rgb
		+ texture(TEXTURE, UV - vec2(offset.x, 0.0)).rgb
		+ texture(TEXTURE, UV + vec2(0.0, offset.y)).rgb
		+ texture(TEXTURE, UV - vec2(0.0, offset.y)).rgb) * 0.25, luma_weights);
	float star_protection = max(smoothstep(0.10, 0.20, luminance),
		smoothstep(0.012, 0.050, luminance - nearby));
	float outer_nebula = smoothstep(0.12, 0.35, abs(UV.x - 0.5));
	vec3 tinted_nebula = luminance * nebula_tint / dot(nebula_tint, luma_weights);
	vec3 chapter_color = mix(base.rgb, tinted_nebula,
		0.68 * outer_nebula * (1.0 - star_protection));
	// 원본의 밝은 별만 선택. 짙은 우주·옅은 성운은 그대로 두고
	// 일부 별만 각각 다른 7~14초 주기와 위상으로 최대 22% 어두워진다.
	vec2 cell = floor(UV * vec2(83.0, 137.0));
	float seed = stable_hash(cell);
	float selected = step(0.76, seed);
	float star = smoothstep(0.48, 0.72, luminance) * selected;
	float period = mix(7.0, 14.0, stable_hash(cell + vec2(17.0, 31.0)));
	float pulse = 0.5 + 0.5 * sin(TIME * 6.2831853 / period + seed * 6.2831853);
	COLOR = vec4(chapter_color * (1.0 - 0.22 * star * pulse), base.a);
}
