import bpy,math,random,os
from mathutils import Vector
ROOT='/Users/sejin/Documents/Codex/RuneNexus'; OUT=ROOT+'/design/stage1_3d/environment'; ASSET=ROOT+'/assets/images/stage1_3d/environment/terrain.glb'
bpy.ops.wm.open_mainfile(filepath=OUT+'/terrain-approved.blend')
s=bpy.context.scene
for rootname in ['build_tile','path_tile','blocked_tile']:
 root=bpy.data.objects.get(rootname)
 for ob in list(root.children_recursive):bpy.data.objects.remove(ob,do_unlink=True)
 bpy.data.objects.remove(root,do_unlink=True)
stone=bpy.data.materials['C1_mossy_PBR_stone'];road=bpy.data.materials['C1_worn_earth_cobbles'];wall=bpy.data.materials['C1_natural_rock_faces']
def block(name,root,center,size,material,seed,topmat=None):
 rng=random.Random(seed);x,y,z=size;corners=[(-x*.43,-y*.5),(x*.42,-y*.5),(x*.5,-y*.4),(x*.5,y*.43),(x*.4,y*.5),(-x*.43,y*.5),(-x*.5,y*.4),(-x*.5,-y*.41)]
 corners=[(max(-x/2,min(x/2,a+rng.uniform(-.011,.011))),max(-y/2,min(y/2,b+rng.uniform(-.011,.011)))) for a,b in corners]
 # Keep the tile's exact 1×1 footprint and top reference plane.
 heights=[rng.uniform(-.003,0) for _ in corners] if topmat else [0]*8
 highest=max(heights);heights=[v-highest for v in heights]
 verts=[(a,b,-z/2) for a,b in corners]+[(a,b,z/2+heights[i]) for i,(a,b) in enumerate(corners)];faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(material)
 if topmat:mesh.materials.append(topmat);mesh.polygons[1].material_index=1
 ob=bpy.data.objects.new(name,mesh);s.collection.objects.link(ob);ob.parent=root;ob.location=center;uv=mesh.uv_layers.new(name='UVMap')
 for poly in mesh.polygons:
  axis=max(range(3),key=lambda a:abs(poly.normal[a]))
  for li in poly.loop_indices:
   v=mesh.vertices[mesh.loops[li].vertex_index].co
   uv.data[li].uv=(v.x+.5,v.y+.5) if axis==2 else (v.y+.5,v.z*2+.5) if axis==0 else (v.x+.5,v.z*2+.5)
 mod=ob.modifiers.new('natural stone edge','BEVEL');mod.width=.009 if topmat else .020;mod.segments=2;bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name)
 if topmat:
  delta=z/2-max(v.co.z for v in ob.data.vertices)
  for v in ob.data.vertices:
   if v.co.z>0:v.co.z+=delta
 ob.select_set(False);return ob
roots=[]
for name,top in [('build_tile',stone),('path_tile',road),('blocked_tile',wall)]:
 root=bpy.data.objects.new(name,None);s.collection.objects.link(root);roots.append(root)
 surface=block(name+'_natural_surface',root,(0,0,-.167),(1,1,.334),wall,10,top)
 # Embedded low natural-rock faces; they stay beneath the playable top surface.
 fragments=[]
 for j in range(8):
  edge=j//2;along=(-.25,.25)[j%2];x,y=[(along,-.445),(.445,along),(along,.445),(-.445,along)][edge]
  f=block(name+'_natural_edge',root,(x,y,-.151),(.11 if edge%2 else .29,.29 if edge%2 else .11,.19),wall,100+j);fragments.append(f)
 if name=='build_tile':
  rng=random.Random(163)
  moss=bpy.data.materials.get('C1_edge_moss') or bpy.data.materials.new('C1_edge_moss');moss.diffuse_color=(.043,.105,.026,1);moss.use_nodes=True;p=moss.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.043,.105,.026,1);p.inputs['Roughness'].default_value=.94
  for j in range(12):
   angle=rng.random()*math.tau;radius=rng.uniform(.39,.465);x=math.cos(angle)*radius;y=math.sin(angle)*radius
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,y,.004));o=bpy.context.object;o.name='build_tile_edge_moss';o.scale=(rng.uniform(.015,.035),rng.uniform(.012,.031),.008);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.parent=root;o.data.materials.append(moss);fragments.append(o)
 bpy.ops.object.select_all(action='DESELECT');surface.select_set(True)
 for o in fragments:o.select_set(True)
 bpy.context.view_layer.objects.active=surface;bpy.ops.object.join()
bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=ASSET,export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/terrain-approved.blend')

print('GEOMETRY_RESTORED')
