shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 card_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 clip_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 card_size = vec2(90.0, 220.0);
uniform float angle = 0.0;

void fragment() {
	vec2 p = ((SCREEN_UV - card_rect.xy) / card_rect.zw - 0.5) * 2.0;
	float cosine = cos(angle);
	float c = abs(cosine);
	// Upright coordinates on the revealed side reverse X and depth together.
	float depth = sin(angle) * (cosine < 0.0 ? -1.0 : 1.0) * 0.085;
	float fit = 1.0 - abs(depth);
	// Inverse perspective of a Y-rotating plane, fitted inside its original slot.
	float denominator = max(fit * c - p.x * depth, 0.0001);
	vec2 face = vec2(p.x / denominator, 0.0);
	face.y = p.y * (1.0 + depth * face.x) / fit;
	vec2 uv = face * 0.5 + 0.5;
	vec4 color = vec4(0.0);
	bool inside = abs(face.x) <= 1.0 && abs(face.y) <= 1.0;
	if (inside && c > 0.012) {
		// The source changes at 90 degrees. Upright UVs prevent mirrored text
		// while the newly revealed side finishes the same half turn.
		color = textureLod(screen_texture, card_rect.xy + uv * card_rect.zw, 0.0);
		if (color.a > 0.0001) { color.rgb /= color.a; }
		color.rgb *= 0.70 + 0.30 * sqrt(c);
		// A subtle bevel catches light on the near vertical edge.
		float side = smoothstep(0.92, 1.0, abs(face.x)) * abs(sin(angle));
		color.rgb += vec3(0.15, 0.23, 0.23) * side;
	}
	// Thin stock marks the single edge-on crossing inside the original slot.
	float edge_on = 1.0 - smoothstep(0.012, 0.05, c);
	float stock = (1.0 - smoothstep(0.7, 1.5, abs(p.x) * card_size.x * 0.5)) * step(abs(p.y), 0.99) * edge_on;
	color = mix(color, vec4(0.27, 0.44, 0.46, 1.0), stock);
	if (SCREEN_UV.x < clip_rect.x || SCREEN_UV.y < clip_rect.y || SCREEN_UV.x > clip_rect.x + clip_rect.z || SCREEN_UV.y > clip_rect.y + clip_rect.w) { color = vec4(0.0); }
	COLOR = color;
}
