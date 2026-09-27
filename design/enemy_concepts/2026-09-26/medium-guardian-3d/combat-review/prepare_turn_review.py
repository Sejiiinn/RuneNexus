"""Use the shipping asset preparation path in an isolated review project."""
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))
import prepare_godot_project as staging

staging.PROJECT = ROOT / "build/guardian-turn-review-20260927/project"
staging.ASSETS = staging.PROJECT / "assets"
project = staging.prepare()
config = (project / "project.godot").read_text()
config = config.replace('config/name="RuneNexus Battlefield"',
    'config/name="RuneNexus Guardian Turn Review"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="RuneNexusGuardianTurnReview20260927"')
(project / "project.godot").write_text(config)
shutil.copy2(OUT / "capture_turn.gd", project / "capture_turn.gd")
print(project)
