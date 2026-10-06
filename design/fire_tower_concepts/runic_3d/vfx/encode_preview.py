"""Encode Blender renders into a captioned MP4 and looping GIF."""
from pathlib import Path
import subprocess,sys
P=Path(__file__).resolve().parent
exe=sys.argv[1]
font='/System/Library/Fonts/AppleSDGothicNeo.ttc'
def text(label,y,size,enable=None,color='0xE9EEE8'):
    result=f"drawtext=fontfile='{font}':text='{label}':x=32:y={y}:fontsize={size}:fontcolor={color}:shadowcolor=black@0.25:shadowx=1:shadowy=1"
    if enable:result+=f":enable='{enable}'"
    return result
filters=[text('룬 화염 포탑',28,28),
 text('상부 불꽃',69,19,'lt(t,1.208)+between(t,2.7,3.875)+gte(t,5.3)','0xB8CAC1'),
 text('화구 · 발사',69,19,'between(t,1.208,1.5)+between(t,3.875,4.17)','0xFFD396'),
 text('화염 발사체 · 잔불',69,19,'between(t,1.5,2.7)+between(t,4.17,5.3)','0xFFD396')]
video=P/'runic-flame-vfx.mp4'
subprocess.run([exe,'-y','-hide_banner','-loglevel','warning','-framerate','24','-start_number','1','-i',str(P/'frames/frame-%04d.png'),'-vf',','.join(filters),'-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(video)],check=True)
subprocess.run([exe,'-y','-hide_banner','-loglevel','warning','-i',str(video),'-filter_complex','fps=12,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',str(P/'runic-flame-vfx.gif')],check=True)
