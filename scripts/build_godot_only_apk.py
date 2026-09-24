#!/usr/bin/env python3
"""Build the separate arm64 Godot-only inspection APK without Flutter tooling."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/godot-only"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reuse-pack", action="store_true", help="Use the existing prepared PCK without rebuilding it")
    parser.add_argument("--baseline-apk", type=Path, help="Optional prior APK for byte-size comparison")
    args = parser.parse_args()
    if not args.reuse_pack:
        subprocess.run(["python3", "scripts/build_godot_pack.py"], cwd=ROOT, check=True)
    pack = ROOT / "build/godot/android-assets/rune_nexus.pck"
    if not pack.is_file():
        raise SystemExit(f"Missing pack: {pack}")
    env = os.environ.copy()
    if not env.get("JAVA_HOME"):
        local_jdk = Path.home() / "development/jdk-17-temurin/Contents/Home"
        if local_jdk.is_dir():
            env["JAVA_HOME"] = str(local_jdk)
    if not env.get("ANDROID_HOME") and not env.get("ANDROID_SDK_ROOT"):
        properties = ROOT / "android-godot-only/local.properties"
        if properties.is_file():
            for line in properties.read_text().splitlines():
                if line.startswith("sdk.dir="):
                    env["ANDROID_HOME"] = line.split("=", 1)[1]
                    break
    # Incremental APK packaging can retain obsolete uncompressed PCK bytes.
    subprocess.run([
        str(ROOT / "android-godot-only/gradlew"), "-p", str(ROOT / "android-godot-only"),
        ":app:clean", ":app:assembleInspectionDebug", "--console=plain",
    ], cwd=ROOT, env=env, check=True)
    apk = OUTPUT / "rune-nexus-godot-only-arm64.apk"
    shutil.copy2(OUTPUT / "app/outputs/apk/inspection/debug/app-inspection-debug.apk", apk)
    with zipfile.ZipFile(apk) as archive:
        entries = archive.infolist()
        forbidden = [i.filename for i in entries if "flutter" in i.filename.lower() or i.filename.endswith("libapp.so")]
        dex_flutter = [i.filename for i in entries if i.filename.endswith(".dex") and b"Lio/flutter/" in archive.read(i)]
        if forbidden or dex_flutter:
            raise SystemExit(f"Flutter unexpectedly packaged: {forbidden + dex_flutter}")
        report = {
            "apk": str(apk.relative_to(ROOT)),
            "sizeBytes": apk.stat().st_size,
            "packageName": "com.example.rune_nexus.godotonly",
            "variant": "inspectionDebug", "debuggable": True,
            "abis": sorted({i.filename.split("/")[1] for i in entries if i.filename.startswith("lib/")}),
            "nativeCompressedBytes": sum(i.compress_size for i in entries if i.filename.startswith("lib/")),
            "godotPckCompressedBytes": sum(i.compress_size for i in entries if i.filename.endswith(".pck")),
            "flutterEntries": forbidden, "flutterDexReferences": dex_flutter,
            "nativeLibraries": [{"path": i.filename, "compressedBytes": i.compress_size} for i in entries if i.filename.startswith("lib/")],
        }
    if args.baseline_apk:
        size = args.baseline_apk.stat().st_size
        report["baseline"] = {"path": str(args.baseline_apk), "sizeBytes": size,
            "deltaBytes": apk.stat().st_size - size,
            "deltaPercent": round((apk.stat().st_size / size - 1) * 100, 2)}
    (OUTPUT / "apk-audit.json").write_text(json.dumps(report, indent=2) + "\n")
    subprocess.run(["python3", "scripts/audit_godot_pack.py", str(apk), "--output", str(OUTPUT / "pck-audit.json")], cwd=ROOT, check=True)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
