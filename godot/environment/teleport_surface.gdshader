shader_type spatial;
render_mode cull_disabled;

uniform float battle_time = 0.0;
uniform bool outflow = false;
uniform vec3 flow_color = vec3(0.006, 0.19, 1.0);
varying vec3 local_point;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(cell), hash3(cell + vec3(1,0,0)), f.x),
		mix(hash3(cell + vec3(0,1,0)), hash3(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(cell + vec3(0,0,1)), hash3(cell + vec3(1,0,1)), f.x),
		mix(hash3(cell + vec3(0,1,1)), hash3(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

float turbulence(vec3 p) {
	float total = 0.0;
	float weight = 0.0;
	float amplitude = 1.0;
	for (int i = 0; i < 5; i++) {
		total += value_noise(p) * amplitude;
		weight += amplitude;
		p *= 2.0;
		amplitude *= 0.7;
	}
	return total / weight;
}

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	// Same authored polar field on the actual exported bowl/dome. Blender Z-up
	// becomes Godot Y-up; this preserves the approved winding and radial flow.
	float radius = length(local_point.xz) / 0.434;
	float angle = atan(-local_point.z, local_point.x);
	float normalized_height = outflow ? (local_point.y - 0.002) / 0.025 : (local_point.y + 0.096982) / 0.091982;
	vec3 generated = vec3(local_point.x / 0.868 + 0.5, -local_point.z / 0.868 + 0.5, normalized_height);
	float noise = turbulence(generated * 5.0);
	float twist = outflow ? 9.0 : 13.0;
	float spiral = angle * 3.0 - radius * twist + (noise - 0.5) * 0.9;
	float exponent = outflow ? 6.0 - radius * 3.0 : 2.0 + radius * 3.0;
	float arms = pow((cos(spiral) + 1.0) * 0.5, max(exponent, 0.5));
	float fine = pow((cos(spiral * 4.0 + noise * 6.0) + 1.0) * 0.5, 3.0);
	float clock = battle_time / 4.0 * 18.84955592 * (outflow ? 1.0 : -1.0);
	float pulse = sin(radius * 18.84955592 - clock) * 0.38 + 0.62;
	float radial = outflow ? pow(radius, 1.5) * 0.85 + 0.15 : min(radius * 7.0, 1.0) * (1.0 - radius * 0.42);
	float visible = arms * pulse * radial * (0.72 + fine * 0.28);
	visible *= clamp((1.09 - radius) * 7.0, 0.0, 1.0);
	if (outflow) visible += exp(-radius * 23.0) * 1.1;
	vec3 dark = flow_color * vec3(0.015, 0.015, 0.03);
	vec3 middle = flow_color * vec3(0.09, 0.09, 0.16);
	vec3 color = visible < 0.3 ? mix(dark, middle, clamp(visible / 0.3, 0.0, 1.0))
		: mix(middle, flow_color * 1.35, clamp((visible - 0.3) / 0.5, 0.0, 1.0));
	ALBEDO = vec3(0.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = color * 2.4;
}
