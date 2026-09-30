"""Adapted from runic_3d/vfx/encode_preview.py; actual Blender frames only."""
from pathlib import Path
import subprocess,sys
OUT=Path(__file__).resolve().parent;exe=sys.argv[1]
common=[exe,'-y','-hide_banner','-loglevel','warning']
one=OUT/'sniper-fire-single.mp4';preview=OUT/'sniper-fire-preview.mp4'
subprocess.run(common+['-framerate','30','-start_number','1','-i',str(OUT/'frames/frame-%04d.png'),'-frames:v','60','-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(one)],check=True)
subprocess.run(common+['-i',str(one),'-filter_complex','[0:v]split=3[a][b][c];[a]setpts=PTS-STARTPTS[a1];[b]setpts=PTS-STARTPTS[b1];[c]setpts=1.5*(PTS-STARTPTS)[c1];[a1][b1][c1]concat=n=3:v=1:a=0,fps=30[v]','-map','[v]','-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(preview)],check=True)
subprocess.run(common+['-i',str(preview),'-filter_complex','fps=30,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',str(OUT/'sniper-fire-preview.gif')],check=True)
print('ENCODED',one,preview)
