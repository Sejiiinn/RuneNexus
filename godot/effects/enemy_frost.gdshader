shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler3D rime_mask : filter_linear, repeat_disable;
uniform sampler2D grain_texture : filter_linear_mipmap, repeat_enable;
instance uniform float frost_amount : hint_range(0.0, 1.0) = 1.0;
varying vec3 object_position;
varying vec3 object_normal;
varying float object_scale;

void vertex() {
	// Original mesh coordinates, converted back to the Blender authoring axes.
	object_position = vec3(VERTEX.x, -VERTEX.z, VERTEX.y);
	object_normal = vec3(NORMAL.x, -NORMAL.z, NORMAL.y);
	object_scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += NORMAL * 0.004;
}

void fragment() {
	vec3 p = object_position;
	float coverage = texture(rime_mask, (p - vec3(-0.7, -0.7, -0.1)) / 1.4).r;
	vec3 weight = pow(abs(normalize(object_normal)), vec3(4.0));
	weight /= max(dot(weight, vec3(1.0)), 0.0001);
	vec3 g = p * (145.0 / 8.0);
	float grain = texture(grain_texture, g.yz).r * weight.x
		+ texture(grain_texture, g.xz).r * weight.y
		+ texture(grain_texture, g.xy).r * weight.z;
	// The original Blender ramp endpoints in linear RGB.
	ALBEDO = mix(vec3(0.10048, 0.38006, 0.57048), vec3(0.74841, 0.93311, 1.0), grain);
	ROUGHNESS = 0.56;
	SPECULAR = 0.5;
	ALPHA = coverage * frost_amount;
	// Surface-gradient bump in view space, independent of each enemy's UVs.
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy, NORMAL);
	vec3 r2 = cross(NORMAL, dx);
	float det = dot(dx, r1);
	vec3 gradient = (dFdx(grain) * r1 + dFdy(grain) * r2) * (0.013 * 0.32 * object_scale);
	NORMAL = normalize(abs(det) * NORMAL - sign(det) * gradient);
}
