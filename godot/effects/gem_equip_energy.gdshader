shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 gem_color : source_color = vec4(0.1, 0.8, 1.0, 1.0);
uniform float age = 0.0;
uniform float kind = -1.0;
uniform float delay = 0.0;
uniform float seed = 0.0;
varying vec3 world_position;
varying vec3 center_world;
varying float radius_world;
varying vec3 authored;

void vertex() {
	authored = kind < 0.0 ? COLOR.rgb : vec3(kind, seed, delay);
	float time = max(0.0, age - authored.z);
	if (authored.x > 0.5 && authored.x < 1.5) {
		// Fast impact followed by outward travel until the wave is fully faded.
		float expansion = min(1.0, 0.65 * (1.0 - exp(-time * 18.0)) + time * (0.35 / 0.44));
		VERTEX.xz *= mix(0.21, 1.0, expansion);
		VERTEX.y += 0.028 * expansion;
	} else if (authored.x > 1.5 && authored.x < 2.5) {
		VERTEX *= mix(0.68, 1.15, clamp(time / 0.16, 0.0, 1.0));
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	center_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	radius_world = length(MODEL_MATRIX[0].xyz) * (authored.x > 2.5 ? 0.036 : 0.299);
}

void fragment() {
	float time = age - authored.z;
	float alpha = 0.0;
	vec3 radiance = gem_color.rgb;
	if (authored.x < 0.5) {
		// Keep a positive cruise speed: the head reaches the mesh end only
		// after its opacity has vanished, so the afterglow never parks there.
		float travel_time = max(time, 0.0);
		float head = 0.68 * (1.0 - exp(-travel_time * 14.0)) + travel_time * 0.48;
		float behind = head - UV.x;
		float tail = smoothstep(0.0, 0.065, behind) * (1.0 - smoothstep(0.12, 0.55, behind));
		float lateral = abs(UV.y * 2.0 - 1.0);
		float halo = exp(-3.8 * lateral*lateral) * (1.0 - smoothstep(0.8, 1.0, lateral));
		float spine = exp(-34.0 * lateral*lateral);
		float ends = smoothstep(0.0, 0.055, UV.x) * (1.0 - smoothstep(0.90, 1.0, UV.x));
		float fade = 1.0 - smoothstep(0.29, 0.66, time);
		float silk = 0.92 + 0.08 * sin(UV.x * 74.0 - time * 14.0 + authored.y * 19.0);
		// Keep the gem hue in the bright spine as well as the surrounding glow.
		radiance = gem_color.rgb * (0.90 + spine * 0.36);
		alpha = (halo * 0.34 + spine * 0.68) * tail * fade * ends * silk;
	} else if (authored.x < 1.5) {
		float lateral = abs(UV.y * 2.0 - 1.0);
		float feather = exp(-5.5 * lateral*lateral) * (1.0 - smoothstep(0.80, 1.0, lateral));
		float spine = exp(-52.0 * lateral*lateral);
		float strands = 0.60 + 0.24*sin(UV.x*45.0 + authored.y*13.0) + 0.12*sin(UV.x*107.0 - time*8.0);
		float rise = smoothstep(0.0, 0.035, time);
		float fade = 1.0 - smoothstep(0.12, 0.44, time);
		float impact = 1.0 + 0.80 * (1.0 - smoothstep(0.06, 0.15, time));
		radiance = gem_color.rgb * (0.84 + spine * 0.34);
		alpha = (feather * 0.22 + spine * 0.30) * strands * rise * fade * impact;
	} else {
		// Analytic radiance within a real 3D envelope: no solid sphere silhouette.
		vec3 camera = INV_VIEW_MATRIX[3].xyz;
		vec3 ray = normalize(world_position - camera);
		if (PROJECTION_MATRIX[3][3] > 0.5) {
			ray = -normalize(INV_VIEW_MATRIX[2].xyz);
			camera = world_position - ray * dot(world_position - camera, ray);
		}
		float distance_ray = max(0.0, dot(center_world - camera, ray));
		float radial = length(camera + ray * distance_ray - center_world) / max(radius_world, 0.001);
		float soft = exp(-7.0 * radial*radial);
		float pinpoint = exp(-65.0 * radial*radial);
		float envelope = 0.0;
		if (authored.x < 2.5) {
			envelope = smoothstep(0.0, 0.012, time) * (1.0 - smoothstep(0.035, 0.17, time));
			alpha = (soft * 0.48 + pinpoint * 0.90) * envelope;
		} else {
			envelope = smoothstep(0.0, 0.045, time) * (1.0 - smoothstep(0.16, 0.47, time));
			float sparkle = 0.74 + 0.26 * pow(0.5 + 0.5 * sin(time*28.0 + authored.y), 4.0);
			alpha = (soft * 0.26 + pinpoint * 0.84) * envelope * sparkle;
		}
		// White is only a brief pinpoint accent, never the main afterglow color.
		float white_accent = (1.0 - smoothstep(0.025, 0.085, time)) * (authored.x < 2.5 ? 0.60 : 0.12);
		radiance = mix(gem_color.rgb * (0.90 + pinpoint * 0.30), vec3(1.25), pinpoint * white_accent);
	}
	ALBEDO = radiance;
	ALPHA = time < 0.0 ? 0.0 : clamp(alpha, 0.0, 1.0);
}
