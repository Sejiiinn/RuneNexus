"""build-only 후보를 다시 빌드하지 않고 공개해도 되는지 검사한다 (외부 패키지 불필요).

deploy-apk.yml의 promote 작업이 공개 직전에 실행한다. 후보 실행이 기록한 입력·패치 기준과
이번 공개 입력·현재 릴리스 목록을 대조하고, 후보 파일이 매니페스트와 정확히 일치하는지 본다.
하나라도 다르면 공개하지 않으며, 패치 기준이 바뀐 경우는 build-only부터 다시 실행해야 한다.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def published_bases(releases):
    """빌드 단계와 같은 규칙: 공개된 apk-<code> 중 최근 3개."""
    published = [
        (int(match.group(1)), release["tag_name"])
        for release in releases
        if not release["draft"] and release.get("published_at")
        and (match := re.fullmatch(r"apk-([1-9][0-9]*)", release["tag_name"]))
    ]
    return [tag for _, tag in sorted(published, reverse=True)[:3]]


def check_candidate(candidate, recorded, inputs, sha, releases):
    """공개할 수 없으면 이유 목록을 돌려준다. 빈 목록이면 공개 가능."""
    problems = []
    for key in ("version_code", "version_name", "notes", "required_update"):
        if recorded.get(key) != inputs[key]:
            problems.append(f"input {key} differs from the build-only run")
    if recorded.get("sha") != sha:
        problems.append("build-only run built a different commit")
    code = int(inputs["version_code"])
    tags = [release["tag_name"] for release in releases]
    previous = [int(m.group(1)) for tag in tags if (m := re.fullmatch(r"apk-(\d+)", tag))]
    if previous and code <= max(previous):
        problems.append("versionCode no longer exceeds every existing APK release")
    if published_bases(releases) != recorded.get("patch_base_tags"):
        problems.append("published releases changed since the build-only run; rebuild to refresh patches")

    manifest = json.loads((candidate / "update.json").read_text(encoding="utf-8"))
    if manifest.get("versionCode") != code or manifest.get("versionName") != inputs["version_name"] \
            or manifest.get("notes") != inputs["notes"]:
        problems.append("update.json does not match the release inputs")
    if inputs["required_update"] == "true" and manifest.get("minimumSupportedVersionCode") != code:
        problems.append("required update is not reflected in update.json")
    apk = candidate / "rune-nexus.apk"
    if not apk.is_file() or apk.stat().st_size != manifest.get("sizeBytes") or sha256(apk) != manifest.get("sha256"):
        problems.append("rune-nexus.apk does not match update.json")
    expected = {"rune-nexus.apk", "update.json"}
    for patch in manifest.get("patches", []):
        path = candidate / f"patch-from-{patch['fromVersionCode']}.rndelta"
        expected.add(path.name)
        if f"apk-{patch['fromVersionCode']}" not in recorded.get("patch_base_tags", []):
            problems.append(f"{path.name} is not based on a recorded release")
        if not path.is_file() or path.stat().st_size != patch["sizeBytes"] or sha256(path) != patch["sha256"]:
            problems.append(f"{path.name} does not match update.json")
    actual = {path.name for path in candidate.iterdir()}
    if actual != expected:
        problems.append(f"candidate files differ from update.json: {sorted(actual ^ expected)}")
    return problems


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--recorded-inputs", required=True, type=Path)
    parser.add_argument("--releases", required=True, type=Path, help="gh api --paginate --slurp 출력")
    parser.add_argument("--version-code", required=True)
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--notes-file", required=True, type=Path)
    parser.add_argument("--required-update", required=True, choices=["true", "false"])
    parser.add_argument("--sha", required=True)
    args = parser.parse_args()
    found = check_candidate(
        args.candidate,
        json.loads(args.recorded_inputs.read_text(encoding="utf-8")),
        {"version_code": args.version_code, "version_name": args.version_name,
         "notes": args.notes_file.read_text(encoding="utf-8"), "required_update": args.required_update},
        args.sha,
        [release for page in json.loads(args.releases.read_text()) for release in page],
    )
    if found:
        raise SystemExit("Cannot promote build-only candidate:\n- " + "\n- ".join(found))
    print("Build-only candidate matches the release inputs and current releases")
