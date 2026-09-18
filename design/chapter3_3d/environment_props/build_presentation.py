"""Blender-only mounted review scene; append copies of approved sources."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Matrix, Vector
HERE=Path(__file__).resolve().parent
TILES=HERE.parent/'tiles/chapter3-thick-tiles.blend'
PROPS=HERE/'foundry-props.blend'
assert bpy.app.background
hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (TILES,PROPS)}
bpy.ops.wm.read_factory_settings(use_empty=True)
def read_objects(path):
    with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.objects=src.objects
    return {o.name:o for o in dst.objects if o}
tile_lib=read_objects(TILES)
prop_lib=read_objects(PROPS)
def empty(name,loc=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.scene.collection.objects.link(o);o.location=loc;return o
def copy_hierarchy(source,parent):
    for ob in source.children:
        clone=ob.copy()
        bpy.context.scene.collection.objects.link(clone);clone.parent=parent
        clone.matrix_parent_inverse=Matrix.Identity(4)
        clone.hide_render=False;clone.hide_set(False)
        copy_hierarchy(ob,clone)
def copy_parts(source,parent,angle=0):
    for ob in source.children:
        clone=ob.copy();bpy.context.scene.collection.objects.link(clone);clone.parent=parent
        clone.matrix_parent_inverse=Matrix.Identity(4)
        clone.matrix_basis=Matrix.Rotation(angle,4,'Z')@ob.matrix_basis
        clone.hide_render=False;clone.hide_set(False)
def tile(name,loc,kind):
    root=empty(name,loc);copy_parts(tile_lib[kind],root)
    for i in range(4):copy_parts(tile_lib['05_Panel_solid'],root,i*math.pi/2)
    return root
iron=bpy.data.materials.get('Recess walls | forged iron')
edge=bpy.data.materials.get('Exposed worn iron edges')
def prism(name,verts,faces,parent,mat):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.scene.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat)
    b=o.modifiers.new('Rounded iron edges','BEVEL');b.width=.006;b.segments=3
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return o
def box(name,center,dim,parent,mat):
    x,y,z=center;w,d,h=[v/2 for v in dim]
    v=[(x+a*w,y+b*d,z+c*h) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return prism(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],parent,mat)
mounts=[]
for idx,(kind,prop_name) in enumerate([('04_Plain_construction_foundation','elbow_pipe'),('02_Heat_vent_grate','side_conduit'),('04_Plain_construction_foundation','exhaust_vent')]):
    root=tile('Mount '+prop_name,((idx-1)*1.65,0,0),kind)
    mount=empty(prop_name+' mounted');mount.parent=root
    mount.location=(0,-.45,0)
    copy_hierarchy(prop_lib[prop_name],mount);mounts.append(mount)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.world=bpy.data.worlds.new('Foundry neutral studio');scene.world.use_nodes=True
bg=scene.world.node_tree.nodes.get('Background');bg.inputs[0].default_value=(.15,.18,.20,1);bg.inputs[1].default_value=.40
for name,loc,power,size in [('Key',(-3,-4,6),750,4),('Fill',(4,-1,4),300,3),('Rim',(0,4,5),500,3)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
ground=bpy.data.materials.new('Charcoal background');ground.use_nodes=True;p=ground.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.022,.030,.034,1);p.inputs['Roughness'].default_value=.9
box('Studio floor',(0,0,-.545),(200,200,.05),None,ground)
d=bpy.data.cameras.new('Mounted review');cam=bpy.data.objects.new('Mounted review',d);scene.collection.objects.link(cam);scene.camera=cam;d.type='ORTHO';d.ortho_scale=5.7
scene.render.resolution_x=2000;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
report={'source_hashes':hashes,'props':{}}
for o in mounts:
    def meshes(node):
        return ([node] if node.type=='MESH' else [])+sum((meshes(c) for c in node.children),[])
    bpy.context.view_layer.update()
    points=[o.matrix_world.inverted()@m.matrix_world@Vector(v) for m in meshes(o) for v in m.bound_box]
    report['props'][o.name]={'bounds':[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)],'mount':list(o.location)}
cam.location=(3.8,-7,5.9);cam.rotation_euler=(Vector((0,-.15,-.10))-cam.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'mounted-scene.blend'))
assert hashes=={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (TILES,PROPS)}
(HERE/'presentation-check.json').write_text(json.dumps(report,indent=2))
print('MOUNTED_REVIEW_READY',flush=True)
