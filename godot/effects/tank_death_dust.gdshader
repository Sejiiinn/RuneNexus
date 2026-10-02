shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
instance uniform float death_age = 0.0;
varying float puff_age;
void vertex() {
    puff_age = death_age - INSTANCE_CUSTOM.w;
    float u = clamp(puff_age/.28,0.0,1.0);
    vec3 center = MODEL_MATRIX[3].xyz;
    center.xz += INSTANCE_CUSTOM.xy * u * .10;
    center.y += u * .055;
    vec3 world = center + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * (.65+u*.8);
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world,1.0);
}
void fragment() {
    float radius = length((UV-.5)*2.0);
    float shape = 1.0-smoothstep(.25,1.0,radius);
    float fade = smoothstep(0.0,.035,puff_age)*(1.0-smoothstep(.09,.28,puff_age));
    ALBEDO = vec3(.29,.27,.23);
    ALPHA = shape*fade*.20;
}
