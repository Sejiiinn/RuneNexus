"""Mount this art study into the existing MCP-only Godot editor project."""
from pathlib import Path
import shutil

SOURCE = Path(__file__).resolve().parent
REPO = SOURCE.parents[3]
EDITOR = REPO / "build/godot/editor"
DEST = EDITOR / "previews/runic_fire"

if not (EDITOR / "project.godot").is_file():
    raise SystemExit("Prepare the Godot MCP editor project first; see .agents/godot_mcp_guide.md")

DEST.mkdir(parents=True, exist_ok=True)
for name in ("preview.gd", "preview.tscn", "body_fire.tscn"):
    target = DEST / name
    if target.is_symlink() and target.resolve() == SOURCE / name:
        continue
    if target.exists() or target.is_symlink():
        raise SystemExit(f"Preserving existing editor file: {target}")
    target.symlink_to(SOURCE / name)

(DEST / "model").mkdir(exist_ok=True)
shutil.copy2(REPO / "assets/images/stage1_3d/turrets/magic.glb", DEST / "model/magic.glb")
shutil.copy2(REPO / "godot/materials/battlefield_reflection_sky.tres", DEST / "model/battlefield_reflection_sky.tres")
(DEST / "atlas").mkdir(exist_ok=True)
for name in ("flame_flipbook.png", "ember.png"):
    shutil.copy2(SOURCE / "atlas" / name, DEST / "atlas" / name)
print(f"Prepared {DEST / 'preview.tscn'}")
