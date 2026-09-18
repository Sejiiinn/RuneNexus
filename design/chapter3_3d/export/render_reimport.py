"""Render actual six-root GLB with exchanged panels and open-seat depth proof."""
import bpy,math,json
from mathutils import Vector
from pathlib import Path
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'tiles/chapter3-thick-tiles.blend'))
s=bpy.context.scene
for ob in list(s.objects):
 if ob.type not in ('LIGHT','CAMERA') and ob.name!='Studio ground':bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/images/stage1_3d/environment/chapter3_tiles.glb'))
names=('path_tile','grate_tile','build_tile','plain_build_tile')
panels={name:bpy.data.objects[name] for name in ('panel_solid','panel_vent')}
def mount(tile,side,vent=False):
 ob=panels['panel_vent' if vent else 'panel_solid'].copy();ob.data=ob.data.copy();s.collection.objects.link(ob);ob.location=tile.location;ob.rotation_mode='XYZ';ob.rotation_euler.z=side*math.pi/2
 return ob
for i,name in enumerate(names):
 tile=bpy.data.objects[name];tile.location=((i-1.5)*1.22,0,0)
 for side in range(4):mount(tile,side,i in (1,3) and side==0)
for ob in panels.values():ob.hide_render=True
s.cycles.samples=32;s.render.resolution_percentage=100;s.render.filepath=str(OUT/'glb-reimport-hero.png');bpy.ops.render.render(write_still=True)
for ob in list(s.objects):
 if ob.type=='MESH' and ob.name!='Studio ground' and ob not in panels.values():ob.hide_render=True
plain=bpy.data.objects['plain_build_tile']
for i,kind in enumerate(('empty','solid','vent')):
 tile=plain.copy();tile.data=plain.data;s.collection.objects.link(tile);tile.hide_render=False;tile.location=((i-1)*1.12,0,0)
 for side in range(4):
  if kind=='empty' and side==0:continue
  ob=mount(tile,side,kind=='vent' and side==0);ob.hide_render=False
cam=s.camera;cam.location=(1.5,-8,1.9);cam.rotation_euler=(Vector((0,0,-.22))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=3.7
s.render.resolution_x=1600;s.render.resolution_y=720;s.render.filepath=str(OUT/'glb-reimport-panel-depth.png');bpy.ops.render.render(write_still=True)
print('REIMPORT_RENDERS_READY',flush=True)
