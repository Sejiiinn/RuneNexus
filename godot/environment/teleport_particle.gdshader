shader_type spatial;
render_mode cull_disabled;

uniform float battle_time = 0.0;
uniform bool outflow = false;
uniform vec3 flow_color = vec3(0.006, 0.19, 1.0);

void vertex() {
	float t = fract(battle_time / 4.0 + INSTANCE_CUSTOM.g);
	float q = 0.055 + 0.9 * (outflow ? t : 1.0 - t);
	float angle = INSTANCE_CUSTOM.r * 6.28318530718 / 3.0 + (outflow ? 3.0 : 13.0 / 3.0) * q;
	float radius = 0.428 * q;
	float height = outflow ? 0.014 + 0.028 * pow(1.0 - q, 1.6) : 0.003 - 0.088 * pow(1.0 - q, 2.0);
	float fade = max(0.001, min(min(t / 0.09, (1.0 - t) / 0.09), 1.0));
	VERTEX *= vec3(fade, fade * 0.52, fade);
	VERTEX += vec3(radius * cos(angle), height, -radius * sin(angle));
}

void fragment() {
	ALBEDO = flow_color * 0.15;
	EMISSION = flow_color * 5.0;
}
