shader_type spatial;
instance uniform float charge = 1.0;
instance uniform vec4 height_plane = vec4(0.0, 1.0, 0.0, 0.0);
varying float height;
void vertex() { height = dot(height_plane, vec4(VERTEX, 1.0)); }
void fragment() {
 float level = smoothstep(height - .022, height + .012, mix(.055, .39, charge));
 ALBEDO = mix(vec3(.015,.055,.07), vec3(.025,.24,.30), level);
 METALLIC = .72; ROUGHNESS = .29;
 EMISSION = vec3(.02,.65,.85) * level * 2.6;
}
