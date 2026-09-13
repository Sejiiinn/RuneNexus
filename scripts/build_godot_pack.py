#!/usr/bin/env python3
"""Android 본게임과 검수 앱에 공통 Godot 전장을 증분 패키징한다."""

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/godot"
PROJECT = BUILD / "project"
PACK = BUILD / "android-assets/rune_nexus.pck"
STAMP = BUILD / "pack-inputs.json"
VERSION = "4.7.2.stable"


def input_digest():
    inputs = [Path(__file__), ROOT / "scripts/prepare_godot_project.py"]
    inputs += [ROOT / "assets/images/diamond_currency.png", ROOT / "assets/fonts/NotoSansKR-VF.ttf"]
    for folder in (ROOT / "godot", ROOT / "assets/images/stage1_3d"):
        inputs.extend(
            path for path in folder.rglob("*")
            if path.is_file() and ".godot" not in path.parts
            and path.suffix != ".import"
        )
    digest = hashlib.sha256(VERSION.encode())
    for path in sorted(inputs):
        digest.update(str(path.relative_to(ROOT)).encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def godot_executable():
    configured = os.environ.get("GODOT_EXECUTABLE")
    if configured:
        return configured
    for candidate in (
        shutil.which("godot"),
        shutil.which("godot4"),
        ROOT / "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot",
        ROOT / "build/godot/tools/Godot.app/Contents/MacOS/Godot",
        ROOT / "build/godot/tools/godot",
    ):
        if candidate and Path(candidate).is_file():
            return str(candidate)
    raise RuntimeError(
        "Godot 4.7.2 실행 파일이 필요합니다. GODOT_EXECUTABLE을 지정하세요. "
        "Android 빌드 안내: docs/stage1_3d_preview.md"
    )


def run(command):
    completed = subprocess.run(
        command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if completed.returncode or re.search(
        r"(?:SCRIPT ERROR|Parse Error|^ERROR:)", completed.stdout, re.MULTILINE
    ):
        print(completed.stdout, file=sys.stderr)
        raise RuntimeError("Godot 전장 패키징에 실패했습니다.")
    return completed.stdout


def main():
    fingerprint = input_digest()
    if PACK.is_file() and STAMP.is_file():
        saved = json.loads(STAMP.read_text())
        if saved.get("inputs") == fingerprint:
            print(f"Godot 전장 팩 최신: {PACK}")
            return
    executable = godot_executable()
    version = run([executable, "--version"]).strip()
    if not version.startswith(VERSION + "."):
        raise RuntimeError(f"Android AAR와 같은 Godot {VERSION}이 필요합니다: {version}")
    run([sys.executable, str(ROOT / "scripts/prepare_godot_project.py")])
    PACK.parent.mkdir(parents=True, exist_ok=True)
    run([executable, "--headless", "--editor", "--path", str(PROJECT), "--import"])
    run([executable, "--headless", "--path", str(PROJECT), "--script", "res://export_licenses.gd"])
    run([executable, "--headless", "--path", str(PROJECT), "--export-pack", "Android Pack", str(PACK)])
    if not PACK.is_file() or PACK.stat().st_size == 0:
        raise RuntimeError("Godot 전장 팩이 생성되지 않았습니다.")
    STAMP.write_text(json.dumps({"inputs": fingerprint, "version": version}))
    print(f"Godot 전장 팩 생성: {PACK}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as error:
        sys.exit(str(error))
