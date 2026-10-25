"""Encode the raw RGB frames from capture_support_core.gd (--gif --video) into an MP4 and a GIF with ffmpeg.

~/.venvs/media-tools/bin/python make_video.py <gif-frames dir> <output stem>
ffmpeg comes from the imageio-ffmpeg wheel (static build, no Homebrew): python3 -m venv ~/.venvs/media-tools
&& ~/.venvs/media-tools/bin/pip install imageio-ffmpeg. Writes <stem>.mp4 (H.264, yuv420p, plays on phones)
and <stem>.gif (half size, 20 fps, per-run palette with error diffusion).
"""
import json, subprocess, sys
from pathlib import Path

import imageio_ffmpeg


def main(source, stem):
    info = json.loads((source / 'frames.json').read_text())
    w, h, count, fps = info['width'], info['height'], info['count'], info['fps']
    raw = b''.join((source / f'{i:03d}.rgb').read_bytes() for i in range(count))
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    source_args = ['-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{w}x{h}', '-r', str(fps), '-i', '-']
    even = f'crop={w - w % 2}:{h - h % 2}:0:0'
    subprocess.run([ffmpeg, '-y', '-loglevel', 'error', *source_args, '-vf', even, '-c:v', 'libx264',
                    '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                    str(stem.with_suffix('.mp4'))], input=raw, check=True)
    gif = (f'fps=20,scale={w // 2}:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=full[p];'
           '[b][p]paletteuse=dither=sierra2_4a')
    subprocess.run([ffmpeg, '-y', '-loglevel', 'error', *source_args, '-vf', gif, '-loop', '0',
                    str(stem.with_suffix('.gif'))], input=raw, check=True)
    for suffix in ('.mp4', '.gif'):
        path = stem.with_suffix(suffix)
        print('VIDEO', path, w, h, count, fps, path.stat().st_size)


if __name__ == '__main__':
    main(Path(sys.argv[1]), Path(sys.argv[2]))
