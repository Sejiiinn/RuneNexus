// Immutable seed-1404 parameters shared by every impact. Rows 0..55 are sparks;
// rows 56..89 are fragments. RGBA32F values are data, never source_color.
uniform sampler2D u_particle_data : filter_nearest, repeat_disable;
uniform float u_age = 0.0;
uniform float u_radius = 1.0;
uniform float u_angle = 0.0;

// Basis.from_euler(angles, EULER_ORDER_XYZ) = Rx * Ry * Rz.
mat3 impact_euler_xyz(vec3 angles) {
	vec3 c = cos(angles);
	vec3 s = sin(angles);
	return mat3(
		vec3(c.y * c.z, c.z * s.x * s.y + c.x * s.z, -c.x * c.z * s.y + s.x * s.z),
		vec3(-c.y * s.z, c.x * c.z - s.x * s.y * s.z, c.z * s.x + c.x * s.y * s.z),
		vec3(s.y, -c.y * s.x, c.x * c.y)
	);
}

// The shortest arc Quaternion(Vector3.BACK, direction), without a camera-facing
// basis. All seeded velocities have a nonzero horizontal component, so the
// anti-parallel pole cannot occur in this effect.
vec3 impact_align_back(vec3 value, vec3 direction) {
	vec3 q = vec3(-direction.y, direction.x, 0.0);
	float w = 1.0 + direction.z;
	// Basis(Quaternion) divides by the quaternion's squared length too.
	// Keeping q unnormalized avoids a reciprocal-sqrt precision loss near -Z.
	return value + (2.0 / (dot(q, q) + w * w)) * cross(q, cross(q, value) + w * value);
}

void vertex() {
#ifdef IMPACT_SPARK
	int index = INSTANCE_ID;
	const float drag = 1.8;
	const float gravity = 4.8;
#else
	int index = INSTANCE_ID + 56;
	const float drag = 0.75;
	const float gravity = 5.4;
#endif
	vec4 launch = texelFetch(u_particle_data, ivec2(0, index), 0);
	vec4 shape = texelFetch(u_particle_data, ivec2(1, index), 0);
	float time = max(0.0, u_age - shape.x);
	float decay = exp(-drag * time);
	float travel = (1.0 - decay) / drag;
	float height = 0.055 + launch.z * time - gravity * time * time;
	float heading = launch.x + u_angle;
	vec2 velocity_xz = vec2(cos(heading), sin(heading)) * launch.y;
	vec3 origin = vec3(velocity_xz.x * travel, height, velocity_xz.y * travel) * u_radius;
	bool alive = u_age >= shape.x && time <= launch.w && height >= 0.014;

	if (alive) {
#ifdef IMPACT_SPARK
		vec3 direction = normalize(vec3(velocity_xz.x * decay,
			launch.z - 2.0 * gravity * time, velocity_xz.y * decay));
		vec3 particle_scale = vec3(shape.y, shape.y, shape.z * (1.0 - time / launch.w)) * u_radius;
		VERTEX = impact_align_back(VERTEX * particle_scale, direction) + origin;
		NORMAL = impact_align_back(NORMAL * particle_scale, direction);
#else
		float spin = texelFetch(u_particle_data, ivec2(2, index), 0).x;
		mat3 rotation = impact_euler_xyz(vec3(time * spin + float(index),
			time * spin * 0.73, time * spin * 1.31));
		float fade = clamp((launch.w - time) / 0.11, 0.0, 1.0);
		vec3 particle_scale = vec3(shape.y, shape.y * shape.w, shape.y) * u_radius * fade;
		VERTEX = rotation * (VERTEX * particle_scale) + origin;
		// Match Godot 4.7 Mobile's existing MultiMesh normal path:
		// model_normal_matrix *= mat3(instance_transform). Changing this to an
		// inverse scale would change the approved fragment face lighting.
		NORMAL = rotation * (NORMAL * particle_scale);
#endif
	} else {
		// Same zero-scale degenerate triangles as the old CPU transform path.
		// No ALPHA/discard, so the fragments keep the opaque depth/PBR passes.
		VERTEX = origin;
	}
}
