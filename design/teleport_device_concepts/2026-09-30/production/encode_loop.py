"""Encode the existing Blender render frames; does not alter the source."""
from pathlib import Path
import argparse, shutil, subprocess

here=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--ffmpeg',default=shutil.which('ffmpeg'))
args=parser.parse_args()
if not args.ffmpeg:parser.error('Pass --ffmpeg /absolute/path/to/ffmpeg')
frames=list((here/'_frames').glob('frame-*.png'))
if len(frames)!=96:raise RuntimeError(f'Expected 96 rendered frames, found {len(frames)}')
subprocess.run([args.ffmpeg,'-y','-framerate','24','-start_number','1','-i',str(here/'_frames/frame-%04d.png'),'-frames:v','96','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(here/'four-variants-loop.mp4')],check=True)
