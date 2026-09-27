"""Use the shipping asset preparation path in an isolated review project."""
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[6]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))
import prepare_godot_project as staging

staging.PROJECT = ROOT / "build/fast-hound-game-20260928/project"
staging.ASSETS = staging.PROJECT / "assets"
project = staging.prepare()
config = (project / "project.godot").read_text()
config = config.replace('config/name="RuneNexus Battlefield"',
    'config/name="RuneNexus Fast Hound Review"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="RuneNexusFastHoundReview20260928"')
(project / "project.godot").write_text(config)
shutil.copy2(OUT / "capture_death.gd", project / "capture_death.gd")
print(project)
