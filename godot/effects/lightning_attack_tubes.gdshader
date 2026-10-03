shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

// UV2.x is the authored centerline station. Stretching only that station
// preserves the actual 3D tube radius at changing world-space endpoints.
uniform float beam_length = 1.0;
uniform float energy : hint_range(0.0, 2.0) = 1.0;
uniform float event_age = 0.0;
uniform float seed_phase = 0.0;

void vertex() {
	VERTEX.z += UV2.x * (beam_length - 1.0);
}

void fragment() {
	float hot_core = UV.y;
	float current = 0.94 + 0.06 * sin(UV.x * 91.0 - event_age * 52.0 + seed_phase);
	ALBEDO = COLOR.rgb * mix(1.0, 1.9, hot_core) * current;
	ALPHA = COLOR.a * energy;
}
