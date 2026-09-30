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

repo = Path.cwd()
review = Path(__file__).resolve().parent
godot = repo / "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot"
prepared = repo / "build/godot/project"
with tempfile.TemporaryDirectory(prefix="runenexus-swift-s26-qhd-") as directory:
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
                    "--optimized=" + str(review.parent.parent / "sniper-swift-optimized.glb")], check=True)
    subprocess.run([str(godot), "--headless", "--path", str(project),
                    "--script", str(review / "pack_native.gd")], check=True)

baseline = json.loads((review.parent / "asset-comparison.json").read_text())
paths = {"original": review.parents[2] / "sniper-c-preview.glb",
         "optimized": review.parents[1] / "sniper-swift-optimized.glb"}
hashes = {key: hashlib.sha256(path.read_bytes()).hexdigest() for key, path in paths.items()}
assert all(hashes[key] == baseline[key]["sha256"] for key in hashes)
conditions_path = review / "capture-conditions.json"
conditions = json.loads(conditions_path.read_text())
conditions.update({"asset_sha256": hashes, "asset_hashes_match_previous_review": True,
                   "godot_version": "4.7.2.stable.official.ed1daf0bf",
                   "gpu": "Apple M4 / Metal 4.0 / Forward Mobile",
                   "screen_spec": "Samsung Galaxy S26 Ultra QHD+ 1440x3120, not a physical device capture",
                   "image_sizes": {}})
for image in review.glob("*.png"):
    dimensions = list(struct.unpack(">II", image.read_bytes()[16:24]))
    conditions["image_sizes"][image.name] = dimensions
    if image.name.endswith("-full.png"):
        assert dimensions == [1440, 3120]
conditions["verified_3d_internal_size"] = [round(value * conditions["scaling_3d_scale"])
                                            for value in conditions["physical_render_target"]]
conditions_path.write_text(json.dumps(conditions, ensure_ascii=False, indent=2) + "\n")
