#!/usr/bin/env python3
"""Isolated native auth/save regression + real loopback HTTPRequest smoke check.

No installed-app data, production API, credentials, or shared Godot project is used.
The hash oracle was produced by Dart jsonEncode(GameSaveData v2 fixture results).
Entries whose fixtures were rewritten for machinegun/flame turret IDs were
regenerated with the Godot hash; the rest are still the Dart values.
"""
from __future__ import annotations
import http.server
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading

from verify_godot_app_services import copy_with_references

ROOT = Path(__file__).resolve().parents[1]
ENGINE_ERROR = re.compile(r"(?:^|\n)(?:SCRIPT ERROR:|ERROR:)|Parse Error:|Compile Error:")
GODOT = Path(os.environ.get("GODOT_BIN", ROOT / "build/godot-preview/tools/Godot.app/Contents/MacOS/Godot"))

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0"))).decode()
        body = json.dumps({"received": raw, "key": self.headers.get("Idempotency-Key")}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *_args):
        pass

def main():
    if not GODOT.is_file():
        raise SystemExit("Godot is required; set GODOT_BIN. This check cannot pass by skipping.")
    with tempfile.TemporaryDirectory(prefix="rune-account-check-") as directory:
        project = Path(directory)
        environment = dict(os.environ, XDG_DATA_HOME=str(project / "user"), XDG_CACHE_HOME=str(project / "cache"), XDG_CONFIG_HOME=str(project / "config"))
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Isolated account checks"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        copy_with_references(project, ("tests/verify_account_services.gd", "tests/verify_durable_record.gd"))
        shutil.copyfile(ROOT / "godot/tests/verify_account_services.gd", project / "verify.gd")
        imported = subprocess.run([str(GODOT), "--headless", "--editor", "--path", str(project), "--quit"], env=environment, capture_output=True, text=True, timeout=60)
        if imported.returncode or ENGINE_ERROR.search(imported.stdout + imported.stderr):
            raise SystemExit(imported.stdout + imported.stderr)
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
            threading.Thread(target=server.serve_forever, daemon=True).start()
            env = dict(environment, RUNE_ACCOUNT_TEST_ROOT=str(project / "state"), RUNE_ACCOUNT_HASH_FIXTURE=str(ROOT / "test/fixtures/godot_account_payload_hashes.json"), RUNE_ACCOUNT_CODEC_FIXTURE=str(ROOT / "test/fixtures/godot_save_codec_expected.json"), RUNE_ACCOUNT_HTTP_FIXTURE=f"http://127.0.0.1:{server.server_port}")
            try:
                for script in ("tests/verify_durable_record.gd", "verify.gd"):
                    result = subprocess.run([str(GODOT), "--headless", "--path", str(project), "--script", script], env=env, capture_output=True, text=True, timeout=60)
                    print(result.stdout, end="")
                    print(result.stderr, end="")
                    if result.returncode or ENGINE_ERROR.search(result.stdout + result.stderr) or "PASS:" not in result.stdout:
                        raise SystemExit(result.returncode or 1)
            finally:
                server.shutdown()

if __name__ == "__main__":
    main()
