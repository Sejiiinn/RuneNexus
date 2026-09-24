#!/usr/bin/env python3
"""Isolated native auth/save regression + real loopback HTTPRequest smoke check.

No installed-app data, production API, credentials, or shared Godot project is used.
The hash oracle was produced by Dart jsonEncode(GameSaveData v2 fixture results).
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
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Isolated account checks"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for folder, files in {
            "app": ["save_codec.gd", "save_json.gd", "local_save_slot.gd", "local_save_store.gd"],
            "services": ["http_transport.gd", "durable_record.gd", "account_session.gd", "online_save.gd", "save_payload_hash.gd"],
        }.items():
            (project / folder).mkdir()
            for name in files:
                shutil.copyfile(ROOT / "godot" / folder / name, project / folder / name)
        shutil.copyfile(ROOT / "godot/verify_account_services.gd", project / "verify.gd")
        imported = subprocess.run([str(GODOT), "--headless", "--editor", "--path", str(project), "--quit"], capture_output=True, text=True, timeout=60)
        if imported.returncode or ENGINE_ERROR.search(imported.stdout + imported.stderr):
            raise SystemExit(imported.stdout + imported.stderr)
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
            threading.Thread(target=server.serve_forever, daemon=True).start()
            env = dict(os.environ, RUNE_ACCOUNT_TEST_ROOT=str(project / "state"), RUNE_ACCOUNT_HASH_FIXTURE=str(ROOT / "test/fixtures/godot_account_payload_hashes.json"), RUNE_ACCOUNT_CODEC_FIXTURE=str(ROOT / "test/fixtures/godot_save_codec_expected.json"), RUNE_ACCOUNT_HTTP_FIXTURE=f"http://127.0.0.1:{server.server_port}")
            try:
                result = subprocess.run([str(GODOT), "--headless", "--path", str(project), "--script", "verify.gd"], env=env, capture_output=True, text=True, timeout=60)
                print(result.stdout, end="")
                print(result.stderr, end="")
                if result.returncode or ENGINE_ERROR.search(result.stdout + result.stderr) or "PASS:" not in result.stdout:
                    raise SystemExit(result.returncode or 1)
            finally:
                server.shutdown()

if __name__ == "__main__":
    main()
