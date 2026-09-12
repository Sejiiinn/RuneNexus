#!/usr/bin/env python3
"""실제 APK ZIP 압축 크기와 ABI·에셋 기여도를 보존하는 검증 기록."""
import hashlib
import json
from collections import defaultdict
from pathlib import Path
import sys
import struct
import zipfile

apk = Path(sys.argv[1])
destination = Path(sys.argv[2])
groups = defaultdict(lambda: {"compressed_bytes": 0, "uncompressed_bytes": 0, "entries": 0})
with zipfile.ZipFile(apk) as archive:
    entries = []
    for item in archive.infolist():
        name = item.filename
        group = (
            "/".join(name.split("/")[:2]) if name.startswith("lib/")
            else "godot_pck" if name.endswith(".pck")
            else "flutter_stage1_3d" if name.startswith("assets/flutter_assets/assets/images/stage1_3d/")
            else "flutter_assets" if name.startswith("assets/flutter_assets/")
            else "other"
        )
        groups[group]["compressed_bytes"] += item.compress_size
        groups[group]["uncompressed_bytes"] += item.file_size
        groups[group]["entries"] += 1
        entries.append({"name": name, "compressed_bytes": item.compress_size, "uncompressed_bytes": item.file_size})
    pck_entries = []
    for entry in entries:
        if not entry["name"].endswith(".pck"):
            continue
        payload = archive.read(entry["name"])
        assert payload[:4] == b"GDPC" and struct.unpack_from("<I", payload, 4)[0] == 4
        file_base, directory_offset = struct.unpack_from("<QQ", payload, 24)
        count = struct.unpack_from("<I", payload, directory_offset)[0]
        cursor = directory_offset + 4
        files = []
        for _ in range(count):
            length = struct.unpack_from("<I", payload, cursor)[0]
            cursor += 4
            name = payload[cursor:cursor + length].rstrip(b"\0").decode()
            cursor += length
            offset, size = struct.unpack_from("<QQ", payload, cursor)
            digest = payload[cursor + 16:cursor + 32]
            flags = struct.unpack_from("<I", payload, cursor + 32)[0]
            cursor += 36
            data = payload[file_base + offset:file_base + offset + size]
            assert len(data) == size and hashlib.md5(data).digest() == digest, name
            files.append({"name": name, "size_bytes": size, "flags": flags})
        assert cursor <= len(payload)
        pck_entries.append(dict(entry, sha256=hashlib.sha256(payload).hexdigest(), files=files))

result = {
    "apk_path": str(apk),
    "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
    "size_bytes": apk.stat().st_size,
    "groups": dict(groups),
    "abis": sorted(group.removeprefix("lib/") for group in groups if group.startswith("lib/")),
    "native_libraries": [entry for entry in entries if entry["name"].startswith("lib/")],
    "pck": pck_entries,
    "stage1_glb": [entry for entry in entries if "/stage1_3d/" in entry["name"] and entry["name"].endswith(".glb")],
    "largest_entries": sorted(entries, key=lambda entry: entry["compressed_bytes"], reverse=True)[:20],
    "design_files_in_apk": [entry for entry in entries if entry["name"].startswith("design/") or "/design/" in entry["name"]],
    "all_entries": entries,
}
destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({key: value for key, value in result.items() if key not in ("all_entries", "largest_entries", "stage1_glb")}, ensure_ascii=False, indent=2))
