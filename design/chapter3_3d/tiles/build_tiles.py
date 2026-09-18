"""Chapter 3 approved thick foundry tiles. Source-only; no runtime export.
Reuses chapter2 tiles' polygon extrusion, bevels, independent background workflow.
Run Blender --background --python build_tiles.py. Existing source is preserved.
"""
import bpy, math, json, random, sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
SOURCE=HERE/'chapter3-thick-tiles.blend'
RNG=random.Random(31826)
REF='design/chapter3_3d_concepts/2026-09-18/tiles-multiview-thick-approved.png'

def metal(name,dark,light,rough=.48):
    m=bpy.data.materials.new(name);m.use_nodes=True
    n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
    p.inputs['Metallic'].default_value=.88
    tc=n.new('ShaderNodeTexCoord')
    broad=n.new('ShaderNodeTexNoise');broad.inputs['Scale'].default_value=12;broad.inputs['Detail'].default_value=5;broad.inputs['Roughness'].default_value=.78
    grain=n.new('ShaderNodeTexNoise');grain.inputs['Scale'].default_value=240;grain.inputs['Detail'].default_value=3
    pits=n.new('ShaderNodeTexNoise');pits.inputs['Scale'].default_value=69;pits.inputs['Detail'].default_value=3
    for node in (broad,grain,pits):l.new(tc.outputs['Object'],node.inputs['Vector'])
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.22;ramp.color_ramp.elements[0].color=(*dark,1);ramp.color_ramp.elements[1].position=.79;ramp.color_ramp.elements[1].color=(*light,1);l.new(broad.outputs['Fac'],ramp.inputs[0])
    vor=n.new('ShaderNodeTexVoronoi');vor.feature='DISTANCE_TO_EDGE';vor.inputs['Scale'].default_value=20;l.new(tc.outputs['Object'],vor.inputs['Vector'])
    scratch=n.new('ShaderNodeMath');scratch.operation='LESS_THAN';scratch.inputs[1].default_value=.008;l.new(vor.outputs['Distance'],scratch.inputs[0])
    mask=n.new('ShaderNodeMath');mask.operation='GREATER_THAN';mask.inputs[1].default_value=.57;l.new(pits.outputs['Fac'],mask.inputs[0])
    mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';l.new(scratch.outputs[0],mul.inputs[0]);l.new(mask.outputs[0],mul.inputs[1])
    mix=n.new('ShaderNodeMixRGB');mix.blend_type='MIX';l.new(mul.outputs[0],mix.inputs[0]);l.new(ramp.outputs[0],mix.inputs[1]);mix.inputs[2].default_value=(*(v*1.45 for v in light),1);l.new(mix.outputs[0],p.inputs['Base Color'])
    remap=n.new('ShaderNodeMapRange');remap.inputs['To Min'].default_value=rough-.13;remap.inputs['To Max'].default_value=rough+.15;l.new(grain.outputs[0],remap.inputs[0]);l.new(remap.outputs[0],p.inputs['Roughness'])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.16;bump.inputs['Distance'].default_value=.002;l.new(pits.outputs['Fac'],bump.inputs['Height'])
    micro=n.new('ShaderNodeBump');micro.inputs['Strength'].default_value=.13;micro.inputs['Distance'].default_value=.0007;l.new(grain.outputs['Fac'],micro.inputs['Height']);l.new(bump.outputs['Normal'],micro.inputs['Normal']);l.new(micro.outputs['Normal'],p.inputs['Normal'])
    return m

def rect(x0,y0,x1,y1,c=.035):
    return [(x0+c,y0),(x1-c,y0),(x1,y0+c),(x1,y1-c),(x1-c,y1),(x0+c,y1),(x0,y1-c),(x0,y0+c)]

def prism(name,poly,z0,z1,mat,parent,bevel=.004):
    k=len(poly);v=[(x,y,z) for z in (z0,z1) for x,y in poly]
    f=[tuple(reversed(range(k))),tuple(range(k,k*2))]+[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(v,[],f);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.parent=parent
    obj.data.materials.append(mat);obj.data.materials.append(M['worn_bronze'] if mat==M['bronze'] else M['edge'])
    if bevel:
        mod=obj.modifiers.new('Worn machined bevel','BEVEL');mod.width=bevel;mod.segments=3;mod.material=1
        mod=obj.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=30
    return obj

def box(name,loc,dim,mat,parent,bevel=.004,clip=.003):
    x,y,z=loc;w,d,h=dim
    return prism(name,rect(x-w/2,y-d/2,x+w/2,y+d/2,min(clip,w*.25,d*.25)),z-h/2,z+h/2,mat,parent,bevel)

def ring(name,r0,r1,z0,z1,mat,parent,segments=96):
    v=[]
    for z,r in ((z0,r0),(z0,r1),(z1,r0),(z1,r1)):
        v += [(math.cos(i*2*math.pi/segments)*r,math.sin(i*2*math.pi/segments)*r,z) for i in range(segments)]
    f=[]
    for i in range(segments):
        j=(i+1)%segments
        f.extend([(i,j,j+segments,i+segments),(i+2*segments,i+3*segments,j+3*segments,j+2*segments),(i,i+2*segments,j+2*segments,j),(i+segments,j+segments,j+3*segments,i+3*segments)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(v,[],f);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat);o.data.materials.append(M['worn_bronze'])
    b=o.modifiers.new('Ring worn bevel','BEVEL');b.width=.003;b.segments=3;b.material=1;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o

def cylinder(name,x,y,z0,z1,r,mat,parent,n=8):
    return prism(name,[(x+math.cos(i*2*math.pi/n)*r,y+math.sin(i*2*math.pi/n)*r) for i in range(n)],z0,z1,mat,parent,.002)

def bolt(parent,x,y,i):
    cylinder('Corner_%d_washer'%i,x,y,.001,.008,.043,M['dark'],parent,32)
    cylinder('Corner_%d_hex_bolt'%i,x,y,.007,.030,.031,M['bolt'],parent,6)
    # Small forged depression in the hex top is real geometry, not painted shine.
    cylinder('Corner_%d_forge_mark'%i,x,y,.030,.0305,.007,M['dark'],parent,12)

def base(name,topmat,grate=False):
    root=bpy.data.objects.new(name,None);bpy.context.scene.collection.objects.link(root)
    root['approvedConcept']=REF;root['footprint']=[1.,1.];root['bodyThickness']=.34;root['surfaceZ']=0.
    prism('Bottom_flange',rect(-.5,-.5,.5,.5,.060),-.34,-.295,M['dark'],root,.005)
    prism('Recessed_housing',rect(-.450,-.450,.450,.450,.036),-.303,-.049,M['side'],root,.004)
    # Hollow grate cavity, actual perforated upper plate, and internal heat bed.
    top=prism('Top_flange_plate',rect(-.5,-.5,.5,.5,.060),-.063,0,topmat,root,.005)
    if grate:
        # Boolean cutters leave 25 true holes through the .063-thick plate.
        for mod in list(top.modifiers):top.modifiers.remove(mod)
        for row in range(5):
            for col in range(5):
                x=(col-2)*.128;y=(row-2)*.128
                cut=box('temporary_hole',(x,y,0),(.093,.093,.3),M['dark'],None,0,0)
                bpy.context.view_layer.objects.active=top
                b=top.modifiers.new('Hole_%d_%d'%(row,col),'BOOLEAN');b.operation='DIFFERENCE';b.solver='EXACT';b.object=cut;bpy.ops.object.modifier_apply(modifier=b.name)
                bpy.data.objects.remove(cut,do_unlink=True)
        b=top.modifiers.new('Perforation worn edges','BEVEL');b.width=.004;b.segments=3;b.material=1;top.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
        # Replace solid housing with four thick cavity walls. Outer dimensions unchanged.
        old=next(o for o in root.children if o.name.startswith('Recessed_housing'));bpy.data.objects.remove(old,do_unlink=True)
        for side in range(4):
            a=side*math.pi/2
            poly=[(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a)) for x,y in rect(-.45,-.45,.45,-.35,.01)]
            prism('Cavity_wall_%d'%side,poly,-.303,-.049,M['side'],root,.003)
        bed=box('Recessed_embers',(0,0,-.275),(.68,.68,.018),M['ember'],root,.003)
        # A few low black ribs break the internal glow into depth layers.
        for i in range(4):box('Internal_baffle_%d'%i,((i-1.5)*.145,0,-.235),(.024,.68,.060),M['dark'],root,.002)
    for side in range(4):
        a=side*math.pi/2
        def rotated(poly):return [(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a)) for x,y in poly]
        for j,x in enumerate((-.20,.20)):
            prism('Side_%d_reinforcement_%d'%(side,j),rotated(rect(x-.034,-.5,x+.034,-.44,.004)),-.313,-.047,M['side'],root,.004)
        # Corner posts delimit exactly three recessed compartments on each face.
        for j,x in enumerate((-.439,.439)):
            prism('Side_%d_corner_post_%d'%(side,j),rotated(rect(x-.020,-.48,x+.020,-.433,.003)),-.307,-.05,M['side'],root,.003)
        # Recessed lower seam lip catches a fine physical highlight within each panel.
        for j,(x0,x1) in enumerate(((-.415,-.24),(-.158,.158),(.24,.415))):
            prism('Side_%d_panel_sill_%d'%(side,j),rotated(rect(x0,-.455,x1,-.447,.001)),-.287,-.279,M['edge'],root,.001)
    for i,(x,y) in enumerate(((-.405,-.405),(.405,-.405),(.405,.405),(-.405,.405))):bolt(root,x,y,i)
    return root

def make_tiles():
    a=base('01_Cast_iron_plate',M['steel'])
    for j in range(5):
        y=(j-2)*.137
        # Capsule ribs use a long eight-sided footprint and generous roundover.
        poly=[(.328+math.cos(-math.pi/2+i*math.pi/12)*.026,y+math.sin(-math.pi/2+i*math.pi/12)*.026) for i in range(13)]
        poly += [(-.328+math.cos(math.pi/2+i*math.pi/12)*.026,y+math.sin(math.pi/2+i*math.pi/12)*.026) for i in range(13)]
        prism('Raised_tread_%d'%(j+1),poly,.001,.030,M['steel'],a,.011)
    b=base('02_Heat_vent_grate',M['steel'],True)
    c=base('03_Construction_foundation',M['blue'])
    ring('Bronze_mounting_ring',.301,.373,.002,.025,M['bronze'],c)
    for j in range(4):
        t=j*math.pi/2;x=.350*math.cos(t);y=.350*math.sin(t)
        poly=rect(-.043,-.07,.043,.07,.005)
        # Radial clamp, long dimension radial (Y before rotation).
        r=t-math.pi/2
        poly=[(px*math.cos(r)-py*math.sin(r)+x,px*math.sin(r)+py*math.cos(r)+y) for px,py in poly]
        prism('Cardinal_ring_clamp_%d'%j,poly,.020,.044,M['bronze'],c,.005)
    return [a,b,c]

def studio(roots):
    s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=80;s.cycles.use_denoising=True
    s.world=bpy.data.worlds.new('Neutral foundry studio');s.world.use_nodes=True
    s.world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.20,.20,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    for name,loc,power,size in [('Large neutral key',(-3,-4,6),650,4),('Soft neutral fill',(4,-1,3),260,3),('Rear metal separation',(0,4,5),500,3)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        o=bpy.data.objects.new(name,data);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    ground=bpy.data.materials.new('Charcoal studio ground');ground.diffuse_color=(.024,.025,.026,1);ground.use_nodes=True;ground.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.024,.025,.026,1);ground.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.85
    box('Studio ground',(0,0,-.379),(200,200,.04),ground,None,0,0)
    camdata=bpy.data.cameras.new('Review camera');cam=bpy.data.objects.new('Review camera',camdata);s.collection.objects.link(cam);camdata.type='ORTHO';camdata.ortho_scale=4.3;s.camera=cam
    s.render.resolution_x=2100;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG'
    s.view_settings.view_transform='AgX'
    s.view_settings.look='AgX - Medium High Contrast'
    # Root spacing follows the image horizontal axis, preventing overlap in 3/4 view.
    for i,r in enumerate(roots):r.location=((i-1)*1.35,0,0)
    return s,cam

def pose(cam,kind):
    cam.location={'hero':(2.8,-6,5.2),'top':(0,0,8),'side':(0,-8,.20)}[kind]
    cam.rotation_euler=(Vector((0,0,-.13))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale={'hero':4.25,'top':4.05,'side':4.05}[kind]

def main():
    global M
    if not bpy.app.background:raise RuntimeError('Separate background Blender required; preserve the open workspace.')
    if SOURCE.exists() and '--regenerate' not in sys.argv:raise RuntimeError('Source exists; preserve manual edits. Back up and use --regenerate explicitly.')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    M={
      'steel':metal('Cast iron | silver graphite',(.065,.058,.050),(.15,.139,.12)),
      'blue':metal('Construction plate | blue graphite',(.023,.027,.035),(.065,.071,.083)),
      'dark':metal('Flanges | dark forged iron',(.039,.045,.052),(.105,.117,.13)),
      'side':metal('Recess walls | forged iron',(.045,.048,.053),(.13,.135,.14)),
      'edge':metal('Exposed worn iron edges',(.11,.10,.085),(.25,.235,.21),.40),
      'bolt':metal('Forged steel fasteners',(.13,.11,.085),(.27,.23,.18),.43),
      'bronze':metal('Mounting ring | aged bronze',(.085,.055,.028),(.24,.163,.087),.42),
      'worn_bronze':metal('Worn bronze bevel',(.15,.11,.07),(.32,.24,.145),.40),
    }
    ember=bpy.data.materials.new('Deep ember bed | localized orange only');ember.use_nodes=True;p=ember.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.018,.012,.009,1);p.inputs['Emission Color'].default_value=(.42,.065,.004,1);p.inputs['Emission Strength'].default_value=.60;p.inputs['Roughness'].default_value=.9;M['ember']=ember
    # Heat is concentrated physically in the central bed, fading to cool edges.
    n=ember.node_tree.nodes;l=ember.node_tree.links
    tc=n.new('ShaderNodeTexCoord');separate=n.new('ShaderNodeSeparateXYZ');l.new(tc.outputs['Object'],separate.inputs[0])
    planar=n.new('ShaderNodeCombineXYZ');l.new(separate.outputs['X'],planar.inputs['X']);l.new(separate.outputs['Y'],planar.inputs['Y'])
    radius=n.new('ShaderNodeVectorMath');radius.operation='LENGTH';l.new(planar.outputs[0],radius.inputs[0])
    heat=n.new('ShaderNodeMapRange');heat.clamp=True;heat.interpolation_type='SMOOTHERSTEP';heat.inputs['From Min'].default_value=0;heat.inputs['From Max'].default_value=.30;heat.inputs['To Min'].default_value=.28;heat.inputs['To Max'].default_value=.002;l.new(radius.outputs['Value'],heat.inputs['Value']);l.new(heat.outputs['Result'],p.inputs['Emission Strength'])
    roots=make_tiles();s,cam=studio(roots)
    report={'approved_reference':REF,'blender':bpy.app.version_string,'body_thickness':.34,'footprint':[1,1],'common_top_z':0,'features':{'cast_treads':5,'grate_through_holes':[5,5],'corner_bolts_per_tile':4,'ring_clamps':4,'reinforcements_per_side':2,'recessed_compartments_per_side':3},'tiles':{}}
    for root in roots:
        pts=[root.matrix_world.inverted() @ o.matrix_world @ Vector(p) for o in root.children if o.type=='MESH' for p in o.bound_box]
        dims=[max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3)]
        report['tiles'][root.name]={'mesh_objects':len(root.children),'bounds_dimensions':dims}
    (HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    pose(cam,'hero');bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    for kind in ('hero','top','side'):
        pose(cam,kind);s.render.resolution_y={'hero':1000,'top':750,'side':540}[kind]
        s.render.filepath=str(HERE/('tiles-'+kind+'.png'));bpy.ops.render.render(write_still=True);print('RENDER_READY',kind,flush=True)
    pose(cam,'hero');s.render.resolution_y=1000;s.render.filepath=str(HERE/'tiles-hero.png');bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE));print('CHAPTER3_TILES_READY',flush=True)
if __name__=='__main__':main()
