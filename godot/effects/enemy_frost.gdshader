shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler3D rime_mask : filter_linear, repeat_disable;
uniform sampler2D grain_texture : filter_linear_mipmap, repeat_enable;
uniform float coordinate_scale = 1.0;
uniform bool preserve_colored_core = false;
uniform sampler2D body_albedo : source_color, filter_linear_mipmap;
uniform bool preserve_emission_core = false;
uniform sampler2D body_emission : source_color, filter_linear_mipmap;
instance uniform float frost_amount : hint_range(0.0, 1.0) = 1.0;
varying vec3 object_position;
varying vec3 object_normal;
varying float object_scale;

void vertex() {
	// Original mesh coordinates, converted back to the Blender authoring axes.
	object_position = vec3(VERTEX.x, -VERTEX.z, VERTEX.y) * coordinate_scale;
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
	vec3 body_color = texture(body_albedo, UV).rgb;
	bool colored_core = preserve_colored_core && ((body_color.g > body_color.r * 1.25 && body_color.b > body_color.r * 1.25) || (body_color.r > body_color.g * 1.25 && body_color.b > body_color.g * 1.25));
	vec3 emission_mask = texture(body_emission, UV).rgb;
	bool protected_core = preserve_emission_core ? max(emission_mask.r, max(emission_mask.g, emission_mask.b)) > 0.01 : colored_core;
	ALPHA = protected_core ? 0.0 : coverage * frost_amount;
	// Surface-gradient bump in view space, independent of each enemy's UVs.
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy, NORMAL);
	vec3 r2 = cross(NORMAL, dx);
	float det = dot(dx, r1);
	vec3 gradient = (dFdx(grain) * r1 + dFdy(grain) * r2) * (0.013 * 0.32 * object_scale);
	NORMAL = normalize(abs(det) * NORMAL - sign(det) * gradient);
}
