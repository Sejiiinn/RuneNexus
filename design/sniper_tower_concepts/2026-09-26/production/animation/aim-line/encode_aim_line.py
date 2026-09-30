"""Encode actual 30 fps Blender tracking frames; no slow motion."""
from pathlib import Path
import subprocess,sys
OUT=Path(__file__).resolve().parent;exe=sys.argv[1]
common=[exe,'-y','-hide_banner','-loglevel','warning']
video=OUT/'sniper-aim-line-preview.mp4'
subprocess.run(common+['-framerate','30','-start_number','1','-i',str(OUT/'frames/frame-%04d.png'),'-frames:v','120','-c:v','libx264','-preset','medium','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(video)],check=True)
subprocess.run(common+['-i',str(video),'-filter_complex','fps=30,scale=700:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',str(OUT/'sniper-aim-line-preview.gif')],check=True)
print('AIM_LINE_VIDEO_READY')
