import bpy,sys,shutil
from pathlib import Path
OUT=Path(__file__).resolve().parent;s=bpy.context.scene
mode=sys.argv[-1]
if mode=='stills':
    s.render.resolution_x=1000;s.render.resolution_y=1000;s.cycles.samples=32
    for f,name in [(17,'sniper-fire-shot.png'),(18,'sniper-fire-recoil.png'),(36,'sniper-fire-restored.png')]:
        s.frame_set(f);s.render.filepath=str(OUT/name);bpy.ops.render.render(write_still=True)
else:
    (OUT/'frames').mkdir(exist_ok=True)
    # Exact resting states repeat; reuse their rendered pixels, never interpolate
    # the active animation or substitute static images for movement.
    for f in [1]+list(range(10,37)):
        s.frame_set(f);s.render.filepath=str(OUT/'frames'/('frame-%04d.png'%f));bpy.ops.render.render(write_still=True)
    for f in list(range(2,10))+list(range(37,61)):
        shutil.copyfile(OUT/'frames/frame-0001.png',OUT/'frames'/('frame-%04d.png'%f))
