shader_type spatial;
render_mode unshaded;

uniform float battle_time = 0.0;
uniform float alert : hint_range(0.0, 1.0) = 0.0;

varying vec2 surface_position;

void vertex() {
	// 원본 오목한 메시의 로컬 반경: 타일 위치·회전과 독립.
	surface_position = VERTEX.xz / 0.305;
}

void fragment() {
	float radius = length(surface_position);
	float angle = atan(surface_position.y, surface_position.x);
	float phase = angle * 3.0 + radius * 12.0 - battle_time * 1.8;
	float ribbons = pow(max(0.0, sin(phase + sin(radius * 15.0 - battle_time) * 0.35)), 5.0);
	float inner_fade = smoothstep(0.10, 0.50, radius);
	float edge_fade = 1.0 - smoothstep(0.86, 1.0, radius);
	float ring = exp(-pow((radius - 0.92) * 24.0, 2.0));
	float energy = ribbons * inner_fade * edge_fade + ring * 0.62;
	vec3 depth = mix(vec3(0.008, 0.002, 0.020), vec3(0.060, 0.012, 0.130), clamp(radius, 0.0, 1.0));
	// 불투명 바닥과 어두운 중심: 투명 정렬·추가 광원 없이 깊이 유지.
	ALBEDO = depth + vec3(0.34, 0.085, 0.72) * energy;
	EMISSION = vec3(0.36, 0.11, 0.76) * energy * (0.65 + alert * 0.5);
}
