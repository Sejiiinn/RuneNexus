#!/usr/bin/env python3
"""Claude가 구현한 변경을 Codex(gpt-6-astra, high)에게 독립 검증받는다.

  codex_verify.py --prompt-file <검증 요청.md> --out <보고서.md> [--timeout 3600]

Codex는 저장소 루트에서 workspace-write 샌드박스로 실행한다(검사 실행에 필요한 build/·/tmp 쓰기).
실행 전후의 작업 트리 상태를 비교해 Codex가 바꾼 추적·미추적 파일을 함께 보고한다.
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

MODEL = "gpt-6-astra"  # 사용자 지정. 다른 모델로 바꾸지 않는다.
EFFORT = "high"


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, check=True).stdout


def tree_state(root):
    """경로별 상태와 내용 해시. 수정된 파일의 추가 변경도 잡는다."""
    state = {}
    entries = iter(git(root, "status", "--porcelain=v1", "-uall", "-z").split("\0"))
    for line in entries:
        if not line:
            continue
        if line[0] in "RC":
            next(entries, None)  # -z 출력에서 이름 변경의 원래 경로는 다음 항목이다.
        path = line[3:]
        file = root / path
        digest = hashlib.sha256(file.read_bytes()).hexdigest() if file.is_file() else "-"
        state[path] = (line[:2], digest)
    return state


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt-file", required=True)
    parser.add_argument("--out", required=True, help="Codex 최종 보고서 경로")
    parser.add_argument("--timeout", type=int, default=3600, help="제한 시간(초)")
    args = parser.parse_args()

    root = Path(git(Path.cwd(), "rev-parse", "--show-toplevel").strip())
    prompt = Path(args.prompt_file).read_text(encoding="utf-8")
    before_head = git(root, "rev-parse", "HEAD").strip()
    before = tree_state(root)

    cmd = ["codex", "exec", "-m", MODEL, "-c", f"model_reasoning_effort={EFFORT}",
           "-s", "workspace-write", "-C", str(root), "--ephemeral", "-o", args.out, "-"]
    try:
        proc = subprocess.run(cmd, input=prompt, capture_output=True, text=True, timeout=args.timeout)
        exit_code, error = proc.returncode, proc.stderr[-2000:] if proc.returncode else ""
    except subprocess.TimeoutExpired:
        exit_code, error = None, f"timeout after {args.timeout}s"

    after = tree_state(root)
    changed = sorted(p for p in set(before) | set(after) if before.get(p) != after.get(p))
    report = Path(args.out)
    result = {
        "ok": exit_code == 0 and report.is_file(),
        "codex_exit": exit_code,
        "error": error,
        "report": str(report) if report.is_file() else None,
        "head_changed": git(root, "rev-parse", "HEAD").strip() != before_head,
        "worktree_changed_by_codex": changed,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
