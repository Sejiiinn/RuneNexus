"""Reopen packed editable artifact; inspect geometry and render actual GLBs.

The inherited approved source studio is read-only. Render comparisons use the
same source camera, lighting and Cycles settings for baseline and candidate.
"""
import bpy, json, math, sys, hashlib, argparse
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
import optimize_tiles as opt
OUT=opt.OUT;ROOT=opt.ROOT
parser=argparse.ArgumentParser()
parser.add_argument('--before',type=Path,default=OUT/'checks/chapter3_tiles-current.glb')
parser.add_argument('--candidate',type=Path,default=OUT/'checks/error002-hybrid.glb')
parser.add_argument('--before-label',default='before')
parser.add_argument('--after-label',default='after')
parser.add_argument('--skip-validate',action='store_true')
parser.add_argument('--validate-only',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
BASE=args.before.resolve();AFTER=args.candidate.resolve()
SOURCE=OUT.parent/'tiles/chapter3-thick-tiles.blend'
NAMES=('path_tile','grate_tile','build_tile','plain_build_tile','panel_solid','panel_vent')

def load(path):
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    s=bpy.context.scene
    for ob in list(s.objects):
        if ob.type not in ('LIGHT','CAMERA') and ob.name!='Studio ground':bpy.data.objects.remove(ob,do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes={n:bpy.data.objects[n] for n in NAMES}
    return s,meshes

def mount(s,meshes,tile,side,vent=False):
    ob=meshes['panel_vent' if vent else 'panel_solid'].copy();s.collection.objects.link(ob);ob.location=tile.location;ob.rotation_euler.z=side*math.pi/2
    return ob

def render(path,label):
    s,meshes=load(path)
    for i,name in enumerate(NAMES[:4]):
        tile=meshes[name];tile.location=((i-1.5)*1.22,0,0)
        for side in range(4):mount(s,meshes,tile,side,i in (1,3) and side==0)
    for name in NAMES[4:]:meshes[name].hide_render=True
    s.cycles.samples=32;s.render.resolution_percentage=100
    s.render.filepath=str(OUT/'checks'/f'{label}-hero.png');bpy.ops.render.render(write_still=True)
    for ob in list(s.objects):
        if ob.type=='MESH' and ob.name!='Studio ground':ob.hide_render=True
    for i,kind in enumerate(('empty','solid','vent')):
        tile=meshes['plain_build_tile'].copy();s.collection.objects.link(tile);tile.hide_render=False;tile.location=((i-1)*1.12,0,0)
        for side in range(4):
            if kind=='empty' and side==0:continue
            ob=mount(s,meshes,tile,side,kind=='vent' and side==0);ob.hide_render=False
    cam=s.camera;cam.location=(1.5,-8,1.9);cam.rotation_euler=(Vector((0,0,-.22))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=3.7
    s.render.resolution_x=1600;s.render.resolution_y=720;s.render.filepath=str(OUT/'checks'/f'{label}-seats.png');bpy.ops.render.render(write_still=True)

def validate():
    s,meshes=load(AFTER)
    checks={}
    for name,ob in meshes.items():
        me=ob.data;me.calc_loop_triangles()
        vertices=[v.co for v in me.vertices];faces=[t.vertices for t in me.loop_triangles]
        bv=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
        rays=[]
        if name in NAMES[:4]:
            for side in range(4):
                a=side*math.pi/2
                point=Vector((.072,-1,-.28));direction=Vector((0,1,0))
                point=Vector((point.x*math.cos(a)-point.y*math.sin(a),point.x*math.sin(a)+point.y*math.cos(a),point.z));direction=Vector((-math.sin(a),math.cos(a),0))
                hit=bv.ray_cast(point,direction,2)
                assert hit[0] is None or hit[3]>=.67,(name,side,hit)
                rays.append(None if hit[0] is None else hit[3])
        else:
            hit=bv.ray_cast(Vector((.072,-1,-.28)),Vector((0,1,0)),2)
            expected=-.465 if name=='panel_vent' else -.452
            assert abs(hit[0].y-expected)<1e-5,(name,hit)
            rays.append(hit[0].y)
        checks[name]={'triangles':len(faces),'seat_or_aperture_rays':rays}
    # Keep only the six editable runtime meshes; the studio and preview mounts
    # are not game geometry and do not enter the final packed artifact.
    for ob in list(bpy.data.objects):
        if ob not in meshes.values():bpy.data.objects.remove(ob,do_unlink=True)
    bpy.ops.file.pack_all()
    blend=OUT/'chapter3-tiles-optimized.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    assert {o.name for o in bpy.context.scene.objects}==set(NAMES)
    assert len([im for im in bpy.data.images if im.type=='IMAGE' and im.users])==4
    assert all(im.packed_file for im in bpy.data.images if im.type=='IMAGE' and im.users)
    for name in NAMES:
        me=bpy.data.objects[name].data;me.calc_loop_triangles();assert len(me.loop_triangles)==checks[name]['triangles']
    return checks,blend


def main():
    source_sha=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    if not args.skip_validate:
        checks,blend=validate()
        (OUT/'checks/reimport-reopen.json').write_text(json.dumps({'candidate':str(AFTER.relative_to(ROOT)),'candidate_sha256':hashlib.sha256(AFTER.read_bytes()).hexdigest(),'reimport':checks,'packed_blend':str(blend.relative_to(ROOT)),'saved_reopened':True,'packed_images':4,'source_sha256':source_sha},indent=2)+'\n')
    if not args.validate_only:
        for path,label in [(BASE,args.before_label),(AFTER,args.after_label)]:render(path,label)
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_sha
    print('RENDER_VERIFY_COMPLETE',flush=True)

if __name__=='__main__':main()
