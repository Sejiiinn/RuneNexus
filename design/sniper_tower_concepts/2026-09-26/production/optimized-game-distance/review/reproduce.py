"""Capture current Godot source against existing prepared assets without replacing game files.
Run from the RuneNexus repository root after normal asset preparation.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path.cwd()
review = Path(__file__).resolve().parent
godot = repo / "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot"
prepared = repo / "build/godot/project"
with tempfile.TemporaryDirectory(prefix="runenexus-swift-comparison-") as directory:
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
    subprocess.run([str(godot), "--path", str(project), "--resolution", "440x900",
                    "--script", str(review / "capture_compare.gd"), "--", "--fixture",
                    "--optimized=" + str(review.parent / "sniper-swift-optimized.glb")], check=True)
    subprocess.run([str(godot), "--headless", "--path", str(project),
                    "--script", str(review / "pack_native.gd")], check=True)
