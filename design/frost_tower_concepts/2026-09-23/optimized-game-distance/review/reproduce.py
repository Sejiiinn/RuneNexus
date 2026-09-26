"""Capture current Godot source against existing prepared assets without replacing game files.
Run from the RuneNexus repository root after normal asset preparation.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import json
import hashlib
import struct
import sys

repo = Path.cwd()
review = Path(__file__).resolve().parent
godot = repo / "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot"
prepared = repo / "build/godot/project"
with tempfile.TemporaryDirectory(prefix="runenexus-frost-s26-qhd-") as directory:
    baseline = Path(directory) / "original-frost.glb"
    data = subprocess.check_output(["git", "show", "1bb0c1365481d05183c6c4110310a35add423a25:assets/images/stage1_3d/turrets/frost.glb"], cwd=repo)
    assert hashlib.sha256(data).hexdigest() == "e84d5a97650056d139fd6a61868e621042955937d0584c996416dc6cc59a8544"
    baseline.write_bytes(data)
    project = Path(directory) / "project"
    shutil.copytree(repo / "godot", project,
                    ignore=shutil.ignore_patterns(".godot", "assets", "*.uid"))
    (project / "assets").symlink_to(prepared / "assets", target_is_directory=True)
    (project / ".godot").mkdir()
    (project / ".godot/imported").symlink_to(prepared / ".godot/imported", target_is_directory=True)
    for name in ["global_script_class_cache.cfg", "uid_cache.bin"]:
        source = prepared / ".godot" / name
        if source.exists():
            shutil.copy2(source, project / ".godot" / name)
    subprocess.run([str(godot), "--path", str(project), "--resolution", "440x760",
                    "--script", str(review / "capture_compare.gd"), "--", "--fixture",
                    "--original=" + str(baseline), "--optimized=" + str(Path(sys.argv[1]).resolve())], check=True, timeout=150)
    subprocess.run([str(godot), "--headless", "--path", str(project),
                    "--script", str(review / "pack_native.gd")], check=True, timeout=150)
