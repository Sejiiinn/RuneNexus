import bpy,sys,shutil
from pathlib import Path
OUT=Path(__file__).resolve().parent;s=bpy.context.scene
if sys.argv[-1]=='stills':
    s.cycles.samples=24
    for f,name in [(32,'sniper-aim-line.png'),(51,'sniper-aim-shot.png'),(95,'sniper-aim-idle.png')]:
        s.frame_set(f);s.render.filepath=str(OUT/name);bpy.ops.render.render(write_still=True)
else:
    (OUT/'frames').mkdir(exist_ok=True)
    for f in range(1,86):
        s.frame_set(f);s.render.filepath=str(OUT/'frames'/('frame-%04d.png'%f));bpy.ops.render.render(write_still=True)
    for f in range(86,121):shutil.copyfile(OUT/'frames/frame-0085.png',OUT/'frames'/('frame-%04d.png'%f))
