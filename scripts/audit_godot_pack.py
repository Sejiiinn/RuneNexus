#!/usr/bin/env python3
"""Read-only Godot 4 PCK v4 inventory, including packs inside APK ZIPs.

Reports logical duplicate bytes separately from repeated physical payload ranges.
No size thresholds are imposed, and no archive paths are extracted.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import shutil
import struct
import tempfile
import zipfile


class PackError(ValueError):
    """Unsupported or malformed pack."""


def _read(stream, count):
    data = stream.read(count)
    if len(data) != count:
        raise PackError("Truncated PCK")
    return data


def audit_stream(stream, source="<stream>", largest=20):
    stream.seek(0, 2)
    pack_bytes = stream.tell()
    stream.seek(0)
    magic, version, major, minor, patch, flags, base, directory = struct.unpack(
        "<6I2Q", _read(stream, 40))
    if magic != 0x43504447 or version != 4:
        raise PackError("Expected standalone GDPC format version 4")
    if flags & ~2:
        raise PackError(f"Unsupported PCK flags: {flags:#x}")
    if not 40 <= directory <= pack_bytes - 4 or not 40 <= base <= pack_bytes:
        raise PackError("Invalid directory or data base offset")
    stream.seek(directory)
    count, = struct.unpack("<I", _read(stream, 4))
    if count > (pack_bytes - directory - 4) // 44:
        raise PackError("Impossible file count")
    entries = []
    paths = set()
    for _ in range(count):
        length, = struct.unpack("<I", _read(stream, 4))
        if length == 0 or length > 1024 * 1024 or length > pack_bytes - stream.tell() - 36:
            raise PackError("Invalid path length")
        raw_path = _read(stream, length)
        try:
            path = raw_path.rstrip(b"\0").decode("utf-8")
        except UnicodeDecodeError as error:
            raise PackError("Invalid UTF-8 path") from error
        if not path or "\0" in path or path in paths:
            raise PackError("Empty, embedded-NUL or duplicate path")
        paths.add(path)
        offset, size, md5, file_flags = struct.unpack("<2Q16sI", _read(stream, 36))
        if file_flags:
            raise PackError(f"Unsupported flags for {path}: {file_flags:#x}")
        absolute = base + offset
        if absolute > pack_bytes or size > pack_bytes - absolute:
            raise PackError(f"Out-of-bounds payload: {path}")
        entries.append({"path": path, "bytes": size, "offset": absolute,
                        "directory_md5": md5.hex()})
    directory_end = stream.tell()
    cache = {}
    for entry in entries:
        start, size = entry["offset"], entry["bytes"]
        if size and (start < 40 or (start < directory_end and start + size > directory)):
            raise PackError(f"Payload overlaps metadata: {entry['path']}")
        key = (start, size)
        if key not in cache:
            stream.seek(start)
            sha = hashlib.sha256()
            remaining = size
            while remaining:
                data = _read(stream, min(remaining, 1024 * 1024))
                sha.update(data)
                remaining -= len(data)
            cache[key] = sha.hexdigest()
        entry["sha256"] = cache[key]
    groups = defaultdict(list)
    for entry in entries:
        groups[(entry["sha256"], entry["bytes"])].append(entry)
    duplicate_groups = []
    for (sha, size), group in groups.items():
        if len(group) < 2 or not size:
            continue
        ranges = {(entry["offset"], size) for entry in group}
        duplicate_groups.append({
            "sha256": sha, "bytes_each": size, "count": len(group),
            "logical_duplicate_bytes": (len(group) - 1) * size,
            "distinct_payload_ranges": len(ranges),
            "distinct_range_duplicate_bytes": (len(ranges) - 1) * size,
            "paths": sorted(entry["path"] for entry in group),
        })
    duplicate_groups.sort(key=lambda group: (-group["logical_duplicate_bytes"], group["sha256"]))
    return {
        "source": str(source), "format_version": version,
        "engine_version": f"{major}.{minor}.{patch}", "pack_bytes": pack_bytes,
        "entry_count": count, "logical_payload_bytes": sum(e["bytes"] for e in entries),
        "logical_duplicate_bytes": sum(g["logical_duplicate_bytes"] for g in duplicate_groups),
        "distinct_range_duplicate_bytes": sum(g["distinct_range_duplicate_bytes"] for g in duplicate_groups),
        "duplicate_metric_note": "Logical bytes count every path; distinct-range bytes exclude identical offset aliases. Neither predicts export savings or accounts for partially overlapping ranges.",
        "duplicate_groups": duplicate_groups,
        "largest_items": sorted(entries, key=lambda e: (-e["bytes"], e["path"]))[:largest],
        "entries": sorted(entries, key=lambda e: e["path"]),
    }


def audit_path(path, member=None, largest=20):
    path = Path(path)
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as archive:
            candidates = [i for i in archive.infolist() if i.filename.endswith(".pck")]
            if member is not None:
                candidates = [i for i in candidates if i.filename == member]
            if len(candidates) != 1:
                raise PackError("APK must contain exactly one selected PCK; use --member")
            info = candidates[0]
            with archive.open(info) as packed, tempfile.TemporaryFile() as stream:
                shutil.copyfileobj(packed, stream, 1024 * 1024)
                result = audit_stream(stream, f"{path}!{info.filename}", largest)
            result["archive_bytes"] = path.stat().st_size
            result["member_compressed_bytes"] = info.compress_size
            return result
    if member is not None:
        raise PackError("--member requires a ZIP/APK")
    with path.open("rb") as stream:
        return audit_stream(stream, path, largest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--member")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--largest", type=int, default=20)
    args = parser.parse_args()
    if args.largest < 0:
        parser.error("--largest must be nonnegative")
    try:
        report = audit_path(args.input, args.member, args.largest)
    except (OSError, PackError, zipfile.BadZipFile) as error:
        parser.exit(1, f"PCK audit failed: {error}\n")
    text = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
