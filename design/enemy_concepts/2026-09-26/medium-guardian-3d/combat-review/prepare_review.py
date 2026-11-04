"""Isolate the current app and its imported assets for guardian combat review."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
PROJECT = ROOT / 'build/guardian-combat-review-20260927/project'
if not (PROJECT / 'project.godot').exists():
    shutil.copytree(ROOT / 'build/godot/project', PROJECT, dirs_exist_ok=True)
shutil.copytree(ROOT / 'godot', PROJECT, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns('.godot', 'assets', '*.import', '*.uid'))
config = (PROJECT / 'project.godot').read_text()
config = config.replace('config/name="RuneNexus Battlefield"',
    'config/name="RuneNexus Guardian Review"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="RuneNexusGuardianReview20260927"')
(PROJECT / 'project.godot').write_text(config)
for source, name in [
    (OUT / 'medium-guardian-walk.glb', 'guardian_preview_walk.glb'),
    (OUT.parent / 'death/v4-whole-exit/medium-guardian-whole-exit.glb', 'guardian_preview_death.glb'),
]:
    if source.exists(): shutil.copy2(source, PROJECT / 'assets/enemies' / name)
for name in ('capture_combat.gd',):
    if (OUT / name).exists(): shutil.copy2(OUT / name, PROJECT / name)
print(PROJECT)
