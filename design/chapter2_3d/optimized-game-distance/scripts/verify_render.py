"""Reimport GLBs, save/reopen three packed editable artifacts and render A/B."""
import bpy,json,hashlib,sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parents[1];ROOT=OUT.parents[2];CHECKS=OUT/'checks'
ASSETS=('chapter2_tiles','chapter2_tiles_optimized','chapter2_tiles_expansion')
BLENDS=dict(zip(ASSETS,('chapter2-base-tiles-optimized.blend','chapter2-shared-tiles-optimized.blend','chapter2-expansion-tiles-optimized.blend')))
SOURCE=ROOT/'design/chapter2_3d/tiles/chapter2-tiles.blend'
def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path));return bpy.context.scene

def verify():
    records=[]
    for asset in ASSETS:
        path=CHECKS/f'{asset}-candidate.glb';scene=load(path)
        counts={o.name:len(o.data.polygons) for o in scene.objects if o.type=='MESH'}
        bpy.ops.file.pack_all();blend=OUT/BLENDS[asset];bpy.ops.wm.save_as_mainfile(filepath=str(blend));bpy.ops.wm.open_mainfile(filepath=str(blend))
        assert counts=={o.name:len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'}
        images=[i for i in bpy.data.images if i.type=='IMAGE' and i.users];assert len(images)==9;assert all(i.packed_file for i in images)
        records.append(dict(asset=asset,glb_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),packed_blend=str(blend.relative_to(ROOT)),packed_blend_sha256=hashlib.sha256(blend.read_bytes()).hexdigest(),reimported=True,saved_reopened=True,packed_images=len(images),triangles=sum(counts.values()),mesh_counts=counts))
    (CHECKS/'reimport-reopen.json').write_text(json.dumps(records,indent=2)+'\n')

def studio(scene):
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    world=bpy.data.worlds.new('C2 inherited studio');world.use_nodes=True;scene.world=world;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.11,.13,.17,1);bg.inputs[1].default_value=.5
    for name,loc,power,size in [('Key',(-3,-4,6),500,4),('Fill',(4,2,5),180,4)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.location=loc;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
    cam=bpy.data.objects.new('C2 comparison camera',bpy.data.cameras.new('C2 comparison camera'));scene.collection.objects.link(cam);scene.camera=cam;cam.data.type='ORTHO';cam.location=(3,-5,4.5);cam.rotation_euler=(Vector((0,0,-.15))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=3.7
    scene.render.resolution_x=1500;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
    return cam

def render(asset,label,names,filename,close=False):
    scene=load(CHECKS/f'{asset}-{label}.glb');selected=[bpy.data.objects[n] for n in names]
    for o in scene.objects:
        if o.type=='MESH':o.hide_render=True
    for i,root in enumerate(selected):
        root.location.x=(i-(len(selected)-1)/2)*1.12
        for o in [root,*root.children_recursive]:o.hide_render=False
    cam=studio(scene)
    if close:cam.location=(2.5,-6,2.1);cam.rotation_euler=(Vector((0,0,-.18))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=3.5
    scene.render.filepath=str(CHECKS/f'{label}-{filename}.png');bpy.ops.render.render(write_still=True)

def main():
    assert bpy.app.background;verify()
    for label in ('before','candidate'):
        render('chapter2_tiles',label,['path_tile','build_tile'],'base')
        render('chapter2_tiles_optimized',label,['path_tile_mask_2','path_tile_mask_15','build_tile_mask_15'],'masks',True)
        render('chapter2_tiles_expansion',label,['build_tile_mask_1','path_tile_mask_1','path_tile_mask_3'],'expansion',True)
    print('C2_REIMPORT_REOPEN_RENDER_COMPLETE',flush=True)
if __name__=='__main__':main()
