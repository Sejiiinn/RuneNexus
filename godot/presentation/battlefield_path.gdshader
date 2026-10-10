shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float battle_time = 0.0;
uniform float pulse_count = 1.0;

void fragment() {
	// Original guide: 0.13 glow / 0.05 line, 1.32 spacing, 0.36 pulses.
	float lateral = abs(UV.y);
	// Keep the moving pulses distinct with a quieter static guide underneath.
	float glow = 0.025 * exp(-pow(lateral / 0.055, 2.0));
	float line = 0.065 * (1.0 - smoothstep(0.023, 0.027, lateral));
	float phase = battle_time * 0.42;
	float moving_distance = UV.x - phase * 1.32;
	float wrapped = mod(moving_distance, 1.32);
	float pulse_distance = min(wrapped, 1.32 - wrapped);
	float dash = 1.0 - smoothstep(0.16, 0.18, pulse_distance);
	float pulse_index = floor(moving_distance / 1.32 + 0.5);
	float wave = sin((pulse_index / pulse_count + phase) * 6.283185);
	float pulse_alpha = 0.07 + (wave + 1.0) * 0.025;
	float pulse = pulse_alpha * dash * (1.0 - smoothstep(0.0305, 0.0545, lateral));
	float core = pulse_alpha * 0.35 * dash * (1.0 - smoothstep(0.013, 0.017, lateral));
	float alpha = glow + line + pulse + core;
	// Per-vertex origin tint keeps one shared shader/material for both portals.
	vec3 glow_color = COLOR.rgb;
	vec3 line_color = mix(COLOR.rgb, vec3(1.0), 0.62);
	vec3 pulse_color = mix(COLOR.rgb, vec3(1.0), 0.34);
	ALBEDO = (glow_color * glow + line_color * line + pulse_color * pulse + vec3(core)) / max(alpha, 0.00001);
	ALPHA = alpha;
}
