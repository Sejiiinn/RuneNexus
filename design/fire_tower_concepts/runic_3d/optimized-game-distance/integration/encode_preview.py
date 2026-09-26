"""Encode actual 30fps Godot frames. Existing reviewed wide video is preserved."""
from pathlib import Path
import subprocess,sys,json,hashlib
OUT=Path(__file__).resolve().parent
video=OUT/'runtime-fire-close-preview.mp4'
subprocess.run([sys.argv[1],'-y','-hide_banner','-loglevel','warning','-framerate','30','-start_number','1','-i',str(OUT/'frames/frame-%04d.png'),'-frames:v','100','-c:v','libx264','-preset','medium','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(video)],check=True)
record=OUT/'runtime-check.json';data=json.loads(record.read_text())
data['video']={'file':video.name,'frames':100,'fps':30,'size':[960,720],'duration_seconds':100/30,'sha256':hashlib.sha256(video.read_bytes()).hexdigest()}
data['reviewed_wide_video']='runtime-fire-preview.mp4'
record.write_text(json.dumps(data,indent=2)+'\n')
