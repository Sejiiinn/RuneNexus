shader_type spatial;
// Strengthened-turret base mark: a ring near the tile edge, brighter on each
// side a support core touches. When the link's energy packet arrives (same
// period and travel share as support_core_link) the ring flashes and a ripple
// spreads outward.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.3, 0.95, 0.9, 1.0);
uniform float battle_time = 0.0;
uniform float period = 1.4;
uniform float travel = 0.62;
// Near the tile edge, outside the turret foot (plane half size = 1.0).
uniform float radius = 0.84;
uniform float width = 0.035;
// x: +X side, y: -X side, z: +Z side, w: -Z side (1 when a core touches it).
instance uniform vec4 sides = vec4(0.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float angle = atan(p.y, p.x);
	float arc = 0.0;
	arc += sides.x * smoothstep(0.7, 0.0, abs(angle));
	arc += sides.y * smoothstep(0.7, 0.0, abs(abs(angle) - PI));
	arc += sides.z * smoothstep(0.7, 0.0, abs(angle - PI * 0.5));
	arc += sides.w * smoothstep(0.7, 0.0, abs(angle + PI * 0.5));
	arc = min(arc, 1.0);
	float phase = fract(battle_time / period);
	float arrival = clamp((phase - travel) / (1.0 - travel), 0.0, 1.0);
	float active = step(travel, phase);
	float flash = active * exp(-arrival * 5.0);
	float ring = smoothstep(width * 2.6, 0.0, abs(d - radius));
	float ripple_radius = mix(radius, 0.99, arrival);
	float ripple = active * smoothstep(width * 3.0, 0.0, abs(d - ripple_radius)) * pow(1.0 - arrival, 1.5) * smoothstep(1.0, 0.95, d);
	float glow = ring * (0.55 + arc * 1.3 + flash * 1.6) + ripple * (0.6 + arc * 0.9);
	ALBEDO = color.rgb * glow;
	ALPHA = clamp(glow, 0.0, 1.0);
}
