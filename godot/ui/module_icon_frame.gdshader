shader_type canvas_item;

// Clip only the opaque background outside the source frame's chamfer.
// Nine-patch UVs keep these corners at their original size when resized.
uniform vec2 source_size = vec2(684.0, 464.0);
uniform float corner_cut = 20.0;

void fragment() {
	vec2 corner_distance = min(UV, vec2(1.0) - UV) * source_size;
	COLOR.a *= smoothstep(corner_cut - 0.5, corner_cut + 0.5,
		corner_distance.x + corner_distance.y);
}
