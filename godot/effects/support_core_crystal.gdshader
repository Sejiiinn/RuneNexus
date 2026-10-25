shader_type spatial;
// Support core floating crystal: clear cyan gem. The scene behind (the glowing
// heart inside, the crown well below) shows through with refraction and
// thickness absorption; every facet keeps its own brightness and catches a
// glint as the crystal turns, and the silhouette lights up with a Fresnel rim.
// Follows the base core's glass (environment/core_crystal.gdshader).
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 tint : source_color = vec4(0.12, 0.85, 0.78, 1.0);
uniform vec4 rim_color : source_color = vec4(0.3, 1.0, 0.9, 1.0);
// Lower facets (girdle and pavilion) glow less so the crystal keeps an outline over the arms.
uniform float body_glow = 0.4;
uniform float rim_energy = 1.5;
uniform float glint_energy = 1.6;
uniform float transmission_factor = 0.85;
uniform float index_of_refraction = 1.6;
// Optical path through the crystal at a head-on facet (model units, crystal about .16 tall).
uniform float thickness_scale = 0.05;

varying vec3 facet;

void vertex() {
	// Model-space flat normal: one value per facet that turns with the crystal.
	facet = NORMAL;
}

float hash(vec3 p) {
	return fract(sin(dot(floor(p * 7.0 + 0.5), vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	float facing = clamp(dot(normal, view), 0.0, 1.0);
	float reflectance = pow((index_of_refraction - 1.0) / (index_of_refraction + 1.0), 2.0);
	float fresnel = reflectance + (1.0 - reflectance) * pow(1.0 - facing, 4.0);
	float thickness = thickness_scale / max(facing, 0.3);
	vec3 ray = refract(-view, normal, 1.0 / index_of_refraction);
	vec4 projected = PROJECTION_MATRIX * vec4(VERTEX + ray * thickness, 1.0);
	vec2 refraction_uv = clamp(projected.xy / projected.w * 0.5 + 0.5, vec2(0.001), vec2(0.999));
	vec4 behind = INV_PROJECTION_MATRIX * vec4(refraction_uv * 2.0 - 1.0, texture(scene_depth, refraction_uv).r, 1.0);
	// Do not pull things in front of the crystal into it.
	if (behind.z / behind.w > VERTEX.z - 0.002) {
		refraction_uv = SCREEN_UV;
	}
	vec3 transmission = texture(scene_color, refraction_uv).rgb;
	vec3 absorption = pow(max(tint.rgb, vec3(0.001)), vec3(thickness / thickness_scale));
	// Each facet a slightly different depth of cyan, like the concept's cut faces.
	float cut = 0.65 + 0.7 * hash(normalize(facet));
	float glint = pow(facing, 18.0) * glint_energy;
	ALBEDO = tint.rgb * (1.0 - transmission_factor);
	METALLIC = 0.0;
	ROUGHNESS = 0.04;
	SPECULAR = 0.9;
	EMISSION = transmission * absorption * transmission_factor * (1.0 - fresnel)
		+ tint.rgb * body_glow * cut
		+ rim_color.rgb * (fresnel * rim_energy + glint);
	ALPHA = 1.0;
}
