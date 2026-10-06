shader_type spatial;
uniform vec4 chip_color : source_color = vec4(0.22, 0.24, 0.22, 1.0);
instance uniform float death_opacity = 1.0;

void fragment() {
	// GeometryInstance3D.transparency is ignored by the Mobile renderer.
	float coverage = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	if (coverage > death_opacity) discard;
	ALBEDO = chip_color.rgb;
	ROUGHNESS = 1.0;
}
