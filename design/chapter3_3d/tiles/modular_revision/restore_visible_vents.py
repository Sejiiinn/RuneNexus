"""Restore three readable vertical orange slots without altering other roots."""
import bpy, math, json, hashlib, shutil
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'chapter3-thick-tiles.blend'

def reshape_vent(root):
    for ob in root.children:
        name = ob.name
        bounds = None
        if name.startswith('Panel frame upper'):
            bounds = ((-.146,.146),(-.485,-.425),(-.185,-.157))
        elif name.startswith('Panel frame lower'):
            bounds = ((-.146,.146),(-.485,-.425),(-.403,-.385))
        elif name.startswith('Panel frame left'):
            bounds = ((-.146,-.108),(-.485,-.425),(-.385,-.185))
        elif name.startswith('Panel frame right'):
            bounds = ((.108,.146),(-.485,-.425),(-.385,-.185))
        elif name.startswith('Seat inner return'):
            bounds = (None,(-.425,-.355),(-.385,-.185))
        elif name.startswith('Vent mullion'):
            bounds = (None,(-.485,-.425),(-.385,-.185))
        elif name.startswith('Vent cavity back'):
            bounds = (None,None,(-.400,-.185))
        elif name.startswith('Recessed vent heat core'):
            center = (min(v.co.x for v in ob.data.vertices)+max(v.co.x for v in ob.data.vertices))/2
            bounds = ((center-.022,center+.022),(-.465,-.453),(-.393,-.192))
        if bounds:
            for axis, target in enumerate(bounds):
                if target is None: continue
                lo=min(v.co[axis] for v in ob.data.vertices)
                hi=max(v.co[axis] for v in ob.data.vertices)
                for v in ob.data.vertices:
                    v.co[axis]=target[0]+(v.co[axis]-lo)/(hi-lo)*(target[1]-target[0])
    root['heatRecession']=.020
    root['ventApertureHeight']=.200

def root_hash(root):
    values=[]
    for ob in sorted(root.children,key=lambda o:o.name):
        values.append((ob.name, [tuple(v.co) for v in ob.data.vertices]))
    return hashlib.sha256(repr(values).encode()).hexdigest()

def main():
    assert bpy.app.background
    backup=HERE/'before-readable-vents.blend'
    if not backup.exists(): shutil.copy2(SOURCE,backup)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    unchanged=[bpy.data.objects[n] for n in ('01_Cast_iron_plate','02_Heat_vent_grate','03_Construction_foundation','04_Plain_construction_foundation','05_Panel_solid')]
    before={r.name:root_hash(r) for r in unchanged}
    reshape_vent(bpy.data.objects['06_Panel_vent'])
    assert before=={r.name:root_hash(r) for r in unchanged}
    (HERE/'vent-preservation.json').write_text(json.dumps({'unchanged_root_geometry_sha256':before,'frame_front':-.485,'heat_front':-.465,'recession':.020,'heat_width':.044,'heat_height':.201},indent=2)+'\n')
    s=bpy.context.scene;cam=s.camera
    cam.location=(0,-7,7*math.tan(math.radians(55))-.18)
    cam.rotation_euler=(Vector((0,0,-.18))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=5.25;s.cycles.samples=32
    s.render.resolution_x=1800;s.render.resolution_y=950
    s.render.filepath=str(HERE/'vent-55deg-source.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.render.render(write_still=True)
    print('READABLE_VENT_SOURCE_READY',flush=True)

if __name__=='__main__': main()
