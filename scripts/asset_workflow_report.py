#!/usr/bin/env python3
"""기존 에셋 제작 경로와 출력 파일을 요약한다. 제작·검증 명령은 실행하지 않는다."""

import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
CATALOG = Path("design/stage1_3d/blender_workspace/catalog.json")


def file_info(root, relative, with_hash=False):
    path = root / relative
    result = {"path": relative, "exists": path.is_file()}
    if result["exists"]:
        result["bytes"] = path.stat().st_size
        if with_hash:
            digest = hashlib.sha256()
            with path.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            result["sha256"] = digest.hexdigest()
    return result


def collect(root, asset):
    workflows = json.loads((root / CATALOG).read_text())["workflows"]
    if asset not in workflows:
        raise ValueError(f"알 수 없는 에셋: {asset}. 선택: {', '.join(workflows)}")
    recipe = workflows[asset]
    required = [recipe["source"], recipe["guide"]]
    required += [step["script"] for step in recipe["steps"]]
    required += recipe["checks"]
    outputs = [file_info(root, p, True) for p in recipe["outputs"]]
    inputs = [file_info(root, p) for p in required]
    return {
        "asset": asset,
        "status": "files_present" if all(p["exists"] for p in inputs + outputs)
        else "missing_files",
        "recipe": recipe,
        "inputs": inputs,
        "outputs": outputs,
        "output_bytes": sum(p.get("bytes", 0) for p in outputs),
        "records": [file_info(root, p) for p in recipe["records"]],
        "validation": "not_run",
        "record_freshness": "not_verified",
        "packaging_command": "python3 scripts/build_godot_pack.py",
        "verification_context": "headless checks는 준비된 build/godot/project에서 실행. "
        "실제 화면·Android 확인은 .agents/in_app_test_guide.md 참조.",
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("asset", nargs="?", help="생략하면 등록된 경로 이름만 표시")
    parser.add_argument("--json-out", type=Path, help="상세 JSON 저장 경로")
    args = parser.parse_args(argv)
    try:
        if not args.asset:
            workflows = json.loads((ROOT / CATALOG).read_text())["workflows"]
            for name, recipe in workflows.items():
                print(f"{name}: {recipe['guide']}")
            return 0
        report = collect(ROOT, args.asset)
        if args.json_out:
            args.json_out.parent.mkdir(parents=True, exist_ok=True)
            args.json_out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        recipe = report["recipe"]
        print(f"{args.asset}: {report['status']} / 출력 {report['output_bytes']:,} B")
        print(f"원본: {recipe['source']}\n안내: {recipe['guide']}")
        for step in recipe["steps"]:
            print(f"제작: {step['script']} → {step['entrypoint']}")
            print(f"  {step['context']}")
        print(f"패키징: {report['packaging_command']}")
        print("관련 검사: " + ", ".join(recipe["checks"]))
        print("미실행: 제작·패키징·검증. 기존 기록의 현재 출력 대응은 미확인.")
        print("한계: " + recipe["limitation"])
        missing = [p["path"] for p in report["inputs"] + report["outputs"] if not p["exists"]]
        if missing:
            print("누락: " + ", ".join(missing), file=sys.stderr)
        if args.json_out:
            print(f"상세: {args.json_out}")
        return 1 if missing else 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"에셋 요약 실패: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
