shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_back;
uniform float age=0.0;
uniform float effect_radius=1.58;
uniform sampler2D noise_tex:repeat_enable,filter_linear;
varying vec3 local_pos;
varying float seed;
varying float life;
void vertex(){
 seed=INSTANCE_CUSTOM.x;float theta=INSTANCE_CUSTOM.y*6.2831853;float band=INSTANCE_CUSTOM.z;
 float t=clamp(age,0.,1.);float progress=1.-pow(1.-t,2.2);
 float radius=(.18+1.20*progress)*mix(.42,1.,band);
 vec3 direction=vec3(cos(theta),0.,sin(theta));
 float sz=mix(.08,.32,progress)*mix(.72,1.25,seed);
 local_pos=VERTEX;
 VERTEX*=vec3(sz*1.5,sz*1.4,sz*1.35);
 VERTEX+=direction*radius+vec3(0.,.09+progress*(.07+.22*seed),0.);
 VERTEX.xz*=effect_radius/1.92;
 life=smoothstep(0.,.09,t)*(1.-smoothstep(.40,1.,t));
}
void fragment(){
 vec2 uv1=local_pos.xz*.65+vec2(seed*4.,age*.15);
 float n=texture(noise_tex,uv1).r;
 float n2=texture(noise_tex,local_pos.xy*1.1+seed*8.-age*.12).r;
 float contour=pow(clamp(dot(normalize(NORMAL),normalize(VIEW)),0.,1.),3.8);
 float density=smoothstep(.12,.78,n*.65+n2*.35);
 ALPHA=contour*density*life*.32;
 ALBEDO=mix(vec3(.21,.48,.57),vec3(.72,.87,.88),n);
 ROUGHNESS=1.;EMISSION=vec3(.06,.15,.18)*life*.30;
}
