#!/usr/bin/env python3
"""Native account/app orchestration, isolated from real app data and APIs."""
from __future__ import annotations
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "godot"
ENGINE_ERROR = re.compile(r"(?:^|\n)(?:SCRIPT ERROR:|ERROR:)|Parse Error:|Compile Error:")
SCRIPTS = {"verify_app_services.gd": "APP_SERVICES failures=0",
           "verify_background_receipt.gd": "BACKGROUND_RECEIPT failures=0",
           "verify_mailbox_notifications.gd": "MAILBOX_NOTIFICATIONS checks="}
GODOT = Path(os.environ.get("GODOT_BIN", ROOT / "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot"))

def main():
    if not GODOT.is_file(): raise SystemExit("Set GODOT_BIN; native checks cannot be skipped.")
    with tempfile.TemporaryDirectory(prefix="rune-app-services-") as directory:
        project=Path(directory)
        environment=dict(os.environ, RUNE_APP_TEST_ROOT=str(project / "state"),
                         XDG_DATA_HOME=str(project / "user"),
                         XDG_CACHE_HOME=str(project / "cache"),
                         XDG_CONFIG_HOME=str(project / "config"))
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Isolated app services"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        pending=list(SCRIPTS)
        seen=set()
        while pending:
            relative=pending.pop()
            if relative in seen: continue
            seen.add(relative)
            origin=SOURCE / relative
            if not origin.is_file(): continue
            destination=project / relative
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(origin,destination)
            if origin.suffix == ".gd":
                pending.extend(re.findall(r'["\']res://([^"\']+)["\']',origin.read_text()))
        imported=subprocess.run([str(GODOT),"--headless","--editor","--path",str(project),"--quit"],env=environment,capture_output=True,text=True,timeout=90)
        if imported.returncode or ENGINE_ERROR.search(imported.stdout + imported.stderr): raise SystemExit(imported.stdout+imported.stderr)
        for script, marker in SCRIPTS.items():
            try:
                result=subprocess.run([str(GODOT),"--headless","--path",str(project),"--script",script],env=environment,capture_output=True,text=True,timeout=90)
            except subprocess.TimeoutExpired as error:
                raise SystemExit(f"{script} timed out: {error.stdout!r} {error.stderr!r}") from error
            print(result.stdout,end="");print(result.stderr,end="")
            if result.returncode or ENGINE_ERROR.search(result.stdout + result.stderr) or marker not in result.stdout: raise SystemExit(result.returncode or 1)

if __name__ == "__main__": main()
