"""Record the Godot art scene with Movie Maker, then encode a review MP4.

Pass an installed FFmpeg binary as the first argument. This is a deterministic
visual recording, never a performance measurement. Stop the editor game first.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

SOURCE = Path(__file__).resolve().parent
REPO = SOURCE.parents[3]
GODOT = REPO / "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot"
EDITOR = REPO / "build/godot/editor"

if len(sys.argv) != 2:
    raise SystemExit("Usage: python3 capture_preview.py /absolute/path/to/ffmpeg")

with tempfile.TemporaryDirectory(prefix="runic-flipbook-movie-") as temporary:
    movie = Path(temporary) / "preview.avi"
    with (SOURCE / "movie-render.log").open("w") as log:
        subprocess.run([
            str(GODOT), "--path", str(EDITOR),
            "--write-movie", str(movie), "--fixed-fps", "30",
            "res://previews/runic_fire/preview.tscn", "--", "--capture",
        ], stdout=log, stderr=subprocess.STDOUT, check=True)
    subprocess.run([
        sys.argv[1], "-y", "-hide_banner", "-loglevel", "warning",
        "-i", str(movie), "-ss", "1", "-an", "-c:v", "libx264",
        "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
        str(SOURCE / "godot-flame-preview.mp4"),
    ], check=True)
print(SOURCE / "godot-flame-preview.mp4")
