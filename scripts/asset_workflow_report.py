#!/usr/bin/env python3
"""기존 에셋 제작 경로와 출력 파일을 요약한다. 제작·검증 명령은 실행하지 않는다."""

import argparse
import hashlib
import json
from pathlib import Path
import re
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


def _field(document, keys):
    for key in keys:
        document = document[key]
    return document


def _summary(items):
    statuses = [item["status"] for item in items]
    return "mismatch" if "mismatch" in statuses else (
        "unknown" if not statuses or "unknown" in statuses else "matched")


def _record_paths(recipe):
    return recipe.get("records", [link["path"] for link in recipe.get("record_links", []) if link.get("path")])


def verify_records(root, recipe, outputs):
    """명시된 파일과 기록 필드만 대조한다. 서명·시각 검수는 실행하지 않는다."""
    cache = {str((root / item["path"]).resolve()): item for item in outputs}
    documents = {}
    record_hashes = {}
    links = recipe.get("record_links", [])
    for link in links:
        if not link.get("bindings") or not link.get("path"):
            continue
        try:
            document = json.loads((root / link["path"]).read_text())
            documents[link["path"]] = document
        except (OSError, ValueError):
            continue
        if recipe.get("expected_hashes_from_records"):
            for binding in link["bindings"]:
                try:
                    digest = _field(document, binding["sha256_field"])
                except (KeyError, IndexError, TypeError):
                    continue
                if isinstance(digest, str) and re.fullmatch(r"[0-9a-fA-F]{64}", digest):
                    record_hashes.setdefault(binding["target"], {
                        "sha256": digest, "path": link["path"], "field": binding["sha256_field"]})

    def identity(spec, target):
        path = spec.get("path")
        result = dict(spec, status="unknown")
        if not path:
            return dict(result, reason="missing_path")
        key = str((root / path).resolve())
        try:
            if key not in cache:
                cache[key] = file_info(root, path, True)
            result.update(cache[key], path=path)
        except OSError as error:
            return dict(result, reason="unreadable_file", error=str(error))
        if "error" in result:
            return dict(result, reason="unreadable_file")
        if not result["exists"]:
            parts = Path(path).parts
            unmounted = len(parts) > 2 and parts[1] == "Volumes" and not Path(*parts[:3]).exists()
            return dict(result, reason="unmounted_volume" if unmounted else "missing_file")
        expected = spec.get("sha256")
        if not expected and target in record_hashes:
            expected = record_hashes[target]["sha256"]
            result["expected_record"] = record_hashes[target]
        result["actual_sha256"] = result["sha256"]
        result["expected_sha256"] = expected
        if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", expected):
            return dict(result, status="unknown", reason="missing_or_invalid_expected_sha256")
        return dict(result, status="matched" if expected.lower() == result["sha256"] else "mismatch",
                    reason="sha256_equal" if expected.lower() == result["sha256"] else "sha256_changed")

    artifacts = {"source": identity({"path": recipe["source"], "sha256": recipe.get("source_sha256")}, "source")}
    accepted = recipe.get("accepted_source", recipe.get("approved_source"))
    artifacts["accepted"] = identity({"path": accepted, "sha256": recipe.get(
        "accepted_source_sha256", recipe.get("approved_source_sha256"))}, "accepted")
    for spec in recipe.get("record_inputs", []):
        artifacts[spec["id"]] = identity(spec, spec["id"])
    runtime_specs = recipe.get("runtime_outputs", [{"path": path} for path in recipe["outputs"]]
                               if recipe.get("expected_hashes_from_records") else [])
    runtime = [identity(spec, spec.get("path")) for spec in runtime_specs]
    artifacts.update({item["path"]: item for item in runtime if item.get("path")})
    declared = {item.get("path") for item in runtime_specs}
    coverage = [{"path": path, "status": "unknown", "reason": "runtime_identity_not_registered"}
                for path in recipe["outputs"] if path not in declared]
    coverage += [{"path": path, "status": "mismatch", "reason": "runtime_path_not_in_recipe_outputs"}
                 for path in declared if path not in recipe["outputs"]]
    records = []
    for link in links:
        record = dict(link, status="unknown", comparisons=[])
        path = link.get("path")
        if not path or not (root / path).is_file():
            records.append(dict(record, reason="missing_record"))
            continue
        if not link.get("bindings"):
            records.append(dict(record, reason="no_identity_binding"))
            continue
        try:
            document = documents[path] if path in documents else json.loads((root / path).read_text())
        except (OSError, ValueError) as error:
            records.append(dict(record, reason="unreadable_record", error=str(error)))
            continue
        for binding in link["bindings"]:
            comparison = dict(binding, status="unknown")
            target = artifacts.get(binding["target"])
            try:
                digest = _field(document, binding["sha256_field"])
                comparison["recorded_sha256"] = digest
                if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
                    comparison["reason"] = "missing_or_invalid_record_sha256"
                elif not target:
                    comparison["reason"] = "unregistered_target"
                elif not target.get("actual_sha256"):
                    comparison["reason"] = "target_unavailable"
                else:
                    comparison.update(status="matched" if digest.lower() == target["actual_sha256"]
                                      else "mismatch", reason="record_sha256_equal" if digest.lower()
                                      == target["actual_sha256"] else "record_sha256_changed")
            except (KeyError, IndexError, TypeError):
                comparison.update(status="unknown", reason="missing_record_field")
            if "path_field" in binding:
                try:
                    recorded_path = _field(document, binding["path_field"])
                    comparison["recorded_path"] = recorded_path
                    if not isinstance(recorded_path, str) or not recorded_path or not target:
                        if comparison["status"] != "mismatch":
                            comparison.update(status="unknown", reason="missing_record_path_or_target")
                    else:
                        base = (root / path).parent if binding.get("path_base") == "record" else root
                        if (base / recorded_path).resolve() != (root / target["path"]).resolve():
                            comparison.update(status="mismatch", reason="record_path_changed")
                except (KeyError, IndexError, TypeError):
                    if comparison["status"] != "mismatch":
                        comparison.update(status="unknown", reason="missing_record_path_field")
            record["comparisons"].append(comparison)
        record["status"] = _summary(record["comparisons"])
        record["signature_verification"] = "not_run"
        records.append(record)
    registered = {link.get("path") for link in links}
    records += [{"path": path, "status": "unknown", "reason": "record_binding_not_registered"}
                for path in _record_paths(recipe) if path not in registered]
    if not records:
        records.append({"status": "unknown", "reason": "no_records_registered"})
    references = []
    for reference in recipe.get("runtime_references", []):
        result = dict(reference, status="unknown")
        try:
            text = (root / reference["path"]).read_text()
            if reference["output"] not in declared:
                result.update(status="mismatch", reason="reference_output_not_registered")
            else:
                result.update(status="matched" if reference["token"] in text else "mismatch",
                              reason="loader_token_present" if reference["token"] in text else "loader_token_missing")
        except OSError:
            result["reason"] = "missing_loader_file"
        references.append(result)
    if not references:
        references.append({"status": "unknown", "reason": "runtime_loader_not_registered"})
    prerequisites = [{"path": path, "status": "unknown", "reason": "missing_workflow_file"}
                     for path in [recipe["guide"]] + [step["script"] for step in recipe["steps"]] + recipe["checks"]
                     if not (root / path).is_file()]
    return {"status": _summary(list(artifacts.values()) + coverage + records + references + prerequisites),
            "source": artifacts["source"], "accepted": artifacts["accepted"],
            "record_inputs": [artifacts[spec["id"]] for spec in recipe.get("record_inputs", [])],
            "runtime_outputs": runtime, "recipe_coverage": coverage,
            "missing_prerequisites": prerequisites,
            "records": records, "runtime_references": references,
            "scope": "registered file identity and literal loader references only; visual review, signed receipts, prepared project and packaging not verified"}


def collect(root, asset, with_records=False):
    workflows = json.loads((root / CATALOG).read_text())["workflows"]
    if asset not in workflows:
        raise ValueError(f"알 수 없는 에셋: {asset}. 선택: {', '.join(workflows)}")
    recipe = workflows[asset]
    required = [recipe["source"], recipe["guide"]]
    required += [step["script"] for step in recipe["steps"]]
    required += recipe["checks"]
    def observed_info(path, with_hash=False):
        try:
            return file_info(root, path, with_hash)
        except OSError as error:
            if not with_records:
                raise
            return {"path": path, "exists": False, "error": str(error)}

    outputs = [observed_info(p, True) for p in recipe["outputs"]]
    inputs = [observed_info(p) for p in required]
    report = {
        "asset": asset,
        "status": "files_present" if all(p["exists"] for p in inputs + outputs)
        else "missing_files",
        "recipe": recipe,
        "inputs": inputs,
        "outputs": outputs,
        "output_bytes": sum(p.get("bytes", 0) for p in outputs),
        "records": [observed_info(p) for p in _record_paths(recipe)],
        "validation": "not_run",
        "record_freshness": "not_verified",
        "packaging_command": "python3 scripts/build_godot_pack.py",
        "verification_context": "headless checks는 준비된 build/godot/project에서 실행. "
        "실제 화면·Android 확인은 .agents/in_app_test_guide.md 참조.",
    }
    if with_records:
        report["record_verification"] = verify_records(root, recipe, outputs)
        report["record_freshness"] = report["record_verification"]["status"]
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("asset", nargs="?", help="생략하면 등록된 경로 이름만 표시")
    parser.add_argument("--json-out", type=Path, help="상세 JSON 저장 경로")
    parser.add_argument("--verify-records", action="store_true", help="등록된 SHA·기록 연결만 읽기 전용 대조 (0 일치 / 1 불일치 / 2 미확인)")
    args = parser.parse_args(argv)
    try:
        if not args.asset:
            if args.verify_records:
                parser.error("--verify-records에는 에셋 ID가 필요합니다")
            workflows = json.loads((ROOT / CATALOG).read_text())["workflows"]
            for name, recipe in workflows.items():
                print(f"{name}: {recipe['guide']}")
            return 0
        report = collect(ROOT, args.asset, args.verify_records)
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
        print("미실행: 제작·패키징·시각 검증·receipt 서명 검증.")
        if args.verify_records:
            verification = report["record_verification"]
            print(f"기록 대응: {verification['status']} (검수 PASS 판정 아님)")
            for group in ("source", "accepted"):
                item = verification[group]
                print(f"  {group}: {item['status']} / {item.get('path')} / {item['reason']}")
            for item in verification["record_inputs"] + verification["runtime_outputs"] + verification["recipe_coverage"] + verification["records"] + verification["runtime_references"] + verification["missing_prerequisites"]:
                print(f"  {item['status']}: {item.get('path', '(미등록)')} / {item.get('reason', 'record_fields_compared')}")
        else:
            print("기존 기록의 현재 출력 대응은 미확인.")
        print("한계: " + recipe["limitation"])
        missing = [p["path"] for p in report["inputs"] + report["outputs"] if not p["exists"]]
        if missing:
            print("누락: " + ", ".join(missing), file=sys.stderr)
        if args.json_out:
            print(f"상세: {args.json_out}")
        if args.verify_records:
            return {"matched": 0, "mismatch": 1, "unknown": 2}[report["record_verification"]["status"]]
        return 1 if missing else 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"에셋 요약 실패: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
