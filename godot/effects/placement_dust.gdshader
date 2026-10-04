shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform bool orthographic = true;
uniform float real_time = 0.0;
uniform float start_center_factor;
uniform float end_center_factor;
uniform vec3 mesh_size = vec3(1.0);
uniform vec2 shape_range;
uniform float noise_scale;
uniform vec2 noise_strength;
uniform float warp_scale;
uniform float warp_amplitude;
uniform vec3 warp_offsets[3];
uniform float index_phase;
uniform vec3 noise_advection;
uniform float density_multiplier;
uniform vec3 native_tint;
uniform float native_tint_mix;
uniform int ray_steps;
uniform bool opaque_depth_clip;
uniform vec2 color_alpha_factor;
uniform vec4 particle_path[32];
uniform vec4 particle_size[32];
uniform vec2 particle_turn[32];
uniform vec4 motion_curve[4];
uniform vec2 alpha_curve[4];
varying float dust_progress;
varying flat float dust_seed;
varying vec3 dust_local;
varying flat mat3 view_to_density;

vec3 motion_at(float age) {
	for (int i=0;i<3;i++) {
		if (age <= motion_curve[i+1].x) {
			float p = clamp((age-motion_curve[i].x)/(motion_curve[i+1].x-motion_curve[i].x),0.0,1.0);
			return mix(motion_curve[i].yzw,motion_curve[i+1].yzw,p);
		}
	}
	return motion_curve[3].yzw;
}
float opacity_at(float age) {
	for (int i=0;i<3;i++) {
		if (age <= alpha_curve[i+1].x) {
			float p = clamp((age-alpha_curve[i].x)/(alpha_curve[i+1].x-alpha_curve[i].x),0.0,1.0);
			return mix(alpha_curve[i].y,alpha_curve[i+1].y,p);
		}
	}
	return 0.0;
}
vec3 turn_y(vec3 point, float angle) {
	float c=cos(angle), s=sin(angle);
	return vec3(point.x*c+point.z*s,point.y,-point.x*s+point.z*c);
}
void vertex() {
	dust_progress = clamp((real_time-INSTANCE_CUSTOM.x)/INSTANCE_CUSTOM.y,0.0,1.0);
	dust_local = VERTEX/mesh_size;
	dust_seed = INSTANCE_CUSTOM.z;
	int index = int(INSTANCE_CUSTOM.z);
	vec4 path = particle_path[index];
	vec4 size = particle_size[index];
	vec3 curve = motion_at(dust_progress);
	float width = mix(size.x,size.y,dust_progress)*curve.y;
	float height = mix(size.z,size.w,dust_progress)*curve.y;
	vec3 scale = vec3(width,height,width)/mesh_size;
	float turn = particle_turn[index].x+particle_turn[index].y*dust_progress;
	VERTEX = turn_y(VERTEX*scale,turn);
	NORMAL = normalize(turn_y(NORMAL/scale,turn));
	mat3 inverse_turn = mat3(turn_y(vec3(1,0,0),-turn),vec3(0,1,0),turn_y(vec3(0,0,1),-turn));
	mat3 density_scale = mat3(vec3(1.0/width,0,0),vec3(0,1.0/height,0),vec3(0,0,1.0/width));
	view_to_density = density_scale*inverse_turn*inverse(mat3(MODELVIEW_MATRIX));
	float radius = mix(path.y,path.z,curve.x);
	VERTEX += vec3(cos(path.x)*radius,mix(size.z*start_center_factor,size.w*end_center_factor,curve.x)+path.w*curve.z,-sin(path.x)*radius);
}
float hash3(vec3 p) {
	return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);
}
float noise3(vec3 p) {
	vec3 i=floor(p),f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void fragment() {
	float envelope=opacity_at(dust_progress);
	if (envelope <= 0.001) discard;
	vec3 view_direction=orthographic ? vec3(0,0,-1) : -normalize(VIEW);
	vec3 raw_direction=view_to_density*view_direction;
	vec3 direction=normalize(raw_direction);
	vec3 inverse_direction=1.0/(sign(direction+vec3(0.00001))*max(abs(direction),vec3(0.00001)));
	vec3 a=(-vec3(0.5)-dust_local)*inverse_direction;
	vec3 b=(vec3(0.5)-dust_local)*inverse_direction;
	vec3 exits=max(a,b);
	float ray_length=max(0.0,min(exits.x,min(exits.y,exits.z)));
	// Opaque tile/turret depth clips the moving instance in the same view frame.
	float depth=texture(scene_depth,SCREEN_UV).r;
	vec3 ndc=vec3(SCREEN_UV*2.0-1.0,depth);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ndc.z=depth*2.0-1.0;
#endif
	vec4 opaque_view=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	float opaque_distance=dot(opaque_view.xyz/opaque_view.w-VERTEX,view_direction);
	if (opaque_depth_clip) ray_length=min(ray_length,max(0.0,opaque_distance)*length(raw_direction));
	float step_length=ray_length/float(ray_steps);
	float opacity=0.0;
	for (int sample=0;sample<16;sample++) {
		if (sample >= ray_steps) break;
		vec3 p=dust_local+direction*(float(sample)+0.5)*step_length;
		vec3 flow=dust_progress*noise_advection+vec3(0,dust_seed*index_phase,0);
		vec3 warp=vec3(noise3(p*warp_scale+flow+warp_offsets[0]),noise3(p*warp_scale+flow+warp_offsets[1]),noise3(p*warp_scale+flow+warp_offsets[2]))-vec3(0.5);
		float shape=1.0-smoothstep(shape_range.x,shape_range.y,length(p+warp*warp_amplitude));
		float turbulence=noise3(p*noise_scale+flow);
		float density=shape*(noise_strength.x+noise_strength.y*turbulence)*envelope*density_multiplier;
		opacity+=(1.0-opacity)*(1.0-exp(-density*step_length));
	}
	ALBEDO=mix(COLOR.rgb,native_tint,native_tint_mix);
	ALPHA=opacity*(color_alpha_factor.x+color_alpha_factor.y*COLOR.a);
}
