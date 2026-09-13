shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D face_palette : filter_nearest, repeat_disable;
varying flat float variant;

void vertex() {
	variant = INSTANCE_CUSTOM.x;
	// Rotate only the two hexagonal rings. The broken tip remains off center.
	if (UV.y < 0.5) {
		float x = VERTEX.x;
		float z = VERTEX.z;
		VERTEX.x = INSTANCE_CUSTOM.y * x + INSTANCE_CUSTOM.z * z / 0.68;
		VERTEX.z = -0.68 * INSTANCE_CUSTOM.z * x + INSTANCE_CUSTOM.y * z;
	}
	float nx = NORMAL.x;
	float nz = NORMAL.z;
	NORMAL.x = INSTANCE_CUSTOM.y * nx + 0.68 * INSTANCE_CUSTOM.z * nz;
	NORMAL.z = -INSTANCE_CUSTOM.z * nx / 0.68 + INSTANCE_CUSTOM.y * nz;
	NORMAL = normalize(NORMAL);
}

void fragment() {
	vec4 surface = texture(face_palette, vec2((floor(UV.x * 13.0 + 0.1) + 0.5) / 13.0, (variant + 0.5) / 40.0));
	ALBEDO = surface.rgb;
	ROUGHNESS = surface.a;
	SPECULAR = 0.5;
	// Reconstruct flat faces after the ring twist and nonuniform instance scale.
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = face_normal * (dot(face_normal, NORMAL) < 0.0 ? -1.0 : 1.0);
}
