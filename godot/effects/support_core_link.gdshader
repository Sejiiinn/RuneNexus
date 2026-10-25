shader_type spatial;
// Support core connection from the core (UV.x = 0) to the strengthened turret
// (UV.x = 1); UV.y crosses the ribbon width. A steady beam carries one energy
// packet per period; the turret mark ripples when it arrives (same period).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.3, 0.95, 0.9, 1.0);
uniform float battle_time = 0.0;
uniform float intensity = 1.6;
uniform float period = 1.4;
// Share of the period the packet spends travelling; the rest is the ripple.
uniform float travel = 0.62;
uniform float pulse_speed = 1.1;
uniform float pulses = 3.0;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float ends = smoothstep(0.0, 0.1, UV.x) * smoothstep(1.0, 0.86, UV.x);
	float head = fract(battle_time / period) / travel;
	// Bright front with a trailing tail; gone once it has reached the turret.
	float behind = head - UV.x;
	float packet = step(0.0, behind) * pow(clamp(1.0 - behind / 0.4, 0.0, 1.0), 2.0) * smoothstep(1.15, 1.0, head);
	packet += smoothstep(0.05, 0.0, abs(behind)) * step(head, 1.05);
	packet = min(packet, 1.4);
	// The packet swells the beam: a softer falloff spreads it across the ribbon.
	float core = pow(across, mix(5.0, 2.2, min(packet, 1.0)));
	float halo = pow(across, mix(1.3, 0.6, min(packet, 1.0)));
	float flow = fract(UV.x * pulses - battle_time * pulse_speed);
	float dashes = smoothstep(0.0, 0.2, flow) * smoothstep(0.45, 0.2, flow);
	float glow = (core * (0.75 + dashes * 0.5 + packet * 2.6) + halo * (0.4 + packet * 1.2)) * ends * intensity;
	ALBEDO = color.rgb * glow;
	ALPHA = clamp(glow, 0.0, 1.0);
}
