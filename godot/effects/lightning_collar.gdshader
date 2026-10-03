shader_type spatial;
render_mode cull_back;
uniform vec4 base_color : source_color = vec4(.3,.15,.6,1.0);
uniform vec4 emission_color : source_color = vec4(.3,.15,.6,1.0);
uniform float metallic = .0;
uniform float roughness = .4;
uniform float charge : hint_range(0.0,1.0) = 0.0;
varying float longitudinal;
void vertex() { longitudinal = VERTEX.z; }
void fragment() {
	// Three authored stations, back to front. Geometry and base PBR stay intact.
	float station = clamp(floor((longitudinal + .1985) / .193), 0.0, 2.0);
	float level = smoothstep(.10 + station * .21, .36 + station * .21, charge);
	ALBEDO = base_color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = emission_color.rgb * (.18 + 2.7 * level);
}
