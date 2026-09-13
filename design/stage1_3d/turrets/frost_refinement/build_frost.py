import bpy, math, random, os
from mathutils import Vector
ROOT='/Users/sejin/Documents/Codex/RuneNexus'; OUT=ROOT+'/design/stage1_3d/turrets/frost_refinement'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=12
scene.render.bake.use_pass_direct=False; scene.render.bake.use_pass_indirect=False; scene.render.bake.use_pass_color=True

def color(h):
    c=[int(h[i:i+2],16)/255 for i in (0,2,4)]; return tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in c)+(1,)

def mat(name,h,rough=.7,metal=0):
    m=bpy.data.materials.new(name); m.use_nodes=True; p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=color(h); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal; return m
ice=mat('fractured_blue_ice','4A9CB7',.33,.06); n=ice.node_tree.nodes; l=ice.node_tree.links; p=n.get('Principled BSDF')
uv=n.new('ShaderNodeTexCoord'); noise=n.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=6; noise.inputs['Detail'].default_value=4; l.new(uv.outputs['UV'],noise.inputs[0])
dis=n.new('ShaderNodeVectorMath'); dis.operation='SCALE'; dis.inputs[3].default_value=.11; l.new(noise.outputs['Color'],dis.inputs[0]); add=n.new('ShaderNodeVectorMath'); add.operation='ADD'; l.new(uv.outputs['UV'],add.inputs[0]); l.new(dis.outputs[0],add.inputs[1])
v=n.new('ShaderNodeTexVoronoi'); v.feature='DISTANCE_TO_EDGE'; v.inputs['Scale'].default_value=5.5; l.new(add.outputs[0],v.inputs['Vector'])
r=n.new('ShaderNodeValToRGB'); r.color_ramp.elements[0].position=.0015; r.color_ramp.elements[0].color=color('D1E9E9'); r.color_ramp.elements[1].position=.027; r.color_ramp.elements[1].color=color('609CB9'); middle=r.color_ramp.elements.new(.008); middle.color=color('96C7D6'); l.new(v.outputs['Distance'],r.inputs[0])
cloud=n.new('ShaderNodeMixRGB'); cloud.blend_type='MULTIPLY'; cloud.inputs[0].default_value=.22; l.new(r.outputs['Color'],cloud.inputs[1]); l.new(noise.outputs['Fac'],cloud.inputs[2]); l.new(cloud.outputs[0],p.inputs['Base Color'])
rough=n.new('ShaderNodeMapRange'); rough.inputs['To Min'].default_value=.19; rough.inputs['To Max'].default_value=.57; l.new(noise.outputs[0],rough.inputs[0]); l.new(rough.outputs[0],p.inputs['Roughness'])
bump=n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.18; bump.inputs['Distance'].default_value=.012; l.new(v.outputs['Distance'],bump.inputs['Height']); l.new(bump.outputs[0],p.inputs['Normal'])
bpy.ops.mesh.primitive_plane_add(size=1); plane=bpy.context.object; plane.data.materials.append(ice); baked={}
for channel,mode in [('basecolor','DIFFUSE'),('normal','NORMAL'),('roughness','ROUGHNESS')]:
    img=bpy.data.images.new('ice_'+channel,width=512,height=512,alpha=False)
    if channel!='basecolor': img.colorspace_settings.name='Non-Color'
    node=n.new('ShaderNodeTexImage'); node.image=img; n.active=node; bpy.ops.object.bake(type=mode,margin=4); img.filepath_raw=OUT+'/textures/ice_'+channel+'.png'; img.file_format='PNG'; img.save(); baked[channel]=img
bpy.data.objects.remove(plane,do_unlink=True)
for node in list(n):
    if node!=p and node.type!='OUTPUT_MATERIAL': n.remove(node)
for channel,img in baked.items():
    node=n.new('ShaderNodeTexImage'); node.image=img
    if channel=='normal':
        normal=n.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=.45; l.new(node.outputs[0],normal.inputs['Color']); l.new(normal.outputs[0],p.inputs['Normal'])
    else: l.new(node.outputs[0],p.inputs['Base Color' if channel=='basecolor' else 'Roughness'])
p.inputs['Emission Color'].default_value=color('16455A'); p.inputs['Emission Strength'].default_value=.14
metal=mat('frosted_dark_steel','334952',.69,.65)
stone=mat('rough_frozen_stone','364B54',.89)
p=stone.node_tree.nodes.get('Principled BSDF'); n=stone.node_tree.nodes; l=stone.node_tree.links
for channel in ['basecolor','normal','roughness']:
    img=bpy.data.images.load(ROOT+'/design/stage1_3d/environment/textures/weathered_stone_'+channel+'.png'); node=n.new('ShaderNodeTexImage'); node.image=img
    if channel=='normal':
        normal=n.new('ShaderNodeNormalMap'); l.new(node.outputs[0],normal.inputs['Color']); l.new(normal.outputs[0],p.inputs['Normal'])
    else: l.new(node.outputs[0],p.inputs['Base Color' if channel=='basecolor' else 'Roughness'])
frost=mat('edge_hoarfrost','C4DCE0',.9)
light=mat('refrigerant_cyan','399BB5',.35,.2); p=light.node_tree.nodes.get('Principled BSDF'); p.inputs['Emission Color'].default_value=color('348DA5'); p.inputs['Emission Strength'].default_value=.65

def empty(name,parent=None,loc=(0,0,0)):
    o=bpy.data.objects.new(name,None); scene.collection.objects.link(o); o.parent=parent; o.location=loc; return o
root=empty('turret_root'); head=empty('turret_head',root); barrel=empty('turret_barrel',head); muzzle=empty('muzzle',barrel,(0,-.12,.85))
def cylinder(name,radius,depth,z,material,verts=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=(0,0,z)); o=bpy.context.object; o.name=name; o.parent=root; o.data.materials.append(material); mod=o.modifiers.new('Machined worn edge','BEVEL'); mod.width=.012; mod.segments=2; bpy.ops.object.modifier_apply(modifier=mod.name); return o
cylinder('frozen_stone_foot',.39,.075,.0375,stone)
cylinder('steel_refrigeration_base',.32,.085,.1025,metal)
cylinder('cyan_cooling_seal',.269,.018,.153,light)
cylinder('dark_crystal_socket',.252,.048,.183,metal)

def shard(name,x,y,height,radius,seed,lean):
    rng=random.Random(seed); count=5; vs=[]
    angles=[i*math.tau/count+rng.uniform(-.08,.08) for i in range(count)]
    for z,scale in [(.19,.64),(.25,1),(height*.68,.78)]:
        for a in angles:
            rr=radius*scale*rng.uniform(.82,1.1); vs.append((x+math.cos(a)*rr+lean[0]*z,y+math.sin(a)*rr+lean[1]*z,z))
    vs.extend([(x+lean[0]*height+radius*.12,y+lean[1]*height-radius*.09,height)])
    faces=[tuple(reversed(range(count)))]
    for ring in range(2):
        for i in range(count): faces.append((ring*count+i,ring*count+(i+1)%count,(ring+1)*count+(i+1)%count,(ring+1)*count+i))
    for i in range(count): faces.append((10+i,10+(i+1)%count,15))
    me=bpy.data.meshes.new(name); me.from_pydata(vs,[],faces); me.materials.append(ice); ob=bpy.data.objects.new(name,me); scene.collection.objects.link(ob); ob.parent=barrel
    uv=me.uv_layers.new(name='Ice grain UV')
    for poly in me.polygons:
        for li in poly.loop_indices:
            co=me.vertices[me.loops[li].vertex_index].co; uv.data[li].uv=((co.x-x)*2.8+(co.y-y)*1.7+.45,co.z*.83)
    # Thin opaque frost on selected vertical ridges, no transparency dependency.
    frostverts=[]; frostfaces=[]
    for j in [0,2]:
        start=Vector(vs[5+j]); mid=Vector(vs[10+j]); tip=Vector(vs[15]); outward=Vector((math.cos(angles[j]),math.sin(angles[j]),0)); tangent=Vector((-outward.y,outward.x,0))*.003
        offset=outward*.0016; index=len(frostverts)
        for point in [start,mid,tip]: frostverts.extend([tuple(point+offset-tangent),tuple(point+offset+tangent)])
        frostfaces.extend([(index,index+1,index+3,index+2),(index+2,index+3,index+5,index+4)])
    fm=bpy.data.meshes.new(name+'_frost_mesh'); fm.from_pydata(frostverts,[],frostfaces); fm.materials.append(frost); fo=bpy.data.objects.new(name+'_frost_ridges',fm); scene.collection.objects.link(fo); fo.parent=barrel
    return ob
shard('main_fractured_ice',-.035,.035,.96,.123,111,(-.045,.045))
shard('front_ice_shard',.13,-.13,.64,.075,242,(.07,-.11))
shard('left_ice_shard',-.18,-.09,.55,.064,425,(-.10,-.09))
shard('rear_ice_shard',.12,.135,.76,.067,88,(.09,.11))
for i in range(5):
    a=i*math.tau/5; bpy.ops.mesh.primitive_cube_add(size=1,location=(math.cos(a)*.235,math.sin(a)*.235,.225)); o=bpy.context.object; o.name='dark_steel_crystal_clamp_'+str(i); o.dimensions=(.055,.085,.145); o.rotation_euler=(.15*math.sin(a),-.15*math.cos(a),a); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(metal); o.parent=head; mod=o.modifiers.new('Clamp bevel','BEVEL'); mod.width=.008; mod.segments=2; bpy.ops.object.modifier_apply(modifier=mod.name)
# Select only the hierarchy for GLB export; Blender -Y becomes glTF +Z.
bpy.ops.object.select_all(action='DESELECT'); root.select_set(True)
for ob in root.children_recursive: ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/images/stage1_3d/turrets/frost.glb',export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/frost.blend')
# Requested steep game-camera QA.
world=scene.world or bpy.data.worlds.new('World'); scene.world=world; world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.07,.10,.14,1); world.node_tree.nodes['Background'].inputs[1].default_value=.7
bpy.ops.object.light_add(type='AREA',location=(-2,-3,6)); bpy.context.object.data.energy=380; bpy.context.object.data.size=4
bpy.ops.object.light_add(type='AREA',location=(3,2,4)); bpy.context.object.data.energy=220; bpy.context.object.data.color=(.5,.76,1); bpy.context.object.data.size=3
bpy.ops.object.camera_add(location=(5,-13,27)); cam=bpy.context.object; cam.rotation_euler=(Vector((0,0,.36))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=1.42; scene.camera=cam
scene.render.resolution_x=900; scene.render.resolution_y=900; scene.render.resolution_percentage=100; scene.cycles.samples=40; scene.view_settings.view_transform='AgX'; scene.render.filepath=OUT+'/frost-steep-qa.png'; scene.render.image_settings.file_format='PNG'; bpy.ops.render.render(write_still=True)
print('FROST_DONE')
