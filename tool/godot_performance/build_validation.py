#!/usr/bin/env python3
"""Build preview-only validation APK, restoring the production pack even on failure."""
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/godot/validation'
PACK = ROOT / 'build/godot/android-assets/rune_nexus.pck'
GODOT = ROOT / 'build/godot-preview/tools/Godot.app/Contents/MacOS/Godot'

def run(args, **kwargs):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, **kwargs)
    print(result.stdout, end="", flush=True)
    if re.search(r"(?:SCRIPT ERROR|Parse Error|^ERROR:)", result.stdout, re.MULTILINE):
        raise RuntimeError("Validation build reported a Godot error")

def main():
    run([sys.executable, 'scripts/build_godot_pack.py'])
    shutil.copytree(ROOT/'build/godot/project', OUT, dirs_exist_ok=True)
    shutil.copytree(ROOT/'tool/godot_performance/native', OUT/'validation', dirs_exist_ok=True)
    main_script = OUT/'main.gd'
    main_script.write_text(main_script.read_text().replace(
        'preload("res://ui/battlefield_selection.gd")',
        'preload("res://validation/range_comparison.gd")'))
    config = OUT/'project.godot'
    config.write_text(config.read_text().replace('run/main_scene="res://main.tscn"', 'run/main_scene="res://validation/entry.tscn"'))
    run([GODOT, '--headless', '--editor', '--path', OUT, '--import'])
    validation_pack = OUT.parent/'validation.pck'
    run([GODOT, '--headless', '--path', OUT, '--export-pack', 'Android Pack', validation_pack])
    backup = OUT.parent/'production-pack-validation-backup.pck'
    shutil.copy2(PACK, backup)
    try:
        shutil.copy2(validation_pack, PACK)
        env = dict(os.environ, WORK_DIR=str(ROOT), ORG_GRADLE_PROJECT_runeNexusGodotPreview='true')
        defines = [f'--dart-define={key}={env[key]}' for key in ['RN_VALIDATION_SCENARIO', 'RN_VALIDATION_SECONDS', 'RN_VALIDATION_HIDE_OVERLAY'] if key in env]
        run(['scripts/in_app_server_macos.sh', 'flutter', 'build', 'apk', '--release', '--target-platform', 'android-arm64', '--split-per-abi', '--no-tree-shake-icons', '-t', 'tool/godot_performance/validation_baseline.dart', '--dart-define=RUNE_NEXUS_DEBUG_PANEL=true', '--dart-define=RN_VALIDATION_HANDOFF=true', *defines], env=env)
        target = ROOT/'build/godot/validation.apk'
        shutil.copy2(ROOT/'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk', target)
        print(target)
    finally:
        shutil.copy2(backup, PACK)
        backup.unlink()

if __name__ == '__main__':
    main()
