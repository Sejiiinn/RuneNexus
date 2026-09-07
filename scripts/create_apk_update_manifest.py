"""APK 직접 배포용 업데이트 메타데이터 생성 (외부 패키지 불필요)."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile


def create_manifest(
    apk, version_code, version_name, repository, notes, existing_tags,
    base_releases=(), patch_output_dir=None,
):
    if not 1 <= version_code <= 2_100_000_000:
        raise ValueError("versionCode must be between 1 and 2100000000")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Invalid GitHub repository")
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version_name):
        raise ValueError("versionName must use x.y.z format")
    previous_codes = [
        int(match.group(1))
        for tag in existing_tags
        if (match := re.fullmatch(r"apk-(\d+)", tag.strip()))
    ]
    if previous_codes and version_code <= max(previous_codes):
        raise ValueError("versionCode must exceed every existing APK release")
    size = apk.stat().st_size
    if not 1 <= size <= 512 * 1024 * 1024:
        raise ValueError("APK size must be between 1 byte and 512 MiB")
    digest = hashlib.sha256()
    with apk.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    manifest = {
        "schemaVersion": 1,
        "versionCode": version_code,
        "versionName": version_name,
        "packageName": "com.example.rune_nexus",
        "apkUrl": f"https://github.com/{repository}/releases/download/apk-{version_code}/rune-nexus.apk",
        "sha256": digest.hexdigest(),
        "sizeBytes": size,
        "notes": notes,
    }
    if base_releases:
        if len(base_releases) > 3 or patch_output_dir is None:
            raise ValueError("At most three base releases and a patch output directory are required")
        patches = create_release_patches(apk, manifest, base_releases, patch_output_dir, repository)
        if patches:
            manifest["patches"] = patches
    # 앱 수신 한도와 동일한 UTF-8 바이트 기준
    encoded = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    if len(encoded) > 64 * 1024:
        raise ValueError("Update manifest must not exceed 64 KiB in UTF-8")
    return manifest


def create_release_patches(apk, target, base_releases, output_dir, repository):
    from apk_delta import apply_patch, create_patch

    patches = []
    seen_versions = set()
    output_dir.mkdir(parents=True, exist_ok=True)
    for base_dir in base_releases:
        match = re.fullmatch(r"apk-([1-9][0-9]*)", base_dir.name)
        if not match:
            raise ValueError("Base directory must use the release tag apk-<versionCode>")
        version = int(match.group(1))
        if version >= target["versionCode"] or version in seen_versions:
            raise ValueError("Base versions must be distinct and older than the target")
        seen_versions.add(version)
        raw = (base_dir / "update.json").read_bytes()
        if len(raw) > 65536:
            raise ValueError("Base manifest exceeds 64 KiB")
        base = json.loads(raw)
        expected_url = f"https://github.com/{repository}/releases/download/apk-{version}/rune-nexus.apk"
        if (
            not isinstance(base, dict)
            or type(base.get("schemaVersion")) is not int
            or base["schemaVersion"] != 1
            or type(base.get("versionCode")) is not int
            or base["versionCode"] != version
            or base.get("packageName") != target["packageName"]
            or base.get("apkUrl") != expected_url
            or not isinstance(base.get("sha256"), str)
            or not re.fullmatch(r"[0-9a-f]{64}", base["sha256"])
            or type(base.get("sizeBytes")) is not int
            or not 1 <= base["sizeBytes"] <= 512 * 1024 * 1024
        ):
            raise ValueError(f"Invalid metadata for base release apk-{version}")
        base_apk = base_dir / "rune-nexus.apk"
        if base_apk.stat().st_size != base["sizeBytes"]:
            raise ValueError(f"Base APK size mismatch: apk-{version}")
        digest = hashlib.sha256()
        with base_apk.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != base["sha256"]:
            raise ValueError(f"Base APK hash mismatch: apk-{version}")

        # 게시 전 실제 패치 적용 결과를 최종 APK와 대조
        with tempfile.TemporaryDirectory() as directory:
            patch = Path(directory) / f"patch-from-{version}.rndelta"
            restored = Path(directory) / "restored.apk"
            create_patch(base_apk, apk, patch)
            apply_patch(base_apk, patch, restored)
            restored_digest = hashlib.sha256()
            with restored.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    restored_digest.update(chunk)
            if restored.stat().st_size != target["sizeBytes"] or restored_digest.hexdigest() != target["sha256"]:
                raise ValueError(f"Patch reconstruction mismatch: apk-{version}")
            if patch.stat().st_size * 10 >= target["sizeBytes"] * 9:
                continue
            patch_size = patch.stat().st_size
            patch_digest = hashlib.sha256()
            with patch.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    patch_digest.update(chunk)
            shutil.copyfile(patch, output_dir / patch.name)
            patches.append({
                "format": "rune-apk-delta-v1",
                "fromVersionCode": version,
                "fromSha256": base["sha256"],
                "url": f"https://github.com/{repository}/releases/download/apk-{target['versionCode']}/{patch.name}",
                "sha256": patch_digest.hexdigest(),
                "sizeBytes": patch_size,
            })
    return patches


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--version-code", required=True, type=int)
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--notes-file", required=True, type=Path)
    parser.add_argument("--existing-tags-file", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--base-releases-dir", type=Path)
    args = parser.parse_args()
    bases = sorted(args.base_releases_dir.glob("apk-*")) if args.base_releases_dir else []
    manifest = create_manifest(
        args.apk, args.version_code, args.version_name, args.repository,
        args.notes_file.read_text(encoding="utf-8"),
        args.existing_tags_file.read_text(encoding="utf-8").splitlines(),
        bases, args.output.parent,
    )
    args.output.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
